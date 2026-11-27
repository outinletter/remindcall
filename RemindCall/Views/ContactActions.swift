import SwiftData
import SwiftUI

/// 목록·카드에서 공통으로 쓰는 연락처 동작(전화·메시지·복사·즐겨찾기).
@MainActor
enum ContactActions {
    static func call(_ phone: PhoneEntry, contact: ContactInfo, context: ModelContext, openURL: OpenURLAction) {
        let key = phone.key.isEmpty ? contact.primaryKey : phone.key
        context.insert(CallLog(phoneKey: key))
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "postCallEnabled") {
            let minutes = defaults.object(forKey: "postCallMinutes") as? Int ?? 10
            NotificationManager.shared.schedulePostCall(name: contact.name, phoneKey: key, afterMinutes: minutes)
        }
        let dial = phone.number.filter { $0.isNumber || $0 == "+" }
        if let url = URL(string: "tel://\(dial)") { openURL(url) }
    }

    /// 시스템 메시지 앱으로 넘긴다(앱은 문자를 읽거나 보내지 않는다).
    static func message(_ phone: PhoneEntry, openURL: OpenURLAction) {
        let number = phone.number.filter { $0.isNumber || $0 == "+" }
        if let url = URL(string: "sms:\(number)") { openURL(url) }
    }

    static func copy(_ text: String) {
        UIPasteboard.general.string = text
    }

    static func setFavorite(_ contact: ContactInfo, _ isOn: Bool, context: ModelContext) {
        let keys = contact.allKeys
        let found = (try? context.fetch(FetchDescriptor<ContactProfile>(
            predicate: #Predicate { keys.contains($0.phoneKey) }))) ?? []
        if found.isEmpty {
            guard isOn else { return }
            let profile = ContactProfile(phoneKey: contact.primaryKey)
            profile.isFavorite = true
            context.insert(profile)
        } else {
            found.forEach { $0.isFavorite = isOn }
        }
    }
}

/// 길게 누르기 메뉴와(목록 행이면) 스와이프 동작
struct ContactMenuModifier: ViewModifier {
    let contact: ContactInfo
    let isFavorite: Bool
    var swipe = false

    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL

    func body(content: Content) -> some View {
        if swipe {
            content
                .contextMenu { menu }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if let phone = contact.phones.first {
                        Button { ContactActions.call(phone, contact: contact, context: context, openURL: openURL) } label: {
                            Label("전화", systemImage: "phone.fill")
                        }
                        .tint(.green)
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    if let phone = contact.phones.first {
                        Button { ContactActions.message(phone, openURL: openURL) } label: {
                            Label("메시지", systemImage: "message.fill")
                        }
                        .tint(.blue)
                    }
                }
        } else {
            content.contextMenu { menu }
        }
    }

    private var favoriteButton: some View {
        Button { ContactActions.setFavorite(contact, !isFavorite, context: context) } label: {
            Label(isFavorite ? "즐겨찾기에서 제거" : "즐겨찾기에 추가",
                  systemImage: isFavorite ? "star.slash" : "star")
        }
    }

    @ViewBuilder
    private var menu: some View {
        let phones = contact.phones
        if phones.count == 1, let phone = phones.first {
            Button { ContactActions.call(phone, contact: contact, context: context, openURL: openURL) } label: {
                Label("전화", systemImage: "phone")
            }
            Button { ContactActions.message(phone, openURL: openURL) } label: {
                Label("메시지", systemImage: "message")
            }
            Button { ContactActions.copy(phone.number) } label: {
                Label("번호 복사", systemImage: "doc.on.doc")
            }
        } else if phones.count > 1 {
            Menu {
                ForEach(phones, id: \.self) { phone in
                    Button("\(phone.label) \(phone.number)") {
                        ContactActions.call(phone, contact: contact, context: context, openURL: openURL)
                    }
                }
            } label: { Label("전화", systemImage: "phone") }
            Menu {
                ForEach(phones, id: \.self) { phone in
                    Button("\(phone.label) \(phone.number)") { ContactActions.message(phone, openURL: openURL) }
                }
            } label: { Label("메시지", systemImage: "message") }
            Menu {
                ForEach(phones, id: \.self) { phone in
                    Button("\(phone.label) \(phone.number)") { ContactActions.copy(phone.number) }
                }
            } label: { Label("번호 복사", systemImage: "doc.on.doc") }
        }
        Divider()
        favoriteButton
    }
}

extension View {
    func contactMenu(_ contact: ContactInfo, isFavorite: Bool, swipe: Bool = false) -> some View {
        modifier(ContactMenuModifier(contact: contact, isFavorite: isFavorite, swipe: swipe))
    }
}
