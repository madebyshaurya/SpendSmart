//
//  PaywallView.swift
//  SpendSmart
//
//  Created by Claude on 2026-01-18.
//
//  Beautiful branded paywall with mesh gradients and 3D buttons.
//  Supports both dynamic RevenueCat packages and demo mode.
//

import SwiftUI
import RevenueCat

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var localStorage = LocalReceiptStorage.shared
    @StateObject private var haptics = HapticManager.shared
    
    @State private var selectedPackage: Package?
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var animateIn = false
    @State private var showSyncConfirmation = false
    @State private var showPurchaseSuccess = false
    
    let trigger: PaywallTrigger
    
    init(trigger: PaywallTrigger = .general) {
        self.trigger = trigger
    }
    
    var body: some View {
        ZStack {
            // Background
            backgroundGradient
            
            ScrollView {
                VStack(spacing: 0) {
                    // Close button
                    closeButton
                    
                    // Hero section
                    heroSection
                        .padding(.top, 20)
                    
                    // Features list
                    featuresSection
                        .padding(.top, 32)
                    
                    // Pricing cards
                    pricingSection
                        .padding(.top, 32)
                    
                    // CTA button
                    ctaButton
                        .padding(.top, 24)
                    
                    // Restore & Terms
                    footerSection
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                }
                .padding(.horizontal, 24)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.6)) {
                animateIn = true
            }
            // Select first package by default
            if selectedPackage == nil {
                selectedPackage = subscriptionManager.availablePackages.first(where: { $0.packageType == .annual })
                    ?? subscriptionManager.availablePackages.first
            }
        }
        .alert("Something went wrong", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .fullScreenCover(isPresented: $showSyncConfirmation) {
            SyncConfirmationView {
                dismiss()
            }
        }
        .fullScreenCover(isPresented: $showPurchaseSuccess) {
            PurchaseSuccessView {
                showPurchaseSuccess = false
                // Check if user has local receipts to sync
                if localStorage.localReceipts.count > 0 {
                    showSyncConfirmation = true
                } else {
                    dismiss()
                }
            }
        }
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        MeshGradient.brandSoft
            .ignoresSafeArea()
    }
    
    // MARK: - Close Button
    
    private var closeButton: some View {
        HStack {
            Spacer()
            Button {
                haptics.buttonPress()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.brandTextTertiary)
            }
        }
        .padding(.top, 16)
    }
    
    // MARK: - Hero Section
    
    private var heroSection: some View {
        VStack(spacing: 16) {
            // Plus badge
            plusBadgeMesh
            
            // Title
            Text(trigger.title)
                .font(.instrumentSerif(size: 32))
                .foregroundStyle(Color.brandTextPrimary)
                .multilineTextAlignment(.center)
            
            // Subtitle
            Text(trigger.subtitle)
                .font(.manrope(size: 16))
                .foregroundStyle(Color.brandTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 20)
    }
    
    @available(iOS 18.0, *)
    private var plusBadgeMesh: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 16, weight: .semibold))
            Text("PLUS")
                .font(.manrope(size: 14, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            MeshGradient.brandButton
                .clipShape(Capsule())
        )
        .shadow(color: Color.brandVibrantBlue.opacity(0.3), radius: 8, y: 4)
    }
    
    private var plusBadgeFallback: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 16, weight: .semibold))
            Text("PLUS")
                .font(.manrope(size: 14, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            LinearGradient.brandPrimary
                .clipShape(Capsule())
        )
        .shadow(color: Color.brandVibrantBlue.opacity(0.3), radius: 8, y: 4)
    }
    
    // MARK: - Features Section
    
    private var featuresSection: some View {
        VStack(spacing: 12) {
            FeatureRow(icon: "infinity", title: "Unlimited Scans", description: "Scan as many receipts as you want", index: 0)
            FeatureRow(icon: "icloud.fill", title: "Cloud Backup", description: "Securely sync across all your devices", index: 1)
            FeatureRow(icon: "chart.bar.fill", title: "Smart Analytics", description: "AI-powered spending insights", index: 2)
            FeatureRow(icon: "magnifyingglass", title: "Advanced Search", description: "Find any receipt instantly", index: 3)
            FeatureRow(icon: "map.fill", title: "Store Map", description: "Visualize your shopping habits", index: 4)
            FeatureRow(icon: "sparkles", title: "Priority Processing", description: "Faster, more accurate AI extraction", index: 5)
        }
    }
    
    // MARK: - Pricing Section
    
    private var pricingSection: some View {
        VStack(spacing: 12) {
            if subscriptionManager.availablePackages.isEmpty {
                // Demo mode - show placeholder prices
                PricingCard(
                    title: "Yearly",
                    price: "$19.99",
                    period: "per year",
                    monthlyPrice: "$1.67/mo",
                    savings: "Save 44%",
                    isSelected: true,
                    isBestValue: true
                ) {
                    // No-op in demo mode
                }
                
                PricingCard(
                    title: "Monthly",
                    price: "$2.99",
                    period: "per month",
                    monthlyPrice: nil,
                    savings: nil,
                    isSelected: false,
                    isBestValue: false
                ) {
                    // No-op in demo mode
                }
            } else {
                // Real packages from RevenueCat
                ForEach(subscriptionManager.availablePackages.sorted(by: { $0.packageType.rawValue > $1.packageType.rawValue }), id: \.identifier) { package in
                    let isYearly = package.packageType == .annual
                    PricingCard(
                        title: isYearly ? "Yearly" : "Monthly",
                        price: package.localizedPriceString,
                        period: package.periodText,
                        monthlyPrice: isYearly ? package.pricePerMonth + "/mo" : nil,
                        savings: package.savingsPercentage.map { "Save \($0)%" },
                        isSelected: selectedPackage?.identifier == package.identifier,
                        isBestValue: isYearly
                    ) {
                        withAnimation(.spring(duration: 0.3)) {
                            selectedPackage = package
                        }
                    }
                }
            }
        }
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 40)
        .animation(.spring(duration: 0.6).delay(0.2), value: animateIn)
    }
    
    // MARK: - CTA Button
    
    private var ctaButton: some View {
        Button {
            haptics.buttonPress()
            purchase()
        } label: {
            HStack(spacing: 12) {
                if isPurchasing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Continue")
                        .font(.manrope(size: 18, weight: .bold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                MeshGradient.brandButton
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.brandVibrantBlue.opacity(0.4), radius: 12, y: 6)
        }
        .disabled(isPurchasing || (selectedPackage == nil && !subscriptionManager.availablePackages.isEmpty))
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 50)
        .animation(.spring(duration: 0.6).delay(0.3), value: animateIn)
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        VStack(spacing: 12) {
            Button {
                haptics.buttonPress()
                restore()
            } label: {
                Text("Restore Purchases")
                    .font(.manrope(size: 14, weight: .medium))
                    .foregroundStyle(Color.brandVibrantBlue)
            }
            
            HStack(spacing: 16) {
                Link("Terms of Use", destination: AppConstants.termsOfServiceURL)
                    .font(.manrope(size: 12))
                    .foregroundStyle(Color.brandTextTertiary)
                
                Text("|")
                    .foregroundStyle(Color.brandTextTertiary)
                
                Link("Privacy Policy", destination: AppConstants.privacyPolicyURL)
                    .font(.manrope(size: 12))
                    .foregroundStyle(Color.brandTextTertiary)
            }
            
            Text("Cancel anytime. Subscription auto-renews.")
                .font(.manrope(size: 11))
                .foregroundStyle(Color.brandTextTertiary)
        }
    }
    
    // MARK: - Actions
    
    private func purchase() {
        guard let package = selectedPackage else {
            // Demo mode - just dismiss
            if subscriptionManager.availablePackages.isEmpty {
                dismiss()
            }
            return
        }
        
        isPurchasing = true
        
        Task {
            do {
                let success = try await subscriptionManager.purchase(package: package)
                if success {
                    // Show celebration success screen
                    showPurchaseSuccess = true
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isPurchasing = false
        }
    }
    
    private func restore() {
        isPurchasing = true
        
        Task {
            do {
                try await subscriptionManager.restorePurchases()
                if subscriptionManager.isPlus {
                    // Show celebration success screen
                    showPurchaseSuccess = true
                }
            } catch {
                errorMessage = "Could not restore purchases. Please try again."
                showError = true
            }
            isPurchasing = false
        }
    }
}

// MARK: - Feature Row

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    var index: Int = 0
    var isAnimated: Bool = true
    
    @State private var isVisible = false
    @State private var checkmarkScale: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon with subtle animation
            ZStack {
                Circle()
                    .fill(Color.brandAccentLight)
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.brandVibrantBlue)
                    .symbolEffect(.pulse, isActive: isVisible)
            }
            
            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.manrope(size: 16, weight: .semibold))
                    .foregroundStyle(Color.brandTextPrimary)
                
                Text(description)
                    .font(.manrope(size: 13))
                    .foregroundStyle(Color.brandTextSecondary)
            }
            
            Spacer()
            
            // Animated checkmark
            ZStack {
                Circle()
                    .fill(Color.brandSuccessLight)
                    .frame(width: 28, height: 28)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.brandSuccess)
            }
            .scaleEffect(checkmarkScale)
        }
        .padding(.vertical, 8)
        .opacity(isVisible ? 1 : 0)
        .offset(x: isVisible ? 0 : -20)
        .onAppear {
            guard isAnimated else {
                isVisible = true
                checkmarkScale = 1
                return
            }
            
            let delay = Double(index) * 0.08
            withAnimation(.brandEaseOut.delay(delay + 0.2)) {
                isVisible = true
            }
            withAnimation(.brandBouncy.delay(delay + 0.4)) {
                checkmarkScale = 1
            }
        }
    }
}

// MARK: - Pricing Card

private struct PricingCard: View {
    let title: String
    let price: String
    let period: String
    let monthlyPrice: String?
    let savings: String?
    let isSelected: Bool
    let isBestValue: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button {
            HapticManager.shared.selection()
            action()
        } label: {
            ZStack(alignment: .topTrailing) {
                // Main card content
                HStack(spacing: 16) {
                    // Selection indicator with animation
                    ZStack {
                        Circle()
                            .stroke(isSelected ? Color.brandVibrantBlue : Color.brandBorder, lineWidth: 2)
                            .frame(width: 24, height: 24)
                        
                        if isSelected {
                            Circle()
                                .fill(Color.brandVibrantBlue)
                                .frame(width: 14, height: 14)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .animation(.brandSnappy, value: isSelected)
                    
                    // Plan info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.manrope(size: 17, weight: .bold))
                            .foregroundStyle(Color.brandTextPrimary)
                        
                        if let monthlyPrice = monthlyPrice {
                            Text(monthlyPrice)
                                .font(.manrope(size: 14))
                                .foregroundStyle(Color.brandTextSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Price with emphasis
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(price)
                            .font(.manrope(size: 22, weight: .bold))
                            .foregroundStyle(isSelected ? Color.brandVibrantBlue : Color.brandTextPrimary)
                        
                        if let savings = savings {
                            Text(savings)
                                .font(.manrope(size: 12, weight: .semibold))
                                .foregroundStyle(Color.brandSuccess)
                        } else {
                            Text(period)
                                .font(.manrope(size: 12))
                                .foregroundStyle(Color.brandTextSecondary)
                        }
                    }
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.brandSurface)
                        .shadow(
                            color: isSelected ? Color.brandVibrantBlue.opacity(0.2) : Color.black.opacity(0.04),
                            radius: isSelected ? 16 : 8,
                            y: isSelected ? 6 : 3
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color.brandVibrantBlue : Color.brandBorder.opacity(0.5), lineWidth: isSelected ? 2 : 1)
                )
                
                // Best Value badge
                if isBestValue {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                        Text("BEST VALUE")
                            .font(.manrope(size: 10, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        LinearGradient(
                            colors: [Color.brandWarning, Color.brandWarningDark],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .offset(x: 8, y: -10)
                    .shadow(color: Color.brandWarning.opacity(0.3), radius: 4, y: 2)
                }
            }
        }
        .buttonStyle(PricingCardButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.brandSnappy, value: isSelected)
    }
}

// Custom button style for pricing card
private struct PricingCardButtonStyle: SwiftUI.ButtonStyle {
    typealias Configuration = SwiftUI.ButtonStyleConfiguration
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

// MARK: - Scan Limit Banner

struct ScanLimitBanner: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    var body: some View {
        if !subscriptionManager.isPlus {
            Button {
                subscriptionManager.presentPaywall(trigger: .general)
            } label: {
                HStack(spacing: 12) {
                    // Progress ring
                    ZStack {
                        Circle()
                            .stroke(Color.brandBorder, lineWidth: 3)
                            .frame(width: 36, height: 36)
                        
                        Circle()
                            .trim(from: 0, to: progressValue)
                            .stroke(progressColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 36, height: 36)
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(subscriptionManager.scansRemaining ?? 0)")
                            .font(.manrope(size: 12, weight: .bold))
                            .foregroundStyle(progressColor)
                    }
                    
                    // Text
                    VStack(alignment: .leading, spacing: 2) {
                        Text(subscriptionManager.scansUsedText)
                            .font(.manrope(size: 14, weight: .medium))
                            .foregroundStyle(Color.brandTextPrimary)
                        
                        Text("Tap to upgrade")
                            .font(.manrope(size: 12))
                            .foregroundStyle(Color.brandVibrantBlue)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.brandTextTertiary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.brandSurfaceElevated)
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    private var progressValue: CGFloat {
        let remaining = CGFloat(subscriptionManager.scansRemaining ?? 0)
        let total = CGFloat(5)
        return remaining / total
    }
    
    private var progressColor: Color {
        let remaining = subscriptionManager.scansRemaining ?? 0
        if remaining <= 1 {
            return Color.brandError
        } else if remaining <= 2 {
            return Color.brandWarning
        } else {
            return Color.brandVibrantBlue
        }
    }
}

// MARK: - Preview

#Preview {
    PaywallView(trigger: .scanLimitReached)
}

#Preview("Scan Limit Banner") {
    VStack {
        ScanLimitBanner()
            .padding()
        Spacer()
    }
}
