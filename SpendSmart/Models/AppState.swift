import Combine
import Supabase
import SwiftUI

class AppState: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var userEmail: String = ""
    @Published var isGuestUser: Bool = false

    @Published var isOnboardingComplete: Bool = false
    @Published var pendingDisplayName: String? = nil
    @Published var shouldLaunchScanner: Bool = false
    @Published var pendingShareImagePath: String? = nil
    @AppStorage("usePlainReceiptColors") var usePlainReceiptColors: Bool = false
    @AppStorage("isHapticsEnabled") var isHapticsEnabled: Bool = true
    @Published var isBootstrapping: Bool = true

    @Published var showVersionUpdateAlert: Bool = false
    @Published var availableVersion: String = ""
    @Published var releaseNotes: String = ""
    @Published var isCheckingForUpdates: Bool = false
    @Published var isForceUpdateRequired: Bool = false
    
    // MARK: - Subscription State
    @Published var showPaywall: Bool = false
    
    // MARK: - Prefetched Data
    /// Prefetched receipts for faster dashboard load
    @Published var prefetchedReceipts: [Receipt]?
    /// Indicates if prefetch is in progress
    @Published var isPrefetchingData: Bool = false

    enum Appearance: String, CaseIterable, Identifiable, Codable {
        case system, light, dark
        var id: String { rawValue }
    }

    @AppStorage("appearanceSelection") var appearanceSelection: Appearance = .system

    @Published var useLocalStorage: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private var currentUserId: UUID? = nil
    private var hasBootstrapped: Bool = false

    init() {
        setupAuthListener()
    }

    private func setupAuthListener() {
        SupabaseManager.shared.$session
            .receive(on: RunLoop.main)
            .sink { [weak self] session in
                guard let self = self else { return }

                if let session = session {
                    self.isLoggedIn = true
                    self.userEmail = session.user.email ?? "User"
                    self.isGuestUser = session.user.email?.contains("guest") ?? false
                    self.currentUserId = session.user.id
                    self.isOnboardingComplete = self.loadOnboardingComplete(for: session.user.id)
        } else {
            self.isLoggedIn = false
            self.userEmail = ""
            self.isGuestUser = false
            self.currentUserId = nil
            self.isOnboardingComplete = false
            self.pendingDisplayName = nil
            self.shouldLaunchScanner = false
        }

                if !self.hasBootstrapped {
                    self.hasBootstrapped = true
                    Task { await self.performInitialBootstrap(with: session) }
                } else {
                    Task { await self.refreshSubscriptionStatus(for: session) }
                }
            }
            .store(in: &cancellables)
    }

    @MainActor
    private func performInitialBootstrap(with session: Auth.Session?) async {
        // Start subscription refresh and data prefetch in parallel for faster perceived loading
        async let subscriptionTask: () = refreshSubscriptionStatus(for: session)
        async let prefetchTask: () = prefetchDashboardData(for: session)
        async let versionTask = VersionUpdateManager.shared.checkForUpdates()
        
        // Await all parallel tasks
        await subscriptionTask
        await prefetchTask
        _ = await versionTask
        
        // Minimum splash duration for smooth UX
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        isBootstrapping = false
    }
    
    // MARK: - Data Prefetching
    
    /// Prefetches dashboard data during bootstrap for faster initial load
    @MainActor
    private func prefetchDashboardData(for session: Auth.Session?) async {
        guard session != nil else {
            prefetchedReceipts = nil
            return
        }
        
        isPrefetchingData = true
        defer { isPrefetchingData = false }
        
        do {
            // Prefetch first page of receipts (most common dashboard view)
            let receipts = try await SupabaseManager.shared.fetchReceipts(page: 1, limit: 20)
            prefetchedReceipts = receipts
            
            // Also ensure profile is loaded
            await SupabaseManager.shared.refreshProfile()
        } catch {
            // Prefetch failure is non-critical, dashboard will fetch on demand
            print("Prefetch failed (non-critical): \(error.localizedDescription)")
            prefetchedReceipts = nil
        }
    }
    
    /// Clears prefetched data (call when data changes)
    func invalidatePrefetchedData() {
        prefetchedReceipts = nil
    }

    @MainActor
    private func refreshSubscriptionStatus(for session: Auth.Session?) async {
        guard let session else {
            let freeStatus = SubscriptionStatusPayload(
                isSubscribed: false,
                subscriptionTier: "free",
                subscriptionExpiresAt: nil,
                hasCloudAccess: false
            )
            SubscriptionManager.shared.applyServerStatus(freeStatus)
            return
        }

        await SubscriptionManager.shared.identifyUser(userId: session.user.id.uuidString)
        await SubscriptionManager.shared.refreshSubscriptionStatusFromServer()
    }

    func markOnboardingComplete() {
        guard let userId = currentUserId else { return }
        saveOnboardingComplete(true, for: userId)
        isOnboardingComplete = true
        pendingDisplayName = nil
    }

    func queueFirstScanLaunch() {
        shouldLaunchScanner = true
    }

    func handleIncomingShareImage() {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.spendsmart.shared") else { return }

        guard let imagePath = sharedDefaults.string(forKey: "pendingShareImagePath"),
              let timestamp = sharedDefaults.object(forKey: "pendingShareTimestamp") as? Double else { return }

        let shareDate = Date(timeIntervalSince1970: timestamp)
        guard Date().timeIntervalSince(shareDate) < 60 else {
            sharedDefaults.removeObject(forKey: "pendingShareImagePath")
            sharedDefaults.removeObject(forKey: "pendingShareTimestamp")
            return
        }

        if FileManager.default.fileExists(atPath: imagePath) {
            pendingShareImagePath = imagePath
            shouldLaunchScanner = true
        }

        sharedDefaults.removeObject(forKey: "pendingShareImagePath")
        sharedDefaults.removeObject(forKey: "pendingShareTimestamp")
    }

    func clearOnboardingStateForCurrentUser() {
        guard let userId = currentUserId else { return }
        UserDefaults.standard.removeObject(forKey: onboardingKey(for: userId))
        isOnboardingComplete = false
    }

    func resetState() {
        Task {
            try? await SupabaseManager.shared.signOut()
        }
    }

    func shouldCheckForUpdates() -> Bool {
        if let lastActiveDate = UserDefaults.standard.object(forKey: "lastActiveDate") as? Date {
            return Date().timeIntervalSince(lastActiveDate) > 1800
        }
        return false
    }

    func updateLastActiveDate() {
        UserDefaults.standard.set(Date(), forKey: "lastActiveDate")
    }

    private func onboardingKey(for userId: UUID) -> String {
        "onboarding_complete_\(userId.uuidString)"
    }

    private func loadOnboardingComplete(for userId: UUID) -> Bool {
        let key = onboardingKey(for: userId)
        let defaults = UserDefaults.standard

        if defaults.object(forKey: key) != nil {
            return defaults.bool(forKey: key)
        }

        // Migration: older versions stored a single global onboarding flag.
        if defaults.bool(forKey: "isOnboardingComplete") {
            saveOnboardingComplete(true, for: userId)
            defaults.removeObject(forKey: "isOnboardingComplete")
            return true
        }

        return false
    }

    private func saveOnboardingComplete(_ value: Bool, for userId: UUID) {
        UserDefaults.standard.set(value, forKey: onboardingKey(for: userId))
    }
}
