import SwiftData
import SwiftUI

/// RemindCall에서 건 통화와 남긴 메모를 시간순으로 보여 준다.
struct RecentsView: View {
    let store: ContactsStore
    let onSelect: (ContactInfo) -> Void

    @Query(sort: \CallLog.calledAt, order: .reverse) private var calls: [CallLog]
    @Query(sort: \ContactNote.createdAt, order: .reverse) private var notes: [ContactNote]

    private struct Event: Identifiable {
        let id: String
        let key: String
        let date: Date
        let isCall: Bool
        let text: String
    }

    private var events: [Event] {
        let callEvents = calls.prefix(100).map {
            Event(id: "c-\(String(describing: $0.persistentModelID))", key: $0.phoneKey,
                  date: $0.calledAt, isCall: true, text: "RemindCall에서 건 통화")
        }
        let noteEvents = notes.prefix(100).map {
            Event(id: "n-\(String(describing: $0.persistentModelID))", key: $0.phoneKey,
                  date: $0.createdAt, isCall: false, text: $0.body)
        }
        return Array((callEvents + noteEvents).sorted { $0.date > $1.date }.prefix(100))
    }

    var body: some View {
        NavigationStack {
            Group {
                if events.isEmpty {
                    ContentUnavailableView("기록이 없습니다", systemImage: "clock",
                                           description: Text("RemindCall에서 건 통화와 남긴 메모가 여기에 표시됩니다."))
                } else {
                    List {
                        ForEach(events) { event in
                            row(event)
                        }
                        Text("시스템 전화 앱의 통화 기록은 iOS 정책상 볼 수 없어, RemindCall에서 건 통화만 표시됩니다.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("최근")
        }
    }

    private func row(_ event: Event) -> some View {
        let contact = store.byKey[event.key]
        return Button {
            if let contact { onSelect(contact) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: event.isCall ? "phone.arrow.up.right" : "note.text")
                    .foregroundStyle(event.isCall ? .green : .yellow)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact?.name ?? event.key).font(.body).foregroundStyle(.primary)
                    Text(event.text).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Text(event.date.formatted(.relative(presentation: .numeric)))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
