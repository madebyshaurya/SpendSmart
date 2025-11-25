import SwiftUI

struct SubscriptionMultilineTextField: View {
    var title: String
    @Binding var text: String
    var placeholder: String
    var tint: Color = .blue
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.instrumentSans(size: 13))
                .foregroundColor(.secondary)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(.instrumentSans(size: 16))
                    .padding(8)
                    .frame(minHeight: 80, maxHeight: 160)
                    .background(Color.clear)

                if text.isEmpty {
                    Text(placeholder)
                        .font(.instrumentSans(size: 16))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 16)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
            )
        }
    }
}


