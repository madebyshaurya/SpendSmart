import SwiftUI

@main
struct SpendSmartApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var versionUpdateManager = VersionUpdateManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasChecked = false

    init() {
        // Initialize RevenueCat
        SubscriptionManager.shared.configure()
        // Load persisted insights on launch
        InsightsEngine.shared.load()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(subscriptionManager)
                .preferredColorScheme(.light)
                .tint(.blue)
                .onOpenURL { url in
                    if url.scheme == "spendsmart" && url.host == "share" {
                        appState.handleIncomingShareImage()
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        if !hasChecked || shouldCheck() { Task { await check() } }
                    } else if phase == .background {
                        UserDefaults.standard.set(Date(), forKey: "lastActiveDate")
                    }
                }
                .sheet(isPresented: $subscriptionManager.showPaywall) {
                    PaywallView(trigger: subscriptionManager.paywallTrigger)
                }
        }
    }
    
    private func shouldCheck() -> Bool {
        guard let last = UserDefaults.standard.object(forKey: "lastActiveDate") as? Date else { return true }
        return Date().timeIntervalSince(last) > 1800
    }

    @MainActor
    private func check() async {
        UserDefaults.standard.set(Date(), forKey: "lastActiveDate")
        let res = await versionUpdateManager.checkForUpdates()
        hasChecked = true
        switch res {
        case .updateAvailable(let info), .forcedUpdateRequired(let info):
            appState.availableVersion = info.latestVersion
            appState.releaseNotes = info.releaseNotes ?? ""
            appState.showVersionUpdateAlert = true
            appState.isForceUpdateRequired = info.isForced
            UserDefaults.standard.set(info.latestVersion, forKey: "lastAvailableVersion")
            if let n = info.releaseNotes { UserDefaults.standard.set(n, forKey: "lastReleaseNotes") }
            if info.isForced { UserDefaults.standard.set(true, forKey: "isForceUpdateRequired") }
        case .upToDate:
            ["lastAvailableVersion", "lastReleaseNotes", "isForceUpdateRequired"].forEach { UserDefaults.standard.removeObject(forKey: $0) }
            appState.isForceUpdateRequired = false
        case .error:
            if let v = UserDefaults.standard.string(forKey: "lastAvailableVersion"), let n = UserDefaults.standard.string(forKey: "lastReleaseNotes") {
                appState.availableVersion = v
                appState.releaseNotes = n
                appState.showVersionUpdateAlert = true
                appState.isForceUpdateRequired = UserDefaults.standard.bool(forKey: "isForceUpdateRequired")
            }
        default: break
        }
    }
}
