import CallKit
import Foundation

/// 앱이 App Group 파일에 써 둔 이름표를 전화 수신 화면에 연결한다.
final class CallDirectoryHandler: CXCallDirectoryProvider {
    private struct Entry: Decodable {
        let n: Int64
        let l: String
    }

    override func beginRequest(with context: CXCallDirectoryExtensionContext) {
        context.delegate = self

        // 항상 전체 목록을 다시 넣는다.
        if context.isIncremental {
            context.removeAllIdentificationEntries()
        }

        if let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.addvalue.remindcall")?
            .appendingPathComponent("labels.json"),
           let data = try? Data(contentsOf: url),
           let entries = try? JSONDecoder().decode([Entry].self, from: data) {
            // 번호는 오름차순으로 추가해야 한다.
            for entry in entries.sorted(by: { $0.n < $1.n }) {
                context.addIdentificationEntry(withNextSequentialPhoneNumber: CXCallDirectoryPhoneNumber(entry.n),
                                               label: entry.l)
            }
        }

        context.completeRequest()
    }
}

extension CallDirectoryHandler: CXCallDirectoryExtensionContextDelegate {
    func requestFailed(for extensionContext: CXCallDirectoryExtensionContext, withError error: Error) {
        // 실패하면 시스템이 이전 목록을 유지한다.
    }
}
