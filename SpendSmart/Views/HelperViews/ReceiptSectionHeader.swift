import SwiftUI

struct ReceiptSectionHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.blue)
            Text(title)
                .font(.instrumentSans(size: 20, weight: .bold))
                .foregroundColor(.primary)
        }
        .padding(.leading)
    }
}
