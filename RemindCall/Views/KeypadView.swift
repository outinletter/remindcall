import SwiftData
import SwiftUI

/// 번호를 누르면 일치하는 연락처 카드가 위에 나타난다.
struct KeypadView: View {
    let store: ContactsStore
    let onSelect: (ContactInfo) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @AppStorage("postCallEnabled") private var postCallEnabled = false
    @AppStorage("postCallMinutes") private var postCallMinutes = 10
    @AppStorage("labelEnabled") private var labelEnabled = false
    @State private var number = ""
    @State private var showLabelEditor = false
    @Query(filter: #Predicate<ContactProfile> { $0.isFavorite }) private var favorites: [ContactProfile]
    @Query(sort: \CallLog.calledAt, order: .reverse) private var calls: [CallLog]
    @Query(sort: \ContactNote.createdAt, order: .reverse) private var notes: [ContactNote]

    private let rows = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["*", "0", "#"]]

    private var matches: [ContactInfo] {
        let digits = number.filter(\.isNumber)
        guard digits.count >= 2 else { return [] }
        let typed = PhoneKey.make(number)
        let favoriteKeys = Set(favorites.map(\.phoneKey))
        var lastContact: [String: Date] = [:]
        for call in calls where lastContact[call.phoneKey] == nil { lastContact[call.phoneKey] = call.calledAt }
        for note in notes where (lastContact[note.phoneKey] ?? .distantPast) < note.createdAt {
            lastContact[note.phoneKey] = note.createdAt
        }

        // 정렬: 번호 완전 일치 > 뒷자리 일치 > 즐겨찾기 > 최근 연락 > 이름
        struct Ranked { let contact: ContactInfo; let score: Int; let last: Date }
        let ranked: [Ranked] = store.contacts.compactMap { contact in
            let keys = contact.phones.map(\.key)
            guard keys.contains(where: { $0.contains(digits) }) else { return nil }
            var score = 0
            if keys.contains(typed) { score += 8 }
            if keys.contains(where: { $0.hasSuffix(digits) }) { score += 4 }
            if contact.allKeys.contains(where: favoriteKeys.contains) { score += 2 }
            let last = contact.allKeys.compactMap { lastContact[$0] }.max() ?? .distantPast
            return Ranked(contact: contact, score: score, last: last)
        }
        let best = ranked.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            if $0.last != $1.last { return $0.last > $1.last }
            return $0.contact.name.localizedStandardCompare($1.contact.name) == .orderedAscending
        }
        return Array(best.prefix(20).map(\.contact))
    }

    private func isFavorite(_ contact: ContactInfo) -> Bool {
        let keys = Set(favorites.map(\.phoneKey))
        return contact.allKeys.contains(where: keys.contains)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 남는 공간만 쓰고, 넘치면 그 안에서 스크롤한다(키패드는 밀리지 않음).
            // 목록이 짧으면 키패드 쪽(아래)에 붙이고, 길면 1순위가 보이는 맨 위부터 스크롤한다.
            GeometryReader { proxy in
                ScrollView {
                    matchList
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .frame(minHeight: proxy.size.height, alignment: .bottom)
                }
            }
            .clipped() // 상태 표시줄 아래로 목록이 비치지 않게
            .scrollBounceBehavior(.basedOnSize)
            .frame(minHeight: 0, maxHeight: .infinity)
            .layoutPriority(-1)

            HStack {
                Spacer(minLength: 44)
                Text(number.isEmpty ? " " : number)
                    .font(.system(size: 38, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentShape(Rectangle())
                    .contextMenu {
                        // iPhone 전화 앱처럼 번호 칸을 길게 눌러 붙여넣기·복사
                        Button("붙여넣기", systemImage: "doc.on.clipboard") { paste() }
                        if !number.isEmpty {
                            Button("복사", systemImage: "doc.on.doc") { ContactActions.copy(number) }
                        }
                    }
                if number.isEmpty {
                    Spacer(minLength: 44)
                } else {
                    Button { number.removeLast() } label: {
                        Image(systemName: "delete.left").font(.title3).foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("지우기")
                    .frame(width: 44)
                    .simultaneousGesture(LongPressGesture().onEnded { _ in number = "" })
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 64)

            VStack(spacing: 14) {
                ForEach(rows, id: \.self) { row in
                    HStack(spacing: 30) {
                        ForEach(row, id: \.self) { key in
                            Button { number.append(key) } label: { KeyFace(key: key) }
                                .buttonStyle(KeyPressStyle())
                                .accessibilityLabel(Self.spoken(key))
                        }
                    }
                }
                Button(action: dial) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.white)
                        .frame(width: 74, height: 74)
                        .background(Color(red: 0.2, green: 0.78, blue: 0.35), in: Circle())
                }
                .buttonStyle(KeyPressStyle())
                .accessibilityLabel("전화")
                .padding(.top, 10)
            }
            .sensoryFeedback(.selection, trigger: number) // 키를 누를 때 가벼운 햅틱
            .padding(.top, 4)
            .padding(.bottom, 56) // iOS 전화 앱처럼 통화 버튼과 탭 바 사이를 넉넉히
        }
    }

    @ViewBuilder
    private var matchList: some View {
        if matches.isEmpty {
            VStack(spacing: 8) {
                Text(number.filter(\.isNumber).count < 2 ? L("번호 뒷자리를 입력하면\n일치하는 연락처가 나타납니다") : L("일치하는 연락처가 없습니다"))
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                if labelEnabled, LabelDirectory.e164(number) != nil {
                    Button("이 번호에 이름표 달기") { showLabelEditor = true }
                        .font(.footnote.weight(.semibold))
                }
            }
            .padding(.bottom, 12)
            .sheet(isPresented: $showLabelEditor) { LabelEditorView(existing: nil, number: number) }
        } else {
            VStack(spacing: 6) {
                ForEach(matches) { contact in
                    Button { onSelect(contact) } label: {
                        HStack(spacing: 12) {
                            AvatarView(contact: contact, size: 34)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(contact.name).font(.body.weight(.semibold)).foregroundStyle(.primary)
                                Text(contact.phones.first?.number ?? "").font(.footnote).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if isFavorite(contact) {
                                Image(systemName: "star.fill").font(.caption).foregroundStyle(.yellow)
                            }
                            if let next = contact.birthday?.nextBirthday(), next.days <= 30 {
                                Text(next.days == 0 ? "🎂 " + L("오늘") : "🎂 D-\(next.days)").font(.caption)
                            }
                            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .contactMenu(contact, isFavorite: isFavorite(contact))
                }
            }
        }
    }

    /// iOS 전화 앱처럼 숫자 아래에 문자 표시
    private struct KeyFace: View {
        let key: String
        private static let letters = ["2": "ABC", "3": "DEF", "4": "GHI", "5": "JKL", "6": "MNO",
                                      "7": "PQRS", "8": "TUV", "9": "WXYZ", "0": "+"]
        var body: some View {
            VStack(spacing: -2) {
                Text(key)
                    .font(.system(size: key == "*" ? 42 : 34, weight: .regular))
                    .offset(y: key == "*" ? 6 : 0)
                if let sub = Self.letters[key] {
                    Text(sub).font(.system(size: 10, weight: .bold)).tracking(2)
                }
            }
            .foregroundStyle(.primary)
            .frame(width: 74, height: 74)
            .background(Color(.systemGray5), in: Circle())
        }
    }

    private struct KeyPressStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label.brightness(configuration.isPressed ? 0.25 : 0)
        }
    }

    private static func spoken(_ key: String) -> String {
        switch key {
        case "*": L("별표")
        case "#": L("우물 정")
        default: key
        }
    }

    /// 복사한 번호에서 숫자와 + * #만 남긴다.
    private func paste() {
        guard let text = UIPasteboard.general.string else { return }
        let cleaned = text.filter { $0.isNumber || "+*#".contains($0) }
        if !cleaned.isEmpty { number = cleaned }
    }

    private func dial() {
        guard !number.isEmpty else { return }
        let key = PhoneKey.make(number)
        context.insert(CallLog(phoneKey: key))
        if postCallEnabled {
            NotificationManager.shared.schedulePostCall(name: matches.first?.name ?? number, phoneKey: key,
                                                        afterMinutes: postCallMinutes)
        }
        let encoded = number.replacingOccurrences(of: "#", with: "%23")
        if let url = URL(string: "tel://\(encoded)") { openURL(url) }
    }
}
