//
//  OnboardingView.swift
//  SpendSmart
//
//  Multi-step onboarding flow with statistics, budget setup, and currency selection.
//

import SwiftUI
import SwiftUICharts

// MARK: - Onboarding Step
enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case name = 1
    case features = 2
    case tryScanning = 3
    case plusPaywall = 4
    case stats = 5
    case intent = 6
    case referral = 7
    case currency = 8
    case ready = 9

    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .name: return "Your Name"
        case .features: return "Features"
        case .tryScanning: return "Try Scanning"
        case .plusPaywall: return "Plus"
        case .stats: return "Why SpendSmart"
        case .intent: return "Your Goal"
        case .referral: return "Attribution"
        case .currency: return "Currency"
        case .ready: return "Ready"
        }
    }

    var isSkippable: Bool {
        switch self {
        case .tryScanning, .plusPaywall, .intent, .referral:
            return true
        default:
            return false
        }
    }

    /// Icon for each step (for animated progress)
    var icon: String {
        switch self {
        case .welcome: return "hand.wave.fill"
        case .name: return "person.fill"
        case .features: return "sparkles"
        case .tryScanning: return "camera.fill"
        case .plusPaywall: return "crown.fill"
        case .stats: return "chart.line.uptrend.xyaxis"
        case .intent: return "target"
        case .referral: return "megaphone.fill"
        case .currency: return "dollarsign.circle.fill"
        case .ready: return "checkmark.seal.fill"
        }
    }
}

// MARK: - Onboarding View
struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var supabase = SupabaseManager.shared
    @AppStorage("currencyCode") private var currencyCode: String = "USD"
    
    @State private var currentStep: OnboardingStep = .welcome
    @State private var animateContent = false
    @State private var selectedCurrency: String = "USD"
    @State private var displayNameInput: String = ""
    @State private var showCurrencySearch = false
    
    // Try Scanning state
    @State private var tryScanningAdvance = false
    
    // Insights
    @State private var selectedIntent: String?
    @State private var selectedReferral: String?
    
    var body: some View {
        ZStack {
            // Background gradient
            backgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress indicator
                progressIndicator
                    .padding(.top, 20)
                    .padding(.horizontal, 32)
                
                // Content
                TabView(selection: $currentStep) {
                    welcomeStep
                        .tag(OnboardingStep.welcome)

                    nameStep
                        .tag(OnboardingStep.name)
                    
                    featuresStep
                        .tag(OnboardingStep.features)
                    
                    // New Try Scanning Step
                    TryScanningStep(
                        shouldAdvance: $tryScanningAdvance,
                        onSkip: {
                            advanceToNextStep()
                        }
                    )
                    .tag(OnboardingStep.tryScanning)

                    plusPaywallStep
                        .tag(OnboardingStep.plusPaywall)

                    statsStep
                        .tag(OnboardingStep.stats)
                    
                    intentStep
                        .tag(OnboardingStep.intent)
                    
                    referralStep
                        .tag(OnboardingStep.referral)
                    
                    currencyStep
                        .tag(OnboardingStep.currency)
                    
                    readyStep
                        .tag(OnboardingStep.ready)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: currentStep)
                
                // Navigation buttons (hidden on tryScanning and plusPaywall steps - they have their own)
                if currentStep != .tryScanning && currentStep != .plusPaywall {
                    navigationButtons
                        .padding(.horizontal, 32)
                        .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            selectedCurrency = currencyCode
            displayNameInput = appState.pendingDisplayName ?? ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(duration: 0.8)) {
                    animateContent = true
                }
            }
        }
        .onChange(of: tryScanningAdvance) { _, newValue in
            if newValue {
                advanceToNextStep()
                tryScanningAdvance = false
            }
        }
        .sheet(isPresented: $showCurrencySearch) {
            CurrencyPickerView(selectedCurrency: $selectedCurrency)
        }
    }
    
    // Helper to advance to next step
    private func advanceToNextStep() {
        withAnimation {
            currentStep = OnboardingStep(rawValue: currentStep.rawValue + 1) ?? .ready
        }
    }
    
    // MARK: - Background
    
    @Environment(\.scenePhase) private var scenePhase

    private var backgroundGradient: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: scenePhase != .active)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            MeshGradient(width: 3, height: 3, points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5],
                [Float(0.5 + 0.08 * cos(time * 0.3)), Float(0.5 + 0.06 * sin(time * 0.4))],
                [1, 0.5],
                [0, 1], [0.5, 1], [1, 1]
            ], colors: [
                .brandDeepNavy, .brandDeepNavy.opacity(0.9), .brandDeepNavy,
                .brandDarkNavy, .brandVibrantBlue.opacity(0.4), .brandMidnightBlue,
                .brandDeepNavy, .brandDarkNavy, .brandDeepNavy
            ])
            .drawingGroup()
        }
    }
    
    // MARK: - Progress Indicator
    
    private var progressIndicator: some View {
        VStack(spacing: 12) {
            // Step counter text
            Text("Step \(currentStep.rawValue + 1) of \(OnboardingStep.allCases.count)")
                .font(.manrope(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .animation(.easeInOut(duration: 0.2), value: currentStep)
            
            // Progress bar segments
            HStack(spacing: 8) {
                ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                    Capsule()
                        .fill(step.rawValue <= currentStep.rawValue ? Color.white : Color.white.opacity(0.3))
                        .frame(height: 4)
                        .animation(.spring(duration: 0.3), value: currentStep)
                }
            }
        }
    }
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        HStack(spacing: 16) {
            // Back button (hidden on first step)
            if currentStep != .welcome {
                Button {
                    HapticManager.shared.buttonPress()
                    withAnimation {
                        currentStep = OnboardingStep(rawValue: currentStep.rawValue - 1) ?? .welcome
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                            .font(.manrope(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                }
            }
            
            Spacer()
            
            // Next/Get Started button
            Button {
                HapticManager.shared.buttonPress()
                if currentStep == .ready {
                    // Save settings, insights, and complete onboarding
                    currencyCode = selectedCurrency
                    let trimmedName = displayNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedName.isEmpty {
                        appState.pendingDisplayName = trimmedName
                        Task {
                            await supabase.ensureProfileNameExists(trimmedName)
                        }
                    }
                    
                    if let intent = selectedIntent, let referral = selectedReferral {
                        Task {
                            await supabase.saveOnboardingInsights(intent: intent, referral: referral)
                        }
                    }
                    
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                        appState.markOnboardingComplete()
                        appState.queueFirstScanLaunch()
                    }
                } else {
                    if currentStep == .name {
                        let trimmedName = displayNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmedName.isEmpty {
                            appState.pendingDisplayName = trimmedName
                            Task {
                                await supabase.ensureProfileNameExists(trimmedName)
                            }
                        }
                    }
                    withAnimation {
                        currentStep = OnboardingStep(rawValue: currentStep.rawValue + 1) ?? .ready
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(currentStep == .ready ? "Start First Scan" : "Continue")
                        .font(.manrope(size: 16, weight: .bold))
                    Image(systemName: currentStep == .ready ? "arrow.right" : "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(Color.brandDeepNavy)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.5))
                            .offset(y: 4)
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                    }
                )
                .shadow(color: Color.brandVibrantBlue.opacity(0.3), radius: 12, y: 6)
            }
        }
    }
    
    // MARK: - Step 1: Welcome
    
    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Welcome to SpendSmart,")
                    .font(.instrumentSerif(size: 42))
                    .foregroundStyle(.white)
                
                Text("\(firstName).")
                    .font(.instrumentSerifItalic(size: 42))
                    .foregroundStyle(Color.brandSkyBlue)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .blur(radius: animateContent ? 0 : 20)
            .opacity(animateContent ? 1 : 0)
            
            Text("Smart receipt tracking powered by AI. Scan, organize, and understand your spending in seconds.")
                .font(.manrope(size: 17, weight: .regular))
                .foregroundStyle(.white.opacity(0.75))
                .lineSpacing(4)
                .blur(radius: animateContent ? 0 : 16)
                .opacity(animateContent ? 1 : 0)
            
            Spacer()
            Spacer()
        }
        .padding(32)
    }

    // MARK: - Step 1: Name

    private var nameStep: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 10) {
                Text("What should we call you?")
                    .font(.instrumentSerif(size: 32))
                    .foregroundStyle(.white)

                Text("This helps personalize your dashboard and receipts.")
                    .font(.manrope(size: 15, weight: .regular))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            TextField("Your name", text: $displayNameInput)
                .font(.manrope(size: 18, weight: .semibold))
                .foregroundStyle(Color.brandDeepNavy)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white)
                )
                .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
        .padding(32)
    }
    
    // MARK: - Step 2: Features
    
    private var featuresStep: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 8) {
                Text("Powerful Features")
                    .font(.instrumentSerif(size: 32))
                    .foregroundStyle(.white)
                
                Text("Everything you need to track expenses")
                    .font(.manrope(size: 15, weight: .regular))
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            VStack(spacing: 20) {
                featureRow(icon: "camera.viewfinder", title: "AI-Powered Scanning", description: "Just snap a photo - AI extracts all details instantly", lottieName: "lottie_scan")
                featureRow(icon: "chart.pie.fill", title: "Smart Analytics", description: "Understand your spending patterns with beautiful charts", lottieName: "lottie_chart")
                featureRow(icon: "map.fill", title: "Store Map", description: "Visualize where and how much you spend", lottieName: "lottie_map")
                featureRow(icon: "bubble.left.and.bubble.right.fill", title: "AI Assistant", description: "Ask questions about your spending in natural language", lottieName: "lottie_ai")
            }
            
            Spacer()
            Spacer()
        }
        .padding(32)
    }
    
    // MARK: - Step: Plus Paywall

    private var plusPaywallStep: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(Color.brandSkyBlue)

                Text("Unlock Your Full Potential")
                    .font(.instrumentSerifItalic(size: 32))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Get the most out of SpendSmart with Plus")
                    .font(.manrope(size: 15, weight: .regular))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                plusFeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Smart Insights", description: "AI-powered spending analysis and trends")
                plusFeatureRow(icon: "infinity", title: "Unlimited Scans", description: "No weekly limits on receipt scanning")
                plusFeatureRow(icon: "bubble.left.and.bubble.right.fill", title: "Unlimited AI Chat", description: "Ask anything about your spending habits")
                plusFeatureRow(icon: "icloud.fill", title: "Cloud Sync", description: "Access your data across all your devices")
                plusFeatureRow(icon: "square.and.arrow.up.fill", title: "Data Export", description: "Export your receipts and reports anytime")
            }

            VStack(spacing: 12) {
                Brand3DButton(title: "Start Free Trial", icon: "sparkles", style: .primary) {
                    HapticManager.shared.buttonPress()
                    SubscriptionManager.shared.presentPaywall(trigger: .settingsUpgrade)
                }

                Button {
                    HapticManager.shared.selection()
                    advanceToNextStep()
                } label: {
                    Text("Skip for now")
                        .font(.manrope(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            Spacer()
            Spacer()
        }
        .padding(32)
    }

    private func plusFeatureRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 40, height: 40)

                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.brandSuccess)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.manrope(size: 15, weight: .semibold))
                    .foregroundStyle(.white)

                Text(description)
                    .font(.manrope(size: 12, weight: .regular))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.brandSkyBlue)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
        )
    }

    // MARK: - Step 3: Stats (with Chart)
    
    private var statsStep: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 8) {
                Text("See Your Growth")
                    .font(.instrumentSerif(size: 32))
                    .foregroundStyle(.white)
                
                Text("Visualize your savings over time")
                    .font(.manrope(size: 15, weight: .regular))
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            // Animated Chart
            OnboardingChartView()
                .frame(height: 220)
                .padding(.horizontal)
            
            // Key metrics
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    statCompact(value: "84%", label: "overspend without tracking", icon: "exclamationmark.triangle.fill", color: Color.brandWarning, source: "NerdWallet, 2023")
                    statCompact(value: "69%", label: "live paycheck to paycheck", icon: "creditcard.fill", color: Color.brandSkyBlue, source: "Investopedia")
                }
                
                statCompact(value: "3×", label: "more savings with tracking apps", icon: "arrow.up.right.circle.fill", color: Color.brandSuccess, source: "CFPB Study")
            }
            
            Spacer()
            Spacer()
        }
        .padding(32)
    }
    
    private func statCompact(value: String, label: String, icon: String, color: Color, source: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(color)
            
            Text(value)
                .font(.ibmPlexMono(size: 20))
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            VStack(spacing: 2) {
                Text(label)
                    .font(.manrope(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                
                Text(source)
                    .font(.manrope(size: 9))
                    .foregroundStyle(.white.opacity(0.3))
                    .italic()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.white.opacity(0.08))
        .cornerRadius(16)
    }
    
    // MARK: - Step 4: Intent
    
    private var intentStep: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 8) {
                Text("Your Goal")
                    .font(.instrumentSerif(size: 32))
                    .foregroundStyle(.white)
                
                Text("How will you use SpendSmart?")
                    .font(.manrope(size: 15, weight: .regular))
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            VStack(spacing: 12) {
                selectionOption(title: "Track Personal Spending", value: "personal", selection: $selectedIntent)
                selectionOption(title: "Business Expenses", value: "business", selection: $selectedIntent)
                selectionOption(title: "Split Bills with Others", value: "split", selection: $selectedIntent)
                selectionOption(title: "Tax Preparation", value: "tax", selection: $selectedIntent)
            }
            .padding(.horizontal, 32)
            
            // Skip button
            Button {
                HapticManager.shared.selection()
                advanceToNextStep()
            } label: {
                Text("Skip for now")
                    .font(.manrope(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
            
            Spacer()
            Spacer()
        }
    }
    
    // MARK: - Step 5: Referral
    
    private var referralStep: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 8) {
                Text("One Last Thing")
                    .font(.instrumentSerif(size: 32))
                    .foregroundStyle(.white)
                
                Text("Where did you hear about us?")
                    .font(.manrope(size: 15, weight: .regular))
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            VStack(spacing: 12) {
                selectionOption(title: "App Store Search", value: "app_store", selection: $selectedReferral)
                selectionOption(title: "Social Media (TikTok/IG)", value: "social", selection: $selectedReferral)
                selectionOption(title: "Friend or Family", value: "friend", selection: $selectedReferral)
                selectionOption(title: "Blog or Article", value: "blog", selection: $selectedReferral)
                selectionOption(title: "Other", value: "other", selection: $selectedReferral)
            }
            .padding(.horizontal, 32)
            
            // Skip button
            Button {
                HapticManager.shared.selection()
                advanceToNextStep()
            } label: {
                Text("Skip for now")
                    .font(.manrope(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
            
            Spacer()
            Spacer()
        }
    }
    
    private func selectionOption(title: String, value: String, selection: Binding<String?>) -> some View {
        Button {
            HapticManager.shared.selection()
            withAnimation(.spring(duration: 0.3)) {
                selection.wrappedValue = value
            }
        } label: {
            HStack {
                Text(title)
                    .font(.manrope(size: 16, weight: .medium))
                    .foregroundStyle(selection.wrappedValue == value ? Color.brandDeepNavy : .white)
                
                Spacer()
                
                if selection.wrappedValue == value {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.brandDeepNavy)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selection.wrappedValue == value ? Color.white : Color.white.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Step 5: Currency Selection
    
    private var currencyStep: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 8) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(Color.brandSkyBlue)
                
                Text("Choose Currency")
                    .font(.instrumentSerif(size: 32))
                    .foregroundStyle(.white)
                
                Text("Your default currency for tracking")
                    .font(.manrope(size: 15, weight: .regular))
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            // Popular currencies grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                currencyOption("USD", "US Dollar", "🇺🇸")
                currencyOption("EUR", "Euro", "🇪🇺")
                currencyOption("GBP", "British Pound", "🇬🇧")
                currencyOption("CAD", "Canadian Dollar", "🇨🇦")
                currencyOption("AUD", "Australian Dollar", "🇦🇺")
                currencyOption("JPY", "Japanese Yen", "🇯🇵")
                currencyOption("INR", "Indian Rupee", "🇮🇳")
                currencyOption("CNY", "Chinese Yuan", "🇨🇳")
            }
            .padding(.vertical, 16)

            Button {
                HapticManager.shared.selection()
                showCurrencySearch = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Search currencies")
                        .font(.manrope(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.12))
                )
            }
            
            Text("You can change this anytime in Settings")
                .font(.manrope(size: 13, weight: .regular))
                .foregroundStyle(.white.opacity(0.5))
            
            Spacer()
            Spacer()
        }
        .padding(32)
    }
    
    private func currencyOption(_ code: String, _ name: String, _ flag: String) -> some View {
        Button {
            HapticManager.shared.selection()
            selectedCurrency = code
        } label: {
            HStack(spacing: 10) {
                Text(flag)
                    .font(.system(size: 24))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(code)
                        .font(.manrope(size: 15, weight: .semibold))
                        .foregroundStyle(selectedCurrency == code ? Color.brandDeepNavy : .white)
                    
                    Text(name)
                        .font(.manrope(size: 11, weight: .regular))
                        .foregroundStyle(selectedCurrency == code ? Color.brandDeepNavy.opacity(0.7) : .white.opacity(0.6))
                }
                
                Spacer()
                
                if selectedCurrency == code {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.brandDeepNavy)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedCurrency == code ? Color.white : Color.white.opacity(0.1))
            )
        }
    }
    
    // MARK: - Step 7: Ready
    
    private var readyStep: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Animated checkmark
            ZStack {
                Circle()
                    .fill(Color.brandSuccess.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Circle()
                    .fill(Color.brandSuccess.opacity(0.3))
                    .frame(width: 90, height: 90)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.brandSuccess)
            }
            
            VStack(spacing: 12) {
                Text("Create Your First Scan")
                    .font(.instrumentSerif(size: 36))
                    .foregroundStyle(.white)

                Text("Start by scanning a receipt. We'll pull in totals, items, and categories automatically.")
                    .font(.manrope(size: 16, weight: .regular))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            // Summary card
            VStack(spacing: 16) {
                summaryRow(icon: "dollarsign.circle", label: "Currency", value: selectedCurrency)
                summaryRow(icon: "gift.fill", label: "Free Scans", value: "5 per week")
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.1))
            )
            
            Spacer()
            Spacer()
        }
        .padding(32)
    }
    
    private func summaryRow(icon: String, label: String, value: String) -> some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.brandSkyBlue)
                    .frame(width: 24)
                
                Text(label)
                    .font(.manrope(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            Spacer()
            
            Text(value)
                .font(.manrope(size: 14, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
    
    // MARK: - Helper Views
    
    private func featureRow(icon: String, title: String, description: String, lottieName: String? = nil) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 48, height: 48)
                
                // Try Lottie first, fallback to SF Symbol
                if let lottie = lottieName {
                    LottieView(name: lottie, loopMode: .loop)
                        .frame(width: 32, height: 32)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.brandSkyBlue)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.manrope(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                
                Text(description)
                    .font(.manrope(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            Spacer()
        }
    }
    
    private func statCard(value: String, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.manrope(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                
                Text(label)
                    .font(.manrope(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
        )
    }
    
    // MARK: - Helper Functions
    
    private var firstName: String {
        if let pending = appState.pendingDisplayName,
            let pendingName = sanitizedFirstName(from: pending)
        {
            return pendingName
        }

        if let stored = supabase.profile?.full_name,
            let name = sanitizedFirstName(from: stored)
        {
            return name
        }

        if let email = supabase.session?.user.email,
            let fallback = sanitizedFirstName(from: email)
        {
            return fallback
        }

        return "friend"
    }

    private func sanitizedFirstName(from value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let atIndex = trimmed.firstIndex(of: "@"), atIndex != trimmed.startIndex {
            let prefix = String(trimmed[..<atIndex]).trimmingCharacters(in: .whitespaces)
            if let firstWord = prefix.split(separator: " ").first {
                return String(firstWord).capitalized
            }
            return prefix.capitalized
        }

        if let word = trimmed.split(separator: " ").first {
            return String(word).capitalized
        }

        return trimmed.capitalized
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = AppFormatters.currency(code: selectedCurrency, maximumFractionDigits: 0)
        return formatter.string(from: NSNumber(value: amount)) ?? "\(selectedCurrency) \(Int(amount))"
    }
}

// MARK: - Onboarding Chart View

struct OnboardingChartView: View {
    @State private var appearing = false
    @State private var animatedData: [Double] = Array(repeating: 0, count: 12)
    
    // "Real research" simulated data: exponential savings growth
    // Represents monthly savings accumulation: 0 -> 1240 over 12 months
    let data: [Double] = [0, 50, 120, 180, 290, 350, 480, 600, 750, 920, 1100, 1240]
    
    var body: some View {
        ZStack {
            // Background gradient
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: 8) {
                // Chart using SpendSmartSparkline
                GeometryReader { geometry in
                    ZStack {
                        // Gradient fill area
                        Path { path in
                            guard animatedData.count > 1 else { return }
                            let maxValue = max(data.max() ?? 1, 1)
                            let stepX = geometry.size.width / CGFloat(animatedData.count - 1)
                            
                            path.move(to: CGPoint(x: 0, y: geometry.size.height))
                            
                            for (index, value) in animatedData.enumerated() {
                                let x = CGFloat(index) * stepX
                                let normalizedY = value / maxValue
                                let y = geometry.size.height * (1 - CGFloat(normalizedY))
                                
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                            
                            path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                colors: [Color.brandVibrantBlue.opacity(0.3), Color.brandVibrantBlue.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        
                        // Line
                        Path { path in
                            guard animatedData.count > 1 else { return }
                            let maxValue = max(data.max() ?? 1, 1)
                            let stepX = geometry.size.width / CGFloat(animatedData.count - 1)
                            
                            for (index, value) in animatedData.enumerated() {
                                let x = CGFloat(index) * stepX
                                let normalizedY = value / maxValue
                                let y = geometry.size.height * (1 - CGFloat(normalizedY))
                                
                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(
                            LinearGradient(
                                colors: [Color.brandVibrantBlue, Color.brandSkyBlue],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                        )
                        
                        // Average line
                        if appearing {
                            let avgY = geometry.size.height * (1 - (600.0 / (data.max() ?? 1)))
                            
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: avgY))
                                path.addLine(to: CGPoint(x: geometry.size.width, y: avgY))
                            }
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .foregroundStyle(.white.opacity(0.25))
                            
                            Text("Average Growth")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.5))
                                .position(x: 60, y: avgY - 12)
                        }
                    }
                }
                
                // X-axis labels
                HStack {
                    Text("Jan")
                        .font(.manrope(size: 10))
                        .foregroundStyle(.white.opacity(0.4))
                    Spacer()
                    Text("Jun")
                        .font(.manrope(size: 10))
                        .foregroundStyle(.white.opacity(0.4))
                    Spacer()
                    Text("Dec")
                        .font(.manrope(size: 10))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.horizontal, 8)
            }
            .padding(16)
        }
        .onAppear {
            // Animate data points sequentially
            for (index, value) in data.enumerated() {
                let delay = Double(index) * 0.1
                DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.3) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        animatedData[index] = value
                    }
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    appearing = true
                }
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
}
