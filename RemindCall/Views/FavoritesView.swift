import SwiftData
import SwiftUI

struct FavoritesView: View {
    let store: ContactsStore
    let onSelect: (ContactInfo) -> Void

    @AppStorage("favFieldOrder") private var orderRaw = InfoField.favOrder
    @AppStorage("favFieldEnabled") private var enabledRaw = InfoField.favEnabled
    @State private var showSettings = false

    @Query private var profiles: [ContactProfile]
    @Query private var notes: [ContactNote]
    @Query private var calls: [CallLog]

    private var favoriteContacts: [ContactInfo] {
        var seen = Set<String>()
        return profiles.filter(\.isFavorite)
            .compactMap { store.byKey[$0.phoneKey] }
            .filter { seen.insert($0.id).inserted }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                favoriteGrid
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            .navigationTitle("즐겨찾기")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                FieldSettingsView(
                    title: "즐겨찾기 표시 설정",
                    orderRaw: $orderRaw, enabledRaw: $enabledRaw,
                    defaultOrder: InfoField.favOrder, defaultEnabled: InfoField.favEnabled
                ) { fields in
                    FavoriteCard(contact: .sample, fields: fields, memo: SampleData.memo,
                                 tags: SampleData.tags, lastDate: SampleData.lastDate)
                        .frame(width: 180)
                }
            }
        }
    }

    @ViewBuilder
    private var favoriteGrid: some View {
        let contacts = favoriteContacts
        if contacts.isEmpty {
            ContentUnavailableView("즐겨찾기가 없습니다", systemImage: "star",
                                   description: Text("연락처 카드의 별 버튼으로 추가하세요."))
                .padding(.top, 40)
        } else {
            let memos = latestMemos
            let last = lastContactDates
            let tagsByKey = Dictionary(profiles.filter { !$0.tags.isEmpty }.map { ($0.phoneKey, $0.tags) },
                                       uniquingKeysWith: { first, _ in first })
            let fields = InfoField.visible(orderRaw: orderRaw, enabledRaw: enabledRaw)
            // 두 장씩 한 줄로 묶어, 같은 줄의 카드 높이를 맞춘다.
            VStack(spacing: 12) {
                ForEach(Array(stride(from: 0, to: contacts.count, by: 2)), id: \.self) { index in
                    HStack(alignment: .top, spacing: 12) {
                        cardButton(contacts[index], fields: fields, memos: memos, tagsByKey: tagsByKey, last: last)
                        if index + 1 < contacts.count {
                            cardButton(contacts[index + 1], fields: fields, memos: memos, tagsByKey: tagsByKey, last: last)
                        } else {
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func cardButton(_ contact: ContactInfo, fields: [InfoField], memos: [String: ContactNote],
                            tagsByKey: [String: [String]], last: [String: Date]) -> some View {
        Button { onSelect(contact) } label: {
            FavoriteCard(
                contact: contact, fields: fields,
                memo: contact.allKeys.compactMap { memos[$0] }.max { $0.createdAt < $1.createdAt }?.body,
                tags: contact.allKeys.compactMap { tagsByKey[$0] }.first ?? [],
                lastDate: contact.allKeys.compactMap { last[$0] }.max()
            )
        }
        .buttonStyle(.plain)
        .contactMenu(contact, isFavorite: true)
    }

    private var latestMemos: [String: ContactNote] {
        var result: [String: ContactNote] = [:]
        for note in notes where note.createdAt > (result[note.phoneKey]?.createdAt ?? .distantPast) {
            result[note.phoneKey] = note
        }
        return result
    }

    private var lastContactDates: [String: Date] {
        var result: [String: Date] = [:]
        for call in calls { result[call.phoneKey] = max(result[call.phoneKey] ?? .distantPast, call.calledAt) }
        for note in notes { result[note.phoneKey] = max(result[note.phoneKey] ?? .distantPast, note.createdAt) }
        return result
    }
}

struct FavoriteCard: View {
    let contact: ContactInfo
    let fields: [InfoField]
    let memo: String?
    let tags: [String]
    let lastDate: Date?

    var body: some View {
        VStack(spacing: 6) {
            AvatarView(contact: contact, size: 68)
            Text(contact.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).lineLimit(1)
            ForEach(fields) { field in
                fieldView(field)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.vertical, 14).padding(.horizontal, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder
    private func fieldView(_ field: InfoField) -> some View {
        switch field {
        case .birthday:
            if let badge = contact.birthdayBadge {
                Text(badge.text)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(badge.urgent ? .orange : .secondary)
            }
        case .company:
            if !contact.company.isEmpty {
                Text(contact.company).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        case .number:
            if let number = contact.phones.first?.number {
                Text(number).font(.caption).monospacedDigit().foregroundStyle(.secondary).lineLimit(1)
            }
        case .last:
            if let lastDate {
                Text("연락 \(lastDate.formatted(.relative(presentation: .named).locale(LanguageManager.shared.locale)))")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
        case .memo:
            if let memo, !memo.isEmpty {
                Text(memo.replacingOccurrences(of: "\n", with: " "))
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(2).multilineTextAlignment(.center)
            }
        case .tags:
            if !tags.isEmpty {
                Text(tags.prefix(2).joined(separator: " · ") + (tags.count > 2 ? " +\(tags.count - 2)" : ""))
                    .font(.caption2)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(.secondary.opacity(0.18), in: Capsule())
                    .lineLimit(1)
            }
        }
    }
}
