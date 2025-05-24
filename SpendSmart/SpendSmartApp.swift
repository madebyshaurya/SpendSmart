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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    // Check for updates when app comes to foreground
                    Task {
                        await checkForVersionUpdate()
                    }
                }
                .onAppear {
                    // Check for updates on app launch
                    Task {
                        await checkForVersionUpdate()
                    }
                }
        }
    }

    @MainActor
    private func checkForVersionUpdate() async {
        let result = await versionUpdateManager.checkForUpdates()

        switch result {
        case .updateAvailable(let versionInfo):
            appState.availableVersion = versionInfo.latestVersion
            appState.releaseNotes = versionInfo.releaseNotes ?? ""
            appState.showVersionUpdateAlert = true
        case .upToDate, .skipped, .remindLater:
            // Don't show alert for these cases
            break
        case .error(let error):
            // Silently handle errors - don't bother users with network issues
            print("Version check error: \(error.localizedDescription)")
        }
    }
}
