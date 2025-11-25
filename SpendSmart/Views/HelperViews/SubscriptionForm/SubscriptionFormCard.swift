import SwiftUI

struct SubscriptionFormCard: View {
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

    @Binding var category: String
    @Binding var paymentMethod: String

    // Visual assets
    var logoImage: UIImage?
    var isLoadingLogo: Bool

    // Validation UI
    var showDateValidationError: Bool
    var dateValidationMessage: String

    // Data sources
    var allCurrencies: [String]
    var categories: [String]
    var paymentMethods: [String]

    // Events
    var onServiceNameChanged: (String) -> Void
    var onNextRenewalChanged: (Date) -> Void

    @State private var animate = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header with Back handled by parent
            HStack { Spacer(); Text("Subscription Details").font(.instrumentSans(size: 20, weight: .bold)); Spacer() }

            // Service Information
            VStack(alignment: .leading, spacing: 14) {
                SubscriptionSectionHeader(title: "Service Information", systemImage: "building.2")

                HStack(spacing: 12) {
                    if isLoadingLogo {
                        ProgressView().frame(width: 40, height: 40)
                    } else {
                        LogoPreview(image: logoImage, title: serviceName)
                    }

                    SubscriptionAnimatedTextField(
                        title: "Service Name",
                        text: $serviceName,
                        placeholder: "e.g., Netflix, Spotify, iCloud+",
                        systemImage: "building.2",
                        isRequired: true,
                        validationMessage: serviceName.trimmingCharacters(in: .whitespaces).isEmpty ? "Service name is required" : nil,
                        isValid: !serviceName.trimmingCharacters(in: .whitespaces).isEmpty,
                        maxLength: 50
                    )
                    .onChange(of: serviceName) { _, newValue in
                        onServiceNameChanged(newValue)
                    }
                }

                AmountCurrencyField(
                    amount: $amount,
                    currency: $currency,
                    allCurrencies: allCurrencies
                )
            }
            .formSection()
            .opacity(animate ? 1 : 0)
            .offset(y: animate ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animate)

            // Billing Information
            VStack(alignment: .leading, spacing: 14) {
                SubscriptionSectionHeader(title: "Billing Information", systemImage: "creditcard")

                ChipsSelector(title: "Billing Cycle", options: Subscription.BillingCycle.allCases, selection: $cycle)

                if cycle == .custom {
                    SubscriptionAnimatedTextField(
                        title: "Custom Interval (months)",
                        text: $intervalCount,
                        placeholder: "e.g., 3",
                        systemImage: "number",
                        keyboardType: .numberPad,
                        isRequired: true,
                        validationMessage: validateInterval(intervalCount),
                        isValid: isValidInterval(intervalCount),
                        maxLength: 2
                    )
                }

                VStack(alignment: .leading, spacing: 6) {
                    InlineDateSelector(
                        title: "Next Renewal Date",
                        date: $nextRenewal,
                        minDate: Date(),
                        showValidationIcon: showDateValidationError,
                        validationColor: .red
                    )
                    .onChange(of: nextRenewal) { _, newDate in
                        onNextRenewalChanged(newDate)
                    }

                    if showDateValidationError && !dateValidationMessage.isEmpty {
                        Text(dateValidationMessage)
                            .font(.instrumentSans(size: 12))
                            .foregroundColor(.red)
                    }
                }
            }
            .formSection()
            .opacity(animate ? 1 : 0)
            .offset(y: animate ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: animate)

            // Status & Trial
            VStack(alignment: .leading, spacing: 14) {
                SubscriptionSectionHeader(title: "Status & Trial", systemImage: "bell")

                ToggleRow(title: "Active Subscription", subtitle: "Enable notifications and tracking", isOn: $isActive, tint: .blue)

                ToggleRow(title: "Free Trial", subtitle: "Set trial end date and notifications", isOn: $isTrial, tint: .orange)

                if isTrial {
                    InlineDateSelector(title: "Trial End Date", date: $trialEnd, tint: .orange)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .formSection()
            .opacity(animate ? 1 : 0)
            .offset(y: animate ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: animate)

            // Notifications
            VStack(alignment: .leading, spacing: 14) {
                SubscriptionSectionHeader(title: "Notifications", systemImage: "bell.badge")

                StepperRow(title: "Renewal Reminder (days before)", value: $notifyRenewalDays, range: 0...30, tint: .blue)

                if isTrial {
                    StepperRow(title: "Trial End Reminder (days before)", value: $notifyTrialDays, range: 0...14, tint: .orange)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .formSection()
            .opacity(animate ? 1 : 0)
            .offset(y: animate ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: animate)

            // Additional Information
            VStack(alignment: .leading, spacing: 14) {
                SubscriptionSectionHeader(title: "Additional Information", systemImage: "note.text")

                AnimatedDropdown(
                    title: "Category", 
                    icon: "folder", 
                    options: categories, 
                    selection: $category,
                    isRequired: false
                )

                AnimatedDropdown(
                    title: "Payment Method (Optional)", 
                    icon: "creditcard", 
                    options: paymentMethods, 
                    selection: $paymentMethod,
                    isRequired: false
                )
            }
            .formSection()
            .opacity(animate ? 1 : 0)
            .offset(y: animate ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: animate)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.001)) // transparent container, parent supplies background
        )
        .onAppear {
            withAnimation {
                animate = true
            }
        }
    }
    
    // MARK: - Validation Helper Functions
    private func validateInterval(_ interval: String) -> String? {
        guard !interval.isEmpty else {
            return "Custom interval is required"
        }
        
        guard let value = Int(interval), value > 0 else {
            return "Please enter a valid number"
        }
        
        if value > 36 {
            return "Interval cannot exceed 36 months"
        }
        
        return nil
    }
    
    private func isValidInterval(_ interval: String) -> Bool {
        guard !interval.isEmpty else { return false }
        guard let value = Int(interval), value > 0, value <= 36 else { return false }
        return true
    }
}


