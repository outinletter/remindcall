import SwiftUI

/// 즐겨찾기 카드와 연락처 목록 행에 표시할 수 있는 정보.
/// 순서(위→아래, 이름 아래)와 표시 여부는 탭마다 따로 저장한다.
enum InfoField: String, CaseIterable, Identifiable {
    case birthday, company, number, last, memo, tags

    var id: String { rawValue }

    var title: String {
        switch self {
        case .birthday: "생일"
        case .company: "회사"
        case .number: "전화번호"
        case .last: "마지막 연락"
        case .memo: "메모 미리보기"
        case .tags: "태그"
        }
    }

    var symbol: String {
        switch self {
        case .birthday: "gift"
        case .company: "building.2"
        case .number: "phone"
        case .last: "clock"
        case .memo: "note.text"
        case .tags: "tag"
        }
    }

    static let favOrder = "birthday,company,number,last,memo,tags"
    static let favEnabled = "birthday,last,memo,tags"
    static let listOrder = "number,company,birthday,last,memo,tags"
    static let listEnabled = "number,company,birthday,memo,tags"

    /// 저장된 순서를 읽고, 빠진 항목은 뒤에 붙인다.
    static func parseOrder(_ raw: String) -> [InfoField] {
        var result: [InfoField] = []
        for part in raw.split(separator: ",") {
            if let field = InfoField(rawValue: String(part)), !result.contains(field) { result.append(field) }
        }
        for field in allCases where !result.contains(field) { result.append(field) }
        return result
    }

    static func parseEnabled(_ raw: String) -> Set<InfoField> {
        Set(raw.split(separator: ",").compactMap { InfoField(rawValue: String($0)) })
    }

    /// 표시할 항목만, 정해진 순서대로
    static func visible(orderRaw: String, enabledRaw: String) -> [InfoField] {
        let enabled = parseEnabled(enabledRaw)
        return parseOrder(orderRaw).filter(enabled.contains)
    }
}

/// 설정 시트 미리보기에 쓰는 예시 데이터
extension ContactInfo {
    static var sample: ContactInfo {
        let soon = Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now
        return ContactInfo(
            id: "sample",
            name: "김민수",
            company: "ABC 상사",
            phones: [PhoneEntry(label: "휴대폰", number: "010-1234-5678")],
            birthday: Calendar.current.dateComponents([.month, .day], from: soon),
            photo: nil
        )
    }
}

enum SampleData {
    static let memo = "지난달 이사함. 아들 이름은 민수"
    static let tags = ["가족", "동창", "거래처"]
    static var lastDate: Date { Date.now.addingTimeInterval(-3 * 86_400) }
}

struct ExtraToggle {
    let title: String
    let symbol: String
    let isOn: Binding<Bool>
}

/// 표시 설정 시트: 위에 미리보기, "표시 중"(순서 변경·숨기기), "숨김"(추가).
struct FieldSettingsView<Preview: View>: View {
    let title: String
    @Binding var orderRaw: String
    @Binding var enabledRaw: String
    let defaultOrder: String
    let defaultEnabled: String
    var extra: ExtraToggle?
    @ViewBuilder let preview: ([InfoField]) -> Preview

    @Environment(\.dismiss) private var dismiss

    private var visible: [InfoField] { InfoField.visible(orderRaw: orderRaw, enabledRaw: enabledRaw) }
    private var hidden: [InfoField] {
        let enabled = InfoField.parseEnabled(enabledRaw)
        return InfoField.parseOrder(orderRaw).filter { !enabled.contains($0) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("미리보기") {
                    preview(visible)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }

                Section {
                    if visible.isEmpty {
                        Text("표시할 정보가 없습니다. 아래 숨김 항목의 ⊕로 추가하세요.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    ForEach(visible) { field in
                        HStack(spacing: 12) {
                            Button { hide(field) } label: {
                                Image(systemName: "minus.circle.fill").foregroundStyle(.red).imageScale(.large)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("\(field.title) 숨기기")
                            Label(field.title, systemImage: field.symbol)
                        }
                    }
                    .onMove(perform: moveVisible)
                } header: {
                    Text("표시 중 · 오른쪽 손잡이를 끌어 순서 변경")
                } footer: {
                    Text("위에서부터 이름 아래에 표시됩니다.")
                }

                if !hidden.isEmpty {
                    Section("숨김") {
                        ForEach(hidden) { field in
                            HStack(spacing: 12) {
                                Button { show(field) } label: {
                                    Image(systemName: "plus.circle.fill").foregroundStyle(.green).imageScale(.large)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("\(field.title) 표시하기")
                                Label(field.title, systemImage: field.symbol).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if let extra {
                    Section {
                        Toggle(isOn: extra.isOn) { Label(extra.title, systemImage: extra.symbol) }
                    }
                }

                Section {
                    Button("기본값으로 되돌리기", role: .destructive) {
                        withAnimation {
                            orderRaw = defaultOrder
                            enabledRaw = defaultEnabled
                            extra?.isOn.wrappedValue = true
                        }
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("완료") { dismiss() } }
            }
        }
        .presentationDetents([.large])
    }

    private func save(order: [InfoField], enabled: Set<InfoField>) {
        orderRaw = order.map(\.rawValue).joined(separator: ",")
        enabledRaw = order.filter(enabled.contains).map(\.rawValue).joined(separator: ",")
    }

    private func moveVisible(from: IndexSet, to: Int) {
        var shown = visible
        shown.move(fromOffsets: from, toOffset: to)
        save(order: shown + hidden, enabled: Set(shown))
    }

    private func hide(_ field: InfoField) {
        withAnimation {
            let shown = visible.filter { $0 != field }
            save(order: shown + [field] + hidden, enabled: Set(shown))
        }
    }

    private func show(_ field: InfoField) {
        withAnimation {
            let shown = visible + [field]
            save(order: shown + hidden.filter { $0 != field }, enabled: Set(shown))
        }
    }
}
