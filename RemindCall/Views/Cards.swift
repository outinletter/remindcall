import SwiftUI

struct InfoCard<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct PhoneCard: View {
    let phones: [PhoneEntry]
    let onCall: (PhoneEntry) -> Void

    var body: some View {
        InfoCard(title: "전화번호", symbol: "phone") {
            if phones.isEmpty {
                Text("저장된 번호가 없습니다").foregroundStyle(.secondary)
            }
            ForEach(phones, id: \.self) { phone in
                Button { onCall(phone) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(phone.number)
                                .font(.system(size: 24, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                            Text(phone.label).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "phone.circle.fill")
                            .font(.title)
                            .foregroundStyle(.green)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct BirthdayCard: View {
    let birthday: DateComponents

    var body: some View {
        if let next = birthday.nextBirthday() {
            InfoCard(title: "생일", symbol: "gift") {
                HStack(alignment: .firstTextBaseline) {
                    Text(next.date.formatted(.dateTime.month().day()))
                        .font(.title2.weight(.semibold))
                    if let turning = next.turning {
                        Text("\(turning)번째 생일").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(next.days == 0 ? "오늘!" : "D-\(next.days)")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(next.days <= 7 ? .orange : .secondary)
                }
            }
        }
    }
}

struct MemoCard: View {
    let notes: [ContactNote]
    let onDelete: (ContactNote) -> Void

    var body: some View {
        InfoCard(title: "메모", symbol: "note.text") {
            if notes.isEmpty {
                Text("아래 메모 버튼으로 첫 메모를 남겨 보세요").foregroundStyle(.secondary)
            }
            ForEach(notes.prefix(5)) { note in
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.body)
                    Text(note.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contextMenu {
                    Button("삭제", systemImage: "trash", role: .destructive) { onDelete(note) }
                }
            }
        }
    }
}

struct TagCard: View {
    let tags: [String]
    let onEdit: () -> Void

    var body: some View {
        InfoCard(title: "태그", symbol: "tag") {
            FlowLayout(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.subheadline)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(.white.opacity(0.15), in: Capsule())
                }
                Button(action: onEdit) {
                    Label(tags.isEmpty ? "태그 추가" : "편집", systemImage: "plus")
                        .font(.subheadline)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .overlay(Capsule().strokeBorder(.white.opacity(0.35)))
                }
            }
        }
    }
}

struct HistoryCard: View {
    let calls: [CallLog]

    var body: some View {
        InfoCard(title: "통화 기록", symbol: "clock.arrow.circlepath") {
            if calls.isEmpty {
                Text("기록 없음").foregroundStyle(.secondary)
            }
            ForEach(calls.prefix(5)) { log in
                HStack {
                    Image(systemName: "phone.arrow.up.right").foregroundStyle(.green)
                    Text(log.calledAt.formatted(date: .abbreviated, time: .shortened))
                }
            }
            Text("RemindCall에서 건 통화만 기록됩니다")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(width: bounds.width, subviews: subviews)
        for (index, point) in result.points.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y),
                                  proposal: .unspecified)
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (points: [CGPoint], size: CGSize) {
        var points: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxWidth = max(maxWidth, x - spacing)
        }
        return (points, CGSize(width: maxWidth, height: y + rowHeight))
    }
}

struct NoteEditorView: View {
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .focused($focused)
                .padding(.horizontal)
                .navigationTitle("메모 추가")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("저장") {
                            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty { onSave(trimmed) }
                            dismiss()
                        }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .onAppear { focused = true }
        }
        .presentationDetents([.medium])
    }
}

struct TagEditorView: View {
    let tags: [String]
    let onSave: ([String]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("태그 (쉼표로 구분)") {
                    TextField("가족, 거래처, 동창", text: $text)
                }
            }
            .navigationTitle("태그 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        onSave(text.split(whereSeparator: { $0 == "," || $0 == "," })
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty })
                        dismiss()
                    }
                }
            }
            .onAppear { text = tags.joined(separator: ", ") }
        }
        .presentationDetents([.height(220)])
    }
}
