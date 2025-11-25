//
//  AppState.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-03-18.
//

import SwiftUI

class AppState: ObservableObject {
    // UserDefaults keys
    private let isGuestUserKey = "isGuestUser"
    private let guestUserIdKey = "guestUserId"
    private let isOnboardingCompleteKey = "isOnboardingComplete"
    private let isFirstLoginKey = "isFirstLogin"
    private let lastVersionCheckKey = "lastVersionCheck"
    private let skippedVersionKey = "skippedVersion"
    private let remindLaterDateKey = "remindLaterDate"
    private let lastAvailableVersionKey = "lastAvailableVersion"
    private let lastReleaseNotesKey = "lastReleaseNotes"
    private let lastActiveDateKey = "lastActiveDate"
    private let appearanceSelectionKey = "appearanceSelection"
    private let usePlainReceiptColorsKey = "usePlainReceiptColors"
    private let isHapticsEnabledKey = "isHapticsEnabled"

    @Published var isLoggedIn: Bool = false
    @Published var userEmail: String = ""
    @Published var isGuestUser: Bool = false {
        didSet {
            UserDefaults.standard.set(isGuestUser, forKey: isGuestUserKey)
        }
    }
    @Published var useLocalStorage: Bool = false
    @Published var guestUserId: UUID? = nil {
        didSet {
            if let userId = guestUserId {
                UserDefaults.standard.set(userId.uuidString, forKey: guestUserIdKey)
            } else {
                UserDefaults.standard.removeObject(forKey: guestUserIdKey)
            }
        }
    }

    // Onboarding state
    @Published var isOnboardingComplete: Bool = false {
        didSet {
            UserDefaults.standard.set(isOnboardingComplete, forKey: isOnboardingCompleteKey)
        }
    }

    // First login flag to show onboarding only after account creation
    @Published var isFirstLogin: Bool = false {
        didSet {
            UserDefaults.standard.set(isFirstLogin, forKey: isFirstLoginKey)
        }
    }

    // Version update state
    @Published var showVersionUpdateAlert: Bool = false
    @Published var availableVersion: String = ""
    @Published var releaseNotes: String = ""
    @Published var isCheckingForUpdates: Bool = false
    @Published var isForceUpdateRequired: Bool = false

    // Appearance
    enum Appearance: String, CaseIterable, Identifiable, Codable { case system, light, dark; var id: String { rawValue } }
    @Published var appearanceSelection: Appearance = .system {
        didSet {
            UserDefaults.standard.set(appearanceSelection.rawValue, forKey: appearanceSelectionKey)
        }
    }
    // History cards color style
    @Published var usePlainReceiptColors: Bool = false {
        didSet {
            UserDefaults.standard.set(usePlainReceiptColors, forKey: usePlainReceiptColorsKey)
        }
    }

    // Haptics
    @Published var isHapticsEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isHapticsEnabled, forKey: isHapticsEnabledKey)
        }
    }

    // Subscriptions sync toggle (local-only by default; can expand to cloud later)
    @Published var syncSubscriptionsWithCloud: Bool = false

    // MARK: - Premium State
    // Premium subscription status and receipt usage tracking
    @Published var isPremium: Bool = false
    @Published var premiumEntitlement: PremiumEntitlement?
    @Published var receiptUsage: ReceiptUsage?

    /// Whether the user can add a new receipt (premium OR under weekly limit)
    var canAddReceipt: Bool {
        isPremium || (receiptUsage?.remainingReceipts ?? 0) > 0
    }

    /// Whether to show the paywall (free tier and limit reached)
    var shouldShowPaywall: Bool {
        !isPremium && (receiptUsage?.isLimitReached ?? false)
    }

    init() {
        // Load onboarding state
        self.isOnboardingComplete = UserDefaults.standard.bool(forKey: isOnboardingCompleteKey)
        self.isFirstLogin = UserDefaults.standard.bool(forKey: isFirstLoginKey)

        // Comprehensive session restoration
        print("🔄 [AppState] Starting session restoration...")
        
        // Debug: Check what's stored in UserDefaults
        let storedEmail = UserDefaults.standard.string(forKey: "backend_user_email")
        let storedToken = UserDefaults.standard.string(forKey: "backend_auth_token")
        print("🔍 [AppState] Stored email: \(storedEmail ?? "nil")")
        print("🔍 [AppState] Stored token: \(storedToken?.prefix(10) ?? "nil")")
        print("🔍 [AppState] BackendAPIService.isAuthenticated(): \(BackendAPIService.shared.isAuthenticated())")
        
        // 1. Check for guest mode from UserDefaults first
        if UserDefaults.standard.bool(forKey: isGuestUserKey) {
            if let userIdString = UserDefaults.standard.string(forKey: guestUserIdKey),
               let userId = UUID(uuidString: userIdString) {
                print("✅ [AppState] Restoring guest mode from UserDefaults with ID: \(userId)")
                self.isLoggedIn = true
                self.isGuestUser = true
                self.useLocalStorage = true
                self.userEmail = "Guest User"
                self.guestUserId = userId
            }
        }
        // 2. Check for backend API session (new authentication method)
        else if BackendAPIService.shared.isAuthenticated() {
            print("✅ [AppState] Restoring backend API session")
            
            // Fetch actual user email from Supabase
            Task { @MainActor in
                if let currentUser = await SupabaseManager.shared.getCurrentUser() {
                    self.userEmail = currentUser.email ?? "Apple ID User"
                    print("✅ [AppState] Retrieved email from Supabase: \(self.userEmail)")
                } else {
                    // Fallback to stored email
                    let userEmail = UserDefaults.standard.string(forKey: "backend_user_email") ?? "Apple ID User"
                    self.userEmail = userEmail
                    print("✅ [AppState] Using stored email: \(userEmail)")
                }
            }
            
            self.isLoggedIn = true
            self.isGuestUser = false
            self.useLocalStorage = false
            print("✅ [AppState] Restored backend session")
        }
        // 3. Check if we have stored backend session data even if not currently authenticated
        else if let storedEmail = UserDefaults.standard.string(forKey: "backend_user_email"),
                let storedToken = UserDefaults.standard.string(forKey: "backend_auth_token"),
                !storedToken.isEmpty {
            print("✅ [AppState] Restoring backend API session from stored data")
            
            // Fetch actual user email from Supabase
            Task { @MainActor in
                if let currentUser = await SupabaseManager.shared.getCurrentUser() {
                    self.userEmail = currentUser.email ?? "Apple ID User"
                    print("✅ [AppState] Retrieved email from Supabase: \(self.userEmail)")
                } else {
                    // Fallback to stored email
                    self.userEmail = storedEmail
                    print("✅ [AppState] Using stored email: \(storedEmail)")
                }
            }
            
            self.isLoggedIn = true
            self.isGuestUser = false
            self.useLocalStorage = false
            print("✅ [AppState] Restored backend session from stored data")
        }
        // 4. Fallback to Supabase session check (for backward compatibility)
        else {
            Task { @MainActor in
                if let user = await getCurrentSupabaseUser() {
                    print("✅ [AppState] Restoring Supabase session")
                    
                    // Sync the BackendAPIService authentication token
                    await BackendAPIService.shared.syncAuthTokenFromSupabase()
                    
                    // Check if this is a guest user by looking at the email
                    let isGuest = user.email?.contains("guest") ?? false
                    
                    if isGuest {
                        // Restore guest mode from Supabase
                        if let userId = UUID(uuidString: user.id) {
                            self.enableGuestMode(userId: userId)
                        } else {
                            self.enableGuestMode()
                        }
                        print("✅ [AppState] Restored guest session from Supabase for user: \(user.id)")
                    } else {
                        // Regular user - use actual email from Supabase
                        self.userEmail = user.email ?? "Apple ID User"
                        self.isLoggedIn = true
                        self.isGuestUser = false
                        self.useLocalStorage = false
                        print("✅ [AppState] Restored regular user session for: \(user.email ?? "Apple ID User")")
                    }
                } else {
                    print("🔍 [AppState] No existing session found")
                }
            }
        }
        
        // Restore version update state if available
        if let storedVersion = UserDefaults.standard.string(forKey: lastAvailableVersionKey),
           let storedNotes = UserDefaults.standard.string(forKey: lastReleaseNotesKey) {
            self.availableVersion = storedVersion
            self.releaseNotes = storedNotes
            self.isForceUpdateRequired = UserDefaults.standard.bool(forKey: "isForceUpdateRequired")
        }

        // Restore appearance and receipt color preferences
        if let appearanceRaw = UserDefaults.standard.string(forKey: appearanceSelectionKey),
           let appearance = Appearance(rawValue: appearanceRaw) {
            self.appearanceSelection = appearance
        }
        self.usePlainReceiptColors = UserDefaults.standard.bool(forKey: usePlainReceiptColorsKey)

        // Restore haptics preference (default: enabled)
        if UserDefaults.standard.object(forKey: isHapticsEnabledKey) != nil {
            self.isHapticsEnabled = UserDefaults.standard.bool(forKey: isHapticsEnabledKey)
        } else {
            UserDefaults.standard.set(true, forKey: isHapticsEnabledKey)
            self.isHapticsEnabled = true
        }

        // MARK: - Premium Status Initialization
        // Sync premium status and receipt usage on app launch
        Task { @MainActor in
            // Only sync if user is logged in (not for logged out state)
            guard self.isLoggedIn else {
                print("ℹ️ [AppState] User not logged in, skipping premium sync")
                return
            }

            print("🔄 [AppState] Syncing premium status on app launch...")
            await self.syncPremiumStatus()
            await self.refreshReceiptUsage()
        }
    }
    
    // Helper method to get current Supabase user asynchronously
    private func getCurrentSupabaseUser() async -> CustomUser? {
        return await SupabaseManager.shared.getCurrentUser()
    }

    // Reset app state
    func resetState() {
        print("🔄 [AppState] Resetting app state - logging out user")
        print("👤 [AppState] Previous state - logged in: \(isLoggedIn), guest: \(isGuestUser), email: \(userEmail)")
        
        isLoggedIn = false
        userEmail = ""
        isGuestUser = false
        useLocalStorage = false
        guestUserId = nil

        // Reset onboarding state if needed
        // Note: We typically don't reset isOnboardingComplete as we don't want
        // to show onboarding again for existing users
        isFirstLogin = false

        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: isGuestUserKey)
        UserDefaults.standard.removeObject(forKey: guestUserIdKey)
        UserDefaults.standard.removeObject(forKey: isFirstLoginKey)
        
        // Clear backend API session data
        UserDefaults.standard.removeObject(forKey: "backend_auth_token")
        UserDefaults.standard.removeObject(forKey: "backend_user_email")

        // Reset version update state
        showVersionUpdateAlert = false
        availableVersion = ""
        releaseNotes = ""
        
        print("✅ [AppState] App state reset complete")
        isCheckingForUpdates = false
        isForceUpdateRequired = false
        
        // Clear stored version info
        UserDefaults.standard.removeObject(forKey: lastAvailableVersionKey)
        UserDefaults.standard.removeObject(forKey: lastReleaseNotesKey)
        UserDefaults.standard.removeObject(forKey: lastActiveDateKey)
        UserDefaults.standard.removeObject(forKey: "isForceUpdateRequired")
    }

    // Set up guest mode
    func enableGuestMode(userId: UUID? = nil) {
        isLoggedIn = true
        isGuestUser = true
        useLocalStorage = true
        userEmail = "Guest User"
        guestUserId = userId

        // Note: We don't set isFirstLogin here because it's managed by the caller
        // This allows us to distinguish between restored sessions and new guest accounts

        print("✅ Guest mode enabled with ID: \(userId?.uuidString ?? "none")")
    }

    // Version update helper methods
    func getLastVersionCheckDate() -> Date? {
        return UserDefaults.standard.object(forKey: lastVersionCheckKey) as? Date
    }

    func setLastVersionCheckDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: lastVersionCheckKey)
    }

    func getSkippedVersion() -> String? {
        return UserDefaults.standard.string(forKey: skippedVersionKey)
    }

    func setSkippedVersion(_ version: String) {
        UserDefaults.standard.set(version, forKey: skippedVersionKey)
    }

    func getRemindLaterDate() -> Date? {
        return UserDefaults.standard.object(forKey: remindLaterDateKey) as? Date
    }

    func setRemindLaterDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: remindLaterDateKey)
    }

    func clearRemindLater() {
        UserDefaults.standard.removeObject(forKey: remindLaterDateKey)
    }
    
    // New version update helper methods
    func shouldCheckForUpdates() -> Bool {
        // Check if we've been in background for more than 30 minutes
        if let lastActiveDate = UserDefaults.standard.object(forKey: lastActiveDateKey) as? Date {
            let timeInBackground = Date().timeIntervalSince(lastActiveDate)
            return timeInBackground > 30 * 60 // 30 minutes
        }
        return false
    }
    
    func updateLastActiveDate() {
        UserDefaults.standard.set(Date(), forKey: lastActiveDateKey)
    }
    
    func storeVersionInfo(version: String, notes: String) {
        UserDefaults.standard.set(version, forKey: lastAvailableVersionKey)
        UserDefaults.standard.set(notes, forKey: lastReleaseNotesKey)
        self.availableVersion = version
        self.releaseNotes = notes
    }
    
    func clearStoredVersionInfo() {
        UserDefaults.standard.removeObject(forKey: lastAvailableVersionKey)
        UserDefaults.standard.removeObject(forKey: lastReleaseNotesKey)
        UserDefaults.standard.removeObject(forKey: "isForceUpdateRequired")
        self.availableVersion = ""
        self.releaseNotes = ""
        self.isForceUpdateRequired = false
    }

    // MARK: - Premium Methods

    /// Sync premium status from backend
    /// Call this on app launch and after successful purchase
    @MainActor
    func syncPremiumStatus() async {
        do {
            let entitlement = try await BackendAPIService.shared.getPremiumStatus()
            self.isPremium = entitlement.isActive
            self.premiumEntitlement = entitlement

            print("✅ [AppState] Premium status synced: \(isPremium ? "Premium" : "Free")")

            if let planType = entitlement.planType {
                print("📊 [AppState] Plan: \(planType)")
            }
        } catch {
            print("❌ [AppState] Failed to sync premium status: \(error.localizedDescription)")
            // On error, default to free tier (safe fallback)
            self.isPremium = false
            self.premiumEntitlement = nil
        }
    }

    /// Refresh receipt usage stats from backend
    /// Call this on app launch and after adding receipts
    @MainActor
    func refreshReceiptUsage() async {
        // Skip for premium users (no limits)
        if isPremium {
            self.receiptUsage = nil
            return
        }

        do {
            let usage = try await BackendAPIService.shared.getReceiptUsage()
            self.receiptUsage = usage

            print("📊 [AppState] Receipt usage: \(usage.receiptsThisWeek)/5 this week")

            // Show warning when approaching limit
            if usage.receiptsThisWeek == 4 {
                print("⚠️ [AppState] User approaching weekly limit (4/5)")
                HapticFeedbackManager.shared.warning()
            }
        } catch {
            print("❌ [AppState] Failed to refresh receipt usage: \(error.localizedDescription)")
            // On error, assume no usage data available
            self.receiptUsage = nil
        }
    }

    /// Mark that a receipt was added
    /// Call this AFTER successfully saving a receipt
    @MainActor
    func markReceiptAdded() async {
        // Skip for premium users (no tracking needed)
        guard !isPremium else {
            print("ℹ️ [AppState] Premium user - no receipt tracking needed")
            return
        }

        do {
            let usage = try await BackendAPIService.shared.incrementReceiptCount()
            self.receiptUsage = usage

            print("📈 [AppState] Receipt count incremented: \(usage.receiptsThisWeek)/5")

            // Show warning at 4 receipts
            if usage.receiptsThisWeek == 4 {
                print("⚠️ [AppState] User has 1 receipt remaining this week")
                HapticFeedbackManager.shared.warning()
            }

            // Show limit reached haptic at 5
            if usage.receiptsThisWeek >= 5 {
                print("🚫 [AppState] User has reached weekly limit")
                HapticFeedbackManager.shared.error()
            }
        } catch {
            print("❌ [AppState] Failed to increment receipt count: \(error.localizedDescription)")
        }
    }
}

