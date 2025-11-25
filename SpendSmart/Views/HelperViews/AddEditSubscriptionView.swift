import SwiftUI

struct AddEditSubscriptionView: View {
    var onSave: (Subscription) -> Void
    var editing: Subscription? = nil

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @StateObject private var currencyManager = CurrencyManager.shared
    @StateObject private var logoService = BrandfetchService.shared

    @State private var name: String = ""
    @State private var serviceName: String = ""
    @State private var logoURL: String = ""
    @State private var amount: String = ""
    @State private var currency: String = CurrencyManager.shared.preferredCurrency
    @State private var cycle: Subscription.BillingCycle = .monthly
    @State private var intervalCount: String = ""
    @State private var nextRenewal: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var isActive: Bool = true
    @State private var isTrial: Bool = false
    @State private var trialEnd: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var notifyRenewalDays: Int = 3
    @State private var notifyTrialDays: Int = 2
    @State private var notes: String = ""
    @State private var category: String = ""
    @State private var paymentMethod: String = ""

    
    private enum Stage { case choose, form }
    @State private var stage: Stage = .choose
    @State private var searchText: String = ""
    @State private var animateForm = false
    @State private var selectedService: PopularSubscriptionItem?
    @State private var selectedCategory: ServiceCategory? = nil
    @State private var showSuccessAnimation = false
    @State private var logoImage: UIImage?
    @State private var isLoadingLogo = false
    @State private var showDateValidationError = false
    @State private var dateValidationMessage = ""
    @State private var isFormValid = false
    @State private var logoDebounceTimer: Timer?
    @State private var useStreamlinedForm = true // Toggle for new vs old form

    private var categories: [String] {
        ServiceCategory.allCases.map { $0.rawValue }
    }
    
    private var paymentMethods: [String] {
        ["Credit Card", "Debit Card", "PayPal", "Apple Pay", "Google Pay", "Bank Transfer", "Cash", "Other"]
    }

    var body: some View {
        NavigationView {
            mainContent
        }
        .onAppear(perform: setupView)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                IconButton(
                    icon: "xmark.circle.fill",
                    size: .medium,
                    style: .outlined
                ) {
                    HapticFeedbackManager.shared.lightImpact()
                    dismiss()
                }
                .glassCompatCircle()
            }
            ToolbarItem(placement: .confirmationAction) {
                saveButton
            }
        }
    }
    
    private var mainContent: some View {
        ZStack {
            DesignTokens.Colors.Background.grouped
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Group {
                        if stage == .choose {
                            glassContainer(spacing: 20) {
                                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                                    chooseViewContent
                                }
                            }
                        } else {
                            formCard
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: stage)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private func glassContainer(
        spacing: CGFloat,
        cornerRadius: CGFloat = 20,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(spacing: spacing) {
            content()
        }
        .padding(DesignTokens.Spacing.lg)
        .glassCompatRect(cornerRadius: cornerRadius, interactive: true)
    }
    
    private var chooseViewContent: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            headerSection
            searchSection
            servicesGrid
        }
    }
    
    private var navigationTitle: String {
        stage == .choose ? "" : (editing != nil ? "Edit Subscription" : "Add Subscription")
    }
    
    private var cancelButton: some View {
        SecondaryButton("Cancel") { 
            HapticFeedbackManager.shared.lightImpact()
            dismiss() 
        }
    }
    
    private var saveButton: some View {
        PrimaryButton("Save", isDisabled: !isValid) { 
            HapticFeedbackManager.shared.formSubmitted()
            save() 
        }
        .respectsMotionPreferences(value: isValid)
    }
    
    private var prominentSaveButton: some View {
        Button(action: {
            HapticFeedbackManager.shared.formSubmitted()
            save()
        }) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                
                Text(editing != nil ? "Save Changes" : "Create Subscription")
                    .font(.instrumentSans(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 40)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .disabled(!isValid)
        .opacity(isValid ? 1.0 : 0.5)
        .animation(.easeInOut(duration: 0.2), value: isValid)
        .padding(.top, 20)
    }
    
    private func setupView() {
        let initialStage: Stage = (editing == nil) ? .choose : .form
        stage = initialStage
        
        if let s = editing {
            populateFieldsFromExistingSubscription(s)
        }
        
        // Initial validation
        validateRenewalDate(nextRenewal)
        validateForm()
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
            animateForm = true
        }
    }
    
    private func populateFieldsFromExistingSubscription(_ subscription: Subscription) {
        name = subscription.name
        serviceName = subscription.service_name
        logoURL = subscription.logo_url ?? ""
        // Ensure the amount is a valid number before formatting
        if subscription.amount.isFinite && !subscription.amount.isNaN {
            amount = String(format: "%.2f", subscription.amount)
        } else {
            amount = ""
        }
        currency = subscription.currency
        cycle = subscription.billing_cycle
        intervalCount = subscription.interval_count != nil ? String(subscription.interval_count!) : ""
        nextRenewal = subscription.next_renewal_date
        isActive = subscription.is_active
        isTrial = subscription.is_trial
        trialEnd = subscription.trial_end_date ?? trialEnd
        notifyRenewalDays = subscription.notify_before_renewal_days
        notifyTrialDays = subscription.notify_before_trial_end_days
        notes = subscription.notes ?? ""
        category = subscription.category ?? ""
        paymentMethod = subscription.payment_method ?? ""
        
        // Fetch logo for existing subscription
        fetchLogoForService(serviceName)
    }
    
    private func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard appState.isHapticsEnabled else { return }
        let impact = UIImpactFeedbackGenerator(style: style)
        impact.impactOccurred()
    }
    
    private func hapticSuccess() {
        guard appState.isHapticsEnabled else { return }
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)
    }

    private var filteredPresets: [PopularSubscriptionItem] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        var results = PopularSubscriptions.items
        
        // Filter by category if selected
        if let category = selectedCategory {
            results = results.filter { $0.category == category }
        }
        
        // Filter by search text if provided
        if !q.isEmpty {
            results = results.filter { $0.serviceName.localizedCaseInsensitiveContains(q) }
        }
        
        return results
    }

    private var chooseView: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            headerSection
            searchSection
            servicesGrid
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Choose a Service")
                .textHierarchy(.pageTitle)
                .accessibilitySectionHeader()
        }
    }
    
    private var searchSection: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            DesignSystemTextField(
                placeholder: "Search services or enter custom name...",
                text: $searchText,
                icon: "magnifyingglass",
                keyboardType: .default
            )
            .glassCompatRect(cornerRadius: 12)
            
            // Quick filter chips for categories
            if searchText.isEmpty {
                quickFilterChips
            }
        }
    }
    
    private var quickFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                // "All" chip
                Button {
                    HapticFeedbackManager.shared.lightImpact()
                    withAnimation(DesignTokens.Animation.easeInOut) {
                        selectedCategory = nil
                        searchText = ""
                    }
                } label: {
                    Text("All")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(selectedCategory == nil ? .white : .secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
                .buttonStyle(PlainButtonStyle())
                .pressAnimation()
                .glassCompatCapsule(
                    tint: selectedCategory == nil ? DesignTokens.Colors.Primary.blue : nil,
                    interactive: selectedCategory == nil
                )
                
                // Category chips
                ForEach(ServiceCategory.allCases, id: \.self) { category in
                    Button {
                        HapticFeedbackManager.shared.lightImpact()
                        withAnimation(DesignTokens.Animation.easeInOut) {
                            selectedCategory = selectedCategory == category ? nil : category
                            searchText = ""
                        }
                    } label: {
                        Text(category.rawValue)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(selectedCategory == category ? .white : .secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .pressAnimation()
                    .glassCompatCapsule(
                        tint: selectedCategory == category ? DesignTokens.Colors.Primary.blue : nil,
                        interactive: selectedCategory == category
                    )
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
        }
    }
    
    private var servicesGrid: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // "Other Service" button - always visible
            otherServiceButton
            
            // Popular services grid
            if filteredPresets.isEmpty {
                emptySearchState
            } else {
                glassContainer(spacing: 20) {
                    LazyVGrid(columns: adaptiveGridColumns, spacing: DesignTokens.Spacing.md) {
                        popularServicesButtons
                    }
                }
            }
        }
    }
    
    private var emptySearchState: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.6))
            
            Text("No services found")
                .textHierarchy(.sectionTitle)
                .foregroundColor(.secondary)
            
            Text("Try a different search term or create a custom subscription")
                .textHierarchy(.caption)
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
            
            Button {
                print("🔥 [CREATE CUSTOM CLICKED] 🎯 'Create Custom' button was tapped!")
                print("🔥 [CREATE CUSTOM CLICKED] Current search text: '\(searchText)'")
                HapticFeedbackManager.shared.lightImpact()
                let currentSearch = searchText
                searchText = ""
                serviceName = currentSearch.isEmpty ? "" : currentSearch
                name = currentSearch.isEmpty ? "" : currentSearch
                
                // Set animateForm first, then change stage
                print("🔥 [CREATE CUSTOM CLICKED] Setting animateForm to true")
                animateForm = true
                
                // Simple stage change
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.stage = .form
                    }
                }
            } label: {
                Text("Create Custom")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            .glassCompatCapsule(tint: .blue, interactive: true)
            .allowsHitTesting(true)
        }
        .padding(.vertical, DesignTokens.Spacing.xl)
        .transition(.opacity)
    }
    
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: DesignTokens.Spacing.md), count: 3)
    }
    
    private var adaptiveGridColumns: [GridItem] {
        // Responsive grid: 2 columns on smaller screens, 3 on larger
        let columnCount = UIDevice.current.userInterfaceIdiom == .pad ? 4 : 3
        return Array(repeating: GridItem(.flexible(), spacing: DesignTokens.Spacing.md), count: columnCount)
    }
    
    private var otherServiceButton: some View {
        Button(action: {
            print("🔥 [OTHER SERVICE CLICKED] 🎯 'Choose Other/Custom' button was tapped!")
            print("🔥 [OTHER SERVICE CLICKED] Current search text: '\(searchText)'")
            print("🔥 [OTHER SERVICE CLICKED] Button action started")
            HapticFeedbackManager.shared.mediumImpact()
            let startingName = searchText.trimmingCharacters(in: .whitespaces)
            
            // Only reset fields if creating new subscription
            if editing == nil {
                serviceName = startingName
                name = startingName
                amount = ""
                logoURL = ""
                print("🔥 [OtherService] Reset fields for new subscription: \(startingName)")
            } else {
                // For editing, allow service name change but preserve other data
                serviceName = startingName.isEmpty ? serviceName : startingName
                print("🔥 [OtherService] Editing mode, updated service name: \(serviceName)")
            }
            
            currency = currencyManager.preferredCurrency
            print("🔥 [OtherService] Set currency: \(currency)")
            
            // Set animateForm first, then change stage
            print("🔥 [OtherService] Setting animateForm to true")
            animateForm = true
            
            // Simple stage change
            DispatchQueue.main.async {
                print("🔥 [OtherService] Transitioning to form stage")
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.stage = .form
                }
            }
        }) { 
            VStack(spacing: DesignTokens.Spacing.sm) {
                // Icon section
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [DesignTokens.Colors.Primary.blue.opacity(0.2), DesignTokens.Colors.Primary.blue.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(DesignTokens.Colors.Primary.blue)
                    )
                
                // Text section
                VStack(spacing: 2) {
                    Text("Create Custom")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Add any service")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.Spacing.lg)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .glassCompatRect(cornerRadius: DesignTokens.CornerRadius.lg)
            .accessibilityFormField(
                label: "Create Custom Subscription",
                hint: "Double tap to create a custom subscription with your own service name"
            )
        }
        .allowsHitTesting(true)
    }
    
    private var popularServicesButtons: some View {
        ForEach(Array(filteredPresets.enumerated()), id: \.element.id) { index, item in
            Button(action: {
                print("🔥 [SERVICE CLICKED] 🎯 \(item.serviceName) was tapped!")
                print("🔥 [SERVICE CLICKED] Service ID: \(item.id)")
                print("🔥 [SERVICE CLICKED] Category: \(item.category.rawValue)")
                handleServiceSelection(item)
            }) {
                presetTile(
                    title: item.serviceName, 
                    logo: item.logoURL, 
                    systemIcon: nil,
                    isSelected: selectedService?.id == item.id
                )
                .accessibilityFormField(
                    label: item.serviceName,
                    hint: "Double tap to create a subscription for \(item.serviceName)"
                )
            }
            .contentShape(Rectangle())
            .allowsHitTesting(true)
        }
    }
    
    private func handleServiceSelection(_ item: PopularSubscriptionItem) {
        print("🔥 [SERVICE SELECTION] 🎯 Processing selection for: \(item.serviceName)")
        print("🔥 [SERVICE SELECTION] Service details - ID: \(item.id), Category: \(item.category.rawValue)")
        HapticFeedbackManager.shared.mediumImpact()
        selectedService = item
        serviceName = item.serviceName
        
        // Only set default name if we're creating new (not editing)
        if editing == nil {
            name = item.serviceName
            print("🔥 [ServiceSelection] Set name: \(name)")
        }
        
        // Only set default amount if we're creating new or if current amount is empty
        if editing == nil || amount.isEmpty {
            if let amt = item.defaultAmount { 
                // Ensure the amount is a valid number before formatting
                if amt.isFinite && !amt.isNaN {
                    amount = String(format: "%.2f", amt)
                    print("🔥 [ServiceSelection] Set amount: \(amount)")
                } else {
                    amount = ""
                    print("🔥 [ServiceSelection] Invalid amount detected, setting to empty")
                }
            }
        }
        
        // Always allow currency and logo updates
        currency = currencyManager.preferredCurrency
        logoURL = item.logoURL
        print("🔥 [ServiceSelection] Set currency: \(currency), logoURL: \(logoURL)")
        
        // Fetch logo for the selected service
        fetchLogoForService(item.serviceName)
        
        // Set animateForm first, then change stage
        print("🔥 [ServiceSelection] Setting animateForm to true")
        animateForm = true
        
        // Simple stage change
        DispatchQueue.main.async {
            print("🔥 [ServiceSelection] Transitioning to form stage")
            withAnimation(.easeInOut(duration: 0.3)) {
                self.stage = .form
            }
        }
    }

    private func presetTile(title: String, logo: String?, systemIcon: String?, isSelected: Bool = false) -> some View {
        baseTileContent(title: title, logo: logo, systemIcon: systemIcon)
            .padding(.vertical, DesignTokens.Spacing.md)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .glassCompatRect(cornerRadius: DesignTokens.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                    .stroke(isSelected ? DesignTokens.Colors.Primary.blue : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
    
    private func baseTileContent(title: String, logo: String?, systemIcon: String?) -> some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            logoSection(logo: logo, systemIcon: systemIcon)
            titleSection(title: title)
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity)
    }
    
    private func logoSection(logo: String?, systemIcon: String?) -> some View {
        ZStack {
            if let logo = logo, let url = URL(string: logo), systemIcon == nil {
                CustomAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm))
                } placeholder: {
                    logoPlaceholder()
                }
            } else if let systemIcon = systemIcon {
                systemIconView(systemIcon: systemIcon)
            }
        }
    }
    
    private func logoPlaceholder() -> some View {
        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
            .fill(DesignTokens.Colors.Fill.secondary)
            .frame(width: 40, height: 40)
            .overlay(
                Image(systemName: "building.2")
                    .foregroundColor(DesignTokens.Colors.Neutral.secondary)
            )
    }
    
    private func systemIconView(systemIcon: String) -> some View {
        Circle()
            .fill(DesignTokens.Colors.Primary.blue.opacity(0.2))
            .frame(width: 40, height: 40)
            .overlay(
                Image(systemName: systemIcon)
                    .font(.system(size: DesignTokens.ComponentSize.iconSize, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.Primary.blue)
            )
    }
    
    private func titleSection(title: String) -> some View {
        Text(title)
            .textHierarchy(.caption, color: DesignTokens.Colors.Neutral.primary)
            .multilineTextAlignment(.center)
            .lineLimit(2)
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Only show back button when creating new subscription, not when editing
            if editing == nil {
                backButton
            }
            
            VStack(spacing: 16) {
                subscriptionForm
            }
            .padding(16)
            .glassCompatRect(cornerRadius: 16)
            
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                    .font(.system(size: 16, weight: .semibold))
                Text("Trials won’t be charged until the trial end date. You can enable a reminder before renewal in Settings > Notifications.")
                    .font(.instrumentSans(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .glassCompatRect(cornerRadius: 12)
            
            // Add prominent save button for both new and editing
            prominentSaveButton
        }
    }
    
    private var backButton: some View {
        HStack {
            Button {
                hapticFeedback(.light)
                print("🔥 [BackButton] Back button tapped")
                animateForm = false
                withAnimation(.easeInOut(duration: 0.3)) { 
                    stage = .choose
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Back")
                        .font(.instrumentSans(size: 16, weight: .medium))
                }
                .foregroundColor(.blue)
            }
            Spacer()
        }
        .opacity(animateForm ? 1 : 0)
        .offset(y: animateForm ? 0 : 10)
        .animation(.easeInOut(duration: 0.3), value: animateForm)
    }
    
    @ViewBuilder
    private var subscriptionForm: some View {
        if useStreamlinedForm {
            StreamlinedSubscriptionForm(
                serviceName: $serviceName,
                amount: $amount,
                currency: $currency,
                cycle: $cycle,
                intervalCount: $intervalCount,
                nextRenewal: $nextRenewal,
                isActive: $isActive,
                isTrial: $isTrial,
                trialEnd: $trialEnd,
                notifyRenewalDays: $notifyRenewalDays,
                notifyTrialDays: $notifyTrialDays,
                logoImage: logoImage,
                isLoadingLogo: isLoadingLogo,
                showDateValidationError: showDateValidationError,
                dateValidationMessage: dateValidationMessage,
                allCurrencies: currencyManager.getCurrencyCodes(),
                onServiceNameChanged: handleServiceNameChange,
                onNextRenewalChanged: handleNextRenewalChange,
                onAmountChanged: handleAmountChange,
                onCycleChanged: handleCycleChange,
                onIntervalCountChanged: handleIntervalCountChange
            )
            .opacity(animateForm ? 1 : 0)
            .offset(y: animateForm ? 0 : 10)
            .animation(.easeInOut(duration: 0.3), value: animateForm)
        } else {
            SubscriptionFormCard(
                serviceName: $serviceName,
                amount: $amount,
                currency: $currency,
                cycle: $cycle,
                intervalCount: $intervalCount,
                nextRenewal: $nextRenewal,
                isActive: $isActive,
                isTrial: $isTrial,
                trialEnd: $trialEnd,
                notifyRenewalDays: $notifyRenewalDays,
                notifyTrialDays: $notifyTrialDays,
                category: $category,
                paymentMethod: $paymentMethod,
                logoImage: logoImage,
                isLoadingLogo: isLoadingLogo,
                showDateValidationError: showDateValidationError,
                dateValidationMessage: dateValidationMessage,
                allCurrencies: currencyManager.getCurrencyCodes(),
                categories: categories,
                paymentMethods: paymentMethods,
                onServiceNameChanged: handleServiceNameChange,
                onNextRenewalChanged: handleNextRenewalChange
            )
            .opacity(animateForm ? 1 : 0)
            .offset(y: animateForm ? 0 : 10)
            .animation(.easeInOut(duration: 0.3), value: animateForm)
        }
    }
    
    private func handleServiceNameChange(_ newValue: String) {
        print("🔥 [ServiceNameChange] Service name changed to: \(newValue)")
        fetchLogoForService(newValue)
        validateForm()
    }
    
    private func handleNextRenewalChange(_ newDate: Date) {
        validateRenewalDate(newDate)
        validateForm()
    }
    
    private func handleAmountChange(_ newValue: String) {
        validateForm()
    }
    
    private func handleCycleChange(_ newValue: Subscription.BillingCycle) {
        validateForm()
    }
    
    private func handleIntervalCountChange(_ newValue: String) {
        validateForm()
    }
    
    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.blue)
            Text(title)
                .font(.instrumentSans(size: 18, weight: .bold))
                .foregroundColor(.primary)
        }
    }

    private var isValid: Bool {
        return isFormValid
    }
    
    private func validateForm() {
        DispatchQueue.main.async {
            let hasValidServiceName = !serviceName.trimmingCharacters(in: .whitespaces).isEmpty
            let hasValidAmount = !amount.trimmingCharacters(in: .whitespaces).isEmpty && Double(amount) != nil && (Double(amount) ?? 0) > 0
            let hasValidDate = !showDateValidationError
            let hasValidCustomInterval = cycle != .custom || (Int(intervalCount) != nil && (Int(intervalCount) ?? 0) > 0 && (Int(intervalCount) ?? 0) <= 36)
            
            isFormValid = hasValidServiceName && hasValidAmount && hasValidDate && hasValidCustomInterval
        }
    }
    
    private func validateRenewalDate(_ date: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let selectedDate = calendar.startOfDay(for: date)
        
        if selectedDate < today {
            showDateValidationError = true
            dateValidationMessage = "Renewal date cannot be in the past"
        } else if selectedDate == today {
            showDateValidationError = true
            dateValidationMessage = "Please select a future date"
        } else {
            showDateValidationError = false
            dateValidationMessage = ""
        }
    }
    
    private func fetchLogoForService(_ serviceName: String) {
        print("🔥 [LogoFetch] Starting logo fetch for: \(serviceName)")
        
        // Cancel previous timer
        logoDebounceTimer?.invalidate()
        
        guard !serviceName.trimmingCharacters(in: .whitespaces).isEmpty else {
            print("🔥 [LogoFetch] Service name is empty, clearing logo")
            logoImage = nil
            logoURL = ""
            return
        }
        
        // Set loading state immediately for better UX
        isLoadingLogo = true
        print("🔥 [LogoFetch] Set loading state to true")
        
        // Debounce API calls by 1 second
        logoDebounceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            Task {
                let fetchedLogo = await BrandfetchService.shared.fetchLogo(for: serviceName, size: 128)

                await MainActor.run {
                    isLoadingLogo = false
                    logoImage = fetchedLogo

                    // Update the logoURL for saving
                    if let _ = fetchedLogo {
                        logoURL = BrandfetchService.shared.getLogoURL(for: serviceName, size: 128) ?? ""
                    }
                }
            }
        }
    }

    private func save() {
        hapticSuccess()
        
        let user = resolveUserId()
        let subscription = createSubscription(userId: user)
        
        onSave(subscription)
        dismiss()
    }
    
    private func resolveUserId() -> UUID {
        return appState.guestUserId 
            ?? UUID(uuidString: BackendAPIService.shared.getAuthToken() ?? "") 
            ?? UUID() // Fallback to random UUID for local-only mode
    }
    
    private func createSubscription(userId: UUID) -> Subscription {
        // Safely convert amount string to Double
        let amountValue: Double
        if amount.trimmingCharacters(in: .whitespaces).isEmpty {
            amountValue = 0.0
        } else {
            amountValue = Double(amount) ?? 0.0
        }
        
        return Subscription(
            id: editing?.id ?? UUID(),
            user_id: userId,
            name: name,
            service_name: serviceName,
            logo_url: logoURL.isEmpty ? nil : logoURL,
            amount: amountValue,
            currency: currency,
            billing_cycle: cycle,
            interval_count: cycle == .custom ? Int(intervalCount) : nil,
            next_renewal_date: nextRenewal,
            is_active: isActive,
            is_trial: isTrial,
            trial_end_date: isTrial ? trialEnd : nil,
            notify_before_renewal_days: notifyRenewalDays,
            notify_before_trial_end_days: notifyTrialDays,
            notes: notes.isEmpty ? nil : notes,
            category: category.isEmpty ? nil : category,
            payment_method: paymentMethod.isEmpty ? nil : paymentMethod
        )
    }
}

// MARK: - View Modifiers
struct TileAccessibilityModifier: ViewModifier {
    let title: String
    let isSelected: Bool
    
    func body(content: Content) -> some View {
        content
            .accessibilityLabel(title)
            .accessibilityHint("Tap to select \(title) service")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct TileAppearanceModifier: ViewModifier {
    let isSelected: Bool
    
    func body(content: Content) -> some View {
        content
            .contentContainer(level: isSelected ? .primary : .secondary)
            .modifier(TileBorderModifier(isSelected: isSelected))
            .modifier(TileShadowModifier(isSelected: isSelected))
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}

struct TileBorderModifier: ViewModifier {
    let isSelected: Bool
    
    func body(content: Content) -> some View {
        content
            .overlay(primaryBorder)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(secondaryBorder)
    }
    
    private var primaryBorder: some View {
        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
            .strokeBorder(
                isSelected ? DesignTokens.Colors.Primary.blue : Color.clear,
                lineWidth: 2
            )
    }
    
    private var secondaryBorder: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(
                isSelected ? Color.blue.opacity(0.8) : Color.white.opacity(0.2),
                lineWidth: isSelected ? 3 : 1
            )
    }
}

struct TileShadowModifier: ViewModifier {
    let isSelected: Bool
    
    func body(content: Content) -> some View {
        content
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: 0,
                y: shadowOffsetY
            )
    }
    
    private var shadowColor: Color {
        isSelected ? Color.blue.opacity(0.3) : Color.black.opacity(0.1)
    }
    
    private var shadowRadius: CGFloat {
        isSelected ? 12 : 6
    }
    
    private var shadowOffsetY: CGFloat {
        isSelected ? 6 : 3
    }
}
