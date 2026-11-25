import SwiftData
import SwiftUI

/// 번호를 누르면 일치하는 연락처 카드가 위에 나타난다.
struct KeypadView: View {
    let store: ContactsStore
    let onSelect: (ContactInfo) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @State private var number = ""

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
                .frame(height: 190, alignment: .bottom)
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
                    HStack(spacing: 24) {
                        ForEach(row, id: \.self) { key in
                            Button { number.append(key) } label: {
                                Text(key)
                                    .font(.system(size: 34, weight: .regular, design: .rounded))
                                    .foregroundStyle(.primary)
                                    .frame(width: 78, height: 78)
                                    .background(.secondary.opacity(0.18), in: Circle())
                            }
                        }
                    }
                }
                Button(action: dial) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.white)
                        .frame(width: 78, height: 78)
                        .background(.green, in: Circle())
                }
                .disabled(number.isEmpty)
                .opacity(number.isEmpty ? 0.4 : 1)
            }
            .padding(.top, 8)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var matchList: some View {
        if matches.isEmpty {
            Text(number.filter(\.isNumber).count < 2 ? "번호 뒷자리를 입력하면\n일치하는 연락처가 나타납니다" : "일치하는 연락처가 없습니다")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.bottom, 12)
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

    private func dial() {
        guard !number.isEmpty else { return }
        context.insert(CallLog(phoneKey: PhoneKey.make(number)))
        let encoded = number.replacingOccurrences(of: "#", with: "%23")
        if let url = URL(string: "tel://\(encoded)") { openURL(url) }
    }
}
