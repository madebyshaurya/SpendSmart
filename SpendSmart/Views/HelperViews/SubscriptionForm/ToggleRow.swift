import SwiftUI

struct ToggleRow: View {
    var title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool
    var tint: Color = .blue

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.instrumentSans(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.instrumentSans(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: tint))
        }
        .solidCard()
    }
}


