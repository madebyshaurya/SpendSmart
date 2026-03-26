import SwiftUI

/// Brand-first shareable spending card for social media.
/// Design: Deep navy bg, Instrument Serif stat, asymmetric layout, brandVibrantBlue accent.
struct SpendingShareCard: View {
    let title: String        // e.g. "This Month"
    let amount: Double
    let currency: String
    let category: String?    // e.g. "Dining"
    let percentChange: Double? // e.g. +23 or -15

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Top: SpendSmart branding
            HStack {
                Text("SpendSmart")
                    .font(.manrope(size: 12, weight: .bold))
                    .foregroundColor(.brandSkyBlue.opacity(0.7))
                    .tracking(1.5)
                    .textCase(.uppercase)
                Spacer()
            }

            Spacer()

            // Main stat
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.manrope(size: 14, weight: .medium))
                    .foregroundColor(.brandSkyBlue)

                Text(formattedAmount)
                    .font(.instrumentSerif(size: 48))
                    .foregroundColor(.white)
                    .monospacedDigit()

                // Accent rule
                Rectangle()
                    .fill(Color.brandVibrantBlue)
                    .frame(width: 40, height: 3)
                    .cornerRadius(1.5)
            }

            // Bottom: category + change
            HStack(spacing: 12) {
                if let category {
                    Text("Top: \(category)")
                        .font(.manrope(size: 12, weight: .medium))
                        .foregroundColor(.brandSkyBlue.opacity(0.8))
                }

                if let pct = percentChange {
                    HStack(spacing: 4) {
                        Image(systemName: pct >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                        Text("\(abs(Int(pct)))% vs last period")
                            .font(.manrope(size: 11, weight: .medium))
                    }
                    .foregroundColor(pct >= 0 ? Color.brandWarning : Color.brandSuccess)
                }

                Spacer()
            }
        }
        .padding(24)
        .frame(width: 320, height: 200)
        .background(Color.brandDeepNavy)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .parallaxTilt()
    }

    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(Int(amount))"
    }

    // MARK: - Render to Image for Sharing

    @MainActor
    func renderToImage() -> UIImage {
        let renderer = ImageRenderer(content: self)
        renderer.scale = 3.0 // Retina
        return renderer.uiImage ?? UIImage()
    }
}

/// Button that generates and shares a spending card.
struct ShareSpendingCardButton: View {
    let title: String
    let amount: Double
    let currency: String
    let category: String?
    let percentChange: Double?

    @State private var isGenerating = false

    var body: some View {
        Button {
            HapticManager.shared.buttonPress()
            shareCard()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .medium))
                Text("Share Stats")
                    .font(.manrope(size: 14, weight: .semibold))
            }
            .foregroundColor(.brandVibrantBlue)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.brandVibrantBlue.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isGenerating ? 0.97 : 1.0)
        .animation(.brandSnappy, value: isGenerating)
    }

    @MainActor
    private func shareCard() {
        isGenerating = true
        let card = SpendingShareCard(
            title: title,
            amount: amount,
            currency: currency,
            category: category,
            percentChange: percentChange
        )
        let image = card.renderToImage()

        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(activityVC, animated: true)
        }
        isGenerating = false
    }
}
