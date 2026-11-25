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
    @AppStorage("contactSort") private var sort: ContactSort = .name
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

    /// 정렬 기준에 맞는 오른쪽 보조 문구
    private func detail(for contact: ContactInfo, last: [String: Date]) -> String? {
        switch sort {
        case .recent, .stale:
            return contact.allKeys.compactMap { last[$0] }.max()
                .map { $0.formatted(.relative(presentation: .named)) }
        case .birthday:
            guard let next = contact.birthday?.nextBirthday() else { return nil }
            return next.days == 0 ? "오늘" : "D-\(next.days)"
        default:
            return nil
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
                ToolbarItem(placement: .topBarTrailing) {
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
        }
    }

    private var list: some View {
        let contacts = sortedContacts
        let last = lastByKey
        return List(contacts) { contact in
            Button { onSelect(contact) } label: {
                HStack(spacing: 12) {
                    AvatarView(contact: contact, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(contact.name).font(.body).foregroundStyle(.primary)
                        if let first = contact.phones.first {
                            Text(first.number).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if let text = detail(for: contact, last: last) {
                        Text(text).font(.footnote).foregroundStyle(.secondary)
                    }
                }
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
