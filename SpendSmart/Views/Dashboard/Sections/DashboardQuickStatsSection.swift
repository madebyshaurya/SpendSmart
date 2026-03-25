import SwiftUI

struct DashboardQuickStatsSection: View {
    let receiptsCount: String
    let averagePerReceipt: String
    let totalSaved: String

    var body: some View {
        HStack(spacing: 12) {
            QuickStatCard(
                title: "Receipts",
                value: receiptsCount,
                icon: "doc.text.fill",
                color: .brandVibrantBlue
            )

            QuickStatCard(
                title: "Avg/Receipt",
                value: averagePerReceipt,
                icon: "chart.bar.fill",
                color: .brandRoyalBlue
            )

            QuickStatCard(
                title: "Saved",
                value: totalSaved,
                icon: "tag.fill",
                color: .brandSuccess
            )
        }
    }
}

private struct QuickStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)

            Text(value)
                .font(.ibmPlexMono(size: 16))
                .fontWeight(.bold)
                .foregroundStyle(Color.brandTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(title)
                .font(.manrope(size: 11, weight: .medium))
                .foregroundStyle(Color.brandTextTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.brandSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.brandBorder, lineWidth: 1)
                )
        )
    }
}
