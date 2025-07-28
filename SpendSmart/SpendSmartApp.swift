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
    
    // Add scene phase to track app state
    @Environment(\.scenePhase) private var scenePhase
    
    // Track if we've already checked for updates in this session
    @State private var hasCheckedForUpdates = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    switch newPhase {
                    case .active:
                        // App became active (launch or from background)
                        print("📱 App became active")
                        // Only check for updates if we haven't already in this session
                        // or if we're coming back from background after a significant time
                        if !hasCheckedForUpdates || shouldCheckForUpdates() {
                            Task {
                                await checkForVersionUpdate()
                            }
                        }
                    case .background:
                        // App went to background
                        print("📱 App went to background")
                    case .inactive:
                        // App became inactive
                        print("📱 App became inactive")
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
            print("📱 Update available: \(versionInfo.latestVersion)")
            appState.availableVersion = versionInfo.latestVersion
            appState.releaseNotes = versionInfo.releaseNotes ?? ""
            appState.showVersionUpdateAlert = true
            
            // Store the version info for later use
            UserDefaults.standard.set(versionInfo.latestVersion, forKey: "lastAvailableVersion")
            if let notes = versionInfo.releaseNotes {
                UserDefaults.standard.set(notes, forKey: "lastReleaseNotes")
            }
            
        case .upToDate:
            print("✅ App is up to date")
            // Clear any stored version info
            UserDefaults.standard.removeObject(forKey: "lastAvailableVersion")
            UserDefaults.standard.removeObject(forKey: "lastReleaseNotes")
            
        case .remindLater(let date):
            print("⏰ Will remind later at \(date)")
            
        case .error(let error):
            print("❌ Version check error: \(error.localizedDescription)")
            // If we have stored version info, we can still show it
            if let storedVersion = UserDefaults.standard.string(forKey: "lastAvailableVersion"),
               let storedNotes = UserDefaults.standard.string(forKey: "lastReleaseNotes") {
                appState.availableVersion = storedVersion
                appState.releaseNotes = storedNotes
                appState.showVersionUpdateAlert = true
            }
        }
    }
}
