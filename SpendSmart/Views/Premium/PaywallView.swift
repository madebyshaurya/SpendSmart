//
//  PaywallView.swift
//  SpendSmart
//
//  Premium subscription paywall with iOS 26 Liquid Glass design
//

import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var stripeService = StripePaymentService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPlan: StripePaymentService.PlanType = .annual
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        ZStack {
            // Background gradient
            BackgroundGradientView()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: DesignTokens.Spacing.xxl) {
                    // Header
                    headerSection

                    // Usage banner (if limit reached)
                    if let usage = appState.receiptUsage {
                        usageBanner(usage)
                    }

                    // Plan selector
                    planSelector

                    // Feature comparison
                    featureComparison

                    // CTA button
                    subscribeButton

                    // Footer
                    footer
                }
                .padding()
            }
        }
        .glassTransition()
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Header

    var headerSection: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // Animated crown icon
            AnimatedIcon.premium(highlight: true)
                .font(.system(size: 64))
                .padding(.top, DesignTokens.Spacing.xxl)

            Text("Upgrade to Premium")
                .font(.hierarchyDisplay(level: 1))
                .multilineTextAlignment(.center)

            Text("Unlimited receipts + cloud sync across devices")
                .font(.hierarchyBody())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Usage Banner

    func usageBanner(_ usage: ReceiptUsage) -> some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            HStack {
                AnimatedIcon.warning()
                    .font(.title3)

                Text("Receipt Limit Reached")
                    .font(.hierarchyTitle())

                Spacer()
            }

            HStack {
                Text(usage.statusMessage)
                    .font(.hierarchyCaption())
                    .foregroundStyle(.secondary)

                Spacer()
            }
        }
        .padding()
        .glassCard(tint: .orange)
        .floatingGlass()
    }

    // MARK: - Plan Selector

    var planSelector: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            PlanCard(
                plan: .monthly,
                isSelected: selectedPlan == .monthly,
                action: {
                    selectedPlan = .monthly
                    HapticFeedbackManager.shared.selection()
                }
            )

            PlanCard(
                plan: .annual,
                isSelected: selectedPlan == .annual,
                action: {
                    selectedPlan = .annual
                    HapticFeedbackManager.shared.selection()
                }
            )
        }
        .frame(height: 160)
    }

    // MARK: - Feature Comparison

    var featureComparison: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("What You Get")
                .font(.hierarchyTitle())
                .frame(maxWidth: .infinity, alignment: .leading)

            PaywallFeatureRow(
                icon: "infinity",
                title: "Unlimited Receipts",
                description: "Process as many receipts as you want",
                isIncluded: true
            )

            PaywallFeatureRow(
                icon: "icloud.fill",
                title: "Cloud Sync",
                description: "Access your receipts from any device",
                isIncluded: true
            )

            PaywallFeatureRow(
                icon: "chart.bar.fill",
                title: "Advanced Analytics",
                description: "Track spending trends over time",
                isIncluded: true
            )

            PaywallFeatureRow(
                icon: "bell.fill",
                title: "Smart Notifications",
                description: "Get reminders for recurring expenses",
                isIncluded: true
            )
        }
        .padding()
        .glassCard()
        .floatingGlass()
    }

    // MARK: - Subscribe Button

    var subscribeButton: some View {
        Button(action: handleSubscribe) {
            HStack {
                if isProcessing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Start Premium")
                        .font(.hierarchyTitle())
                        .foregroundColor(.white)

                    Image(systemName: "arrow.right")
                        .symbolBounce(trigger: selectedPlan)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .buttonStyle(GlassProminentButtonStyle(tint: .blue))
        .interactiveGlass()
        .disabled(isProcessing)
    }

    // MARK: - Footer

    var footer: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // Terms
            Text("Subscription auto-renews. Cancel anytime in settings.")
                .font(.hierarchyCaption())
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            // Restore button
            Button("Restore Purchases") {
                handleRestore()
            }
            .font(.hierarchyCaption())
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    func handleSubscribe() {
        isProcessing = true
        HapticFeedbackManager.shared.mediumImpact()

        Task {
            await stripeService.purchaseSubscription(planType: selectedPlan) { result in
                isProcessing = false

                switch result {
                case .success:
                    HapticFeedbackManager.shared.success()

                    // Sync premium status after user returns from Stripe
                    Task {
                        await appState.syncPremiumStatus()

                        // Dismiss paywall if premium
                        if appState.isPremium {
                            dismiss()
                        }
                    }

                case .failure(let error):
                    HapticFeedbackManager.shared.error()
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    func handleRestore() {
        isProcessing = true

        Task {
            do {
                try await stripeService.restorePurchases(appState: appState)
                HapticFeedbackManager.shared.success()
                dismiss()
            } catch {
                HapticFeedbackManager.shared.error()
                errorMessage = error.localizedDescription
                showError = true
            }
            isProcessing = false
        }
    }
}

// MARK: - Plan Card

struct PlanCard: View {
    let plan: StripePaymentService.PlanType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignTokens.Spacing.sm) {
                // Badge
                if let badge = plan.badgeText {
                    Text(badge)
                        .font(.hierarchyCaption())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(DesignTokens.Colors.PremiumGradients.gold)
                        .cornerRadius(8)
                }

                Spacer()

                // Price
                Text(plan.displayPrice)
                    .font(.hierarchyTitle())
                    .foregroundStyle(.primary)

                // Savings
                if let savings = plan.savings {
                    Text(savings)
                        .font(.hierarchyCaption())
                        .foregroundStyle(.green)
                } else {
                    Text(" ")
                        .font(.hierarchyCaption())
                }

                Spacer()

                // Plan name
                Text(plan.displayName)
                    .font(.hierarchyCaption())
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .glassCard(tint: isSelected ? .blue : nil)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.blue, lineWidth: 2)
                }
            }
        }
        .fluidScale(pressed: isSelected)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(FluidAnimations.glassPress, value: isSelected)
    }
}

// MARK: - Paywall Feature Row

private struct PaywallFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let isIncluded: Bool

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            // Icon
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(DesignTokens.Colors.PremiumGradients.premium)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.hierarchyBody())
                    .foregroundStyle(.primary)

                Text(description)
                    .font(.hierarchyCaption())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Checkmark
            if isIncluded {
                AnimatedIcon.successSmall(show: true)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct PaywallView_Previews: PreviewProvider {
    static var previews: some View {
        PaywallView()
            .environmentObject(AppState())
    }
}
#endif
