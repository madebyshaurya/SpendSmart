//
//  SpendSmartApp.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-03-12.
//

import SwiftUI

@main
struct SpendSmartApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var versionUpdateManager = VersionUpdateManager.shared
    @StateObject private var subscriptionService = SubscriptionService.shared

    // Add scene phase to track app state
    @Environment(\.scenePhase) private var scenePhase

    // Track if we've already checked for updates in this session
    @State private var hasCheckedForUpdates = false

    init() {
        // Print configuration on app startup
        print("🚀 [iOS] ===== SPENDMART APP STARTUP =====")
        print("🔧 [iOS] Environment: \(BackendConfig.shared.isDevelopment ? "Development" : "Production")")
        print("🔧 [iOS] Backend URL will be determined dynamically")
        print("🔑 [iOS] Secret Key configured: \(!secretKey.isEmpty)")
        print("📱 [iOS] App Bundle ID: \(Bundle.main.bundleIdentifier ?? "Unknown")")
        print("📱 [iOS] App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")")
        print("=======================================")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onAppear {
                    Task { await SubscriptionService.shared.requestNotificationPermission() }
                }
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    switch newPhase {
                    case .active:
                        // App became active (launch or from background)
                        print("🟢 [SpendSmartApp] App became active")
                        print("👤 [SpendSmartApp] User logged in: \(appState.isLoggedIn)")
                        print("💾 [SpendSmartApp] Using local storage: \(appState.useLocalStorage)")
                        // Only check for updates if we haven't already in this session
                        // or if we're coming back from background after a significant time
                        if !hasCheckedForUpdates || shouldCheckForUpdates() {
                            print("🔄 [SpendSmartApp] Checking for version updates")
                            Task {
                                await checkForVersionUpdate()
                            }
                        }
                    case .background:
                        // App went to background
                        print("🔴 [SpendSmartApp] App went to background")
                        UserDefaults.standard.set(Date(), forKey: "lastActiveDate")
                    case .inactive:
                        // App became inactive
                        print("🟡 [SpendSmartApp] App became inactive")
                    @unknown default:
                        break
                    }
                }
        }
    }
    
    private func shouldCheckForUpdates() -> Bool {
        // Check if we've been in background for more than 30 minutes
        if let lastActiveDate = UserDefaults.standard.object(forKey: "lastActiveDate") as? Date {
            let timeInBackground = Date().timeIntervalSince(lastActiveDate)
            return timeInBackground > 30 * 60 // 30 minutes
        }
        return false
    }

    @MainActor
    private func checkForVersionUpdate() async {
        print("🔄 Checking for version update...")
        
        // Update last active date
        UserDefaults.standard.set(Date(), forKey: "lastActiveDate")
        
        let result = await versionUpdateManager.checkForUpdates()
        hasCheckedForUpdates = true

        switch result {
        case .updateAvailable(let versionInfo):
            appState.availableVersion = versionInfo.latestVersion
            appState.releaseNotes = versionInfo.releaseNotes ?? ""
            appState.showVersionUpdateAlert = true
            UserDefaults.standard.set(versionInfo.latestVersion, forKey: "lastAvailableVersion")
            if let notes = versionInfo.releaseNotes {
                UserDefaults.standard.set(notes, forKey: "lastReleaseNotes")
            }
            
        case .forcedUpdateRequired(let versionInfo):
            appState.availableVersion = versionInfo.latestVersion
            appState.releaseNotes = versionInfo.releaseNotes ?? ""
            appState.showVersionUpdateAlert = true
            appState.isForceUpdateRequired = true
            UserDefaults.standard.set(versionInfo.latestVersion, forKey: "lastAvailableVersion")
            UserDefaults.standard.set(true, forKey: "isForceUpdateRequired")
            if let notes = versionInfo.releaseNotes {
                UserDefaults.standard.set(notes, forKey: "lastReleaseNotes")
            }
            
        case .upToDate:
            UserDefaults.standard.removeObject(forKey: "lastAvailableVersion")
            UserDefaults.standard.removeObject(forKey: "lastReleaseNotes")
            UserDefaults.standard.removeObject(forKey: "isForceUpdateRequired")
            appState.isForceUpdateRequired = false
            
        case .remindLater(_):
            break
            
        case .error(_):
            if let storedVersion = UserDefaults.standard.string(forKey: "lastAvailableVersion"),
               let storedNotes = UserDefaults.standard.string(forKey: "lastReleaseNotes") {
                appState.availableVersion = storedVersion
                appState.releaseNotes = storedNotes
                appState.showVersionUpdateAlert = true
                appState.isForceUpdateRequired = UserDefaults.standard.bool(forKey: "isForceUpdateRequired")
            }
        }
    }
}
