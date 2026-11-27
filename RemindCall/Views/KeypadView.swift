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

    private let rows = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["*", "0", "#"]]

    private var matches: [ContactInfo] {
        let digits = number.filter(\.isNumber)
        guard digits.count >= 2 else { return [] }
        let found = store.contacts.filter { contact in
            contact.phones.contains { $0.key.contains(digits) }
        }
        // 뒷자리가 일치하는 연락처를 먼저 보여 준다.
        let suffix = found.filter { contact in contact.phones.contains { $0.key.hasSuffix(digits) } }
        let rest = found.filter { contact in !suffix.contains(contact) }
        return Array((suffix + rest).prefix(3))
    }

    var body: some View {
        VStack(spacing: 0) {
            matchList
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.horizontal, 16)

            HStack {
                Spacer(minLength: 44)
                Text(number.isEmpty ? " " : number)
                    .font(.system(size: 38, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if number.isEmpty {
                    Spacer(minLength: 44)
                } else {
                    Button { number.removeLast() } label: {
                        Image(systemName: "delete.left").font(.title3).foregroundStyle(.secondary)
                    }
                    .frame(width: 44)
                    .simultaneousGesture(LongPressGesture().onEnded { _ in number = "" })
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 64)

            VStack(spacing: 14) {
                ForEach(rows, id: \.self) { row in
                    HStack(spacing: 26) {
                        ForEach(row, id: \.self) { key in
                            Button { number.append(key) } label: { KeyFace(key: key) }
                                .buttonStyle(KeyPressStyle())
                        }
                    }
                }
                Button(action: dial) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.white)
                        .frame(width: 76, height: 76)
                        .background(Color(red: 0.2, green: 0.78, blue: 0.35), in: Circle())
                }
                .buttonStyle(KeyPressStyle())
                .padding(.top, 4)
            }
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    private var matchList: some View {
        if matches.isEmpty {
            VStack(spacing: 8) {
                Text(number.filter(\.isNumber).count < 2 ? "번호 뒷자리를 입력하면\n일치하는 연락처가 나타납니다" : "일치하는 연락처가 없습니다")
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
            VStack(spacing: 8) {
                ForEach(matches) { contact in
                    Button { onSelect(contact) } label: {
                        HStack(spacing: 12) {
                            AvatarView(contact: contact, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(contact.name).font(.body.weight(.semibold)).foregroundStyle(.primary)
                                Text(contact.phones.first?.number ?? "").font(.footnote).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let next = contact.birthday?.nextBirthday(), next.days <= 30 {
                                Text(next.days == 0 ? "🎂 오늘" : "🎂 D-\(next.days)").font(.caption)
                            }
                            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
                        }
                        .padding(10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
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
            .frame(width: 76, height: 76)
            .background(Color(.systemGray5), in: Circle())
        }
    }

    private struct KeyPressStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label.brightness(configuration.isPressed ? 0.25 : 0)
        }
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
