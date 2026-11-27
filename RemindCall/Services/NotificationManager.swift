import Foundation
import SwiftData
import UserNotifications

extension Notification.Name {
    static let openContactKey = Notification.Name("openContactKey")
}

/// 통화 후 메모 알림, 생일 알림. 모두 로컬 알림이며 서버를 쓰지 않는다.
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private var container: ModelContainer?
    private let center = UNUserNotificationCenter.current()
    /// iOS는 예약 알림을 64개까지만 허용한다. 생일은 50개, 나머지는 통화 후 알림 몫.
    private let birthdayLimit = 50

    func setup(container: ModelContainer) {
        self.container = container
        center.delegate = self
        let addNote = UNTextInputNotificationAction(
            identifier: "ADD_NOTE", title: L("메모 남기기"), options: [],
            textInputButtonTitle: L("저장"), textInputPlaceholder: L("통화 내용을 한 줄로")
        )
        let category = UNNotificationCategory(identifier: "POST_CALL", actions: [addNote],
                                              intentIdentifiers: [], options: [])
        center.setNotificationCategories([category])
    }

    func requestAuthorization() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        default:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        }
    }

    // MARK: 통화 후 메모 알림

    func schedulePostCall(name: String, phoneKey: String, afterMinutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = L("\(name)님과 통화는 어땠나요?")
        content.body = L("알림을 길게 눌러 메모를 바로 남겨 보세요.")
        content.categoryIdentifier = "POST_CALL"
        content.userInfo = ["phoneKey": phoneKey]
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(max(1, afterMinutes) * 60), repeats: false)
        // 같은 사람에게 연달아 걸면 마지막 알림 하나만 남긴다.
        center.add(UNNotificationRequest(identifier: "postcall-\(phoneKey)", content: content, trigger: trigger))
    }

    func cancelPostCall() {
        Task {
            let ids = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix("postcall-") }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    // MARK: 생일 알림

    func rescheduleBirthdays(contacts: [ContactInfo], enabled: Bool, hour: Int, offsets: [Int],
                             favoritesOnly: Bool, favoriteKeys: Set<String>,
                             memos: [String: String]) async {
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix("bday-") })
        guard enabled, !offsets.isEmpty else { return }

        struct Item { let fire: Date; let title: String; let body: String; let id: String; let key: String }
        let calendar = Calendar.current
        var items: [Item] = []
        for contact in contacts {
            if favoritesOnly && !contact.allKeys.contains(where: favoriteKeys.contains) { continue }
            guard let next = contact.birthday?.nextBirthday(),
                  let base = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: next.date) else { continue }
            let memo = contact.allKeys.compactMap { memos[$0] }.first.map { "\n📝 \($0)" } ?? ""
            let turning = next.turning.map { " (" + L("\($0)번째 생일") + ")" } ?? ""
            for days in offsets {
                guard let fire = calendar.date(byAdding: .day, value: -days, to: base) else { continue }
                let when = switch days {
                case 0: L("오늘")
                case 1: L("내일")
                case 7: L("일주일 뒤")
                default: L("\(days)일 뒤")
                }
                let title = days == 0 ? L("🎂 \(contact.name)님 생일")
                    : L("🎂 \(when) \(contact.name)님 생일")
                let body = switch days {
                case 0: L("오늘이 생일이에요")
                case 1: L("내일이 생일이에요")
                default: L("\(when) 생일이에요")
                }
                items.append(Item(fire: fire, title: title, body: "\(body)\(turning)\(memo)",
                                  id: "bday-\(contact.id)-\(days)", key: contact.primaryKey))
            }
        }
        let upcoming = items.filter { $0.fire > .now }.sorted { $0.fire < $1.fire }.prefix(birthdayLimit)
        for item in upcoming {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default
            content.userInfo = ["phoneKey": item.key]
            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: item.fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: item.id, content: content, trigger: trigger))
        }
    }

    // MARK: UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let key = response.notification.request.content.userInfo["phoneKey"] as? String ?? ""
        guard !key.isEmpty else { return }
        if response.actionIdentifier == "ADD_NOTE", let input = response as? UNTextInputNotificationResponse {
            let text = input.userText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, let container else { return }
            await MainActor.run {
                let context = ModelContext(container)
                context.insert(ContactNote(phoneKey: key, body: text))
                try? context.save()
            }
        } else if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            await MainActor.run {
                NotificationCenter.default.post(name: .openContactKey, object: nil, userInfo: ["phoneKey": key])
            }
        }
    }
}
