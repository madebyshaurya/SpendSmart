//
//  MapMarkerView.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-05-01.
//

import SwiftUI
import MapKit

struct MapMarkerView: View {
    var storeLocation: StoreLocation
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var currencyManager = CurrencyManager.shared
    @State private var isAnimating = false
    @State private var logoImage: UIImage? = nil
    @State private var logoColors: [Color] = [.blue, .blue.opacity(0.7), .blue.opacity(0.5)]

    var body: some View {
        ZStack {
            // Outer circle with shadow
            Circle()
                .fill(colorScheme == .dark ? Color.black.opacity(0.7) : Color.white)
                .frame(width: storeLocation.markerSize, height: storeLocation.markerSize)
                .shadow(color: storeLocation.markerTint.opacity(0.5), radius: 4, x: 0, y: 2)

            // Colored ring
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            storeLocation.markerTint,
                            storeLocation.markerTint.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .frame(width: storeLocation.markerSize - 4, height: storeLocation.markerSize - 4)

            // Logo or store initial
            if let logoImage = logoImage {
                Image(uiImage: logoImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: storeLocation.markerSize * 0.6, height: storeLocation.markerSize * 0.6)
                    .clipShape(Circle())
            } else {
                Text(String(storeLocation.name.prefix(1)))
                    .font(.spaceGrotesk(size: storeLocation.markerSize * 0.4, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? .white : storeLocation.markerTint)
            }

            // Visit count badge
            ZStack {
                Circle()
                    .fill(storeLocation.markerTint)
                    .frame(width: storeLocation.markerSize * 0.4, height: storeLocation.markerSize * 0.4)
                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)

                Text("\(storeLocation.visitCount)")
                    .font(.spaceGrotesk(size: storeLocation.markerSize * 0.2, weight: .bold))
                    .foregroundColor(.white)
            }
            .position(x: storeLocation.markerSize * 0.8, y: storeLocation.markerSize * 0.2)
        }
        .scaleEffect(isAnimating ? 1.05 : 1.0)
        .animation(
            Animation.spring(response: 0.5, dampingFraction: 0.6)
                .repeatForever(autoreverses: true),
            value: isAnimating
        )
        .onAppear {
            loadLogo()
            // Add a slight delay before starting animation
            DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.1...0.5)) {
                isAnimating = true
            }
        }
    }

    private func loadLogo() {
        let logoService = LogoService.shared

        // Use the enhanced logo fetching method
        Task {
            let (image, colors) = await logoService.fetchLogoForStoreLocation(storeLocation)
            await MainActor.run {
                // If we got colors but no image, generate a placeholder
                if image == nil {
                    logoImage = logoService.generatePlaceholderImage(
                        for: storeLocation.name,
                        size: CGSize(width: storeLocation.markerSize * 0.6, height: storeLocation.markerSize * 0.6)
                    )
                } else {
                    logoImage = image
                }
                logoColors = colors
            }
        }
    }
}

struct StoreDetailCard: View {
    var storeLocation: StoreLocation
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var currencyManager = CurrencyManager.shared
    @State private var logoImage: UIImage? = nil
    @State private var logoColors: [Color] = [.blue, .blue.opacity(0.7), .blue.opacity(0.5)]
    @State private var isExpanded = false

    // Break down complex expressions into computed properties
    private var primaryColor: Color {
        logoColors.first ?? .blue
    }

    private var secondaryColor: Color {
        (logoColors.count > 1 ? logoColors[1] : logoColors.first ?? .blue).opacity(0.5)
    }

    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [primaryColor, secondaryColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var backgroundFill: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(colorScheme == .dark ? Color.black.opacity(0.7) : Color.white)
            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
    }

    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: 16)
            .strokeBorder(borderGradient, lineWidth: 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerView
            metricsRow

            // Expanded content
            if isExpanded {
                expandedContentView
            }
        }
        .padding(16)
        .background(backgroundFill)
        .overlay(borderOverlay)
        .onAppear {
            loadLogo()
        }
    }

    // Break down the body into smaller view components
    private var headerView: some View {
        HStack(spacing: 12) {
            // Logo or placeholder
            logoView

            VStack(alignment: .leading, spacing: 2) {
                Text(storeLocation.name)
                    .font(.instrumentSans(size: 18, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : .black)

                Text(storeLocation.address.components(separatedBy: ",").first ?? "")
                    .font(.instrumentSans(size: 14))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Expand/collapse button
            expandCollapseButton
        }
    }

    private var logoView: some View {
        Group {
            if let logoImage = logoImage {
                Image(uiImage: logoImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(primaryColor, lineWidth: 2)
                    )
            } else {
                Circle()
                    .fill(primaryColor)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(storeLocation.name.prefix(1)))
                            .font(.spaceGrotesk(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
        }
    }

    private var expandCollapseButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isExpanded.toggle()
            }
        } label: {
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(8)
                .background(
                    Circle()
                        .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.gray.opacity(0.1))
                )
        }
    }

    private var metricsRow: some View {
        HStack(spacing: 16) {
            metricView(
                icon: "calendar",
                value: "\(storeLocation.visitCount)",
                label: "Visits"
            )

            dividerView

            metricView(
                icon: "dollarsign.circle",
                value: currencyManager.formatAmount(
                    storeLocation.totalSpent,
                    currencyCode: currencyManager.preferredCurrency,
                    compact: true
                ),
                label: "Total Spent"
            )

            dividerView

            metricView(
                icon: "arrow.up.right",
                value: currencyManager.formatAmount(
                    storeLocation.averageSpent,
                    currencyCode: currencyManager.preferredCurrency,
                    compact: true
                ),
                label: "Avg. Spent"
            )
        }
        .padding(.vertical, 8)
    }

    private var dividerView: some View {
        Divider()
            .frame(height: 30)
            .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
    }

    private var expandedContentView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Visits")
                .font(.instrumentSans(size: 16, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white : .black)

            // Recent receipts list
            ForEach(storeLocation.receipts.prefix(3)) { receipt in
                recentReceiptRow(receipt: receipt)
            }
        }
        .padding(.top, 8)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func recentReceiptRow(receipt: Receipt) -> some View {
        HStack {
            Text(formatDate(receipt.purchase_date))
                .font(.instrumentSans(size: 14))
                .foregroundColor(.secondary)
                .lineLimit(1)

            Spacer()

            Text(currencyManager.formatAmount(receipt.total_amount, currencyCode: receipt.currency))
                .font(.spaceGrotesk(size: 16, weight: .bold))
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.vertical, 4)
    }

    private func metricView(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(primaryColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.spaceGrotesk(size: 16, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                Text(label)
                    .font(.instrumentSans(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func loadLogo() {
        let logoService = LogoService.shared

        // Use the enhanced logo fetching method
        Task {
            let (image, colors) = await logoService.fetchLogoForStoreLocation(storeLocation)
            await MainActor.run {
                // If we got colors but no image, generate a placeholder
                if image == nil {
                    logoImage = logoService.generatePlaceholderImage(
                        for: storeLocation.name,
                        size: CGSize(width: 40, height: 40)
                    )
                } else {
                    logoImage = image
                }
                logoColors = colors
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
