//
//  ReceiptDetailView.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-03-31.
//

import SwiftUI

struct ReceiptDetailView: View {
    let receipt: Receipt
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    // Local state for logo and colors; initially not set.
    @State private var logoImage: UIImage? = nil
    @State private var logoColors: [Color] = [.gray]

    // Use the shared cache
    @StateObject private var logoCache = LogoCache.shared

    @State private var animateContent = false
    @State private var currentImageIndex = 0
    @State private var isZoomed = false
    @State private var dragOffset = CGSize.zero
    @State private var lastDragValue = CGSize.zero

    var body: some View {
        ZStack {
            // Animated background based on logo colors
            backgroundGradient
                .ignoresSafeArea()
                .transition(.opacity)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header with logo and store info
                    HStack(alignment: .top, spacing: 16) {
                        if let logo = logoImage {
                            Image(uiImage: logo)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                                .transition(.scale)
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(primaryLogoColor.opacity(0.2))
                                    .frame(width: 80, height: 80)

                                Text(String(receipt.store_name.prefix(1)).uppercased())
                                    .font(.spaceGrotesk(size: 36, weight: .bold))
                                    .foregroundColor(primaryLogoColor)
                            }
                            .transition(.opacity)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(receipt.store_name.capitalized)
                                .font(.instrumentSerif(size: 28))
                                .bold()
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                                .transition(.move(edge: .leading))

                            Text(receipt.receipt_name)
                                .font(.instrumentSans(size: 16))
                                .foregroundColor(.secondary)
                                .transition(.opacity)

                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(.secondary)
                                Text(receipt.purchase_date, style: .date)
                                    .font(.instrumentSans(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 4)
                            .transition(.slide)
                        }
                    }
                    .padding(.bottom, 8)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: animateContent)

                    // Receipt images section
                    if !receipt.image_urls.isEmpty || (receipt.image_url != "placeholder_url") {
                        VStack(spacing: 8) {
                            // Image carousel
                            ZStack {
                                // Main image display
                                TabView(selection: $currentImageIndex) {
                                    // Display images from image_urls array
                                    ForEach(0..<(receipt.image_urls.isEmpty ? 1 : receipt.image_urls.count), id: \.self) { index in
                                        let url = URL(string: receipt.image_urls.isEmpty ? receipt.image_url : receipt.image_urls[index])
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .empty:
                                                ProgressView()
                                                    .frame(height: 200)
                                                    .transition(.opacity)
                                            case .success(let image):
                                                image.resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .cornerRadius(16)
                                                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                                                    .scaleEffect(isZoomed ? 1.5 : 1.0)
                                                    .offset(isZoomed ? dragOffset : .zero)
                                                    .gesture(
                                                        // Tap gesture for zooming
                                                        TapGesture(count: 2).onEnded { _ in
                                                            withAnimation(.spring()) {
                                                                isZoomed.toggle()
                                                                if !isZoomed {
                                                                    dragOffset = .zero
                                                                }
                                                            }
                                                        }
                                                        // Drag gesture for panning when zoomed
                                                        .simultaneously(with:
                                                            DragGesture()
                                                                .onChanged { value in
                                                                    if isZoomed {
                                                                        dragOffset = CGSize(
                                                                            width: lastDragValue.width + value.translation.width,
                                                                            height: lastDragValue.height + value.translation.height
                                                                        )
                                                                    }
                                                                }
                                                                .onEnded { value in
                                                                    if isZoomed {
                                                                        lastDragValue = dragOffset
                                                                    }
                                                                }
                                                        )
                                                    )
                                                    .transition(.scale)
                                            case .failure:
                                                ZStack {
                                                    RoundedRectangle(cornerRadius: 16)
                                                        .fill(Color.red.opacity(0.1))
                                                        .frame(height: 120)

                                                    VStack {
                                                        Image(systemName: "exclamationmark.triangle")
                                                            .font(.system(size: 24))
                                                            .foregroundColor(.red.opacity(0.8))

                                                        Text("Failed to load receipt image")
                                                            .font(.instrumentSans(size: 14))
                                                            .foregroundColor(.secondary)
                                                    }
                                                }
                                                .transition(.opacity)
                                            @unknown default:
                                                EmptyView()
                                            }
                                        }
                                        .tag(index)
                                    }
                                }
                                .tabViewStyle(PageTabViewStyle(indexDisplayMode: receipt.image_urls.count > 1 ? .always : .never))
                                .frame(height: 300)
                                .cornerRadius(16)
                                .animation(.easeInOut, value: currentImageIndex)

                                // Image counter pill (only show if multiple images)
                                if receipt.image_urls.count > 1 {
                                    Text("\(currentImageIndex + 1)/\(receipt.image_urls.count)")
                                        .font(.instrumentSans(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(Color.black.opacity(0.6))
                                        )
                                        .padding(8)
                                        .transition(.opacity)
                                        .animation(.easeInOut, value: currentImageIndex)
                                        .position(x: UIScreen.main.bounds.width - 60, y: 30)
                                }
                            }

                            // Zoom hint text
                            if receipt.image_urls.count > 0 {
                                Text(isZoomed ? "Double-tap to zoom out" : "Double-tap to zoom in")
                                    .font(.instrumentSans(size: 12))
                                    .foregroundColor(.secondary)
                                    .padding(.top, 4)
                                    .transition(.opacity)
                                    .animation(.easeInOut, value: isZoomed)
                            }
                        }
                        .transition(.opacity)
                    }

                    // Summary card with payment, currency, and location details
                    VStack(alignment: .leading, spacing: 20) {
                        // Total amount and tax section
                        VStack(spacing: 16) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Receipt Total")
                                        .font(.instrumentSans(size: 14))
                                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.9) : .black.opacity(0.8))
                                    Text("$\(receipt.total_amount, specifier: "%.2f")")
                                        .font(.spaceGrotesk(size: 32, weight: .bold))
                                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.9) : .black.opacity(0.8))
                                }

                                Spacer()

                                VStack(alignment: .trailing) {
                                    Text("Tax")
                                        .font(.instrumentSans(size: 14))
                                        .foregroundColor(.secondary)
                                    Text("$\(receipt.total_tax, specifier: "%.2f")")
                                        .font(.spaceGrotesk(size: 22, weight: .bold))
                                        .foregroundColor(.secondary)
                                }
                            }

                            // Only show this section if there are savings
                            if receipt.savings > 0 {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Original Price")
                                            .font(.instrumentSans(size: 14))
                                            .foregroundColor(.secondary)
                                        Text("$\(receipt.originalPrice, specifier: "%.2f")")
                                            .font(.spaceGrotesk(size: 24, weight: .bold))
                                            .foregroundColor(.secondary)
                                            .strikethrough(true, color: .red.opacity(0.7))
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing) {
                                        Text("Savings")
                                            .font(.instrumentSans(size: 14))
                                            .foregroundColor(.green)
                                        Text("$\(receipt.savings, specifier: "%.2f")")
                                            .font(.spaceGrotesk(size: 18, weight: .bold))
                                            .foregroundColor(.green)
                                    }
                                }
                                .padding(.top, 4)
                                .padding(.bottom, 4)
                                .padding(.horizontal, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.green.opacity(0.1))
                                )
                            }
                        }

                        Divider()
                            .padding(.vertical, 12)

                        // Payment & Currency section
                        HStack(spacing: 16) {
                            IconDetailView(
                                icon: "creditcard.fill",
                                title: "Payment",
                                detail: receipt.payment_method,
                                color: primaryLogoColor
                            )
                            .transition(.move(edge: .leading))

                            IconDetailView(
                                icon: "dollarsign.circle.fill",
                                title: "Currency",
                                detail: receipt.currency,
                                color: secondaryLogoColor
                            )
                            .transition(.move(edge: .bottom))
                        }
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: animateContent)

                        // Full location section – shows the entire store address on multiple lines.
                        if !receipt.store_address.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(tertiaryLogoColor)
                                    Text("Location")
                                        .font(.instrumentSans(size: 14))
                                        .foregroundColor(.secondary)
                                }
                                Text(receipt.store_address)
                                    .font(.instrumentSans(size: 14))
                                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.9) : .black.opacity(0.8))
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: animateContent)
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white.opacity(0.7))
                            .shadow(color: colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    )
                    .offset(y: animateContent ? 0 : 20)
                    .opacity(animateContent ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: animateContent)

                    // Items section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Items")
                            .font(.instrumentSerif(size: 24))
                            .fontWeight(.bold)
                            .padding(.bottom, 5)

                        ForEach(Array(receipt.items.enumerated()), id: \.element.id) { index, item in
                            ItemCard(item: item, logoColors: logoColors, index: index)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.9)).combined(with: .offset(y: 20)),
                                    removal: .opacity.combined(with: .scale(scale: 0.9))
                                ))
                                .offset(y: animateContent ? 0 : 20)
                                .opacity(animateContent ? 1 : 0)
                                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1 + Double(index) * 0.05), value: animateContent)
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(20)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 24))
                    }
                    .transition(.scale)
                }
            }
        }
        .onAppear {
            // Retrieve logo from cache first; if not, fetch it.
            if let cached = logoCache.logoCache[receipt.store_name.lowercased()] {
                logoImage = cached.image
                logoColors = cached.colors
            } else {
                Task {
                    let (fetchedImage, fetchedColors) = await LogoService.shared.fetchLogo(for: receipt.store_name)
                    await MainActor.run {
                        logoImage = fetchedImage
                        logoColors = fetchedColors
                    }
                }
            }

            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                animateContent = true
            }
        }
    }

    private var backgroundGradient: some View {
        ZStack {
            Rectangle()
                .fill(colorScheme == .dark ? Color.black : Color.white)

            GeometryReader { geometry in
                ForEach(0..<min(logoColors.count, 3), id: \.self) { i in
                    Circle()
                        .fill(logoColors[i].opacity(colorScheme == .dark ? 0.15 : 0.1))
                        .frame(width: geometry.size.width * 0.7)
                        .offset(
                            x: geometry.size.width * (i == 0 ? 0.4 : i == 1 ? -0.3 : 0.2),
                            y: geometry.size.height * (i == 0 ? -0.3 : i == 1 ? 0.4 : 0.1)
                        )
                        .blur(radius: 100)
                        .transition(.scale)
                }
            }
        }
    }

    private var primaryLogoColor: Color {
        logoColors.first ?? (colorScheme == .dark ? .white : .black)
    }

    private var secondaryLogoColor: Color {
        logoColors.count > 1 ? logoColors[1] : primaryLogoColor.opacity(0.7)
    }

    private var tertiaryLogoColor: Color {
        logoColors.count > 2 ? logoColors[2] : secondaryLogoColor.opacity(0.8)
    }

    private func formatAddress(_ address: String) -> String {
        let components = address.components(separatedBy: ",")
        return components.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? address
    }
}
