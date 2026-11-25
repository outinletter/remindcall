import SwiftData
import SwiftUI

struct FavoritesView: View {
    let store: ContactsStore
    let onSelect: (ContactInfo) -> Void

    @Query(filter: #Predicate<ContactProfile> { $0.isFavorite }) private var favorites: [ContactProfile]

    private var favoriteContacts: [ContactInfo] {
        var seen = Set<String>()
        return favorites.compactMap { store.byKey[$0.phoneKey] }.filter { seen.insert($0.id).inserted }
    }

    private var upcoming: [(contact: ContactInfo, days: Int)] {
        store.contacts
            .compactMap { contact -> (ContactInfo, Int)? in
                guard let next = contact.birthday?.nextBirthday(), next.days <= 30 else { return nil }
                return (contact, next.days)
            }
            .sorted { $0.1 < $1.1 }
            .map { (contact: $0.0, days: $0.1) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if !upcoming.isEmpty { birthdayStrip }
                    favoriteGrid
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .navigationTitle("즐겨찾기")
        }
    }

    private var birthdayStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("곧 생일", systemImage: "gift").font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(upcoming, id: \.contact.id) { item in
                        Button { onSelect(item.contact) } label: {
                            VStack(spacing: 6) {
                                AvatarView(contact: item.contact, size: 56)
                                Text(item.contact.name).font(.footnote).foregroundStyle(.primary).lineLimit(1)
                                Text(item.days == 0 ? "오늘" : "D-\(item.days)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(item.days <= 7 ? .orange : .secondary)
                            }
                            .frame(width: 84)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var favoriteGrid: some View {
        if favoriteContacts.isEmpty {
            ContentUnavailableView("즐겨찾기가 없습니다", systemImage: "star",
                                   description: Text("연락처 카드의 별 버튼으로 추가하세요."))
                .padding(.top, 40)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Label("즐겨찾기", systemImage: "star.fill").font(.headline)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 12) {
                    ForEach(favoriteContacts) { contact in
                        Button { onSelect(contact) } label: {
                            VStack(spacing: 8) {
                                AvatarView(contact: contact, size: 72)
                                Text(contact.name).font(.subheadline).foregroundStyle(.primary).lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                    }
                }
            }
        }
    }
}
