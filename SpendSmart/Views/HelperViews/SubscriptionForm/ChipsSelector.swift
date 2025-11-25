import SwiftUI

struct ChipsSelector<Option: Hashable & CustomStringConvertible>: View {
    var title: String
    var options: [Option]
    @Binding var selection: Option
    var tint: Color = .blue

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.instrumentSans(size: 13))
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        let isSelected = option == selection
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                selection = option
                            }
                        }) {
                            Text(option.description)
                                .font(.instrumentSans(size: 14, weight: .semibold))
                                .foregroundColor(isSelected ? tint : .primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule().fill(isSelected ? tint.opacity(0.18) : Color.white.opacity(0.06))
                                )
                                .overlay(
                                    Capsule().stroke(isSelected ? tint.opacity(0.5) : Color.white.opacity(0.12), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}


