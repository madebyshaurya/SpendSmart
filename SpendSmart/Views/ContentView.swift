//
//  ContentView.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-03-12.
//

import SwiftUI
import AuthenticationServices
import Supabase

struct ContentView: View {
    @StateObject private var appState = AppState()

    var body: some View {
        if appState.isLoggedIn {
            TabView {
                Tab("Home", systemImage: "house") {
                    DashboardView(email: appState.userEmail)
                        .environmentObject(appState)
                }
                Tab("History", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90") {
                    NavigationView {
                        HistoryView()
                            .environmentObject(appState)
                    }
                }
                Tab("Settings", systemImage: "gear") {
                    NavigationView {
                        SettingsView()
                            .environmentObject(appState)
                    }
                }
            }
        } else {
            LaunchScreen(appState: appState)
                .task {
                    // Check for existing session on app launch
                    if appState.isGuestUser && appState.guestUserId != nil {
                        // Guest mode already restored from UserDefaults in AppState init
                        print("✅ Using guest mode from UserDefaults")
                    } else if let user = supabase.auth.currentUser {
                        // Check if this is a guest user by looking at the email
                        let isGuest = user.email?.contains("guest") ?? false

                        if isGuest {
                            // Restore guest mode
                            appState.enableGuestMode(userId: user.id)
                            print("✅ Restored guest session from Supabase for user: \(user.id)")
                        } else {
                            // Regular user
                            appState.userEmail = user.email ?? "No Email"
                            appState.isLoggedIn = true
                            print("✅ Restored regular user session for: \(user.email ?? "unknown")")
                        }
                    } else {
                        print("No existing session found")
                    }
                }
        }
    }
}
