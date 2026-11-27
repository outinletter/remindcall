import Foundation
import SwiftData

/// 스토어 스크린샷용 시연 모드. 실행 인자 `-demoMode YES`로만 켜진다(사용자에게는 보이지 않음).
/// 실제 연락처와 iCloud 데이터 대신 메모리에만 있는 예시 데이터를 쓴다.
enum Demo {
    static var isOn: Bool { UserDefaults.standard.bool(forKey: "demoMode") }

    private struct Person { let name: String; let company: String; let number: String; let birthdayIn: Int?; let favorite: Bool; let memo: String?; let tags: [String]; let calledHoursAgo: Double? }

    private static var language: String {
        let code = LanguageManager.shared.code
        return code.isEmpty ? (Bundle.main.preferredLocalizations.first ?? "ko") : code
    }

    private static var people: [Person] {
        switch language {
        case "en": [
            Person(name: "Emma Johnson", company: "", number: "010-0000-1111", birthdayIn: 3, favorite: true, memo: "Moved last month. Son's name is Tom", tags: ["Family"], calledHoursAgo: 2),
            Person(name: "Liam Smith", company: "ABC Trading", number: "010-1111-1111", birthdayIn: 24, favorite: true, memo: "Send the contract draft by Friday", tags: ["Client"], calledHoursAgo: 26),
            Person(name: "Olivia Brown", company: "", number: "010-2222-1111", birthdayIn: nil, favorite: true, memo: nil, tags: ["Classmate"], calledHoursAgo: 50),
            Person(name: "Noah Davis", company: "Green Clinic", number: "010-3333-0000", birthdayIn: 60, favorite: false, memo: "Check-up next Tuesday", tags: [], calledHoursAgo: nil),
            Person(name: "Ava Wilson", company: "", number: "010-4444-0000", birthdayIn: 120, favorite: false, memo: nil, tags: [], calledHoursAgo: nil),
            Person(name: "James Taylor", company: "City Bakery", number: "010-5555-0000", birthdayIn: nil, favorite: false, memo: nil, tags: [], calledHoursAgo: nil),
            Person(name: "Sophia Martin", company: "", number: "010-6666-0000", birthdayIn: 200, favorite: false, memo: nil, tags: [], calledHoursAgo: nil),
            Person(name: "William Lee", company: "", number: "010-7777-0000", birthdayIn: nil, favorite: false, memo: nil, tags: [], calledHoursAgo: nil),
        ]
        case "ja": [
            Person(name: "佐藤 花子", company: "", number: "010-0000-1111", birthdayIn: 3, favorite: true, memo: "先月引っ越し。息子の名前は太郎", tags: ["家族"], calledHoursAgo: 2),
            Person(name: "鈴木 一郎", company: "ABC商事", number: "010-1111-1111", birthdayIn: 24, favorite: true, memo: "金曜日までに契約書の案を送る", tags: ["取引先"], calledHoursAgo: 26),
            Person(name: "高橋 美咲", company: "", number: "010-2222-1111", birthdayIn: nil, favorite: true, memo: nil, tags: ["同級生"], calledHoursAgo: 50),
            Person(name: "田中 健", company: "みどりクリニック", number: "010-3333-0000", birthdayIn: 60, favorite: false, memo: "来週火曜日に検診", tags: [], calledHoursAgo: nil),
            Person(name: "伊藤 さくら", company: "", number: "010-4444-0000", birthdayIn: 120, favorite: false, memo: nil, tags: [], calledHoursAgo: nil),
            Person(name: "渡辺 翔", company: "まちのパン屋", number: "010-5555-0000", birthdayIn: nil, favorite: false, memo: nil, tags: [], calledHoursAgo: nil),
            Person(name: "山本 結衣", company: "", number: "010-6666-0000", birthdayIn: 200, favorite: false, memo: nil, tags: [], calledHoursAgo: nil),
            Person(name: "中村 大輝", company: "", number: "010-7777-0000", birthdayIn: nil, favorite: false, memo: nil, tags: [], calledHoursAgo: nil),
        ]
        case "zh-Hans": [
            Person(name: "王小明", company: "", number: "010-0000-1111", birthdayIn: 3, favorite: true, memo: "上个月搬家了。儿子叫小明", tags: ["家人"], calledHoursAgo: 2),
            Person(name: "李华", company: "ABC贸易", number: "010-1111-1111", birthdayIn: 24, favorite: true, memo: "周五前发送合同草案", tags: ["客户"], calledHoursAgo: 26),
            Person(name: "张丽", company: "", number: "010-2222-1111", birthdayIn: nil, favorite: true, memo: nil, tags: ["同学"], calledHoursAgo: 50),
            Person(name: "刘强", company: "绿色诊所", number: "010-3333-0000", birthdayIn: 60, favorite: false, memo: "下周二体检", tags: [], calledHoursAgo: nil),
            Person(name: "陈静", company: "", number: "010-4444-0000", birthdayIn: 120, favorite: false, memo: nil, tags: [], calledHoursAgo: nil),
            Person(name: "杨帆", company: "街角面包店", number: "010-5555-0000", birthdayIn: nil, favorite: false, memo: nil, tags: [], calledHoursAgo: nil),
            Person(name: "赵敏", company: "", number: "010-6666-0000", birthdayIn: 200, favorite: false, memo: nil, tags: [], calledHoursAgo: nil),
            Person(name: "周杰", company: "", number: "010-7777-0000", birthdayIn: nil, favorite: false, memo: nil, tags: [], calledHoursAgo: nil),
        ]
        default: [
            Person(name: "김민수", company: "", number: "010-0000-1111", birthdayIn: 3, favorite: true, memo: "지난달 이사함. 아들 이름은 민준", tags: ["가족"], calledHoursAgo: 2),
            Person(name: "이지은", company: "ABC 상사", number: "010-1111-1111", birthdayIn: 24, favorite: true, memo: "금요일까지 계약서 초안 보내기", tags: ["거래처"], calledHoursAgo: 26),
            Person(name: "박서준", company: "", number: "010-2222-1111", birthdayIn: nil, favorite: true, memo: nil, tags: ["동창"], calledHoursAgo: 50),
            Person(name: "최유나", company: "초록 의원", number: "010-3333-0000", birthdayIn: 60, favorite: false, memo: "다음 주 화요일 검진", tags: [], calledHoursAgo: nil),
            Person(name: "정하늘", company: "", number: "010-4444-0000", birthdayIn: 120, favorite: false, memo: nil, tags: [], calledHoursAgo: nil),
            Person(name: "한도윤", company: "동네 빵집", number: "010-5555-0000", birthdayIn: nil, favorite: false, memo: nil, tags: [], calledHoursAgo: nil),
            Person(name: "윤서연", company: "", number: "010-6666-0000", birthdayIn: 200, favorite: false, memo: nil, tags: [], calledHoursAgo: nil),
            Person(name: "강태오", company: "", number: "010-7777-0000", birthdayIn: nil, favorite: false, memo: nil, tags: [], calledHoursAgo: nil),
        ]
        }
    }

    static func contacts() -> [ContactInfo] {
        let calendar = Calendar.current
        return people.enumerated().map { index, person in
            let birthday = person.birthdayIn.flatMap { calendar.date(byAdding: .day, value: $0, to: .now) }
                .map { calendar.dateComponents([.year, .month, .day], from: calendar.date(byAdding: .year, value: -(30 + index), to: $0) ?? $0) }
            return ContactInfo(id: "demo-\(index)", name: person.name, company: person.company,
                               phones: [PhoneEntry(label: L("휴대폰"), number: person.number)],
                               birthday: birthday, photo: nil)
        }
    }

    @MainActor static func makeContainer(schema: Schema) -> ModelContainer {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try! ModelContainer(for: schema, configurations: config)
        seed(container.mainContext)
        return container
    }

    /// 예시 메모·태그를 현재 언어로 다시 채운다(언어를 바꿀 때 호출).
    @MainActor static func seed(_ context: ModelContext) {
        try? context.delete(model: ContactNote.self)
        try? context.delete(model: CallLog.self)
        try? context.delete(model: ContactProfile.self)
        for person in people {
            let key = PhoneKey.make(person.number)
            if person.favorite || !person.tags.isEmpty {
                let profile = ContactProfile(phoneKey: key)
                profile.isFavorite = person.favorite
                profile.tags = person.tags
                context.insert(profile)
            }
            if let memo = person.memo {
                let note = ContactNote(phoneKey: key, body: memo)
                note.createdAt = .now.addingTimeInterval(-(person.calledHoursAgo ?? 72) * 3600 + 300)
                context.insert(note)
            }
            if let hours = person.calledHoursAgo {
                let call = CallLog(phoneKey: key)
                call.calledAt = .now.addingTimeInterval(-hours * 3600)
                context.insert(call)
            }
        }
        try? context.save()
    }
}
