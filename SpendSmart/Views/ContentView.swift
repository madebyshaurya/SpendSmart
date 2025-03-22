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
                    if let user = supabase.auth.currentUser {
                        appState.userEmail = user.email ?? "No Email"
                        appState.isLoggedIn = true
                    }
                }
        }
    }
}
