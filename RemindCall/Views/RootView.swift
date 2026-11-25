import SwiftUI

struct RootView: View {
    private enum Tab: Hashable { case favorites, recents, contacts, keypad }

    @State private var store = ContactsStore()
    @State private var selected: ContactInfo?
    @State private var tab: Tab = .contacts

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
        }
        .task { await store.requestAndLoad() }
        .fullScreenCover(item: $selected) { CallCardView(contact: $0) }
    }
}
