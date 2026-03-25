//
//  SubscriptionManager.swift
//  SpendSmart
//
//  Created by Claude on 2026-01-18.
//
//  Manages subscription state, scan limits, and RevenueCat integration.
//  Free tier: 5 scans per week. Pro tier: Unlimited scans.
//

import Foundation
import RevenueCat
import Combine

// MARK: - Subscription Tier

enum SubscriptionTier: String, Codable {
    case free = "free"
    case plus = "plus"
    
    var displayName: String {
        switch self {
        case .free: return "Free"
        case .plus: return "Plus"
        }
    }
    
    var weeklyScansLimit: Int? {
        switch self {
        case .free: return 5
        case .plus: return nil // Unlimited
        }
    }
    
    var hasUnlimitedScans: Bool {
        return weeklyScansLimit == nil
    }
    
    /// Free users can only read existing cloud receipts, not write new ones
    var hasCloudWriteAccess: Bool {
        switch self {
        case .free: return false
        case .plus: return true
        }
    }
}

// MARK: - Subscription Status

struct SubscriptionStatus {
    let tier: SubscriptionTier
    let isActive: Bool
    let expirationDate: Date?
    let willRenew: Bool
    let productIdentifier: String?
    
    static let free = SubscriptionStatus(
        tier: .free,
        isActive: false,
        expirationDate: nil,
        willRenew: false,
        productIdentifier: nil
    )
}

// MARK: - Scan Usage

struct ScanUsage: Codable {
    var scansThisWeek: Int
    var weekStartDate: Date
    
    static let empty = ScanUsage(scansThisWeek: 0, weekStartDate: Date())
    
    var isNewWeek: Bool {
        let calendar = Calendar.current
        let weekOfYear = calendar.component(.weekOfYear, from: Date())
        let storedWeek = calendar.component(.weekOfYear, from: weekStartDate)
        let yearOfDate = calendar.component(.year, from: Date())
        let storedYear = calendar.component(.year, from: weekStartDate)
        return weekOfYear != storedWeek || yearOfDate != storedYear
    }
}

// MARK: - Subscription Manager

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    // MARK: - Published Properties
    
    @Published private(set) var subscriptionStatus: SubscriptionStatus = .free
    @Published private(set) var scanUsage: ScanUsage = .empty
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var availablePackages: [Package] = []
    @Published private(set) var isServerAuthoritative: Bool = false
    @Published var showPaywall: Bool = false
    @Published var paywallTrigger: PaywallTrigger = .general
    
    // MARK: - Computed Properties
    
    /// True if user has Plus subscription
    var isPlus: Bool {
        subscriptionStatus.tier == .plus
    }
    
    /// True if user has unlimited scans (Plus subscribers)
    var hasUnlimitedScans: Bool {
        subscriptionStatus.tier.hasUnlimitedScans
    }
    
    /// True if user can write new receipts to cloud (Plus subscribers only)
    /// Free users can only READ existing cloud receipts
    var hasCloudWriteAccess: Bool {
        subscriptionStatus.tier.hasCloudWriteAccess
    }
    
    var scansRemaining: Int? {
        guard let limit = subscriptionStatus.tier.weeklyScansLimit else {
            return nil // Unlimited for Plus
        }
        return max(0, limit - scanUsage.scansThisWeek)
    }
    
    var canScan: Bool {
        if hasUnlimitedScans { return true }
        return (scansRemaining ?? 0) > 0
    }
    
    var scansUsedText: String {
        if hasUnlimitedScans {
            return "Unlimited scans"
        }
        let limit = subscriptionStatus.tier.weeklyScansLimit ?? 5
        return "\(scanUsage.scansThisWeek)/\(limit) scans this week"
    }
    
    // MARK: - Private Properties
    
    private let scanUsageKey = "com.spendsmart.scanUsage"
    private var cancellables = Set<AnyCancellable>()
    
    // RevenueCat Product Identifiers (matches App Store Connect)
    private let proMonthlyProductId = "spendsmart_plus_monthly"
    private let proYearlyProductId = "spendsmart_plus_annual"
    private let entitlementId = "plus"
    
    // MARK: - Initialization
    
    private init() {
        loadScanUsage()
        resetWeeklyScansIfNeeded()
    }
    
    // MARK: - RevenueCat Configuration
    
    func configure() {
        // Only configure if API key is set
        guard !RevenueCatConfig.apiKey.isEmpty,
              !RevenueCatConfig.apiKey.hasPrefix("YOUR_") else {
            print("RevenueCat API key not configured. Running in demo mode.")
            return
        }
        
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: RevenueCatConfig.apiKey)
        
        // Listen for customer info updates
        Purchases.shared.delegate = RevenueCatDelegate.shared
        
        // Fetch initial customer info
        Task {
            await refreshSubscriptionStatus()
            await fetchAvailablePackages()
        }
    }
    
    /// Link RevenueCat to a user ID (call after login)
    func identifyUser(userId: String) async {
        guard !RevenueCatConfig.apiKey.isEmpty,
              !RevenueCatConfig.apiKey.hasPrefix("YOUR_") else { return }
        
        do {
            let (customerInfo, _) = try await Purchases.shared.logIn(userId)
            updateSubscriptionStatus(from: customerInfo)
        } catch {
            print("Failed to identify user with RevenueCat: \(error.localizedDescription)")
        }
    }
    
    /// Sign out from RevenueCat (call on logout)
    func signOut() async {
        guard !RevenueCatConfig.apiKey.isEmpty,
              !RevenueCatConfig.apiKey.hasPrefix("YOUR_") else { return }
        
        do {
            let customerInfo = try await Purchases.shared.logOut()
            updateSubscriptionStatus(from: customerInfo)
        } catch {
            print("Failed to sign out from RevenueCat: \(error.localizedDescription)")
        }
        
        // Reset scan usage on sign out
        scanUsage = .empty
        saveScanUsage()
    }
    
    // MARK: - Subscription Status
    
    func refreshSubscriptionStatus() async {
        guard !isServerAuthoritative else { return }
        guard !RevenueCatConfig.apiKey.isEmpty,
              !RevenueCatConfig.apiKey.hasPrefix("YOUR_") else {
            // Demo mode - stay on free
            subscriptionStatus = .free
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            updateSubscriptionStatus(from: customerInfo)
        } catch {
            print("Failed to fetch subscription status: \(error.localizedDescription)")
            subscriptionStatus = .free
        }
    }
    
    private func updateSubscriptionStatus(from customerInfo: CustomerInfo) {
        guard !isServerAuthoritative else { return }
        if let entitlement = customerInfo.entitlements[entitlementId],
           entitlement.isActive {
            subscriptionStatus = SubscriptionStatus(
                tier: .plus,
                isActive: true,
                expirationDate: entitlement.expirationDate,
                willRenew: entitlement.willRenew,
                productIdentifier: entitlement.productIdentifier
            )
        } else {
            subscriptionStatus = .free
        }
    }

    func refreshSubscriptionStatusFromServer() async {
        do {
            let serverStatus = try await BackendAPIService.shared.fetchServerSubscriptionStatus()
            applyServerStatus(serverStatus)
        } catch {
            isServerAuthoritative = false
            await refreshSubscriptionStatus()
        }
    }

    func applyServerStatus(_ status: SubscriptionStatusPayload) {
        isServerAuthoritative = true
        let tierValue = (status.subscriptionTier ?? (status.isSubscribed ? "plus" : "free"))
            .lowercased()
        let tier: SubscriptionTier = tierValue == "plus" ? .plus : .free
        subscriptionStatus = SubscriptionStatus(
            tier: tier,
            isActive: status.isSubscribed,
            expirationDate: status.subscriptionExpiresAt,
            willRenew: status.isSubscribed,
            productIdentifier: nil
        )
    }
    
    // MARK: - Packages & Purchasing
    
    func fetchAvailablePackages() async {
        guard !RevenueCatConfig.apiKey.isEmpty,
              !RevenueCatConfig.apiKey.hasPrefix("YOUR_") else { return }
        
        do {
            let offerings = try await Purchases.shared.offerings()
            if let current = offerings.current {
                availablePackages = current.availablePackages
            }
        } catch {
            print("Failed to fetch packages: \(error.localizedDescription)")
        }
    }
    
    func purchase(package: Package) async throws -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result = try await Purchases.shared.purchase(package: package)
            
            if !result.userCancelled {
                updateSubscriptionStatus(from: result.customerInfo)
                return true
            }
            return false
        } catch {
            print("Purchase failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    func restorePurchases() async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            updateSubscriptionStatus(from: customerInfo)
        } catch {
            print("Restore failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Scan Usage Tracking
    
    func recordScan() {
        // Plus users don't need local tracking (they have unlimited)
        if hasUnlimitedScans { return }
        
        // Reset if new week
        resetWeeklyScansIfNeeded()
        
        scanUsage.scansThisWeek += 1
        saveScanUsage()
    }
    
    /// Check if user can scan; if not, trigger paywall
    func checkAndRecordScan() -> Bool {
        if canScan {
            recordScan()
            return true
        } else {
            paywallTrigger = .scanLimitReached
            showPaywall = true
            return false
        }
    }
    
    private func resetWeeklyScansIfNeeded() {
        if scanUsage.isNewWeek {
            scanUsage = ScanUsage(scansThisWeek: 0, weekStartDate: Date())
            saveScanUsage()
        }
    }
    
    private func loadScanUsage() {
        guard let data = UserDefaults.standard.data(forKey: scanUsageKey),
              let usage = try? JSONDecoder().decode(ScanUsage.self, from: data) else {
            scanUsage = .empty
            return
        }
        scanUsage = usage
    }
    
    private func saveScanUsage() {
        guard let data = try? JSONEncoder().encode(scanUsage) else { return }
        UserDefaults.standard.set(data, forKey: scanUsageKey)
    }

    func resetScanUsage() {
        scanUsage = .empty
        UserDefaults.standard.removeObject(forKey: scanUsageKey)
    }
    
    // MARK: - Paywall Helpers
    
    func presentPaywall(trigger: PaywallTrigger = .general) {
        paywallTrigger = trigger
        showPaywall = true
    }
}

// MARK: - Paywall Trigger

enum PaywallTrigger {
    case general
    case scanLimitReached
    case settingsUpgrade
    case featureLocked(String)
    
    var title: String {
        switch self {
        case .general:
            return "Unlock SpendSmart Plus"
        case .scanLimitReached:
            return "Weekly Limit Reached"
        case .settingsUpgrade:
            return "Upgrade to Plus"
        case .featureLocked(let feature):
            return "Unlock \(feature)"
        }
    }
    
    var subtitle: String {
        switch self {
        case .general:
            return "Scan unlimited receipts and access premium features"
        case .scanLimitReached:
            return "You've used all 5 free scans this week. Upgrade to continue scanning."
        case .settingsUpgrade:
            return "Get unlimited scans and premium features"
        case .featureLocked:
            return "This feature requires SpendSmart Plus"
        }
    }
}

// MARK: - RevenueCat Delegate

class RevenueCatDelegate: NSObject, PurchasesDelegate {
    static let shared = RevenueCatDelegate()
    
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            await SubscriptionManager.shared.refreshSubscriptionStatus()
        }
    }
}

// MARK: - RevenueCat Config

struct RevenueCatConfig {
    // Uses the key from APIKeys.swift
    static var apiKey: String {
        revenueCatAPIKey
    }
}

// MARK: - Package Extensions

extension Package {
    var pricePerMonth: String {
        switch packageType {
        case .monthly:
            return localizedPriceString
        case .annual:
            let monthly = storeProduct.price as Decimal / 12
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.locale = storeProduct.priceFormatter?.locale ?? Locale.current
            return formatter.string(from: monthly as NSDecimalNumber) ?? localizedPriceString
        default:
            return localizedPriceString
        }
    }
    
    var savingsPercentage: Int? {
        guard packageType == .annual else { return nil }
        // Assuming monthly is $2.99, yearly is $19.99 = ~44% savings
        return 44
    }
    
    var periodText: String {
        switch packageType {
        case .monthly:
            return "per month"
        case .annual:
            return "per year"
        case .weekly:
            return "per week"
        case .lifetime:
            return "one-time"
        default:
            return ""
        }
    }
}
