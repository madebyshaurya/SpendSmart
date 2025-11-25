import SwiftUI

struct StreamlinedSubscriptionForm: View {
    // Bindings to parent state
    @Binding var serviceName: String
    @Binding var amount: String
    @Binding var currency: String
    @Binding var cycle: Subscription.BillingCycle
    @Binding var intervalCount: String
    @Binding var nextRenewal: Date
    @Binding var isActive: Bool
    @Binding var isTrial: Bool
    @Binding var trialEnd: Date
    @Binding var notifyRenewalDays: Int
    @Binding var notifyTrialDays: Int

    // Visual assets
    var logoImage: UIImage?
    var isLoadingLogo: Bool

    // Validation UI
    var showDateValidationError: Bool
    var dateValidationMessage: String

    // Data sources
    var allCurrencies: [String]

    // Events
    var onServiceNameChanged: (String) -> Void
    var onNextRenewalChanged: (Date) -> Void
    var onAmountChanged: ((String) -> Void)? = nil
    var onCycleChanged: ((Subscription.BillingCycle) -> Void)? = nil
    var onIntervalCountChanged: ((String) -> Void)? = nil
    
    @State private var animate = false

    var body: some View {
        VStack(spacing: 20) {
            // Essential fields card
            essentialFieldsCard
            
            // Quick toggles
            quickTogglesCard
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                animate = true
            }
        }
    }
    
    private var essentialFieldsCard: some View {
        VStack(spacing: 16) {
            // Header with logo
            HStack(spacing: 12) {
                // Logo section
                Group {
                    if isLoadingLogo {
                        ProgressView()
                            .frame(width: 40, height: 40)
                    } else if let logoImage = logoImage {
                        Image(uiImage: logoImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(DesignTokens.Colors.Fill.secondary)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "building.2")
                                    .foregroundColor(.secondary)
                            )
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    AdaptiveText.headline("Subscription Details", priority: .high)
                    AdaptiveText.caption("Essential information", priority: .low)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // Service name
            CompactFormField(
                label: "Service Name",
                text: $serviceName,
                placeholder: "e.g., Netflix, Spotify",
                icon: "building.2",
                isRequired: true,
                validationMessage: serviceName.trimmingCharacters(in: .whitespaces).isEmpty ? "Required" : nil,
                maxLength: 50
            )
            .glassBackground(cornerRadius: 12)
            .padding(.horizontal, 16)
            .onChange(of: serviceName) { _, newValue in
                onServiceNameChanged(newValue)
            }
            
            // Amount and currency inline
            InlineAmountField(
                amount: $amount,
                currency: $currency,
                currencies: allCurrencies,
                label: "Amount"
            )
            .glassBackground(cornerRadius: 12)
            .padding(.horizontal, 16)
            .onChange(of: amount) { _, newValue in
                onAmountChanged?(newValue)
            }
            
            // Billing cycle chips
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .frame(width: 16)
                    
                    AdaptiveText(
                        text: "Billing Cycle",
                        font: DesignTokens.Typography.caption1(weight: .medium),
                        color: .secondary,
                        priority: .normal
                    )
                    
                    Spacer()
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Subscription.BillingCycle.allCases, id: \.self) { billingCycle in
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    cycle = billingCycle
                                }
                                onCycleChanged?(billingCycle)
                            } label: {
                                AdaptiveText(
                                    text: billingCycle.displayName,
                                    font: DesignTokens.Typography.caption1(weight: .medium),
                                    color: cycle == billingCycle ? .white : .primary,
                                    priority: .normal
                                )
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .glassCapsule(tint: cycle == billingCycle ? DesignTokens.Colors.Primary.blue : nil)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.horizontal, 16)
            
            // Custom interval if needed
            if cycle == .custom {
                CompactFormField(
                    label: "Interval (months)",
                    text: $intervalCount,
                    placeholder: "e.g., 3",
                    icon: "number",
                    keyboardType: .numberPad,
                    isRequired: true,
                    validationMessage: validateInterval(intervalCount),
                    maxLength: 2
                )
                .padding(.horizontal, 16)
                .transition(.opacity.combined(with: .offset(y: -10)))
                .onChange(of: intervalCount) { _, newValue in
                    onIntervalCountChanged?(newValue)
                }
            }
            
            // Next renewal date
            CompactDatePicker(
                label: "Next Renewal",
                date: $nextRenewal,
                minDate: Date(),
                icon: "calendar"
            )
            .glassBackground(cornerRadius: 12)
            .padding(.horizontal, 16)
            .onChange(of: nextRenewal) { _, newDate in
                onNextRenewalChanged(newDate)
            }
            
            if showDateValidationError && !dateValidationMessage.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                    
                    AdaptiveText(
                        text: dateValidationMessage,
                        font: DesignTokens.Typography.caption2(weight: .regular),
                        color: .red,
                        priority: .low
                    )
                }
                .padding(.horizontal, 16)
                .transition(.opacity)
            }
            
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                    .font(.system(size: 14, weight: .semibold))
                AdaptiveText(
                    text: "Your card will be charged on the next renewal date. Set reminders below to get notified ahead of time.",
                    font: DesignTokens.Typography.caption2(weight: .regular),
                    color: .secondary,
                    priority: .low
                )
            }
            .padding(12)
            .glassBackground(cornerRadius: 10)
            .padding(.horizontal, 16)
            
            Spacer(minLength: 16)
        }
        .glassBackground(cornerRadius: DesignTokens.CornerRadius.lg)
        .opacity(animate ? 1 : 0)
        .offset(y: animate ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animate)
    }
    
    private var quickTogglesCard: some View {
        VStack(spacing: 16) {
            HStack {
                AdaptiveText.headline("Status", priority: .normal)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            HStack(spacing: 12) {
                ToggleChip(
                    label: "Active",
                    systemImage: "checkmark.circle",
                    isOn: $isActive,
                    description: "Enable tracking"
                )
                .glassCapsule()
                
                ToggleChip(
                    label: "Free Trial",
                    systemImage: "gift",
                    isOn: $isTrial,
                    tint: .orange,
                    description: isTrial ? "Until \(shortDateFormatter.string(from: trialEnd))" : "No trial period"
                )
                .glassCapsule()
            }
            .padding(.horizontal, 16)
            
            if isTrial {
                CompactDatePicker(
                    label: "Trial Ends",
                    date: $trialEnd,
                    minDate: Date(),
                    icon: "gift"
                )
                .glassBackground(cornerRadius: 12)
                .padding(.horizontal, 16)
                .transition(.opacity.combined(with: .offset(y: -10)))
            }
            
            // Notifications section
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "bell")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    AdaptiveText.body("Notifications", priority: .normal)
                    Spacer()
                }
                
                VStack(spacing: 16) {
                    // Renewal reminder
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            AdaptiveText.caption("Renewal reminder", priority: .normal)
                            AdaptiveText(
                                text: "\(notifyRenewalDays) days before",
                                font: DesignTokens.Typography.caption2(weight: .regular),
                                color: .secondary,
                                priority: .low
                            )
                        }
                        Spacer()
                        
                        HStack(spacing: 12) {
                            Button {
                                if notifyRenewalDays > 0 {
                                    notifyRenewalDays -= 1
                                }
                            } label: {
                                Image(systemName: "minus")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(notifyRenewalDays > 0 ? .primary : .secondary)
                            }
                            .disabled(notifyRenewalDays <= 0)
                            
                            Text("\(notifyRenewalDays)")
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.semibold)
                                .frame(minWidth: 30)
                            
                            Button {
                                if notifyRenewalDays < 30 {
                                    notifyRenewalDays += 1
                                }
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(notifyRenewalDays < 30 ? .primary : .secondary)
                            }
                            .disabled(notifyRenewalDays >= 30)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if isTrial {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                AdaptiveText.caption("Trial end reminder", priority: .normal)
                                AdaptiveText(
                                    text: "\(notifyTrialDays) days before",
                                    font: DesignTokens.Typography.caption2(weight: .regular),
                                    color: .secondary,
                                    priority: .low
                                )
                            }
                            Spacer()
                            
                            HStack(spacing: 12) {
                                Button {
                                    if notifyTrialDays > 0 {
                                        notifyTrialDays -= 1
                                    }
                                } label: {
                                    Image(systemName: "minus")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(notifyTrialDays > 0 ? .primary : .secondary)
                                }
                                .disabled(notifyTrialDays <= 0)
                                
                                Text("\(notifyTrialDays)")
                                    .font(.system(.body, design: .rounded))
                                    .fontWeight(.semibold)
                                    .frame(minWidth: 30)
                                
                                Button {
                                    if notifyTrialDays < 14 {
                                        notifyTrialDays += 1
                                    }
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(notifyTrialDays < 14 ? .primary : .secondary)
                                }
                                .disabled(notifyTrialDays >= 14)
                            }
                            .buttonStyle(.plain)
                        }
                        .transition(.opacity)
                    }
                    
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                            .font(.system(size: 14, weight: .semibold))
                        AdaptiveText(
                            text: "We’ll remind you before your trial ends or renewal date based on your settings here.",
                            font: DesignTokens.Typography.caption2(weight: .regular),
                            color: .secondary,
                            priority: .low
                        )
                    }
                    .padding(12)
                    .glassBackground(cornerRadius: 10)
                }
            }
            .padding(.horizontal, 16)
            
            Spacer(minLength: 16)
        }
        .glassBackground(cornerRadius: DesignTokens.CornerRadius.lg)
        .opacity(animate ? 1 : 0)
        .offset(y: animate ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: animate)
    }
    
    
    // MARK: - Helper Properties and Functions
    
    private var shortDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }
    
    private func validateInterval(_ interval: String) -> String? {
        guard !interval.isEmpty else { return "Required" }
        guard let value = Int(interval), value > 0 else { return "Invalid" }
        if value > 36 { return "Max 36 months" }
        return nil
    }
}

// Extension for billing cycle display names
extension Subscription.BillingCycle {
    var displayName: String {
        switch self {
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .quarterly: return "Quarterly"
        case .semiannual: return "Semi-annual"
        case .annual: return "Annual"
        case .custom: return "Custom"
        }
    }
}
