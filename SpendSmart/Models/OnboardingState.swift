//
//  OnboardingState.swift
//  SpendSmart
//
//  Created by Claude on 2025-01-25.
//  User onboarding state management with Supabase integration
//

import SwiftUI
import Foundation
import Combine

// MARK: - Onboarding Data Models
struct OnboardingUserData: Codable {
    let id: UUID
    let userId: String  // Foreign key to auth.users
    let ageRange: AgeRange?
    let appUsageReason: AppUsageReason?
    let spendingGoals: [SpendingGoal]
    let monthlyBudgetRange: BudgetRange?
    let primaryCategories: [ExpenseCategory]
    let currencyPreference: String?
    let themePreference: String?
    let referralSource: String?
    let completedAt: Date?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, userId = "user_id", ageRange = "age_range"
        case appUsageReason = "app_usage_reason", spendingGoals = "spending_goals"
        case monthlyBudgetRange = "monthly_budget_range", primaryCategories = "primary_categories"
        case currencyPreference = "currency_preference", themePreference = "theme_preference", referralSource = "referral_source", completedAt = "completed_at"
        case createdAt = "created_at"
    }
}

// MARK: - Enums for Onboarding Options
enum AgeRange: String, CaseIterable, Codable {
    case under18 = "Under 18"
    case age18to24 = "18 to 24"
    case age25to34 = "25 to 34"
    case age35to49 = "35 to 49"
    case age50plus = "50+"
    
    var displayName: String {
        return self.rawValue
    }
    
    var icon: String {
        switch self {
        case .under18: return "graduationcap.fill"
        case .age18to24: return "person.fill"
        case .age25to34: return "briefcase.fill"
        case .age35to49: return "person.2.fill"
        case .age50plus: return "leaf.fill"
        }
    }
}

enum AppUsageReason: String, CaseIterable, Codable {
    case budgetTracking = "Track my spending and stick to budgets"
    case expenseAnalysis = "Understand where my money goes"
    case savingsGoals = "Save money for specific goals"
    case debtReduction = "Pay off debt and reduce expenses"
    case businessExpenses = "Track business expenses"
    case other = "Something else"
    
    var displayName: String {
        return self.rawValue
    }
    
    var icon: String {
        switch self {
        case .budgetTracking: return "chart.pie.fill"
        case .expenseAnalysis: return "magnifyingglass"
        case .savingsGoals: return "target"
        case .debtReduction: return "minus.circle.fill"
        case .businessExpenses: return "briefcase.fill"
        case .other: return "ellipsis.circle"
        }
    }
}

enum SpendingGoal: String, CaseIterable, Codable {
    case reduceSpending = "Reduce overall spending by 20%"
    case saveMoney = "Save $500+ per month"
    case budgetControl = "Stick to monthly budgets"
    case buildEmergency = "Build 6-month emergency fund"
    case payOffDebt = "Pay off credit card debt"
    
    var displayName: String {
        return self.rawValue
    }
    
    var icon: String {
        switch self {
        case .reduceSpending: return "arrow.down.circle.fill"
        case .saveMoney: return "dollarsign.circle.fill"
        case .budgetControl: return "checkmark.circle.fill"
        case .buildEmergency: return "shield.checkered"
        case .payOffDebt: return "creditcard.fill"
        }
    }
}

enum BudgetRange: String, CaseIterable, Codable {
    case under1k = "Under $1,000/month"
    case oneToThreeK = "$1,000 - $3,000/month"
    case threeToFiveK = "$3,000 - $5,000/month"
    case overFiveK = "Over $5,000/month"
    case preferNotToSay = "Prefer not to say"
    
    var displayName: String {
        return self.rawValue
    }
    
    var icon: String {
        switch self {
        case .under1k: return "1.circle.fill"
        case .oneToThreeK: return "2.circle.fill"
        case .threeToFiveK: return "3.circle.fill"
        case .overFiveK: return "4.circle.fill"
        case .preferNotToSay: return "questionmark.circle.fill"
        }
    }
}

enum ExpenseCategory: String, CaseIterable, Codable {
    case food = "Food & Dining"
    case transportation = "Transportation"
    case shopping = "Shopping"
    case entertainment = "Entertainment"
    case bills = "Bills & Utilities"
    case healthcare = "Healthcare"
    case education = "Education"
    case travel = "Travel"
    case housing = "Housing"
    case insurance = "Insurance"
    case investments = "Investments"
    case gifts = "Gifts & Donations"
    
    var displayName: String {
        return self.rawValue
    }
    
    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .transportation: return "car.fill"
        case .shopping: return "bag.fill"
        case .entertainment: return "tv.fill"
        case .bills: return "doc.text.fill"
        case .healthcare: return "cross.case.fill"
        case .education: return "book.fill"
        case .travel: return "airplane"
        case .housing: return "house.fill"
        case .insurance: return "shield.fill"
        case .investments: return "chart.line.uptrend.xyaxis"
        case .gifts: return "gift.fill"
        }
    }
}

// Prefer fewer, high-signal categories during onboarding
extension ExpenseCategory {
    static let primaryOnboardingCategories: [ExpenseCategory] = [
        .food, .transportation, .shopping, .entertainment,
        .bills, .healthcare, .housing, .travel
    ]
}

// MARK: - Onboarding Steps
enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case appearance = 1
    case discovery = 2
    case usageReason = 3
    case spendingGoals = 4
    case budgetRange = 5
    case categories = 6
    case currency = 7
    case personalization = 8
    case completion = 9
    
    var title: String {
        switch self {
        case .welcome: return "Welcome to SpendSmart"
        case .appearance: return "Choose your appearance"
        case .discovery: return "How did you hear about us?"
        case .usageReason: return "What brings you to SpendSmart?"
        case .spendingGoals: return "Pick your goals"
        case .budgetRange: return "What's your typical monthly spending?"
        case .categories: return "Which categories matter most?"
        case .currency: return "Select your currency"
        case .personalization: return "Personalizing for you..."
        case .completion: return "You're all set!"
        }
    }
    
    var subtitle: String? {
        switch self {
        case .welcome: return "Track spending, achieve goals, build better habits"
        case .appearance: return "System, Light, or Dark"
        case .discovery: return "We use this to improve marketing"
        case .usageReason: return "This helps us tailor recommendations"
        case .spendingGoals: return "Select all that apply"
        case .budgetRange: return "Used to set default budgets"
        case .categories: return "Choose up to 4 categories"
        case .currency: return "Choose the currency you use most often"
        case .personalization: return "We're setting up your personalized experience"
        case .completion: return "Your personalized spending insights await"
        }
    }
    
    var gradientStep: OnboardingGradientStep {
        switch self {
        case .welcome: return .welcome
        case .appearance, .discovery, .usageReason, .spendingGoals, .budgetRange, .categories: return .preferences
        case .currency: return .currency
        case .personalization, .completion: return .completion
        }
    }
    
    static var totalSteps: Int {
        return OnboardingStep.allCases.count
    }
}

// MARK: - Referral Source
enum ReferralSource: String, CaseIterable, Codable {
    case appStore = "App Store"
    case friend = "Friend / Word of Mouth"
    case social = "Social Media"
    case reddit = "Reddit"
    case productHunt = "Product Hunt / Hacker News"
    case other = "Other"

    var displayName: String { rawValue }

    var icon: String {
        switch self {
        case .appStore: return "app.badge"
        case .friend: return "person.2.fill"
        case .social: return "bubble.left.and.bubble.right.fill"
        case .reddit: return "r.circle"
        case .productHunt: return "globe"
        case .other: return "ellipsis.circle"
        }
    }
}

// MARK: - Onboarding State Manager
@MainActor
class OnboardingState: ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentStep: OnboardingStep = .welcome
    // Simplified onboarding selections + restored fields to match Supabase columns
    @Published var appearanceSelection: AppState.Appearance = .system
    @Published var referralSource: ReferralSource? = nil
    @Published var currencyPreference: String = CurrencyManager.shared.preferredCurrency
    @Published var appUsageReason: AppUsageReason? = nil
    @Published var budgetRange: BudgetRange? = nil
    @Published var selectedCategories: Set<ExpenseCategory> = []
    @Published var selectedSpendingGoals: Set<SpendingGoal> = []
    
    // UI State
    @Published var isProcessing = false
    @Published var personalizationProgress: Double = 0.0
    @Published var showError = false
    @Published var errorMessage = ""
    
    // MARK: - Computed Properties
    var canProceed: Bool {
        switch currentStep {
        case .welcome: return true
        case .appearance: return true
        case .discovery: return referralSource != nil
        case .usageReason: return appUsageReason != nil
        case .spendingGoals: return !selectedSpendingGoals.isEmpty
        case .budgetRange: return budgetRange != nil
        case .categories: return selectedCategories.count >= 1 && selectedCategories.count <= 4
        case .currency: return !currencyPreference.isEmpty
        case .personalization: return true
        case .completion: return true
        }
    }
    
    var progressPercentage: Double {
        Double(currentStep.rawValue) / Double(OnboardingStep.totalSteps - 1)
    }
    
    // MARK: - Navigation Methods
    func nextStep() {
        guard canProceed else { return }
        
        if let nextStep = OnboardingStep(rawValue: currentStep.rawValue + 1) {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep = nextStep
            }
            
            // Start personalization process
            if currentStep == .personalization {
                Task {
                    await processPersonalization()
                }
            }
        }
    }
    
    func previousStep() {
        if let previousStep = OnboardingStep(rawValue: currentStep.rawValue - 1) {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep = previousStep
            }
        }
    }
    
    // MARK: - Selection Methods
    func selectReferral(_ source: ReferralSource) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            referralSource = source
        }
    }
    
    func selectUsageReason(_ reason: AppUsageReason) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            appUsageReason = reason
        }
    }
    
    func selectBudgetRange(_ range: BudgetRange) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            budgetRange = range
        }
    }
    
    func toggleCategory(_ category: ExpenseCategory) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if selectedCategories.contains(category) {
                selectedCategories.remove(category)
            } else if selectedCategories.count < 4 {
                selectedCategories.insert(category)
            }
        }
    }
    
    func toggleSpendingGoal(_ goal: SpendingGoal) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if selectedSpendingGoals.contains(goal) {
                selectedSpendingGoals.remove(goal)
            } else {
                selectedSpendingGoals.insert(goal)
            }
        }
    }
    
    // MARK: - Personalization Process
    private func processPersonalization() async {
        isProcessing = true
        personalizationProgress = 0.0
        
        // Simulate personalization with progress updates (slower and smoother)
        let steps = 20
        for i in 1...steps {
            try? await Task.sleep(nanoseconds: 250_000_000) // 0.25 seconds
            
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.25)) {
                    personalizationProgress = Double(i) / Double(steps)
                }
            }
        }
        
        // Save to Supabase
        await saveOnboardingData()
        
        // Complete onboarding
        await MainActor.run {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isProcessing = false
                currentStep = .completion
            }
        }
    }
    
    // MARK: - Supabase Integration
    private func saveOnboardingData() async {
        do {
            // Get current user
            guard let currentUser = await SupabaseManager.shared.getCurrentUser() else {
                showErrorMessage("Unable to save preferences: User not authenticated")
                return
            }
            
            // Check for existing onboarding row so we update instead of creating duplicates
            let existingId = try? await fetchExistingOnboardingId(for: currentUser.id)
            
            let onboardingData = OnboardingUserData(
                id: existingId.flatMap(UUID.init(uuidString:)) ?? UUID(),
                userId: currentUser.id,
                ageRange: nil,
                appUsageReason: appUsageReason,
                spendingGoals: Array(selectedSpendingGoals),
                monthlyBudgetRange: budgetRange,
                primaryCategories: Array(selectedCategories),
                currencyPreference: currencyPreference,
                themePreference: appearanceSelection.rawValue,
                referralSource: referralSource?.rawValue,
                completedAt: Date(),
                createdAt: Date()
            )
            
            // Save to Supabase via backend API or direct client
            try await saveToSupabase(onboardingData)
            
            // Save currency preference locally
            CurrencyManager.shared.preferredCurrency = currencyPreference
            
            // Mark onboarding as complete
            UserDefaults.standard.set(true, forKey: "isOnboardingComplete")
            
        } catch {
            showErrorMessage("Failed to save preferences: \(error.localizedDescription)")
        }
    }
    
    private func fetchExistingOnboardingId(for userId: String) async throws -> String? {
        let supabase = SupabaseManager.shared.supabaseClient
        struct RowId: Decodable { let id: String }
        let rows: [RowId] = try await supabase
            .from("user_onboarding")
            .select("id")
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value
        return rows.first?.id
    }

    private func saveToSupabase(_ data: OnboardingUserData) async throws {
        // Get current user session to ensure we have authentication
        _ = await SupabaseManager.shared.getCurrentUser()
        
        // Create encodable data structure
        struct OnboardingInsert: Encodable {
            let id: String
            let user_id: String
            let age_range: String?
            let app_usage_reason: String?
            let spending_goals: [String]
            let monthly_budget_range: String?
            let primary_categories: [String]
            let currency_preference: String?
            let theme_preference: String?
            let referral_source: String?
            let completed_at: String
            let created_at: String
        }
        
        let insertData = OnboardingInsert(
            id: data.id.uuidString,
            user_id: data.userId,
            age_range: data.ageRange?.rawValue,
            app_usage_reason: data.appUsageReason?.rawValue,
            spending_goals: data.spendingGoals.map(\.rawValue),
            monthly_budget_range: data.monthlyBudgetRange?.rawValue,
            primary_categories: data.primaryCategories.map(\.rawValue),
            currency_preference: data.currencyPreference,
            theme_preference: data.themePreference,
            referral_source: data.referralSource,
            completed_at: ISO8601DateFormatter().string(from: data.completedAt ?? Date()),
            created_at: ISO8601DateFormatter().string(from: data.createdAt)
        )
        
        // Save to Supabase user_onboarding table and replace existing by user_id
        let supabase = SupabaseManager.shared.supabaseClient
        do {
            try await supabase
                .from("user_onboarding")
                .upsert(insertData, onConflict: "user_id")
                .execute()
        } catch {
            // Fallback: retry without new columns if migration not applied yet
            let errorMsg = String(describing: error)
            if errorMsg.contains("column \"theme_preference\"") || errorMsg.contains("column \"referral_source\"") || errorMsg.contains("does not exist") {
                struct OnboardingInsertLegacy: Encodable {
                    let id: String
                    let user_id: String
                    let age_range: String?
                    let app_usage_reason: String?
                    let spending_goals: [String]
                    let monthly_budget_range: String?
                    let primary_categories: [String]
                    let currency_preference: String?
                    let completed_at: String
                    let created_at: String
                }
                let legacy = OnboardingInsertLegacy(
                    id: insertData.id,
                    user_id: insertData.user_id,
                    age_range: insertData.age_range,
                    app_usage_reason: insertData.app_usage_reason,
                    spending_goals: insertData.spending_goals,
                    monthly_budget_range: insertData.monthly_budget_range,
                    primary_categories: insertData.primary_categories,
                    currency_preference: insertData.currency_preference,
                    completed_at: insertData.completed_at,
                    created_at: insertData.created_at
                )
                try await supabase
                    .from("user_onboarding")
                    .upsert(legacy, onConflict: "user_id")
                    .execute()
                print("ℹ️ [OnboardingState] Saved without theme/referral (migration pending)")
            } else {
                throw error
            }
        }
        
        print("✅ [OnboardingState] Successfully saved onboarding data to Supabase for user: \(data.userId)")
        print("📊 [OnboardingState] Age: \(data.ageRange?.displayName ?? "None")")
        print("🎯 [OnboardingState] Reason: \(data.appUsageReason?.displayName ?? "None")")
        print("💰 [OnboardingState] Budget: \(data.monthlyBudgetRange?.displayName ?? "None")")
        print("📋 [OnboardingState] Categories: \(data.primaryCategories.map(\.displayName))")
        print("💱 [OnboardingState] Currency: \(data.currencyPreference ?? "None")")
        print("🎨 [OnboardingState] Theme: \(data.themePreference ?? "system")")
        print("📣 [OnboardingState] Referral: \(data.referralSource ?? "None")")
        
        // Also store locally as backup
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let encoded = try? encoder.encode(data) {
            UserDefaults.standard.set(encoded, forKey: "onboardingData_\(data.userId)")
        }
    }
    
    @MainActor
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
    
    // MARK: - Completion Methods
    func completeOnboarding() async {
        // Final save and navigation
        await saveOnboardingData()
        
        // Update app state
        await MainActor.run {
            NotificationCenter.default.post(name: .onboardingCompleted, object: nil)
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let onboardingCompleted = Notification.Name("onboardingCompleted")
}

// MARK: - UserDefaults Extension
extension UserDefaults {
    var onboardingData: OnboardingUserData? {
        get {
            guard let data = data(forKey: "onboardingData") else { return nil }
            return try? JSONDecoder().decode(OnboardingUserData.self, from: data)
        }
        set {
            if let newValue = newValue {
                let encoder = JSONEncoder()
                if let encoded = try? encoder.encode(newValue) {
                    set(encoded, forKey: "onboardingData")
                }
            } else {
                removeObject(forKey: "onboardingData")
            }
        }
    }
}
