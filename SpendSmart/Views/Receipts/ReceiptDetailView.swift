import SwiftUI
import CoreLocation
import MapKit

// MARK: - Receipt Detail View

struct ReceiptDetailView: View {
    let receipt: Receipt
    let isLocal: Bool
    let onDelete: () -> Void
    let onUpdate: (Receipt) async -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var haptics = HapticManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var viewModel: ReceiptDetailViewModel

    @State private var showDeleteConfirmation = false
    @State private var showEditSheet = false
    @State private var showImageGallery = false
    @State private var selectedImageIndex = 0

    init(receipt: Receipt, isLocal: Bool, onDelete: @escaping () -> Void, onUpdate: @escaping (Receipt) async -> Void) {
        self.receipt = receipt
        self.isLocal = isLocal
        self.onDelete = onDelete
        self.onUpdate = onUpdate
        _viewModel = StateObject(wrappedValue: ReceiptDetailViewModel(receipt: receipt))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero header with store info
                heroHeader
                
                // Content sections
                VStack(spacing: 16) {
                    // Receipt images section
                    if !receipt.image_urls.isEmpty {
                        imagesSection
                    }
                    
                    // Quick stats
                    quickStatsRow
                    
                    // Items section
                    if !receipt.items.isEmpty {
                        itemsSection
                    }
                    
                    // Payment details
                    paymentDetailsSection
                    
                    // Store location
                    if !receipt.store_address.isEmpty {
                        storeLocationSection
                    }
                    
                    // Savings section
                    if receipt.savings > 0 {
                        savingsSection
                    }
                    
                    // Storage status
                    storageStatusSection
                    
                    // Action buttons
                    actionButtonsSection
                }
                .padding()
            }
        }
        .background(Color.brandBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        haptics.buttonPress()
                        showEditSheet = true
                    } label: {
                        Label("Edit Receipt", systemImage: "pencil")
                    }
                    
                    Button {
                        haptics.buttonPress()
                        if subscriptionManager.isPlus {
                            viewModel.shareReceiptImage()
                        } else {
                            subscriptionManager.presentPaywall(trigger: .featureLocked("Receipt Sharing"))
                        }
                    } label: {
                        Label(subscriptionManager.isPlus ? "Share" : "Share (Plus)", systemImage: "square.and.arrow.up")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        haptics.warning()
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Receipt", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.brandVibrantBlue)
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EditReceiptView(
                receipt: receipt,
                isLocalReceipt: isLocal,
                onSave: onUpdate
            )
        }
        .fullScreenCover(isPresented: $showImageGallery) {
            ImageGalleryView(imageURLs: receipt.image_urls, initialIndex: selectedImageIndex)
        }
        .confirmationDialog(
            "Delete Receipt",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                haptics.error()
                onDelete()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this receipt? This action cannot be undone.")
        }
        .popup(isPresented: $viewModel.showRoastPopup) {
            RoastPopupView(message: viewModel.roastMessage, receipt: receipt, isPresented: $viewModel.showRoastPopup)
        } customize: {
            $0
                .type(.floater())
                .position(.center)
                .animation(.spring())
                .closeOnTapOutside(true)
                .backgroundColor(.black.opacity(0.5))
        }
        .task { await viewModel.loadStoreLocation() }
        .task { await viewModel.resolveAllEmojis() }
    }
    
    // MARK: - Hero Header
    
    private var heroHeader: some View {
        VStack(spacing: 0) {
            // Gradient background with logo
            ZStack {
                // Background gradient
                MeshGradient.brandHero
                        .frame(height: 200)
                        .ignoresSafeArea(edges: .top)
                
                VStack(spacing: 16) {
                    // Store logo
                    BrandLogoView(
                        storeName: receipt.store_name,
                        logoSearchTerm: receipt.logo_search_term
                    )
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                    
                    // Store name
                    Text(receipt.store_name.isEmpty ? "Unknown Store" : receipt.store_name)
                        .font(.instrumentSerifItalic(size: 28))
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                    
                    // Date
                    Text(receipt.purchase_date.formatted(date: .long, time: .omitted))
                        .font(.manrope(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(.top, 20)
            }
            
            // Total amount card (overlapping)
            VStack(alignment: .leading, spacing: 6) {
                CurrencyText(amount: receipt.total_amount, currency: receipt.currency)
                    .font(.ibmPlexMono(size: 48))
                    .monospacedDigit()
                    .foregroundStyle(Color.brandTextPrimary)

                if receipt.currency != CurrencyService.shared.preferredCurrency {
                    Text("Converted from \(receipt.currency)")
                        .font(.manrope(size: 12, weight: .medium))
                        .foregroundStyle(Color.brandTextTertiary)
                }
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.brandSurface)
                    .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 5)
            )
            .offset(y: -30)
            .padding(.bottom, -30)
        }
    }
    
    // MARK: - Images Section
    
    private var imagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Receipt Images", icon: "photo.on.rectangle.angled")
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(receipt.image_urls.indices, id: \.self) { index in
                        Button {
                            selectedImageIndex = index
                            showImageGallery = true
                            haptics.medium()
                        } label: {
                            AsyncImage(url: URL(string: receipt.image_urls[index])) { phase in
                                switch phase {
                                case .empty:
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.brandSurface)
                                        .frame(width: 120, height: 160)
                                        .overlay(ProgressView())
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 120, height: 160)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.brandBorder, lineWidth: 1)
                                        )
                                        .overlay(alignment: .bottomTrailing) {
                                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(.white)
                                                .padding(6)
                                                .background(.black.opacity(0.5))
                                                .clipShape(Circle())
                                                .padding(6)
                                        }
                                case .failure:
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.brandSurface)
                                        .frame(width: 120, height: 160)
                                        .overlay(
                                            Image(systemName: "exclamationmark.triangle")
                                                .foregroundStyle(.orange)
                                        )
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 1)
            }
        }
        .padding(16)
        .background(cardBackground)
    }
    
    // MARK: - Quick Stats Row
    
    private var quickStatsRow: some View {
        HStack(spacing: 12) {
            QuickStatPill(
                title: "Items",
                value: "\(receipt.items.count)",
                icon: "cart.fill",
                color: .brandVibrantBlue
            )
            
            QuickStatPill(
                title: "Tax",
                value: viewModel.formatCurrency(receipt.total_tax),
                icon: "percent",
                color: .brandRoyalBlue
            )
            
            if receipt.savings > 0 {
                QuickStatPill(
                    title: "Saved",
                    value: viewModel.formatCurrency(receipt.savings),
                    icon: "tag.fill",
                    color: .brandSuccess
                )
            }
        }
    }
    
    // MARK: - Items Section
    
    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Items (\(receipt.items.count))", icon: "list.bullet.rectangle")
            
            VStack(spacing: 8) {
                ForEach(receipt.items) { item in
                    DetailItemRow(item: item, emoji: viewModel.emojiMap[item.id])
                }
            }
        }
        .padding(16)
        .background(cardBackground)
    }
    
    // MARK: - Payment Details Section
    
    private var paymentDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Payment Details", icon: "creditcard.fill")
            
            VStack(spacing: 10) {
                DetailRow(label: "Payment Method", value: receipt.payment_method.isEmpty ? "Not specified" : receipt.payment_method, icon: "creditcard")
                DetailRow(
                    label: "Currency",
                    value: "\(CurrencyService.shared.getCurrencyInfo(for: receipt.currency)?.flag ?? "🌍") \(receipt.currency)",
                    icon: "dollarsign.circle"
                )
                DetailRow(label: "Subtotal", value: viewModel.formatCurrency(receipt.total_amount - receipt.total_tax), icon: "sum")
                DetailRow(label: "Tax", value: viewModel.formatCurrency(receipt.total_tax), icon: "percent")
                
                Divider()
                    .padding(.vertical, 4)
                
                HStack {
                    Text("Total")
                        .font(.manrope(size: 16, weight: .bold))
                        .foregroundStyle(Color.brandTextPrimary)
                    
                    Spacer()
                    
                    CurrencyText(amount: receipt.total_amount, currency: receipt.currency)
                        .font(.ibmPlexMono(size: 18))
                        .monospacedDigit()
                        .foregroundStyle(Color.brandVibrantBlue)
                }

                if receipt.currency != CurrencyService.shared.preferredCurrency {
                    Text("Converted from \(receipt.currency) to \(CurrencyService.shared.preferredCurrency)")
                        .font(.manrope(size: 11, weight: .medium))
                        .foregroundStyle(Color.brandTextTertiary)
                }
            }
        }
        .padding(16)
        .background(cardBackground)
    }
    
    // MARK: - Store Location Section
    
    private var storeLocationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Store Location", icon: "mappin.circle.fill")
            
            // Address
            HStack(spacing: 12) {
                Image(systemName: "building.2")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.brandVibrantBlue)
                    .frame(width: 24)
                
                Text(receipt.store_address)
                    .font(.manrope(size: 14))
                    .foregroundStyle(Color.brandTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
            }
            
            // Map preview
            if let location = viewModel.storeLocation {
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                ))) {
                    Marker(receipt.store_name, coordinate: location.coordinate)
                        .tint(Color.brandVibrantBlue)
                }
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.brandBorder, lineWidth: 1)
                )
                
                // Open in Maps button
                Button {
                    haptics.buttonPress()
                    viewModel.openInMaps()
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(.system(size: 14))
                        Text("Get Directions")
                            .font(.manrope(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(Color.brandVibrantBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.brandAccentLight)
                    )
                }
            } else if viewModel.isLoadingLocation {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading location...")
                        .font(.manrope(size: 13))
                        .foregroundStyle(Color.brandTextTertiary)
                }
                .frame(height: 100)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(cardBackground)
    }
    
    // MARK: - Savings Section
    
    private var savingsSection: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.brandSuccess.opacity(0.15))
                    .frame(width: 56, height: 56)
                
                Image(systemName: "tag.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.brandSuccess)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("You saved on this purchase")
                    .font(.manrope(size: 14, weight: .medium))
                    .foregroundStyle(Color.brandTextSecondary)
                
                Text(viewModel.formatCurrency(receipt.savings))
                    .font(.ibmPlexMono(size: 28))
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .foregroundStyle(Color.brandSuccess)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.brandSuccessLight)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.brandSuccess.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Storage Status Section
    
    private var storageStatusSection: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill((isLocal ? Color.brandWarning : Color.brandSuccess).opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: isLocal ? "iphone" : "cloud.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isLocal ? Color.brandWarning : Color.brandSuccess)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(isLocal ? "Saved Locally" : "Saved in Cloud")
                    .font(.manrope(size: 15, weight: .semibold))
                    .foregroundStyle(Color.brandTextPrimary)
                
                Text(isLocal ? "Only on this device" : "Synced across all devices")
                    .font(.manrope(size: 12))
                    .foregroundStyle(Color.brandTextSecondary)
            }
            
            Spacer()
            
            if isLocal && !subscriptionManager.isPlus {
                Button {
                    haptics.buttonPress()
                    subscriptionManager.presentPaywall(trigger: .featureLocked("Cloud Sync"))
                } label: {
                    Text("Upgrade")
                        .font(.manrope(size: 12, weight: .semibold))
                        .foregroundStyle(Color.brandVibrantBlue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.brandAccentLight)
                        )
                }
            } else if !isLocal {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.brandSuccess)
            }
        }
        .padding(16)
        .background(cardBackground)
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Edit button
            Button {
                haptics.buttonPress()
                showEditSheet = true
            } label: {
                HStack {
                    Image(systemName: "pencil")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Edit Receipt")
                        .font(.manrope(size: 16, weight: .semibold))
                }
                .foregroundStyle(Color.brandVibrantBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.brandAccentLight)
                )
            }
            
            // Delete button
            Button {
                haptics.warning()
                showDeleteConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Delete Receipt")
                        .font(.manrope(size: 16, weight: .semibold))
                }
                .foregroundStyle(Color.brandError)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.brandError.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Helpers
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.brandSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.brandBorder, lineWidth: 1)
            )
    }
    
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.brandVibrantBlue)
            
            Text(title)
                .font(.manrope(size: 15, weight: .semibold))
                .foregroundStyle(Color.brandTextPrimary)
            
            Spacer()
        }
    }
}

struct RoastPopupView: View {
    let message: String
    let receipt: Receipt
    @Environment(\.dismiss) var dismiss // This won't dismiss the popup directly, relying on binding in parent or close button
    @Binding var isPresented: Bool // Added binding to close manually
    @State private var showShareSheet = false
    @State private var flamePulse = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Close button
            HStack {
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(.bottom, -10)
            
            // Animated Flame
            Image(systemName: "flame.fill")
                .font(.system(size: 56))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.brandRoastOrange, Color.brandRoastDarkOrange],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .scaleEffect(flamePulse ? 1.1 : 0.95)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                        flamePulse = true
                    }
                }
            
            VStack(spacing: 8) {
                Text("The Verdict")
                    .font(.instrumentSerifItalic(size: 32))
                    .foregroundStyle(.white)
                
                ScrollView {
                    Text(message)
                        .font(.manrope(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.95))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal)
                }
                .frame(maxHeight: 200)
            }
            
            Button {
                showShareSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share the Burn")
                }
                .font(.manrope(size: 16, weight: .bold))
                .foregroundStyle(.black)
                .padding(.vertical, 14)
                .padding(.horizontal, 28)
                .background(Color.white)
                .clipShape(Capsule())
                .shadow(color: .white.opacity(0.2), radius: 10, x: 0, y: 0)
            }
        }
        .padding(24)
        .frame(width: 340)
        .background(
            ZStack {
                Color.black.opacity(0.8)
                // Thin blur material for depth
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.3)
                
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [Color.brandRoastOrange.opacity(0.8), Color.brandRoastDarkOrange.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.5), radius: 40, x: 0, y: 20)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [
                "🔥 SpendSmart roasted my purchase at \(receipt.store_name):\n\n\"\(message)\"\n\n#SpendSmart"
            ])
        }
    }
}


// MARK: - Quick Stat Pill

private struct QuickStatPill: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
            
            Text(value)
                .font(.ibmPlexMono(size: 14))
                .fontWeight(.bold)
                .monospacedDigit()
                .foregroundStyle(Color.brandTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text(title)
                .font(.manrope(size: 11, weight: .medium))
                .foregroundStyle(Color.brandTextTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
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

// MARK: - Detail Row

private struct DetailRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.brandVibrantBlue)
                .frame(width: 20)
            
            Text(label)
                .font(.manrope(size: 14))
                .foregroundStyle(Color.brandTextSecondary)
            
            Spacer()
            
            Text(value)
                .font(.manrope(size: 14, weight: .medium))
                .foregroundStyle(Color.brandTextPrimary)
        }
    }
}

// MARK: - Detail Item Row

private struct DetailItemRow: View {
    let item: ReceiptItem
    let emoji: String?
    
    var body: some View {
        HStack(spacing: 12) {
            // Emoji or category icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                if let emoji = emoji {
                    Text(emoji)
                        .font(.system(size: 20))
                } else {
                    Image(systemName: categoryIcon)
                        .font(.system(size: 16))
                        .foregroundStyle(categoryColor)
                }
            }
            
            // Item info
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.manrope(size: 14, weight: .medium))
                    .foregroundStyle(item.isDiscount ? Color.brandSuccess : Color.brandTextPrimary)
                    .lineLimit(2)
                
                if !item.category.isEmpty {
                    Text(item.category.capitalized)
                        .font(.manrope(size: 11, weight: .medium))
                        .foregroundStyle(Color.brandTextTertiary)
                }
            }
            
            Spacer()
            
            // Price
            VStack(alignment: .trailing, spacing: 2) {
                if item.isDiscount {
                    Text("-\(formatPrice(abs(item.price)))")
                        .font(.ibmPlexMono(size: 14))
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .foregroundStyle(Color.brandSuccess)
                } else {
                    Text(formatPrice(item.price))
                        .font(.ibmPlexMono(size: 14))
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .foregroundStyle(Color.brandTextPrimary)
                    
                    if let originalPrice = item.originalPrice, originalPrice > item.price {
                        Text(formatPrice(originalPrice))
                            .font(.manrope(size: 11))
                            .strikethrough()
                            .foregroundStyle(Color.brandTextTertiary)
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(item.isDiscount ? Color.brandSuccess.opacity(0.08) : Color.brandBackground)
        )
    }
    
    private var categoryColor: Color {
        CategoryData.color(for: item.category)
    }
    
    private var categoryIcon: String {
        switch item.category.lowercased() {
        case "food", "groceries": return "cart.fill"
        case "drinks", "beverage": return "cup.and.saucer.fill"
        case "electronics": return "desktopcomputer"
        case "clothing", "apparel": return "tshirt.fill"
        case "health", "pharmacy": return "cross.case.fill"
        case "household": return "house.fill"
        default: return "tag.fill"
        }
    }
    
    private func formatPrice(_ price: Double) -> String {
        let formatter = AppFormatters.currency(code: nil)
        return formatter.string(from: NSNumber(value: price)) ?? "$0.00"
    }
}

#Preview {
    NavigationStack {
        ReceiptDetailView(
            receipt: Receipt(
                id: UUID(),
                user_id: UUID(),
                image_urls: [],
                total_amount: 156.78,
                items: [
                    ReceiptItem(id: UUID(), name: "Organic Milk", price: 5.99, category: "Dairy"),
                    ReceiptItem(id: UUID(), name: "Whole Wheat Bread", price: 4.49, category: "Bakery"),
                    ReceiptItem(id: UUID(), name: "Member Discount", price: -2.50, category: "Discount", isDiscount: true)
                ],
                store_name: "Whole Foods Market",
                store_address: "123 Main Street, San Francisco, CA 94102",
                receipt_name: "Weekly Groceries",
                purchase_date: Date(),
                currency: "USD",
                payment_method: "Apple Pay",
                total_tax: 12.45
            ),
            isLocal: false,
            onDelete: {},
            onUpdate: { _ in }
        )
    }
}
