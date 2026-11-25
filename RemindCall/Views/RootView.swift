import SwiftData
import SwiftUI

struct RootView: View {
    private enum Tab: Hashable { case favorites, recents, contacts, keypad, settings }

    @State private var store = ContactsStore()
    @State private var selected: ContactInfo?
    @State private var tab: Tab = .contacts
    @State private var refreshToken = UUID()

    @Environment(\.scenePhase) private var scenePhase
    @Query private var profiles: [ContactProfile]
    @Query private var notes: [ContactNote]
    @Query private var labels: [NumberLabel]

    @AppStorage("bdayEnabled") private var bdayEnabled = false
    @AppStorage("bdayHour") private var bdayHour = 9
    @AppStorage("bdaySameDay") private var bdaySameDay = true
    @AppStorage("bdayDayBefore") private var bdayDayBefore = false
    @AppStorage("bdayFavoritesOnly") private var bdayFavoritesOnly = false
    @AppStorage("labelEnabled") private var labelEnabled = false

    /// 이 값이 바뀌면 생일 알림을 다시 예약한다.
    private var birthdayKey: String {
        "\(store.contacts.count)|\(bdayEnabled)|\(bdayHour)|\(bdaySameDay)|\(bdayDayBefore)|\(bdayFavoritesOnly)|"
            + "\(profiles.filter(\.isFavorite).count)|\(notes.count)|\(refreshToken)"
    }

    /// 이 값이 바뀌면 이름표 목록을 확장에 다시 전달한다.
    private var labelKey: String {
        "\(labelEnabled)|" + labels.map { $0.number + $0.label }.joined(separator: ";")
    }

    var body: some View {
        TabView(selection: $tab) {
            FavoritesView(store: store) { selected = $0 }
                .tabItem { Label("즐겨찾기", systemImage: "star.fill") }
                .tag(Tab.favorites)
            RecentsView(store: store) { selected = $0 }
                .tabItem { Label("최근", systemImage: "clock.fill") }
                .tag(Tab.recents)
            ContactListView(store: store) { selected = $0 }
                .tabItem { Label("연락처", systemImage: "person.crop.circle.fill") }
                .tag(Tab.contacts)
            KeypadView(store: store) { selected = $0 }
                .tabItem { Label("키패드", systemImage: "circle.grid.3x3.fill") }
                .tag(Tab.keypad)
            SettingsView()
                .tabItem { Label("설정", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
        .task { await store.requestAndLoad() }
        .task(id: birthdayKey) { await rescheduleBirthdays() }
        .task(id: labelKey) {
            LabelDirectory.sync(labels: labels.map { ($0.number, $0.label) }, enabled: labelEnabled)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshToken = UUID() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openContactKey)) { notification in
            if let key = notification.userInfo?["phoneKey"] as? String, let contact = store.byKey[key] {
                selected = contact
            }
        }
        .fullScreenCover(item: $selected) { CallCardView(contact: $0) }
    }

    private func rescheduleBirthdays() async {
        var memos: [String: ContactNote] = [:]
        for note in notes where note.createdAt > (memos[note.phoneKey]?.createdAt ?? .distantPast) {
            memos[note.phoneKey] = note
        }
        await NotificationManager.shared.rescheduleBirthdays(
            contacts: store.contacts,
            enabled: bdayEnabled, hour: bdayHour, sameDay: bdaySameDay, dayBefore: bdayDayBefore,
            favoritesOnly: bdayFavoritesOnly,
            favoriteKeys: Set(profiles.filter(\.isFavorite).map(\.phoneKey)),
            memos: memos.mapValues(\.body)
        )
    }
}
