import Contacts
import Observation
import SwiftUI

struct PhoneEntry: Hashable {
    let label: String
    let number: String
    var key: String { PhoneKey.make(number) }
}

struct ContactInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let company: String
    let phones: [PhoneEntry]
    let birthday: DateComponents?
    let photo: Data?

    /// 번호가 없는 연락처는 연락처 ID를 대신 키로 쓴다.
    var allKeys: [String] {
        let keys = phones.map(\.key).filter { !$0.isEmpty }
        return keys.isEmpty ? [id] : keys
    }
    var primaryKey: String { allKeys[0] }

    var tint: Color {
        let hue = name.unicodeScalars.reduce(0) { ($0 * 31 + Int($1.value)) % 360 }
        return Color(hue: Double(hue) / 360, saturation: 0.55, brightness: 0.55)
    }

    /// 생일 표시 규칙(모든 화면 공통): 오늘 / 30일 이내 D-day / 그 밖에는 날짜
    var birthdayBadge: (text: String, urgent: Bool)? {
        guard let next = birthday?.nextBirthday() else { return nil }
        if next.days == 0 { return ("🎂 오늘", true) }
        if next.days <= 30 { return ("🎂 D-\(next.days)", next.days <= 7) }
        return ("🎂 " + next.date.formatted(.dateTime.month().day()), false)
    }

    func matches(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return true }
        if name.localizedCaseInsensitiveContains(q) || company.localizedCaseInsensitiveContains(q) { return true }
        if q.allSatisfy({ $0.isNumber || $0 == "-" }) {
            let digits = q.filter(\.isNumber)
            return !digits.isEmpty && phones.contains { $0.key.contains(digits) }
        }
        return name.choseong.contains(q)
    }
}

extension String {
    /// "김철수" → "ㄱㅊㅅ" (한글 이외 글자는 그대로)
    var choseong: String {
        let table = Array("ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ")
        return String(unicodeScalars.map { scalar -> Character in
            if (0xAC00...0xD7A3).contains(scalar.value) {
                return table[Int(scalar.value - 0xAC00) / 588]
            }
            return Character(scalar)
        })
    }
}

extension DateComponents {
    /// 다음 생일 날짜, 남은 일수, 올해 맞는 나이(출생 연도가 있을 때)
    func nextBirthday(from now: Date = .now) -> (date: Date, days: Int, turning: Int?)? {
        guard let month, let day else { return nil }
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let thisYear = cal.component(.year, from: today)
        for year in [thisYear, thisYear + 1] {
            guard let date = cal.date(from: DateComponents(year: year, month: month, day: day)), date >= today else { continue }
            let days = cal.dateComponents([.day], from: today, to: date).day ?? 0
            let turning: Int? = {
                guard let birthYear = self.year, birthYear > 1900 else { return nil }
                return year - birthYear
            }()
            return (date, days, turning)
        }
        return nil
    }
}

@MainActor
@Observable
final class ContactsStore {
    var contacts: [ContactInfo] = []
    /// 번호 키 → 연락처 (최근·즐겨찾기 탭에서 이름을 찾는 데 쓴다)
    var byKey: [String: ContactInfo] = [:]
    var status: CNAuthorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
    var isLoading = false

    var hasAccess: Bool {
        if status == .authorized { return true }
        if #available(iOS 18.0, *), status == .limited { return true }
        return false
    }

    func requestAndLoad() async {
        if status == .notDetermined {
            _ = try? await CNContactStore().requestAccess(for: .contacts)
            status = CNContactStore.authorizationStatus(for: .contacts)
        }
        guard hasAccess else { return }
        isLoading = true
        let loaded = await Task.detached { Self.fetchAll() }.value
        contacts = loaded
        byKey = Dictionary(loaded.flatMap { contact in contact.allKeys.map { ($0, contact) } },
                           uniquingKeysWith: { first, _ in first })
        isLoading = false
    }

    nonisolated static func fetchAll() -> [ContactInfo] {
        let keys: [CNKeyDescriptor] = [
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactBirthdayKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor,
        ]
        let request = CNContactFetchRequest(keysToFetch: keys)
        request.sortOrder = .userDefault
        var result: [ContactInfo] = []
        try? CNContactStore().enumerateContacts(with: request) { contact, _ in
            let phones = contact.phoneNumbers.map { value -> PhoneEntry in
                let raw = value.label.map { CNLabeledValue<NSString>.localizedString(forLabel: $0) } ?? ""
                return PhoneEntry(label: raw.isEmpty ? "전화" : raw, number: value.value.stringValue)
            }
            var name = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
            if name.isEmpty { name = contact.organizationName }
            if name.isEmpty { name = phones.first?.number ?? "" }
            guard !name.isEmpty else { return }
            result.append(ContactInfo(
                id: contact.identifier,
                name: name,
                company: contact.organizationName,
                phones: phones,
                birthday: contact.birthday,
                photo: contact.thumbnailImageData
            ))
        }
        return result
    }
}
