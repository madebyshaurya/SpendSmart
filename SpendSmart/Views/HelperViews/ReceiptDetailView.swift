//
//  ReceiptDetailView.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-03-31.
//

import SwiftUI
import Foundation
import UIKit
import Shimmer

struct ReceiptDetailView: View {
    @State private var receipt: Receipt
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    // Callback for when receipt is updated
    var onUpdate: ((Receipt) -> Void)?

    // Local state for logo and colors; initially not set.
    @State private var logoImage: UIImage? = nil
    @State private var logoColors: [Color] = [.gray]


    // Use the shared cache
    @StateObject private var logoCache = LogoCache.shared
    @StateObject private var currencyManager = CurrencyManager.shared

    @State private var animateContent = false
    @State private var currentImageIndex = 0
    @State private var isZoomed = false
    @State private var zoomScale: CGFloat = 1.0
    @State private var dragOffset = CGSize.zero
    @State private var lastDragValue = CGSize.zero
    @State private var showZoomControls = false
    @State private var isFullscreen = false
    @State private var updatedReceipt: Receipt
    @State private var selectedTab = 0
    @State private var logoLoadingTask: Task<Void, Never>? = nil

    // Constants for zoom levels
    private let minZoom: CGFloat = 1.0
    private let maxZoom: CGFloat = 5.0
    private let zoomIncrement: CGFloat = 0.5

    // Initialize with the receipt
    init(receipt: Receipt, onUpdate: ((Receipt) -> Void)? = nil) {
        self._receipt = State(initialValue: receipt)
        self.onUpdate = onUpdate
        // Initialize the updatedReceipt with the original receipt
        _updatedReceipt = State(initialValue: receipt)
    }

    var body: some View {
        ZStack {
            // Enhanced background with design system colors
            DesignTokens.Colors.Background.grouped
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: DesignTokens.Spacing.sectionSpacing) {
                    // Hero Header Section
                    heroHeaderSection
                        .semanticSpacing(.page)

                    // Tab Navigation
                    tabNavigationSection
                        .semanticSpacing(.cardOuter)

                    // Tab Content
                    tabContentSection
                        .semanticSpacing(.cardOuter)
                        .padding(.bottom, DesignTokens.Spacing.massive)
                }
            }
            .scrollIndicators(.hidden)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                IconButton(
                    icon: "xmark.circle.fill",
                    size: .medium,
                    style: .outlined
                ) {
                    withAnimation(DesignTokens.Animation.easeInOut) {
                        dismiss()
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
        }


        .fullScreenCover(isPresented: $isFullscreen) {
            fullscreenImageView
        }
        .onAppear {
            loadLogo()
            withAnimation(DesignTokens.Animation.spring.delay(0.2)) {
                animateContent = true
            }
        }
        .onDisappear {
            // Cancel any ongoing logo loading task
            logoLoadingTask?.cancel()
            logoLoadingTask = nil
        }
    }

    // MARK: - Hero Header Section
    private var heroHeaderSection: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // Store Logo and Info
            HStack(alignment: .top, spacing: 16) {
                // Animated Logo
                ZStack {
                    if let logo = logoImage {
                        Image(uiImage: logo)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(
                                        LinearGradient(
                                            colors: [primaryLogoColor.opacity(0.6), secondaryLogoColor.opacity(0.3)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                            .shadow(color: primaryLogoColor.opacity(0.3), radius: 12, x: 0, y: 6)
                            .scaleEffect(animateContent ? 1.0 : 0.8)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        colors: [primaryLogoColor.opacity(0.2), secondaryLogoColor.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(
                                            LinearGradient(
                                                colors: [primaryLogoColor.opacity(0.4), secondaryLogoColor.opacity(0.2)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 2
                                        )
                                )

                            Text(String(receipt.store_name.prefix(1)).uppercased())
                                .font(.spaceGrotesk(size: 36, weight: .bold))
                                .foregroundColor(primaryLogoColor)
                        }
                        .scaleEffect(animateContent ? 1.0 : 0.8)
                        .transition(.scale.combined(with: .opacity))
                    }
                }

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text(receipt.store_name.capitalized)
                        .textHierarchy(.pageTitle)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                        .accessibilityAddTraits(.isHeader)

                    Text(receipt.receipt_name)
                        .textHierarchy(.body)
                        .transition(.opacity)

                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.system(size: 14))
                                .foregroundColor(secondaryLogoColor)
                            Text(receipt.purchase_date, style: .date)
                                .font(.instrumentSans(size: 14))
                                .fontWeight(.medium)
                                            .foregroundColor(.secondary)
                                    }

                        if !receipt.store_address.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(tertiaryLogoColor)
                                Text(formatAddress(receipt.store_address))
                                    .font(.instrumentSans(size: 14))
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .transition(.slide)
                }
                .offset(x: animateContent ? 0 : -20)
                .opacity(animateContent ? 1 : 0)
            }

            // Total Amount Card
                        VStack(spacing: 16) {
                            HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Amount")
                                        .font(.instrumentSans(size: 14))
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                                    Text(currencyManager.formatAmount(receipt.total_amount, currencyCode: receipt.currency))
                            .font(.spaceGrotesk(size: 36, weight: .bold))
                            .foregroundColor(receipt.savings > 0 ? .green : .primary)

                                    if receipt.currency != currencyManager.preferredCurrency && receipt.total_amount != 0 {
                                        HStack(spacing: 4) {
                                            Text("≈")
                                                .font(.instrumentSans(size: 14))
                                                .foregroundColor(.secondary)
                                            Text(currencyManager.formatAmount(
                                                currencyManager.convertAmountSync(receipt.total_amount,
                                                                               from: receipt.currency,
                                                                               to: currencyManager.preferredCurrency),
                                                currencyCode: currencyManager.preferredCurrency))
                                    .font(.instrumentSans(size: 16))
                                    .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }

                                Spacer()

                    // Savings Badge
                    if receipt.savings > 0 {
                        VStack(spacing: 4) {
                            Text("SAVED")
                                .font(.instrumentSans(size: 10))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .tracking(1)

                            Text(currencyManager.formatAmount(receipt.savings, currencyCode: receipt.currency))
                                .font(.spaceGrotesk(size: 18, weight: .bold))
                                .foregroundColor(.white)

                            if receipt.currency != currencyManager.preferredCurrency && receipt.savings != 0 {
                                            Text(currencyManager.formatAmount(
                                    currencyManager.convertAmountSync(receipt.savings,
                                                                               from: receipt.currency,
                                                                               to: currencyManager.preferredCurrency),
                                                currencyCode: currencyManager.preferredCurrency))
                                    .font(.instrumentSans(size: 12))
                                    .fontWeight(.medium)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.green, Color.green.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: Color.green.opacity(0.3), radius: 8, x: 0, y: 4)
                        )
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                colorScheme == .dark ? Color.black.opacity(0.4) : Color.white.opacity(0.8),
                                colorScheme == .dark ? Color.black.opacity(0.2) : Color.white.opacity(0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [primaryLogoColor.opacity(0.3), secondaryLogoColor.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: primaryLogoColor.opacity(0.1), radius: 12, x: 0, y: 6)
          )
        }
        .offset(y: animateContent ? 0 : 30)
        .opacity(animateContent ? 1 : 0)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.3), value: animateContent)
    }

    // MARK: - Tab Navigation Section
    private var tabNavigationSection: some View {
        HStack(spacing: 0) {
            ForEach(Array(["Details", "Items", "Images", "Edit"].enumerated()), id: \.element) { index, tab in
                Button {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        selectedTab = index
                    }
                } label: {
                    VStack(spacing: 8) {
                        // Icons with increased size
                        Group {
                            switch tab {
                            case "Details":
                                Image(systemName: "info.circle.fill")
                            case "Items":
                                Image(systemName: "list.bullet.rectangle.fill")
                            case "Images":
                                Image(systemName: "photo.circle.fill")
                            case "Edit":
                                Image(systemName: "pencil.circle.fill")
                            default:
                                Image(systemName: "circle.fill")
                            }
                        }
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(selectedTab == index ? primaryLogoColor : .secondary)
                        
                        // Add text labels
                        Text(tab)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(selectedTab == index ? primaryLogoColor : .secondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedTab == index ? 
                                  primaryLogoColor.opacity(0.15) : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedTab == index ? 
                                           primaryLogoColor.opacity(0.4) : Color.clear, lineWidth: 1.5)
                            )
                    )
                    .scaleEffect(selectedTab == index ? 1.02 : 1.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedTab)
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(accessibilityLabel(for: tab))
                .accessibilityHint(accessibilityHint(for: tab))
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [
                            colorScheme == .dark ? Color.black.opacity(0.4) : Color.white.opacity(0.9),
                            colorScheme == .dark ? Color.black.opacity(0.2) : Color.white.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            LinearGradient(
                                colors: [primaryLogoColor.opacity(0.2), secondaryLogoColor.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: primaryLogoColor.opacity(0.08), radius: 12, x: 0, y: 6)
        )
    }

    // MARK: - Tab Content Section
    private var tabContentSection: some View {
        VStack(spacing: 20) {
            switch selectedTab {
            case 0:
                detailsTab
            case 1:
                itemsTab
            case 2:
                imagesTab
            case 3:
                editTab
            default:
                detailsTab
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }

    // MARK: - Details Tab
    private var detailsTab: some View {
        VStack(spacing: 20) {
            // Payment & Currency Info
            VStack(spacing: 16) {
                HStack {
                            IconDetailView(
                                icon: "creditcard.fill",
                        title: "Payment Method",
                                detail: receipt.payment_method,
                                color: primaryLogoColor
                            )

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                                HStack(spacing: 4) {
                                    Image(systemName: "dollarsign.circle.fill")
                                        .foregroundColor(secondaryLogoColor)
                                    Text("Currency")
                                        .font(.instrumentSans(size: 14))
                                .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                }

                                Text(receipt.currency)
                                    .font(.instrumentSans(size: 16))
                            .fontWeight(.semibold)
                                    .foregroundColor(.primary)

                                if receipt.currency != currencyManager.preferredCurrency {
                                    HStack(spacing: 4) {
                                        Text("Converted to")
                                            .font(.instrumentSans(size: 12))
                                            .foregroundColor(.secondary)
                                        Text(currencyManager.preferredCurrency)
                                    .font(.instrumentSans(size: 12))
                                    .fontWeight(.medium)
                                            .foregroundColor(.blue)
                                    }

                                    Text("Rates: \(currencyManager.getLastUpdatedString())")
                                        .font(.instrumentSans(size: 10))
                                        .foregroundColor(.secondary.opacity(0.7))
                                }
                            }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white.opacity(0.7))
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                )

                // Tax Information
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tax Amount")
                            .font(.instrumentSans(size: 14))
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        Text(currencyManager.formatAmount(receipt.total_tax, currencyCode: receipt.currency))
                            .font(.spaceGrotesk(size: 24, weight: .bold))
                            .foregroundColor(.primary)

                        if receipt.currency != currencyManager.preferredCurrency && receipt.total_tax != 0 {
                            Text(currencyManager.formatAmount(
                                currencyManager.convertAmountSync(receipt.total_tax,
                                                               from: receipt.currency,
                                                               to: currencyManager.preferredCurrency),
                                currencyCode: currencyManager.preferredCurrency))
                                .font(.instrumentSans(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // Tax percentage
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Tax Rate")
                            .font(.instrumentSans(size: 14))
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        let taxRate = receipt.total_amount > 0 ? (receipt.total_tax / receipt.total_amount) * 100 : 0
                        Text("\(taxRate, specifier: "%.1f")%")
                            .font(.spaceGrotesk(size: 24, weight: .bold))
                            .foregroundColor(secondaryLogoColor)
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white.opacity(0.7))
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                )
            }


        }
    }

    // MARK: - Items Tab
    private var itemsTab: some View {
        VStack(spacing: 12) {
                        ForEach(Array(receipt.items.enumerated()), id: \.element.id) { index, item in
                ModernReceiptItemCard(
                    item: item,
                    logoColors: logoColors.isEmpty ? [.gray] : logoColors,
                    index: index,
                    currencyCode: receipt.currency
                )
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.9)).combined(with: .offset(y: 15)),
                                    removal: .opacity.combined(with: .scale(scale: 0.9))
                                ))
                                .offset(y: animateContent ? 0 : 15)
                                .opacity(animateContent ? 1 : 0)
                                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1 + Double(index) * 0.05), value: animateContent)
                        }
                    }
    }

    // MARK: - Images Tab
    private var imagesTab: some View {
        VStack(spacing: 20) {
            if !receipt.image_urls.isEmpty || (receipt.image_url != "placeholder_url") {
                // Image carousel
                ZStack {
                    TabView(selection: $currentImageIndex) {
                        ForEach(0..<(receipt.image_urls.isEmpty ? 1 : receipt.image_urls.count), id: \.self) { index in
                            let urlString = receipt.image_urls.isEmpty ? receipt.image_url : receipt.image_urls[index]
                            CustomAsyncImage(urlString: urlString) { image in
                                ZStack {
                                    image.resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .cornerRadius(20)
                                        .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
                                        .scaleEffect(isZoomed ? zoomScale : 1.0)
                                        .offset(isZoomed ? dragOffset : .zero)
                                        .gesture(
                                            TapGesture(count: 2).onEnded { _ in
                        withAnimation(.spring()) {
                                                    isZoomed.toggle()
                                                    if isZoomed {
                                                        zoomScale = 2.0
                                                        showZoomControls = true
                                                    } else {
                                                        zoomScale = 1.0
                                                        dragOffset = .zero
                                                        lastDragValue = .zero
                                                        showZoomControls = false
                                                    }
                                                }
                                            }
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
                                            .simultaneously(with:
                                                MagnificationGesture()
                                                    .onChanged { value in
                                                        if isZoomed {
                                                            let newScale = zoomScale * value
                                                            zoomScale = min(max(newScale, minZoom), maxZoom)
                                                        }
                                                    }
                                            )
                                        )

                                    // Zoom controls overlay
                                    if isZoomed && showZoomControls {
                                        VStack {
                                            Spacer()

                                            HStack(spacing: 20) {
                                                zoomControlButton(icon: "minus.magnifyingglass", action: {
                                                    withAnimation(.spring()) {
                                                        zoomScale = max(zoomScale - zoomIncrement, minZoom)
                                                    }
                                                }, disabled: zoomScale <= minZoom)

                                                zoomControlButton(icon: "arrow.counterclockwise", action: {
                                                    withAnimation(.spring()) {
                                                        zoomScale = 2.0
                                                        dragOffset = .zero
                                                        lastDragValue = .zero
                                                    }
                                                })

                                                zoomControlButton(icon: "plus.magnifyingglass", action: {
                                                    withAnimation(.spring()) {
                                                        zoomScale = min(zoomScale + zoomIncrement, maxZoom)
                                                    }
                                                }, disabled: zoomScale >= maxZoom)

                                                zoomControlButton(icon: "xmark.circle.fill", action: {
                                                    withAnimation(.spring()) {
                                                        isZoomed = false
                                                        zoomScale = 1.0
                                                        dragOffset = .zero
                                                        lastDragValue = .zero
                                                        showZoomControls = false
                                                    }
                                                })
                                            }
                                            .padding(.bottom, 20)
                                            .transition(.move(edge: .bottom).combined(with: .opacity))
                                        }
                                    }
                                }
                            } placeholder: {
                                ProgressView()
                                    .frame(height: 300)
                                    .transition(.opacity)
                            }
                            .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: receipt.image_urls.count > 1 ? .always : .never))
                    .frame(height: 300)
                    .cornerRadius(20)
                    .animation(.easeInOut, value: currentImageIndex)

                    // Image counter pill
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
                VStack(spacing: 4) {
                    if isZoomed {
                        Text("Current zoom: \(Int(zoomScale * 100))%")
                            .font(.instrumentSans(size: 14))
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Text("Pinch to zoom, drag to pan")
                            .font(.instrumentSans(size: 12))
                            .foregroundColor(.secondary)
                    } else {
                        Text("Double-tap to zoom in")
                            .font(.instrumentSans(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colorScheme == .dark ? Color.black.opacity(0.7) : Color.white.opacity(0.9))
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                )
                .transition(.opacity)
                .animation(.easeInOut, value: isZoomed)
            } else {
                EmptyStateView(message: "No images available for this receipt.")
                    .frame(height: 300)
            }
        }
    }

    // MARK: - Edit Tab
    private var editTab: some View {
        InlineReceiptEditView(receipt: $receipt) { updatedReceipt in
            self.updatedReceipt = updatedReceipt
            if let onUpdate = onUpdate {
                onUpdate(updatedReceipt)
            }
            // Reload logo when receipt is updated
            loadLogoSafely()
        }
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 20)
        .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1), value: animateContent)
    }

    // MARK: - Fullscreen Image View
    private var fullscreenImageView: some View {
            ZStack {
                Color.black.ignoresSafeArea()

                GeometryReader { geometry in
                    let urlString = receipt.image_urls.isEmpty ? receipt.image_url : receipt.image_urls[currentImageIndex]
                    CustomAsyncImage(urlString: urlString) { image in
                        image.resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .scaleEffect(zoomScale)
                            .offset(dragOffset)
                            .gesture(
                                TapGesture(count: 2).onEnded { _ in
                                    withAnimation(.spring()) {
                                        if zoomScale > 1.0 {
                                            zoomScale = 1.0
                                            dragOffset = .zero
                                            lastDragValue = .zero
                                        } else {
                                            zoomScale = 3.0
                                        }
                                    }
                                }
                                .simultaneously(with:
                                    DragGesture()
                                        .onChanged { value in
                                            dragOffset = CGSize(
                                                width: lastDragValue.width + value.translation.width,
                                                height: lastDragValue.height + value.translation.height
                                            )
                                        }
                                        .onEnded { value in
                                            lastDragValue = dragOffset
                                        }
                                )
                                .simultaneously(with:
                                    MagnificationGesture()
                                        .onChanged { value in
                                            let newScale = zoomScale * value
                                            zoomScale = min(max(newScale, minZoom), maxZoom)
                                        }
                                )
                            )
                    } placeholder: {
                        ProgressView()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                }

                // Fullscreen controls
                VStack {
                    HStack {
                        Button(action: {
                            withAnimation(.spring()) {
                                isFullscreen = false
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .padding()
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .padding()

                        Spacer()

                        Text("\(Int(zoomScale * 100))%")
                            .font(.instrumentSans(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.black.opacity(0.5)))
                    }

                    Spacer()

                    // Zoom controls
                    HStack(spacing: 30) {
                        Button(action: {
                            withAnimation(.spring()) {
                                zoomScale = max(zoomScale - zoomIncrement, minZoom)
                            }
                        }) {
                            Image(systemName: "minus")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .disabled(zoomScale <= minZoom)
                        .opacity(zoomScale <= minZoom ? 0.5 : 1.0)

                        Button(action: {
                            withAnimation(.spring()) {
                                zoomScale = 1.0
                                dragOffset = .zero
                                lastDragValue = .zero
                            }
                        }) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }

                        Button(action: {
                            withAnimation(.spring()) {
                                zoomScale = min(zoomScale + zoomIncrement, maxZoom)
                            }
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .disabled(zoomScale >= maxZoom)
                        .opacity(zoomScale >= maxZoom ? 0.5 : 1.0)
                    }
                    .padding(.bottom, 40)
                }
            }
            .statusBar(hidden: true)
            .onDisappear {
                if !isZoomed {
                    zoomScale = 1.0
                    dragOffset = .zero
                    lastDragValue = .zero
                }
        }
    }

    // MARK: - Helper Views
    private func zoomControlButton(icon: String, action: @escaping () -> Void, disabled: Bool = false) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.white)
                .padding(12)
                .background(Circle().fill(Color.black.opacity(0.7)))
        }
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1.0)
    }

    // MARK: - Background Gradient
    private var backgroundGradient: some View {
        ZStack {
            Rectangle()
                .fill(colorScheme == .dark ? Color.black : Color.white)

            GeometryReader { geometry in
                if !logoColors.isEmpty {
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
                } else {
                    Circle()
                        .fill(Color.gray.opacity(colorScheme == .dark ? 0.15 : 0.1))
                        .frame(width: geometry.size.width * 0.7)
                        .offset(x: geometry.size.width * 0.4, y: geometry.size.height * -0.3)
                        .blur(radius: 100)
                }
            }
        }
    }

    // MARK: - Computed Properties
    private var primaryLogoColor: Color {
        logoColors.first ?? (colorScheme == .dark ? .white : .black)
    }

    private var secondaryLogoColor: Color {
        logoColors.count > 1 ? logoColors[1] : primaryLogoColor.opacity(0.7)
    }

    private var tertiaryLogoColor: Color {
        logoColors.count > 2 ? logoColors[2] : secondaryLogoColor.opacity(0.8)
    }

    // MARK: - Helper Functions
    private func formatAddress(_ address: String) -> String {
        let components = address.components(separatedBy: ",")
        return components.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? address
    }

    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
    }

    private func loadLogo() {
        loadLogoSafely()
    }
    
    private func loadLogoSafely() {
        // Cancel any existing task
        logoLoadingTask?.cancel()
        
        logoLoadingTask = Task {
            let (image, colors) = await LogoService.shared.fetchLogoForReceipt(receipt)
            
            // Check if task was cancelled
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                logoImage = image
                logoColors = colors
            }
        }
    }

    // MARK: - Accessibility Helper Functions
    private func accessibilityLabel(for tab: String) -> String {
        switch tab {
        case "Details": return "Receipt Details"
        case "Items": return "Receipt Items"
        case "Images": return "Receipt Images"
        case "Edit": return "Edit Receipt"
        default: return tab
        }
    }

    private func accessibilityHint(for tab: String) -> String {
        switch tab {
        case "Details": return "View payment method, tax, and other receipt details"
        case "Items": return "View list of purchased items"
        case "Images": return "View receipt images with zoom capability"
        case "Edit": return "Edit receipt information inline"
        default: return "Tap to switch to \(tab) tab"
        }
    }
}

// MARK: - Modern Receipt Item Card
struct ModernReceiptItemCard: View {
    let item: ReceiptItem
    let logoColors: [Color]
    let index: Int
    let currencyCode: String
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var currencyManager = CurrencyManager.shared

    var body: some View {
        HStack(spacing: 12) {
            // Item icon - reduced size
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                itemColor.opacity(0.2),
                                itemColor.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle()
                            .stroke(itemColor.opacity(0.3), lineWidth: 1)
                    )

                if item.isDiscount {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.green)
                } else {
                    Text(String(item.name.prefix(1)).uppercased())
                        .font(.spaceGrotesk(size: 16, weight: .bold))
                        .foregroundColor(itemColor)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.instrumentSans(size: 14))
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)

                if !item.category.isEmpty {
                    Text(item.category)
                        .font(.instrumentSans(size: 11))
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(itemColor.opacity(0.1))
                                .overlay(
                                    Capsule()
                                        .stroke(itemColor.opacity(0.3), lineWidth: 1)
                                )
                        )
                }

                if item.isDiscount, let description = item.discountDescription {
                    Text(description)
                        .font(.instrumentSans(size: 11))
                        .foregroundColor(.green)
                        .padding(.top, 1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                HStack(spacing: 4) {
                    if let originalPrice = item.originalPrice, originalPrice > 0, originalPrice != item.price {
                        Text(currencyManager.formatAmount(originalPrice, currencyCode: currencyCode))
                            .font(.instrumentSans(size: 12))
                            .foregroundColor(.secondary)
                            .strikethrough(true, color: .green.opacity(0.7))
                    }

                    Text(currencyManager.formatAmount(item.price, currencyCode: currencyCode))
                        .font(.spaceGrotesk(size: 16, weight: .bold))
                        .foregroundColor(itemPriceColor)
                }

                if item.isDiscount {
                    Text("SAVED")
                        .font(.instrumentSans(size: 9))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.green)
                        )
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [
                            colorScheme == .dark ? Color.black.opacity(0.4) : Color.white.opacity(0.8),
                            colorScheme == .dark ? Color.black.opacity(0.2) : Color.white.opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(itemColor.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: itemColor.opacity(0.1), radius: 6, x: 0, y: 3)
    }

    private var itemColor: Color {
        if item.isDiscount {
            return .green
        } else if logoColors.count > 0 {
            return logoColors[index % logoColors.count]
        }
        return .blue
    }

    private var itemPriceColor: Color {
        if item.isDiscount {
            return .green
        } else if item.price == 0 {
            return .green
        } else if let originalPrice = item.originalPrice, originalPrice > item.price {
            return .green
        } else {
            return .primary
        }
    }
}

// MARK: - Icon Detail View
struct IconDetailView: View {
    let icon: String
    let title: String
    let detail: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.instrumentSans(size: 14))
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                Text(detail)
                    .font(.instrumentSans(size: 16))
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
        }
    }
}

// MARK: - Preview
struct ReceiptDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleItems = [
            ReceiptItem(id: UUID(), name: "Coffee", price: 4.99, category: "Dining"),
            ReceiptItem(id: UUID(), name: "Bagel", price: 3.49, category: "Dining"),
            ReceiptItem(id: UUID(), name: "Discount", price: -2.00, category: "Discount", isDiscount: true)
        ]

        let sampleReceipt = Receipt(
            id: UUID(),
            user_id: UUID(),
            image_urls: ["https://example.com/image.jpg"],
            total_amount: 6.48,
            items: sampleItems,
            store_name: "Coffee Shop",
            store_address: "123 Main St",
            receipt_name: "Morning Coffee",
            purchase_date: Date(),
            currency: "USD",
            payment_method: "Credit Card",
            total_tax: 0.58
        )

        return NavigationView {
            ReceiptDetailView(receipt: sampleReceipt)
                .environmentObject(AppState())
        }
    }
}
