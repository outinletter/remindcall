import SwiftData
import SwiftUI

enum ContactSort: String, CaseIterable, Identifiable {
    case name, recent, stale, birthday, favorites

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name: L("이름순")
        case .recent: L("최근 연락순")
        case .stale: L("연락 오래된 순")
        case .birthday: L("생일 임박순")
        case .favorites: L("즐겨찾기 먼저")
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
        func row(_ contact: ContactInfo) -> some View {
            let lastDate = contact.allKeys.compactMap { last[$0] }.max()
            let favorite = contact.allKeys.contains(where: favoriteKeys.contains)
            return Button { onSelect(contact) } label: {
                ContactRow(
                    contact: contact,
                    fields: fields,
                    memo: contact.allKeys.compactMap { memos[$0] }.max { $0.createdAt < $1.createdAt }?.body,
                    tags: contact.allKeys.compactMap { tagsByKey[$0] }.first ?? [],
                    isFavorite: favorite,
                    showStar: showStar,
                    lastDate: lastDate,
                    // 최근 연락순·오래된 순일 때는 마지막 연락 시점을 이름 줄 오른쪽에 붙인다.
                    trailing: (sort == .recent || sort == .stale) && !fields.contains(.last)
                        ? lastDate.map { $0.formatted(.relative(presentation: .named).locale(LanguageManager.shared.locale)) } : nil
                )
            }
            .contactMenu(contact, isFavorite: favorite, swipe: true)
        }
        return List {
            if sort == .name && query.isEmpty {
                // 이름순일 때는 첫 글자로 묶고 오른쪽 색인 바로 이동한다.
                ForEach(IndexGroup.make(contacts), id: \.title) { group in
                    Section(group.title) {
                        ForEach(group.contacts) { row($0) }
                    }
                    .indexLabel(group.title)
                }
            } else {
                ForEach(contacts) { row($0) }
            }
        }
        .listStyle(.plain)
        .indexBarVisible()
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

    /// 번호 줄이 있으면 생일은 그 줄 오른쪽에 붙인다.
    private var birthdayInline: Bool {
        fields.contains(.number) && fields.contains(.birthday) && !contact.phones.isEmpty
    }

    /// 전화번호와 회사는 한 줄("번호 · 회사")로 합쳐, 먼저 나오는 쪽 위치에 둔다.
    private var lines: [InfoField] {
        var result: [InfoField] = []
        var subtitleAdded = false
        for field in fields {
            if field == .birthday && birthdayInline { continue }
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
            HStack(spacing: 6) {
                if let text = subtitle {
                    Text(text).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
                if birthdayInline, let badge = contact.birthdayBadge {
                    Text(badge.text)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(badge.urgent ? .orange : .secondary)
                        .fixedSize()
                }
            }
        case .birthday:
            if let badge = contact.birthdayBadge {
                Text(badge.text)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(badge.urgent ? .orange : .secondary)
            }
        case .last:
            if let lastDate {
                Text("연락 \(lastDate.formatted(.relative(presentation: .named).locale(LanguageManager.shared.locale)))")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        case .memo:
            if let memo, !memo.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "note.text")
                    Text(memo.replacingOccurrences(of: "\n", with: " ")).lineLimit(1)
                }
                .font(.footnote).foregroundStyle(.secondary)
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

/// 이름 첫 글자 묶음: 한글은 초성(ㄱ~ㅎ), 영문은 A~Z, 그 밖은 #
struct IndexGroup {
    let title: String
    let contacts: [ContactInfo]

    static func make(_ contacts: [ContactInfo]) -> [IndexGroup] {
        var order: [String] = []
        var groups: [String: [ContactInfo]] = [:]
        for contact in contacts {
            let key = title(for: contact.name)
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(contact)
        }
        return order.sorted { rank($0) < rank($1) }.map { IndexGroup(title: $0, contacts: groups[$0] ?? []) }
    }

    private static let initials = Array("ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ")
    private static let merge: [Character: Character] = ["ㄲ": "ㄱ", "ㄸ": "ㄷ", "ㅃ": "ㅂ", "ㅆ": "ㅅ", "ㅉ": "ㅈ"]

    static func title(for name: String) -> String {
        guard let first = name.trimmingCharacters(in: .whitespaces).first else { return "#" }
        if let scalar = first.unicodeScalars.first, (0xAC00...0xD7A3).contains(scalar.value) {
            let initial = initials[Int(scalar.value - 0xAC00) / 588]
            return String(merge[initial] ?? initial)
        }
        if let ascii = first.uppercased().first, ascii.isASCII, ascii.isLetter { return String(ascii) }
        return "#"
    }

    /// 한글 → 영문 → #
    private static func rank(_ title: String) -> (Int, String) {
        if title == "#" { return (2, title) }
        if let scalar = title.unicodeScalars.first, scalar.isASCII { return (1, title) }
        return (0, title)
    }
}

private extension View {
    @ViewBuilder
    func indexLabel(_ title: String) -> some View {
        if #available(iOS 26.0, *) { sectionIndexLabel(title) } else { self }
    }

    @ViewBuilder
    func indexBarVisible() -> some View {
        if #available(iOS 26.0, *) { listSectionIndexVisibility(.visible) } else { self }
    }
}
