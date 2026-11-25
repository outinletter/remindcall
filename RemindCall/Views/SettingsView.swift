import CallKit
import SwiftData
import SwiftUI

/// 기능별 켜기/끄기. 알림이 필요한 기능은 켤 때 알림 권한을 요청한다.
struct SettingsView: View {
    @AppStorage("postCallEnabled") private var postCallEnabled = false
    @AppStorage("postCallMinutes") private var postCallMinutes = 10
    @AppStorage("bdayEnabled") private var bdayEnabled = false
    @AppStorage("bdayHour") private var bdayHour = 9
    @AppStorage("bdaySameDay") private var bdaySameDay = true
    @AppStorage("bdayDayBefore") private var bdayDayBefore = false
    @AppStorage("bdayFavoritesOnly") private var bdayFavoritesOnly = false
    @AppStorage("labelEnabled") private var labelEnabled = false

    @Query private var labels: [NumberLabel]
    @State private var showDenied = false
    @State private var directoryStatus: CXCallDirectoryManager.EnabledStatus = .unknown
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            Form {
                postCallSection
                birthdaySection
                labelSection
            }
            .navigationTitle("설정")
            .alert("알림이 꺼져 있습니다", isPresented: $showDenied) {
                Button("설정 열기") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("설정에서 RemindCall의 알림을 허용한 뒤 다시 켜 주세요.")
            }
            .task { directoryStatus = await LabelDirectory.status() }
            .onChange(of: labelEnabled) {
                Task {
                    // 기능을 켜거나 끈 직후 확장 상태를 다시 확인한다.
                    try? await Task.sleep(for: .seconds(1))
                    directoryStatus = await LabelDirectory.status()
                }
            }
            .onChange(of: postCallEnabled) { _, isOn in
                if !isOn { NotificationManager.shared.cancelPostCall() }
            }
        }
    }

    // MARK: 통화 후 메모 알림

    private var postCallSection: some View {
        Section {
            Toggle("통화 후 메모 알림", isOn: permissionBinding($postCallEnabled))
            if postCallEnabled {
                Picker("알림 시점", selection: $postCallMinutes) {
                    Text("5분 후").tag(5)
                    Text("10분 후").tag(10)
                    Text("30분 후").tag(30)
                    Text("1시간 후").tag(60)
                }
            }
        } header: {
            Text("통화")
        } footer: {
            Text("RemindCall에서 전화를 건 뒤 알림이 옵니다. 알림을 길게 누르면 앱을 열지 않고 메모를 바로 남길 수 있어요. 통화가 끝난 시점은 알 수 없어서 정한 시간 뒤에 알립니다.")
        }
    }

    // MARK: 생일 알림

    private var birthdaySection: some View {
        Section {
            Toggle("생일 알림", isOn: permissionBinding($bdayEnabled))
            if bdayEnabled {
                Picker("알림 시각", selection: $bdayHour) {
                    ForEach(0..<24, id: \.self) { Text(Self.hourText($0)).tag($0) }
                }
                Toggle("생일 당일", isOn: $bdaySameDay)
                Toggle("하루 전", isOn: $bdayDayBefore)
                Toggle("즐겨찾기만", isOn: $bdayFavoritesOnly)
            }
        } header: {
            Text("생일")
        } footer: {
            Text("가까운 생일 순으로 최대 50개를 예약하며, 앱을 열 때마다 갱신됩니다. 오랫동안 앱을 열지 않으면 일부 알림이 빠질 수 있어요.")
        }
    }

    // MARK: 모르는 번호 이름표

    private var labelSection: some View {
        Section {
            Toggle("모르는 번호 이름표", isOn: $labelEnabled)
            if labelEnabled {
                NavigationLink {
                    NumberLabelsView()
                } label: {
                    LabeledContent("이름표 관리", value: "\(labels.count)개")
                }
                switch directoryStatus {
                case .enabled:
                    Label("전화 앱에서 켜져 있습니다", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .disabled:
                    Label("전화 앱에서 아직 꺼져 있습니다", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Button("전화 설정 열기") { LabelDirectory.openSettings() }
                default:
                    Label("상태 확인 중", systemImage: "ellipsis.circle").foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("수신 전화")
        } footer: {
            Text("연락처에 없는 번호에서 전화가 오면 정해 둔 이름표(예: 배달 기사)가 수신 화면에 표시됩니다. 전화 앱 설정에서 RemindCall을 허용해야 하며, 이름표 한 줄만 표시할 수 있어요.")
        }
    }

    // MARK: 도우미

    /// 켤 때 알림 권한을 요청하고, 거부되어 있으면 안내한다.
    private func permissionBinding(_ isOn: Binding<Bool>) -> Binding<Bool> {
        Binding(
            get: { isOn.wrappedValue },
            set: { newValue in
                guard newValue else { isOn.wrappedValue = false; return }
                Task {
                    if await NotificationManager.shared.requestAuthorization() {
                        isOn.wrappedValue = true
                    } else {
                        showDenied = true
                    }
                }
            }
        )
    }

    private static func hourText(_ hour: Int) -> String {
        let h12 = hour % 12 == 0 ? 12 : hour % 12
        return (hour < 12 ? "오전 " : "오후 ") + "\(h12)시"
    }
}

// MARK: - 이름표 관리

struct NumberLabelsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \NumberLabel.createdAt, order: .reverse) private var labels: [NumberLabel]
    @State private var editing: NumberLabel?
    @State private var showNew = false

    var body: some View {
        List {
            if labels.isEmpty {
                ContentUnavailableView("이름표가 없습니다", systemImage: "tag",
                                       description: Text("오른쪽 위 +로 번호와 이름표를 추가하세요. 키패드에서 모르는 번호를 입력해도 추가할 수 있어요."))
            }
            ForEach(labels) { item in
                Button { editing = item } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.label).font(.body.weight(.medium)).foregroundStyle(.primary)
                        Text(item.number).font(.subheadline).foregroundStyle(.secondary)
                        if LabelDirectory.e164(item.number) == nil {
                            Text("번호 형식을 확인하세요").font(.caption).foregroundStyle(.orange)
                        }
                    }
                }
            }
            .onDelete { offsets in
                for index in offsets { context.delete(labels[index]) }
            }
        }
        .navigationTitle("이름표 관리")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showNew = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showNew) { LabelEditorView(existing: nil, number: "") }
        .sheet(item: $editing) { LabelEditorView(existing: $0, number: $0.number) }
    }
}

struct LabelEditorView: View {
    let existing: NumberLabel?
    @State var number: String
    @State private var label: String

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    init(existing: NumberLabel?, number: String) {
        self.existing = existing
        _number = State(initialValue: number)
        _label = State(initialValue: existing?.label ?? "")
    }

    private var canSave: Bool {
        LabelDirectory.e164(number) != nil && !label.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("전화번호", text: $number).keyboardType(.phonePad)
                    TextField("이름표 (예: 배달 기사)", text: $label)
                } footer: {
                    Text("국내 번호는 010-1234-5678처럼, 해외 번호는 +국가번호로 입력하세요.")
                }
            }
            .navigationTitle(existing == nil ? "이름표 추가" : "이름표 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        let text = label.trimmingCharacters(in: .whitespaces)
                        if let existing {
                            existing.number = number
                            existing.label = text
                        } else {
                            context.insert(NumberLabel(number: number, label: text))
                        }
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.height(300)])
    }
}
