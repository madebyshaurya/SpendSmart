//
//  ReceiptDetailView.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-03-31.
//

import SwiftUI
import Foundation
import UIKit

struct ReceiptDetailView: View {
    let receipt: Receipt
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    // Callback for when receipt is updated
    var onUpdate: ((Receipt) -> Void)?

    // Local state for logo and colors; initially not set.
    @State private var logoImage: UIImage? = nil
    @State private var logoColors: [Color] = [.gray]
    @State private var isRefreshingRates: Bool = false
    @State private var showRateRefreshAlert: Bool = false

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

    // Constants for zoom levels
    private let minZoom: CGFloat = 1.0
    private let maxZoom: CGFloat = 5.0
    private let zoomIncrement: CGFloat = 0.5
    @State private var showEditSheet = false
    @State private var updatedReceipt: Receipt

    // Initialize with the receipt
    init(receipt: Receipt, onUpdate: ((Receipt) -> Void)? = nil) {
        self.receipt = receipt
        self.onUpdate = onUpdate
        // Initialize the updatedReceipt with the original receipt
        _updatedReceipt = State(initialValue: receipt)
    }

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
                                        let urlString = receipt.image_urls.isEmpty ? receipt.image_url : receipt.image_urls[index]
                                        CustomAsyncImage(urlString: urlString) { image in
                                                ZStack {
                                                    image.resizable()
                                                        .aspectRatio(contentMode: .fit)
                                                        .cornerRadius(16)
                                                        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                                                        .scaleEffect(isZoomed ? zoomScale : 1.0)
                                                        .offset(isZoomed ? dragOffset : .zero)
                                                        .gesture(
                                                            // Tap gesture for zooming
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
                                                            // Magnification gesture for pinch zooming
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
                                                        .transition(.scale)

                                                    // Zoom controls overlay
                                                    if isZoomed && showZoomControls {
                                                        VStack {
                                                            Spacer()

                                                            HStack(spacing: 20) {
                                                                // Zoom out button
                                                                Button(action: {
                                                                    withAnimation(.spring()) {
                                                                        zoomScale = max(zoomScale - zoomIncrement, minZoom)
                                                                    }
                                                                }) {
                                                                    Image(systemName: "minus.magnifyingglass")
                                                                        .font(.system(size: 24))
                                                                        .foregroundColor(.white)
                                                                        .padding(12)
                                                                        .background(Circle().fill(Color.black.opacity(0.7)))
                                                                }
                                                                .disabled(zoomScale <= minZoom)
                                                                .opacity(zoomScale <= minZoom ? 0.5 : 1.0)

                                                                // Fullscreen toggle button
                                                                Button(action: {
                                                                    withAnimation(.spring()) {
                                                                        isFullscreen.toggle()
                                                                    }
                                                                }) {
                                                                    Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                                                        .font(.system(size: 24))
                                                                        .foregroundColor(.white)
                                                                        .padding(12)
                                                                        .background(Circle().fill(Color.black.opacity(0.7)))
                                                                }

                                                                // Reset zoom button
                                                                Button(action: {
                                                                    withAnimation(.spring()) {
                                                                        zoomScale = 2.0
                                                                        dragOffset = .zero
                                                                        lastDragValue = .zero
                                                                    }
                                                                }) {
                                                                    Image(systemName: "arrow.counterclockwise")
                                                                        .font(.system(size: 24))
                                                                        .foregroundColor(.white)
                                                                        .padding(12)
                                                                        .background(Circle().fill(Color.black.opacity(0.7)))
                                                                }

                                                                // Zoom in button
                                                                Button(action: {
                                                                    withAnimation(.spring()) {
                                                                        zoomScale = min(zoomScale + zoomIncrement, maxZoom)
                                                                    }
                                                                }) {
                                                                    Image(systemName: "plus.magnifyingglass")
                                                                        .font(.system(size: 24))
                                                                        .foregroundColor(.white)
                                                                        .padding(12)
                                                                        .background(Circle().fill(Color.black.opacity(0.7)))
                                                                }
                                                                .disabled(zoomScale >= maxZoom)
                                                                .opacity(zoomScale >= maxZoom ? 0.5 : 1.0)

                                                                // Exit zoom mode button
                                                                Button(action: {
                                                                    withAnimation(.spring()) {
                                                                        isZoomed = false
                                                                        zoomScale = 1.0
                                                                        dragOffset = .zero
                                                                        lastDragValue = .zero
                                                                        showZoomControls = false
                                                                    }
                                                                }) {
                                                                    Image(systemName: "xmark.circle.fill")
                                                                        .font(.system(size: 24))
                                                                        .foregroundColor(.white)
                                                                        .padding(12)
                                                                        .background(Circle().fill(Color.black.opacity(0.7)))
                                                                }
                                                            }
                                                            .padding(.bottom, 20)
                                                            .transition(.move(edge: .bottom).combined(with: .opacity))
                                                        }
                                                    }
                                                }
                                        } placeholder: {
                                            ProgressView()
                                                .frame(height: 200)
                                                .transition(.opacity)
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
                                VStack(spacing: 4) {
                                    if isZoomed {
                                        Text("Current zoom: \(Int(zoomScale * 100))%")
                                            .font(.instrumentSans(size: 14, weight: .medium))
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
                                .padding(.top, 8)
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

                                    // Original currency amount
                                    Text(currencyManager.formatAmount(receipt.total_amount, currencyCode: receipt.currency))
                                        .font(.spaceGrotesk(size: 32, weight: .bold))
                                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.9) : .black.opacity(0.8))

                                    // Only show conversion if different from receipt currency
                                    // and the amount is not zero
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
                                                .font(.instrumentSans(size: 16, weight: .medium))
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.top, 2)
                                    }
                                }

                                Spacer()

                                VStack(alignment: .trailing) {
                                    Text("Tax")
                                        .font(.instrumentSans(size: 14))
                                        .foregroundColor(.secondary)

                                    // Original currency tax
                                    Text(currencyManager.formatAmount(receipt.total_tax, currencyCode: receipt.currency))
                                        .font(.spaceGrotesk(size: 22, weight: .bold))
                                        .foregroundColor(.secondary)

                                    // Only show conversion if different from receipt currency
                                    // and the tax amount is not zero
                                    if receipt.currency != currencyManager.preferredCurrency && receipt.total_tax != 0 {
                                        HStack(spacing: 4) {
                                            Text("≈")
                                                .font(.instrumentSans(size: 12))
                                                .foregroundColor(.secondary.opacity(0.7))

                                            Text(currencyManager.formatAmount(
                                                currencyManager.convertAmountSync(receipt.total_tax,
                                                                               from: receipt.currency,
                                                                               to: currencyManager.preferredCurrency),
                                                currencyCode: currencyManager.preferredCurrency))
                                                .font(.instrumentSans(size: 14))
                                                .foregroundColor(.secondary.opacity(0.7))
                                        }
                                    }
                                }
                            }

                            // Only show this section if there are savings
                            if receipt.savings > 0 {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Original Price")
                                            .font(.instrumentSans(size: 14))
                                            .foregroundColor(.secondary)

                                        // Original currency price
                                        Text(currencyManager.formatAmount(receipt.originalPrice, currencyCode: receipt.currency))
                                            .font(.spaceGrotesk(size: 24, weight: .bold))
                                            .foregroundColor(.secondary)
                                            .strikethrough(true, color: .red.opacity(0.7))

                                        // Only show conversion if different from receipt currency
                                        // and the original price is not zero
                                        if receipt.currency != currencyManager.preferredCurrency && receipt.originalPrice != 0 {
                                            HStack(spacing: 4) {
                                                Text("≈")
                                                    .font(.instrumentSans(size: 12))
                                                    .foregroundColor(.secondary.opacity(0.7))

                                                Text(currencyManager.formatAmount(
                                                    currencyManager.convertAmountSync(receipt.originalPrice,
                                                                                   from: receipt.currency,
                                                                                   to: currencyManager.preferredCurrency),
                                                    currencyCode: currencyManager.preferredCurrency))
                                                    .font(.instrumentSans(size: 14))
                                                    .foregroundColor(.secondary.opacity(0.7))
                                                    .strikethrough(true, color: .red.opacity(0.5))
                                            }
                                        }
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing) {
                                        Text("Savings")
                                            .font(.instrumentSans(size: 14))
                                            .foregroundColor(.green)

                                        // Original currency savings
                                        Text(currencyManager.formatAmount(receipt.savings, currencyCode: receipt.currency))
                                            .font(.spaceGrotesk(size: 18, weight: .bold))
                                            .foregroundColor(.green)

                                        // Only show conversion if different from receipt currency
                                        // and the savings amount is not zero
                                        if receipt.currency != currencyManager.preferredCurrency && receipt.savings != 0 {
                                            HStack(spacing: 4) {
                                                Text("≈")
                                                    .font(.instrumentSans(size: 12))
                                                    .foregroundColor(.green.opacity(0.7))

                                                Text(currencyManager.formatAmount(
                                                    currencyManager.convertAmountSync(receipt.savings,
                                                                                   from: receipt.currency,
                                                                                   to: currencyManager.preferredCurrency),
                                                    currencyCode: currencyManager.preferredCurrency))
                                                    .font(.instrumentSans(size: 14))
                                                    .foregroundColor(.green.opacity(0.7))
                                            }
                                        }
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

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Image(systemName: "dollarsign.circle.fill")
                                        .foregroundColor(secondaryLogoColor)

                                    Text("Currency")
                                        .font(.instrumentSans(size: 14))
                                        .foregroundColor(.secondary)
                                }

                                // Show original currency
                                Text(receipt.currency)
                                    .font(.instrumentSans(size: 16))
                                    .foregroundColor(.primary)

                                // Show conversion info if different from preferred currency
                                if receipt.currency != currencyManager.preferredCurrency {
                                    HStack(spacing: 4) {
                                        Text("Converted to")
                                            .font(.instrumentSans(size: 12))
                                            .foregroundColor(.secondary)

                                        Text(currencyManager.preferredCurrency)
                                            .font(.instrumentSans(size: 12, weight: .medium))
                                            .foregroundColor(.blue)
                                    }

                                    // Show last updated timestamp with refresh button
                                    HStack {
                                        Text("Rates: \(currencyManager.getLastUpdatedString())")
                                            .font(.instrumentSans(size: 10))
                                            .foregroundColor(.secondary.opacity(0.7))

                                        Spacer()

                                        Button {
                                            refreshExchangeRates()
                                        } label: {
                                            Image(systemName: isRefreshingRates ? "arrow.triangle.2.circlepath.circle.fill" : "arrow.triangle.2.circlepath.circle")
                                                .foregroundColor(.blue)
                                                .font(.system(size: 14))
                                                .rotationEffect(Angle(degrees: isRefreshingRates ? 360 : 0))
                                                .animation(isRefreshingRates ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshingRates)
                                        }
                                        .disabled(isRefreshingRates)
                                    }
                                }
                            }
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

                                    Spacer()

                                    // Copy button for location
                                    Button(action: {
                                        copyToClipboard(receipt.store_address)
                                    }) {
                                        Image(systemName: "doc.on.doc")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(PlainButtonStyle())
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
                            ReceiptItemCard(item: item, logoColors: logoColors.isEmpty ? [.gray] : logoColors, index: index, currencyCode: receipt.currency)
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        withAnimation(.spring()) {
                            showEditSheet = true
                        }
                    } label: {
                        HStack {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 20))
                            Text("Edit")
                                .font(.instrumentSans(size: 16))
                        }
                        .foregroundColor(.blue)
                    }
                    .transition(.scale)
                }

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
        .sheet(isPresented: $showEditSheet) {
            EditReceiptView(receipt: receipt) { updatedReceipt in
                self.updatedReceipt = updatedReceipt
                if let onUpdate = onUpdate {
                    onUpdate(updatedReceipt)
                }
            }
            .environmentObject(appState)
        }
        .alert(isPresented: $showRateRefreshAlert) {
            Alert(
                title: Text("Exchange Rates Updated"),
                message: Text(currencyManager.conversionError == nil ?
                              "Exchange rates have been refreshed successfully." :
                              "Could not refresh exchange rates. Using cached rates."),
                dismissButton: .default(Text("OK"))
            )
        }
        // Fullscreen image overlay
        .fullScreenCover(isPresented: $isFullscreen) {
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
                                // Tap gesture for zooming
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
                                // Drag gesture for panning
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
                                // Magnification gesture for pinch zooming
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
                // Reset zoom when exiting fullscreen
                if !isZoomed {
                    zoomScale = 1.0
                    dragOffset = .zero
                    lastDragValue = .zero
                }
            }
        }
        .onAppear {
            // Use the enhanced logo fetching method
            Task {
                let (fetchedImage, fetchedColors) = await LogoService.shared.fetchLogoForReceipt(receipt)
                await MainActor.run {
                    logoImage = fetchedImage
                    logoColors = fetchedColors
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
                // Ensure we have colors to work with
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
                    // Fallback if no colors are available
                    Circle()
                        .fill(Color.gray.opacity(colorScheme == .dark ? 0.15 : 0.1))
                        .frame(width: geometry.size.width * 0.7)
                        .offset(x: geometry.size.width * 0.4, y: geometry.size.height * -0.3)
                        .blur(radius: 100)
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

    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        // You could add a toast notification here if desired
    }

    // Helper function to get the appropriate currency symbol
    private func getCurrencySymbol() -> String {
        return currencyManager.getCurrencySymbol(for: receipt.currency)
    }

    // Function to refresh exchange rates
    private func refreshExchangeRates() {
        // Set loading state
        isRefreshingRates = true

        // Refresh rates asynchronously
        Task {
            await currencyManager.refreshExchangeRates()

            // Update UI on main thread
            await MainActor.run {
                isRefreshingRates = false
                showRateRefreshAlert = true
            }
        }
    }
}

// Helper view for displaying icon with title and detail
//struct IconDetailView: View {
//    let icon: String
//    let title: String
//    let detail: String
//    let color: Color
//
//    var body: some View {
//        HStack(spacing: 12) {
//            Image(systemName: icon)
//                .font(.system(size: 20))
//                .foregroundColor(color)
//
//            VStack(alignment: .leading, spacing: 4) {
//                Text(title)
//                    .font(.instrumentSans(size: 14))
//                    .foregroundColor(.secondary)
//
//                Text(detail)
//                    .font(.instrumentSans(size: 16))
//                    .foregroundColor(.primary)
//            }
//        }
//    }
//}

// Item card view
//struct ItemCard: View {
//    let item: ReceiptItem
//    let logoColors: [Color]
//    let index: Int
//    @Environment(\.colorScheme) private var colorScheme
//
//    var body: some View {
//        HStack {
//            VStack(alignment: .leading, spacing: 4) {
//                Text(item.name)
//                    .font(.instrumentSans(size: 16, weight: .medium))
//                    .foregroundColor(.primary)
//
//                Text(item.category)
//                    .font(.instrumentSans(size: 12))
//                    .foregroundColor(.secondary)
//                    .padding(.horizontal, 8)
//                    .padding(.vertical, 2)
//                    .background(
//                        Capsule()
//                            .fill(categoryColor.opacity(0.1))
//                    )
//
//                if item.isDiscount, let description = item.discountDescription {
//                    Text(description)
//                        .font(.instrumentSans(size: 12))
//                        .foregroundColor(.red)
//                        .padding(.top, 2)
//                }
//            }
//
//            Spacer()
//
//            VStack(alignment: .trailing, spacing: 4) {
//                Text("$\(item.price, specifier: "%.2f")")
//                    .font(.instrumentSans(size: 18, weight: .medium))
//                    .foregroundColor(item.isDiscount ? .red : .primary)
//
//                if item.isDiscount, let originalPrice = item.originalPrice {
//                    Text("$\(originalPrice, specifier: "%.2f")")
//                        .font(.instrumentSans(size: 14))
//                        .foregroundColor(.secondary)
//                        .strikethrough(true, color: .red.opacity(0.7))
//                }
//            }
//        }
//        .padding()
//        .background(
//            RoundedRectangle(cornerRadius: 12)
//                .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
//                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
//        )
//    }
//
//    private var categoryColor: Color {
//        if logoColors.count > 0 {
//            return logoColors[index % logoColors.count]
//        }
//        return .blue
//    }
//}

// Preview
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
