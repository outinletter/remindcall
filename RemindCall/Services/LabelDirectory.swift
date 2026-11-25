import CallKit
import Foundation

/// 이름표 목록을 App Group 파일에 쓰고, Call Directory 확장이 읽어 가게 한다.
enum LabelDirectory {
    static let groupID = "group.com.addvalue.remindcall"
    static let extensionID = "com.addvalue.remindcall.directory"

    struct Entry: Codable {
        let n: Int64   // E.164 숫자 (예: 821012345678)
        let l: String  // 표시할 이름표
    }

    /// 입력 번호를 E.164 숫자로 바꾼다. 해석할 수 없으면 nil.
    static func e164(_ raw: String) -> Int64? {
        let digits = raw.filter(\.isNumber)
        guard digits.count >= 7 else { return nil }
        if raw.trimmingCharacters(in: .whitespaces).hasPrefix("+") { return Int64(digits) }
        if digits.hasPrefix("0") { return Int64("82" + digits.dropFirst()) }
        if digits.hasPrefix("82") { return Int64(digits) }
        return nil
    }

    private static var fileURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)?
            .appendingPathComponent("labels.json")
    }

    /// 내용이 바뀐 경우에만 파일을 쓰고 확장을 다시 불러온다. 기능이 꺼져 있으면 빈 목록을 쓴다.
    static func sync(labels: [(number: String, label: String)], enabled: Bool) {
        guard let url = fileURL else { return }
        var seen = Set<Int64>()
        let entries: [Entry] = enabled
            ? labels.compactMap { item -> Entry? in
                guard let n = e164(item.number), !item.label.isEmpty, seen.insert(n).inserted else { return nil }
                return Entry(n: n, l: item.label)
            }.sorted { $0.n < $1.n }
            : []
        guard let data = try? JSONEncoder().encode(entries) else { return }
        if let old = try? Data(contentsOf: url), old == data { return }
        try? data.write(to: url, options: .atomic)
        CXCallDirectoryManager.sharedInstance.reloadExtension(withIdentifier: extensionID) { _ in }
    }

    static func status() async -> CXCallDirectoryManager.EnabledStatus {
        await withCheckedContinuation { continuation in
            CXCallDirectoryManager.sharedInstance.getEnabledStatusForExtension(withIdentifier: extensionID) { status, _ in
                continuation.resume(returning: status)
            }
        }
    }

    static func openSettings() {
        CXCallDirectoryManager.sharedInstance.openSettings { _ in }
    }
}
