//
//  ContentView.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-03-12.
//

import SwiftUI
import AuthenticationServices
import Supabase
import UIKit

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var isShowingError = false
    @State private var errorMessage = ""

    var body: some View {
        Group {
            if appState.isLoggedIn {
                if appState.isForceUpdateRequired {
                    ForcedUpdateBlockingView()
                        .environmentObject(appState)
                        .onAppear { appState.showVersionUpdateAlert = true }
                } else if appState.isFirstLogin && !appState.isOnboardingComplete {
                    OnboardingView()
                        .environmentObject(appState)
                } else {
                    TabView {
                        DashboardView(email: appState.userEmail)
                            .environmentObject(appState)
                            .tabItem {
                                Image(systemName: "house")
                                Text("Home")
                            }

                        NavigationView {
                            HistoryView()
                                .environmentObject(appState)
                        }
                        .tabItem {
                            Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                            Text("History")
                        }

                        NavigationView {
                            SettingsView()
                                .environmentObject(appState)
                        }
                        .tabItem {
                            Image(systemName: "gear")
                            Text("Settings")
                        }
                    }
                }
            } else {
                LaunchScreen(appState: appState)
            }
        }
        .overlay(
            // Version update alert overlay
            Group {
                if appState.showVersionUpdateAlert {
                    VersionUpdateAlert(
                        versionInfo: VersionInfo(
                            currentVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
                            latestVersion: appState.availableVersion,
                            releaseNotes: appState.releaseNotes.isEmpty ? nil : appState.releaseNotes,
                            isForced: appState.isForceUpdateRequired
                        ),
                        onAction: { action in
                            handleVersionUpdateAction(action)
                        }
                    )
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: appState.showVersionUpdateAlert)
                }
            }
        )
        .alert("Error", isPresented: $isShowingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private func handleVersionUpdateAction(_ action: VersionUpdateAction) {
        let versionUpdateManager = VersionUpdateManager.shared
        let isForced = appState.isForceUpdateRequired
        
        versionUpdateManager.handleUserAction(action, for: appState.availableVersion, isForced: isForced)

        if isForced && action != .updateNow { return }

        appState.showVersionUpdateAlert = false
        if !isForced { appState.clearStoredVersionInfo() }
        
        // If there was an error opening the App Store, show an error
        if action == .updateNow {
            Task {
                do {
                    let versionInfo = try await versionUpdateManager.fetchLatestVersionInfo()
                    if let urlString = versionInfo.appStoreURL,
                       let url = URL(string: urlString) {
                        await MainActor.run {
                            UIApplication.shared.open(url) { success in
                                if !success {
                                    // Restore version info and show error
                                    appState.storeVersionInfo(version: appState.availableVersion, notes: appState.releaseNotes)
                                    errorMessage = "Could not open the App Store. Please try again later."
                                    isShowingError = true
                                }
                            }
                        }
                    }
                } catch {
                    // Restore version info and show error
                    appState.storeVersionInfo(version: appState.availableVersion, notes: appState.releaseNotes)
                    errorMessage = "Could not check for updates. Please try again later."
                    isShowingError = true
                }
            }
        }
    }
}
