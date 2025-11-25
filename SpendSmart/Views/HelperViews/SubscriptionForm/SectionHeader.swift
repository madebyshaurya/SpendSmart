import SwiftUI

struct SubscriptionSectionHeader: View {
    var title: String
    var systemImage: String
    var tint: Color = .blue

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(tint)
            Text(title)
                .font(.instrumentSans(size: 18, weight: .bold))
                .foregroundColor(.primary)
        }
    }
}


