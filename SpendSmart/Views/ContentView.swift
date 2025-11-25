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
    @State private var selectedTab: Int = 0

    var body: some View {
        Group {
            if appState.isLoggedIn {
                loggedInView
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
        .preferredColorScheme(
            appState.appearanceSelection == .system ? nil : (appState.appearanceSelection == .dark ? .dark : .light)
        )
        .alert("Error", isPresented: $isShowingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    @ViewBuilder
    private var loggedInView: some View {
        if appState.isForceUpdateRequired {
            ForcedUpdateBlockingView()
                .environmentObject(appState)
                .onAppear { appState.showVersionUpdateAlert = true }
        } else if appState.isFirstLogin && !appState.isOnboardingComplete {
            OnboardingView()
                .environmentObject(appState)
        } else {
            mainTabView
        }
    }

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            DashboardView(email: appState.userEmail, openSubscriptions: { 
                print("🔄 [ContentView] Opening subscriptions tab from dashboard")
                selectedTab = 1 
            })
                .environmentObject(appState)
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "chart.bar.fill" : "chart.bar")
                        .environment(\.symbolVariants, selectedTab == 0 ? .fill : .none)
                    Text("Overview")
                }
                .tag(0)
                .accessibilityLabel("Overview tab")
                .accessibilityHint("View your spending overview and insights")

            NavigationView {
                SubscriptionListView()
                    .environmentObject(appState)
            }
            .tabItem {
                Image(systemName: selectedTab == 1 ? "creditcard.fill" : "creditcard")
                    .environment(\.symbolVariants, selectedTab == 1 ? .fill : .none)
                Text("Subscriptions")
            }
            .tag(1)
            .accessibilityLabel("Subscriptions tab")
            .accessibilityHint("Manage your recurring subscriptions")

            NavigationView {
                HistoryView()
                    .environmentObject(appState)
            }
            .tabItem {
                Image(systemName: selectedTab == 2 ? "clock.fill" : "clock")
                    .environment(\.symbolVariants, selectedTab == 2 ? .fill : .none)
                Text("History")
            }
            .tag(2)
            .accessibilityLabel("History tab")
            .accessibilityHint("View your expense history and receipts")

            NavigationView {
                SettingsView()
                    .environmentObject(appState)
            }
            .tabItem {
                Image(systemName: selectedTab == 3 ? "gearshape.fill" : "gearshape")
                    .environment(\.symbolVariants, selectedTab == 3 ? .fill : .none)
                Text("Settings")
            }
            .tag(3)
            .accessibilityLabel("Settings tab")
            .accessibilityHint("Access app settings and preferences")
        }
        .tint(DesignTokens.Colors.Primary.blue)
        .onChange(of: selectedTab) { oldValue, newValue in
            let tabNames = ["Overview", "Subscriptions", "History", "Settings"]
            print("🔄 [ContentView] Tab changed from \(tabNames[safe: oldValue] ?? "Unknown") to \(tabNames[safe: newValue] ?? "Unknown")")
        }
        .onAppear(perform: configureTabBarAppearance)
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground

        let selectedTitleAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold)
        ]
        let normalTitleAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.secondaryLabel,
            .font: UIFont.systemFont(ofSize: 11, weight: .regular)
        ]

        func configure(_ itemAppearance: UITabBarItemAppearance) {
            itemAppearance.selected.iconColor = UIColor.white
            itemAppearance.selected.titleTextAttributes = selectedTitleAttributes
            itemAppearance.normal.iconColor = UIColor.secondaryLabel
            itemAppearance.normal.titleTextAttributes = normalTitleAttributes
        }

        let stacked = UITabBarItemAppearance()
        stacked.configureWithDefault(for: .stacked)
        configure(stacked)

        let inline = UITabBarItemAppearance()
        inline.configureWithDefault(for: .inline)
        configure(inline)

        let compactInline = UITabBarItemAppearance()
        compactInline.configureWithDefault(for: .compactInline)
        configure(compactInline)

        appearance.stackedLayoutAppearance = stacked
        appearance.inlineLayoutAppearance = inline
        appearance.compactInlineLayoutAppearance = compactInline

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
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
