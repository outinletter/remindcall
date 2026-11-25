import SwiftData
import SwiftUI

/// 아이폰 통화 화면 배치: 위에 이름·번호, 가운데 카드, 아래 액션 버튼.
/// 실제 통화는 시스템 전화 앱이 처리한다. (음소거·키패드 같은 통화 제어 버튼은 두지 않는다.)
struct CallCardView: View {
    let contact: ContactInfo

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL

    @Query private var notes: [ContactNote]
    @Query private var calls: [CallLog]
    @Query private var profiles: [ContactProfile]

    @AppStorage("postCallEnabled") private var postCallEnabled = false
    @AppStorage("postCallMinutes") private var postCallMinutes = 10

    @State private var showNoteEditor = false
    @State private var showTagEditor = false
    @State private var showNumberPicker = false

    // 오른쪽 스와이프·아래로 끌어내리기로 닫기
    @State private var dragOffset: CGSize = .zero
    @State private var dragMode = DragMode.undecided
    @State private var scrollY: CGFloat = 0

    private enum DragMode { case undecided, horizontal, vertical, ignored }

    init(contact: ContactInfo) {
        self.contact = contact
        let keys = contact.allKeys
        _notes = Query(filter: #Predicate<ContactNote> { keys.contains($0.phoneKey) },
                       sort: \.createdAt, order: .reverse)
        _calls = Query(filter: #Predicate<CallLog> { keys.contains($0.phoneKey) },
                       sort: \.calledAt, order: .reverse)
        _profiles = Query(filter: #Predicate<ContactProfile> { keys.contains($0.phoneKey) })
    }

    private var tags: [String] { profiles.first?.tags ?? [] }

    private var lastContact: Date? {
        [calls.first?.calledAt, notes.first?.createdAt].compactMap { $0 }.max()
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [contact.tint.opacity(0.85), Color.black],
                           startPoint: .top, endPoint: .center)
                .background(Color.black)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: 14) {
                        PhoneCard(phones: contact.phones, onCall: call)
                        if let birthday = contact.birthday, birthday.nextBirthday() != nil {
                            BirthdayCard(birthday: birthday)
                        }
                        MemoCard(notes: notes, onDelete: { context.delete($0) })
                        TagCard(tags: tags, onEdit: { showTagEditor = true })
                        HistoryCard(calls: calls)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(GeometryReader { proxy in
                        Color.clear.preference(key: ScrollOffsetKey.self,
                                               value: proxy.frame(in: .named("cardScroll")).minY)
                    })
                }
                .coordinateSpace(name: "cardScroll")
                .onPreferenceChange(ScrollOffsetKey.self) { scrollY = $0 }
                actionBar
            }
        }
        .offset(dragOffset)
        .background(Color.black.ignoresSafeArea())
        .simultaneousGesture(dismissGesture)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showNoteEditor) {
            NoteEditorView { text in
                context.insert(ContactNote(phoneKey: contact.primaryKey, body: text))
            }
        }
        .sheet(isPresented: $showTagEditor) {
            TagEditorView(tags: tags) { newTags in
                if let profile = profiles.first {
                    profile.tags = newTags
                } else {
                    let profile = ContactProfile(phoneKey: contact.primaryKey)
                    profile.tags = newTags
                    context.insert(profile)
                }
            }
        }
        .confirmationDialog("전화할 번호", isPresented: $showNumberPicker, titleVisibility: .visible) {
            ForEach(contact.phones, id: \.self) { phone in
                Button("\(phone.label) \(phone.number)") { call(phone) }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            AvatarView(contact: contact, size: 88)
                .padding(.top, 24)
            Text(contact.name)
                .font(.system(size: 32, weight: .semibold))
                .multilineTextAlignment(.center)
            if !contact.company.isEmpty {
                Text(contact.company).font(.subheadline).foregroundStyle(.secondary)
            }
            Text(lastContact.map { "마지막 연락 \($0.formatted(.relative(presentation: .named)))" } ?? "아직 연락 기록 없음")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .overlay(alignment: .topTrailing) {
            Button(action: toggleFavorite) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .font(.title2)
                    .foregroundStyle(isFavorite ? .yellow : .white.opacity(0.8))
                    .padding(16)
            }
        }
    }

    private var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                let w = value.translation.width, h = value.translation.height
                if dragMode == .undecided {
                    if abs(w) > abs(h) {
                        dragMode = w > 0 ? .horizontal : .ignored
                    } else {
                        // 아래로 끌어내리기는 카드 목록이 맨 위일 때만
                        dragMode = (h > 0 && scrollY >= -1) ? .vertical : .ignored
                    }
                }
                switch dragMode {
                case .horizontal: dragOffset = CGSize(width: max(0, w), height: 0)
                case .vertical: dragOffset = CGSize(width: 0, height: max(0, h))
                default: break
                }
            }
            .onEnded { value in
                let close = (dragMode == .horizontal && (value.translation.width > 100 || value.predictedEndTranslation.width > 250))
                    || (dragMode == .vertical && (value.translation.height > 120 || value.predictedEndTranslation.height > 300))
                dragMode = .undecided
                if close {
                    dismiss()
                } else {
                    withAnimation(.spring(duration: 0.3)) { dragOffset = .zero }
                }
            }
    }

    private var isFavorite: Bool { profiles.first?.isFavorite ?? false }

    private func toggleFavorite() {
        if let profile = profiles.first {
            profile.isFavorite.toggle()
        } else {
            let profile = ContactProfile(phoneKey: contact.primaryKey)
            profile.isFavorite = true
            context.insert(profile)
        }
    }

    private var actionBar: some View {
        HStack(spacing: 36) {
            ActionButton(symbol: "square.and.pencil", title: "메모", tint: .white.opacity(0.18)) {
                showNoteEditor = true
            }
            ActionButton(symbol: "phone.fill", title: "전화", tint: .green, size: 76) {
                if contact.phones.count > 1 {
                    showNumberPicker = true
                } else if let phone = contact.phones.first {
                    call(phone)
                }
            }
            .disabled(contact.phones.isEmpty)
            ActionButton(symbol: "xmark", title: "닫기", tint: .white.opacity(0.18)) {
                dismiss()
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    private func call(_ phone: PhoneEntry) {
        let key = phone.key.isEmpty ? contact.primaryKey : phone.key
        context.insert(CallLog(phoneKey: key))
        if postCallEnabled {
            NotificationManager.shared.schedulePostCall(name: contact.name, phoneKey: key, afterMinutes: postCallMinutes)
        }
        let dial = phone.number.filter { $0.isNumber || $0 == "+" }
        if let url = URL(string: "tel://\(dial)") { openURL(url) }
    }
}

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct ActionButton: View {
    let symbol: String
    let title: String
    let tint: Color
    var size: CGFloat = 64
    let action: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Button(action: action) {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.36, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: size, height: size)
                    .background(tint, in: Circle())
            }
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }
}
