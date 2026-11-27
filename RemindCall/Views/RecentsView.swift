import SwiftData
import SwiftUI

/// RemindCall에서 건 통화와 남긴 메모를 시간순으로 보여 준다.
struct RecentsView: View {
    let store: ContactsStore
    let onSelect: (ContactInfo) -> Void

    @Environment(\.modelContext) private var context
    @State private var selection = Set<String>()
    @State private var editMode = EditMode.inactive
    @State private var confirmClear = false
    @Query(sort: \CallLog.calledAt, order: .reverse) private var calls: [CallLog]
    @Query(sort: \ContactNote.createdAt, order: .reverse) private var notes: [ContactNote]

    private struct Event: Identifiable {
        let id: String
        let key: String
        let date: Date
        let isCall: Bool
        let text: String
        let call: CallLog?
        let note: ContactNote?
    }

    private var events: [Event] {
        let callEvents = calls.prefix(100).map {
            Event(id: "c-\(String(describing: $0.persistentModelID))", key: $0.phoneKey,
                  date: $0.calledAt, isCall: true, text: L("RemindCall에서 건 통화"), call: $0, note: nil)
        }
        let noteEvents = notes.prefix(100).map {
            Event(id: "n-\(String(describing: $0.persistentModelID))", key: $0.phoneKey,
                  date: $0.createdAt, isCall: false, text: $0.body, call: nil, note: $0)
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
                    List(selection: $selection) {
                        ForEach(events) { event in
                            row(event)
                        }
                        .onDelete { offsets in
                            let list = events
                            offsets.forEach { delete(list[$0]) }
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
            .environment(\.editMode, $editMode)
            .toolbar {
                if !events.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) { EditButton() }
                }
                if editMode.isEditing {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("전체 지우기", role: .destructive) { confirmClear = true }
                    }
                    ToolbarItem(placement: .bottomBar) {
                        Button(L("삭제 (\(selection.count))"), role: .destructive) {
                            let chosen = events.filter { selection.contains($0.id) }
                            chosen.forEach(delete)
                            selection.removeAll()
                        }
                        .disabled(selection.isEmpty)
                    }
                }
            }
            .confirmationDialog("모든 기록을 지울까요?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("전체 지우기", role: .destructive) {
                    calls.forEach { context.delete($0) }
                    notes.forEach { context.delete($0) }
                    selection.removeAll()
                    editMode = .inactive
                }
            } message: {
                Text("RemindCall에서 건 통화 기록과 메모가 모두 지워지며 되돌릴 수 없습니다.")
            }
        }
    }

    private func delete(_ event: Event) {
        if let call = event.call { context.delete(call) }
        if let note = event.note { context.delete(note) }
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
                Text(event.date.formatted(.relative(presentation: .numeric).locale(LanguageManager.shared.locale)))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
