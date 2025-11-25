//
//  OnboardingView.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-05-01.
//  Enhanced with mesh gradients, personalization, and Supabase integration
//

import SwiftUI
import Lottie

struct OnboardingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appState: AppState
    @StateObject private var onboardingState = OnboardingState()
    @StateObject private var currencyManager = CurrencyManager.shared
    
    // Currency selection state
    @State private var searchText = ""
    
    // Filtered currencies based on search
    private var filteredCurrencies: [CurrencyManager.CurrencyInfo] {
        if searchText.isEmpty {
            return currencyManager.supportedCurrencies
        } else {
            return currencyManager.searchCurrencies(query: searchText)
        }
    }

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Step content in a centered column for iPad/large screens
                ZStack {
                    stepContent()
                        .id(onboardingState.currentStep)
                        .transition(stepTransition)
                }
                .animation(.easeInOut(duration: 0.28), value: onboardingState.currentStep)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
        }
        .useInstrumentSans()
        .safeAreaInset(edge: .top) { Color.clear.frame(height: 20) }
        .safeAreaInset(edge: .bottom) {
            navigationButtons()
                .frame(maxWidth: 520)
                .padding(.horizontal, 16)
                .background(Color.clear)
        }
        .alert("Error", isPresented: $onboardingState.showError) {
            Button("OK") { }
        } message: {
            Text(onboardingState.errorMessage)
        }
    }

    // Step content based on current onboarding step
    @ViewBuilder
    private func stepContent() -> some View {
        switch onboardingState.currentStep {
        case .welcome:
            welcomeStep()
        case .appearance:
            appearanceStep()
        case .discovery:
            discoveryStep()
        case .usageReason:
            usageReasonStep()
        case .spendingGoals:
            spendingGoalsStep()
        case .budgetRange:
            budgetRangeStep()
        case .categories:
            categoriesStep()
        case .currency:
            currencySelectionStep()
        case .personalization:
            personalizationStep()
        case .completion:
            completionStep()
        }
    }
    
    private func welcomeStep() -> some View {
        VStack(spacing: 0) {
            OnboardingWelcomeCard(
                title: onboardingState.currentStep.title,
                subtitle: onboardingState.currentStep.subtitle,
                features: OnboardingFeature.defaultFeatures,
                showLogo: false
            )
            .padding(.horizontal, 20)
        }
    }
    
    private func appearanceStep() -> some View {
        VStack(spacing: 0) {
            StepProgressHeader(
                currentStep: onboardingState.currentStep.rawValue + 1,
                totalSteps: OnboardingStep.totalSteps,
                title: onboardingState.currentStep.title,
                subtitle: onboardingState.currentStep.subtitle
            ) {
                onboardingState.previousStep()
            }

            VStack(spacing: 12) {
                OnboardingSelectionCard(
                    item: AppState.Appearance.system,
                    isSelected: onboardingState.appearanceSelection == .system,
                    title: "System",
                    icon: "iphone"
                ) {
                    onboardingState.appearanceSelection = .system
                    appState.appearanceSelection = .system
                }
                OnboardingSelectionCard(
                    item: AppState.Appearance.light,
                    isSelected: onboardingState.appearanceSelection == .light,
                    title: "Light",
                    icon: "sun.max.fill"
                ) {
                    onboardingState.appearanceSelection = .light
                    appState.appearanceSelection = .light
                }
                OnboardingSelectionCard(
                    item: AppState.Appearance.dark,
                    isSelected: onboardingState.appearanceSelection == .dark,
                    title: "Dark",
                    icon: "moon.fill"
                ) {
                    onboardingState.appearanceSelection = .dark
                    appState.appearanceSelection = .dark
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 32)
        }
        .bottomSafeAreaFade()
    }

    private func discoveryStep() -> some View {
        VStack(spacing: 0) {
            StepProgressHeader(
                currentStep: onboardingState.currentStep.rawValue + 1,
                totalSteps: OnboardingStep.totalSteps,
                title: onboardingState.currentStep.title,
                subtitle: onboardingState.currentStep.subtitle
            ) {
                onboardingState.previousStep()
            }

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(ReferralSource.allCases, id: \.self) { source in
                        OnboardingSelectionCard(
                            item: source,
                            isSelected: onboardingState.referralSource == source,
                            title: source.displayName,
                            icon: source.icon
                        ) {
                            onboardingState.selectReferral(source)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 32)
            }
        }
        .bottomSafeAreaFade()
    }

    private func usageReasonStep() -> some View {
        VStack(spacing: 0) {
            StepProgressHeader(
                currentStep: onboardingState.currentStep.rawValue + 1,
                totalSteps: OnboardingStep.totalSteps,
                title: onboardingState.currentStep.title,
                subtitle: onboardingState.currentStep.subtitle
            ) { onboardingState.previousStep() }

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(AppUsageReason.allCases, id: \.self) { reason in
                        OnboardingSelectionCard(
                            item: reason,
                            isSelected: onboardingState.appUsageReason == reason,
                            title: reason.displayName,
                            icon: reason.icon
                        ) { onboardingState.selectUsageReason(reason) }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 32)
            }
        }
        .bottomSafeAreaFade()
    }

    private func budgetRangeStep() -> some View {
        VStack(spacing: 0) {
            StepProgressHeader(
                currentStep: onboardingState.currentStep.rawValue + 1,
                totalSteps: OnboardingStep.totalSteps,
                title: onboardingState.currentStep.title,
                subtitle: onboardingState.currentStep.subtitle
            ) { onboardingState.previousStep() }

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(BudgetRange.allCases, id: \.self) { range in
                        OnboardingSelectionCard(
                            item: range,
                            isSelected: onboardingState.budgetRange == range,
                            title: range.displayName,
                            icon: range.icon
                        ) { onboardingState.selectBudgetRange(range) }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 32)
            }
        }
        .bottomSafeAreaFade()
    }

    private func spendingGoalsStep() -> some View {
        VStack(spacing: 0) {
            StepProgressHeader(
                currentStep: onboardingState.currentStep.rawValue + 1,
                totalSteps: OnboardingStep.totalSteps,
                title: onboardingState.currentStep.title,
                subtitle: onboardingState.currentStep.subtitle
            ) { onboardingState.previousStep() }

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(SpendingGoal.allCases, id: \.self) { goal in
                        OnboardingMultiSelectionCard(
                            item: goal,
                            isSelected: onboardingState.selectedSpendingGoals.contains(goal),
                            title: goal.displayName,
                            subtitle: nil,
                            icon: goal.icon,
                            maxSelections: nil,
                            currentSelectionCount: onboardingState.selectedSpendingGoals.count
                        ) { onboardingState.toggleSpendingGoal(goal) }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 32)
            }
        }
        .bottomSafeAreaFade()
    }

    private func categoriesStep() -> some View {
        VStack(spacing: 0) {
            StepProgressHeader(
                currentStep: onboardingState.currentStep.rawValue + 1,
                totalSteps: OnboardingStep.totalSteps,
                title: onboardingState.currentStep.title,
                subtitle: onboardingState.currentStep.subtitle
            ) { onboardingState.previousStep() }

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(ExpenseCategory.primaryOnboardingCategories, id: \.self) { category in
                        OnboardingMultiSelectionCard(
                            item: category,
                            isSelected: onboardingState.selectedCategories.contains(category),
                            title: category.displayName,
                            subtitle: nil,
                            icon: category.icon,
                            maxSelections: 4,
                            currentSelectionCount: onboardingState.selectedCategories.count
                        ) { onboardingState.toggleCategory(category) }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 32)
            }
        }
        .bottomSafeAreaFade()
    }
    
    private func personalizationStep() -> some View {
        VStack {
            Spacer()
            
            PersonalizationProgress(progress: onboardingState.personalizationProgress)
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
    
    private func completionStep() -> some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Success animation
            LottieView(animation: .named("success"))
                .playing(loopMode: .playOnce)
                .animationSpeed(1.0)
                .frame(width: 120, height: 120)
            
            VStack(spacing: 16) {
                Text(onboardingState.currentStep.title)
                    .font(.hierarchyDisplay(level: 1))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(onboardingState.currentStep.subtitle ?? "")
                    .font(.hierarchyBody(emphasis: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
        }
    }

    private func currencySelectionStep() -> some View {
        VStack(spacing: 0) {
            StepProgressHeader(
                currentStep: onboardingState.currentStep.rawValue + 1,
                totalSteps: OnboardingStep.totalSteps,
                title: onboardingState.currentStep.title,
                subtitle: onboardingState.currentStep.subtitle
            ) {
                onboardingState.previousStep()
            }
            
            VStack(spacing: 20) {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("Search currencies", text: $searchText)
                        .font(.hierarchyBody())
                        .foregroundColor(.primary)
                        .tint(.primary)

                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
                .padding(.horizontal, 20)
                .padding(.top, 32)

                // Currency list
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredCurrencies, id: \.code) { currencyInfo in
                            currencyListItem(currencyInfo)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .bottomSafeAreaFade()
    }

    private func currencyListItem(_ currencyInfo: CurrencyManager.CurrencyInfo) -> some View {
        OnboardingSelectionCard(
            item: currencyInfo.code,
            isSelected: onboardingState.currencyPreference == currencyInfo.code,
            title: currencyInfo.name,
            subtitle: "\(currencyInfo.code) · \(currencyInfo.symbol)",
            icon: "coloncurrencysign.circle"
        ) {
            onboardingState.currencyPreference = currencyInfo.code
        }
    }

    @ViewBuilder
    private func navigationButtons() -> some View {
        VStack(spacing: 16) {
            if onboardingState.currentStep != .welcome && onboardingState.currentStep != .personalization {
                OnboardingPrimaryButton(
                    onboardingState.currentStep == .completion ? "Get Started" : "Next",
                    isEnabled: onboardingState.canProceed,
                    isLoading: onboardingState.isProcessing
                ) {
                    if onboardingState.currentStep == .completion {
                        Task {
                            await completeOnboarding()
                        }
                    } else {
                        // Apply appearance immediately when moving forward from appearance step
                        if onboardingState.currentStep == .appearance {
                            // Update global app appearance
                            appState.appearanceSelection = onboardingState.appearanceSelection
                        }
                        onboardingState.nextStep()
                    }
                }
                .padding(.horizontal, 20)
            } else if onboardingState.currentStep == .welcome {
                OnboardingPrimaryButton("Get Started") {
                    onboardingState.nextStep()
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 16)
        .background(Color.clear)
    }
    
    private func completeOnboarding() async {
        await onboardingState.completeOnboarding()
        
        // Update app state on main thread
        await MainActor.run {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                appState.isOnboardingComplete = true
            }
        }
    }
}

// MARK: - Step Transition
extension OnboardingView {
    private var stepTransition: AnyTransition {
        AnyTransition.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
}
