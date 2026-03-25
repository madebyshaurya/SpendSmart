import SwiftUI

struct DashboardInsightsSection<Picker: View, Content: View>: View {
    let showToggle: Bool
    let toggleTitle: String
    let onToggle: () -> Void

    @ViewBuilder let picker: Picker
    @ViewBuilder let content: Content

    init(
        showToggle: Bool,
        toggleTitle: String,
        onToggle: @escaping () -> Void,
        @ViewBuilder picker: () -> Picker,
        @ViewBuilder content: () -> Content
    ) {
        self.showToggle = showToggle
        self.toggleTitle = toggleTitle
        self.onToggle = onToggle
        self.picker = picker()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Insights")
                    .font(.manrope(size: 16, weight: .semibold))
                    .foregroundStyle(Color.brandTextPrimary)

                Spacer()

                if showToggle {
                    Button(action: onToggle) {
                        Text(toggleTitle)
                            .font(.manrope(size: 12, weight: .semibold))
                            .foregroundStyle(Color.brandVibrantBlue)
                    }
                }
            }

            picker

            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.brandSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.brandBorder, lineWidth: 1)
                )
        )
    }
}
