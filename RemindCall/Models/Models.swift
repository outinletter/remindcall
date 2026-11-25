import Foundation
import SwiftData

// CloudKit 동기화 조건: 모든 속성에 기본값, unique 제약 없음.
// 연락처와는 정규화한 전화번호(phoneKey)로 연결한다.

@Model
final class ContactNote {
    var phoneKey: String = ""
    var body: String = ""
    var createdAt: Date = Date()

    init(phoneKey: String, body: String) {
        self.phoneKey = phoneKey
        self.body = body
    }
}

@Model
final class CallLog {
    var phoneKey: String = ""
    var calledAt: Date = Date()

    init(phoneKey: String) {
        self.phoneKey = phoneKey
    }
}

@Model
final class ContactProfile {
    var phoneKey: String = ""
    var tagsText: String = ""
    var isFavorite: Bool = false

    init(phoneKey: String) {
        self.phoneKey = phoneKey
    }

    var tags: [String] {
        get { tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
        set { tagsText = newValue.joined(separator: ",") }
    }
}

enum PhoneKey {
    /// 숫자만 남기고, 국가번호 82는 0으로 바꾼다. (+82 10-1234-5678 → 01012345678)
    static func make(_ raw: String) -> String {
        var digits = raw.filter(\.isNumber)
        if digits.hasPrefix("82"), digits.count > 9 {
            digits = "0" + digits.dropFirst(2)
        }
        return digits
    }
}

enum Store {
    static func makeContainer() -> ModelContainer {
        let schema = Schema([ContactNote.self, CallLog.self, ContactProfile.self])
        let cloud = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
        if let container = try? ModelContainer(for: schema, configurations: cloud) {
            return container
        }
        let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        return try! ModelContainer(for: schema, configurations: local)
    }
}
