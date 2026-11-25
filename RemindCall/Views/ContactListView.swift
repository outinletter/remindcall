import SwiftData
import SwiftUI

enum ContactSort: String, CaseIterable, Identifiable {
    case name, recent, stale, birthday, favorites

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name: "이름순"
        case .recent: "최근 연락순"
        case .stale: "연락 오래된 순"
        case .birthday: "생일 임박순"
        case .favorites: "즐겨찾기 먼저"
        }
    }

    var symbol: String {
        switch self {
        case .name: "textformat"
        case .recent: "clock"
        case .stale: "hourglass"
        case .birthday: "gift"
        case .favorites: "star"
        }
    }
}

struct ContactListView: View {
    let store: ContactsStore
    let onSelect: (ContactInfo) -> Void

    @State private var query = ""
    @State private var showSettings = false
    @AppStorage("contactSort") private var sort: ContactSort = .name
    @AppStorage("listFieldOrder") private var orderRaw = InfoField.listOrder
    @AppStorage("listFieldEnabled") private var enabledRaw = InfoField.listEnabled
    @AppStorage("listShowStar") private var showStar = true
    @Environment(\.openURL) private var openURL

    @Query private var calls: [CallLog]
    @Query private var notes: [ContactNote]
    @Query private var profiles: [ContactProfile]

    /// 번호 키 → 마지막 연락 시각 (앱에서 건 통화, 남긴 메모 기준)
    private var lastByKey: [String: Date] {
        var result: [String: Date] = [:]
        for call in calls { result[call.phoneKey] = max(result[call.phoneKey] ?? .distantPast, call.calledAt) }
        for note in notes { result[note.phoneKey] = max(result[note.phoneKey] ?? .distantPast, note.createdAt) }
        return result
    }

    /// 번호 키 → 가장 최근 메모
    private var latestMemoByKey: [String: ContactNote] {
        var result: [String: ContactNote] = [:]
        for note in notes where note.createdAt > (result[note.phoneKey]?.createdAt ?? .distantPast) {
            result[note.phoneKey] = note
        }
        return result
    }

    private var sortedContacts: [ContactInfo] {
        let base = store.contacts
            .filter { $0.matches(query) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        switch sort {
        case .name:
            return base
        case .recent, .stale:
            let last = lastByKey
            func date(_ c: ContactInfo) -> Date? { c.allKeys.compactMap { last[$0] }.max() }
            let withDate = base.compactMap { c in date(c).map { (c, $0) } }
                .sorted { sort == .recent ? $0.1 > $1.1 : $0.1 < $1.1 }
                .map(\.0)
            let ids = Set(withDate.map(\.id))
            return withDate + base.filter { !ids.contains($0.id) }
        case .birthday:
            let withDays = base.compactMap { c in c.birthday?.nextBirthday().map { (c, $0.days) } }
                .sorted { $0.1 < $1.1 }
                .map(\.0)
            let ids = Set(withDays.map(\.id))
            return withDays + base.filter { !ids.contains($0.id) }
        case .favorites:
            let favoriteKeys = Set(profiles.filter(\.isFavorite).map(\.phoneKey))
            let favorites = base.filter { c in c.allKeys.contains(where: favoriteKeys.contains) }
            let ids = Set(favorites.map(\.id))
            return favorites + base.filter { !ids.contains($0.id) }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.status == .denied || store.status == .restricted {
                    deniedView
                } else if store.isLoading && store.contacts.isEmpty {
                    ProgressView()
                } else {
                    list
                }
            }
            .navigationTitle("연락처")
            .searchable(text: $query, prompt: "이름, 번호 뒷자리, 초성")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    Menu {
                        Picker("정렬", selection: $sort) {
                            ForEach(ContactSort.allCases) { option in
                                Label(option.title, systemImage: option.symbol).tag(option)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                FieldSettingsView(
                    title: "연락처 표시 설정",
                    orderRaw: $orderRaw, enabledRaw: $enabledRaw,
                    defaultOrder: InfoField.listOrder, defaultEnabled: InfoField.listEnabled,
                    extra: ExtraToggle(title: "이름 옆 즐겨찾기 별", symbol: "star", isOn: $showStar)
                ) { fields in
                    ContactRow(contact: .sample, fields: fields, memo: SampleData.memo,
                               tags: SampleData.tags, isFavorite: true, showStar: showStar,
                               lastDate: SampleData.lastDate, trailing: nil)
                        .padding(14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    private var list: some View {
        let contacts = sortedContacts
        let last = lastByKey
        let memos = latestMemoByKey
        let tagsByKey = Dictionary(profiles.filter { !$0.tags.isEmpty }.map { ($0.phoneKey, $0.tags) },
                                   uniquingKeysWith: { first, _ in first })
        let favoriteKeys = Set(profiles.filter(\.isFavorite).map(\.phoneKey))
        let fields = InfoField.visible(orderRaw: orderRaw, enabledRaw: enabledRaw)
        return List(contacts) { contact in
            let lastDate = contact.allKeys.compactMap { last[$0] }.max()
            Button { onSelect(contact) } label: {
                ContactRow(
                    contact: contact,
                    fields: fields,
                    memo: contact.allKeys.compactMap { memos[$0] }.max { $0.createdAt < $1.createdAt }?.body,
                    tags: contact.allKeys.compactMap { tagsByKey[$0] }.first ?? [],
                    isFavorite: contact.allKeys.contains(where: favoriteKeys.contains),
                    showStar: showStar,
                    lastDate: lastDate,
                    // 최근 연락순·오래된 순일 때는 마지막 연락 시점을 이름 줄 오른쪽에 붙인다.
                    trailing: (sort == .recent || sort == .stale) && !fields.contains(.last)
                        ? lastDate.map { $0.formatted(.relative(presentation: .named)) } : nil
                )
            }
        }
        .listStyle(.plain)
        .overlay {
            if contacts.isEmpty && !store.isLoading {
                ContentUnavailableView.search(text: query)
            }
        }
    }

    private var deniedView: some View {
        ContentUnavailableView {
            Label("연락처 접근이 꺼져 있습니다", systemImage: "person.crop.circle.badge.exclamationmark")
        } description: {
            Text("설정에서 RemindCall의 연락처 접근을 허용해 주세요.")
        } actions: {
            Button("설정 열기") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
        }
    }
}

/// 이름은 항상 첫 줄에 고정하고, 선택한 정보를 정해진 순서대로 이름 아래에 보여 준다.
struct ContactRow: View {
    let contact: ContactInfo
    let fields: [InfoField]
    let memo: String?
    let tags: [String]
    let isFavorite: Bool
    let showStar: Bool
    let lastDate: Date?
    let trailing: String?

    /// 전화번호와 회사는 한 줄("번호 · 회사")로 합쳐, 먼저 나오는 쪽 위치에 둔다.
    private var lines: [InfoField] {
        var result: [InfoField] = []
        var subtitleAdded = false
        for field in fields {
            if field == .company || field == .number {
                if !subtitleAdded { result.append(field); subtitleAdded = true }
            } else {
                result.append(field)
            }
        }
        return result
    }

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(contact: contact, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(contact.name).font(.body.weight(.medium)).foregroundStyle(.primary).lineLimit(1)
                    Spacer(minLength: 4)
                    if let trailing {
                        Text(trailing).font(.footnote).foregroundStyle(.secondary)
                    }
                    if showStar && isFavorite {
                        Image(systemName: "star.fill").font(.footnote).foregroundStyle(.yellow)
                    }
                }
                ForEach(lines) { field in
                    line(field)
                }
            }
        }
    }

    @ViewBuilder
    private func line(_ field: InfoField) -> some View {
        switch field {
        case .company, .number:
            if let text = subtitle {
                Text(text).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
        case .birthday:
            if let badge = contact.birthdayBadge {
                Text(badge.text)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(badge.urgent ? .orange : .secondary)
            }
        case .last:
            if let lastDate {
                Text("연락 \(lastDate.formatted(.relative(presentation: .named)))")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        case .memo:
            if let memo, !memo.isEmpty {
                Label(memo.replacingOccurrences(of: "\n", with: " "), systemImage: "note.text")
                    .font(.footnote).foregroundStyle(.secondary).lineLimit(1)
            }
        case .tags:
            if !tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(tags.prefix(3), id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(.secondary.opacity(0.18), in: Capsule())
                    }
                    if tags.count > 3 {
                        Text("+\(tags.count - 3)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var subtitle: String? {
        var parts: [String] = []
        if fields.contains(.number), let number = contact.phones.first?.number { parts.append(number) }
        if fields.contains(.company), !contact.company.isEmpty, contact.company != contact.name { parts.append(contact.company) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

struct AvatarView: View {
    let contact: ContactInfo
    let size: CGFloat

    var body: some View {
        Group {
            if let data = contact.photo, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    LinearGradient(colors: [contact.tint.opacity(0.9), contact.tint.opacity(0.5)],
                                   startPoint: .top, endPoint: .bottom)
                    Text(String(contact.name.prefix(1)))
                        .font(.system(size: size * 0.42, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
