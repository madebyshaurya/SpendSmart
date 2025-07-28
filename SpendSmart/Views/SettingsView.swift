//
//  SettingsView.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-03-17.
//

import SwiftUI
import Supabase

// Import CurrencyManager
@_exported import Foundation

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme

    // Environment object to handle app-wide state
    @EnvironmentObject var appState: AppState

    // Observe the CurrencyManager to update UI when currency changes
    @ObservedObject private var currencyManager = CurrencyManager.shared

    // State for alerts
    @State private var showingSignOutConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteError = false
    @State private var deleteErrorMessage = ""

    // Version update state
    @State private var isCheckingForUpdates = false
    @State private var showUpdateCheckResult = false
    @State private var updateCheckMessage = ""

    var body: some View {
        ZStack {
            BackgroundGradientView()

            List {
            // Account Section
            Section(header: SectionHeaderView(title: "Account", icon: "person.circle.fill")) {
                if appState.isGuestUser {
                    HStack {
                        Text("Account Type")
                            .font(.instrumentSans(size: 16))
                        Spacer()
                        Text("Guest")
                            .font(.instrumentSans(size: 16))
                            .foregroundColor(.gray)
                    }

                    HStack {
                        Text("Storage")
                            .font(.instrumentSans(size: 16))
                        Spacer()
                        Text("Local Device")
                            .font(.instrumentSans(size: 16))
                            .foregroundColor(.gray)
                    }
                } else if let user = supabase.auth.currentUser {
                    HStack {
                        Text("Email")
                            .font(.instrumentSans(size: 16))
                        Spacer()
                        Text(user.email ?? "No Email")
                            .font(.instrumentSans(size: 16))
                            .foregroundColor(.gray)
                    }
                    HStack {
                        Text("User ID")
                            .font(.instrumentSans(size: 16))
                        Spacer()
                        Text(user.id.uuidString)
                            .font(.instrumentSans(size: 16))
                            .foregroundColor(.gray)
                    }

                    HStack {
                        Text("Storage")
                            .font(.instrumentSans(size: 16))
                        Spacer()
                        Text("Cloud")
                            .font(.instrumentSans(size: 16))
                            .foregroundColor(.gray)
                    }
                }
            }

            // Help & Support Section
            Section(header: SectionHeaderView(title: "Help & Support", icon: "questionmark.circle.fill")) {
                NavigationLink(destination: FAQView()) {
                    Text("FAQs")
                        .font(.instrumentSans(size: 16))
                }

                NavigationLink(destination: AboutView()) {
                    Text("About SpendSmart")
                        .font(.instrumentSans(size: 16))
                }
            }

            // Account Actions Section
            Section(header: SectionHeaderView(title: "Account Actions", icon: "exclamationmark.triangle.fill", color: .red)) {
                Button(action: {
                    showingSignOutConfirmation = true
                }) {
                    HStack {
                        Spacer()
                        Text("Sign Out")
                            .font(.instrumentSans(size: 16, weight: .medium))
                            .foregroundColor(.red)
                        Spacer()
                    }
                }
                .alert("Sign Out", isPresented: $showingSignOutConfirmation) {
                    Button("Cancel", role: .cancel) {}
                    Button("Sign Out", role: .destructive) {
                        signOut()
                    }
                } message: {
                    Text("Are you sure you want to sign out?")
                }

                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    HStack {
                        Spacer()
                        Text("Delete Account")
                            .font(.instrumentSans(size: 16, weight: .medium))
                            .foregroundColor(.red)
                        Spacer()
                    }
                }
                .alert("Delete Account", isPresented: $showingDeleteConfirmation) {
                    Button("Cancel", role: .cancel) {}
                    Button("Delete", role: .destructive) {
                        deleteAccount()
                    }
                } message: {
                    Text("Are you sure you want to permanently delete your account? This action cannot be undone.")
                }
                .alert("Error", isPresented: $showingDeleteError) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(deleteErrorMessage)
                }
            }

            // Preferences section
            Section(header: SectionHeaderView(title: "Preferences", icon: "gearshape.fill")) {
                NavigationLink(destination: CurrencySettingsView()) {
                    HStack {
                        Text("Currency")
                            .font(.instrumentSans(size: 16))

                        Spacer()

                        Text(currencyManager.preferredCurrency)
                            .font(.instrumentSans(size: 16))
                            .foregroundColor(.gray)
                    }
                }
            }

            // Data Management section
            Section(header: SectionHeaderView(title: "Data Management", icon: "externaldrive.fill")) {
                NavigationLink(destination: DataExportView()) {
                    HStack {
                        Text("Export Data")
                            .font(.instrumentSans(size: 16))

                        Spacer()

                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.blue)
                    }
                }
            }

            // Other section
            Section(header: SectionHeaderView(title: "Other", icon: "ellipsis.circle.fill")) {
                NavigationLink(destination: CreditsView()) {
                    Text("Credits")
                        .font(.instrumentSans(size: 16))
                }

                // Check for updates button
                Button(action: {
                    checkForUpdates()
                }) {
                    HStack {
                        Text("Check for Updates")
                            .font(.instrumentSans(size: 16))
                            .foregroundColor(isCheckingForUpdates ? .gray : .primary)

                        Spacer()

                        if isCheckingForUpdates {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.down.circle")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .disabled(isCheckingForUpdates)
                
                // Temporary option to test onboarding
                Button(action: {
                    // Reset onboarding completion status
                    UserDefaults.standard.set(false, forKey: "isOnboardingComplete")

                    // Set first login flag to trigger onboarding
                    appState.isFirstLogin = true
                    appState.isOnboardingComplete = false
                }) {
                    HStack {
                        Text("Replay Onboarding Flow")
                            .font(.instrumentSans(size: 16))

                        Spacer()

                        Image(systemName: "arrow.clockwise.circle")
                            .foregroundColor(.blue)
                    }
                }
            }
            }
            .listStyle(.insetGrouped)
            .background(colorScheme == .dark ? Color(hex: "0A0A0A") : Color(hex: "F8FAFC"))
            .scrollContentBackground(.hidden)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .alert("Update Check", isPresented: $showUpdateCheckResult) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(updateCheckMessage)
            }
        }
    }

    private func checkForUpdates() {
        isCheckingForUpdates = true
        print("🔄 Starting manual version check...")

        Task {
            print("📱 Current app version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown")")
            print("📦 Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
            
            let result = await VersionUpdateManager.shared.checkForUpdates(force: true)
            print("✅ Version check completed with result: \(result)")

            await MainActor.run {
                isCheckingForUpdates = false

                switch result {
                case .updateAvailable(let versionInfo):
                    print("📱 Update available: \(versionInfo.latestVersion)")
                    appState.availableVersion = versionInfo.latestVersion
                    appState.releaseNotes = versionInfo.releaseNotes ?? ""
                    appState.showVersionUpdateAlert = true
                case .upToDate:
                    print("✅ App is up to date")
                    updateCheckMessage = "You're using the latest version of SpendSmart!"
                    showUpdateCheckResult = true
                case .remindLater(let date):
                    print("⏰ Will remind later at \(date)")
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    updateCheckMessage = "You chose to be reminded later. Next check: \(formatter.string(from: date))"
                    showUpdateCheckResult = true
                case .error(let error):
                    print("❌ Version check error: \(error.localizedDescription)")
                    updateCheckMessage = "Unable to check for updates: \(error.localizedDescription)"
                    showUpdateCheckResult = true
                }
            }
        }
    }

    private func signOut() {
        // If in guest mode, just reset the app state
        if appState.isGuestUser {
            // Clear local storage if needed
            LocalStorageService.shared.clearAllReceipts()

            DispatchQueue.main.async {
                appState.resetState()
            }
            print("✅ Successfully signed out from guest mode!")
            return
        }

        // Otherwise, sign out from Supabase
        Task {
            do {
                try await supabase.auth.signOut()
                print("✅ Successfully signed out!")

                DispatchQueue.main.async {
                    appState.resetState()
                }
            } catch {
                print("❌ Sign out failed: \(error.localizedDescription)")
            }
        }
    }

    private func deleteAccount() {
        // If in guest mode, delete the guest user from Supabase and clear local storage
        if appState.isGuestUser {
            // Clear local storage
            LocalStorageService.shared.clearAllReceipts()

            // Delete the guest user from Supabase if we have their ID
            if let guestUserId = appState.guestUserId {
                Task {
                    do {
                        // Use the service role key to delete the user
                        let supabaseClient = SupabaseClient(
                            supabaseURL: URL(string: supabaseURL)!,
                            supabaseKey: supabaseServiceRoleKey
                        )

                        // First, delete any receipts that might have been saved to Supabase
                        try await supabase
                            .from("receipts")
                            .delete()
                            .eq("user_id", value: guestUserId)
                            .execute()
                        print("✅ Successfully deleted any guest receipts from Supabase!")

                        // Then delete the guest user account
                        try await supabaseClient.auth.admin.deleteUser(id: guestUserId.uuidString)
                        print("✅ Successfully deleted guest user from Supabase!")

                        // Also sign out from Supabase
                        try? await supabase.auth.signOut()
                    } catch {
                        print("❌ Failed to delete guest user from Supabase: \(error.localizedDescription)")
                    }

                    // Reset app state regardless of whether the Supabase deletion succeeded
                    await MainActor.run {
                        appState.resetState()
                    }
                }
            } else {
                // If we don't have a guest user ID, just reset the app state
                DispatchQueue.main.async {
                    appState.resetState()
                }
                print("✅ Successfully deleted guest account (local only)!")
            }
            return
        }

        // Otherwise, delete account from Supabase
        Task {
            do {
                guard let user = supabase.auth.currentUser else {
                    throw NSError(domain: "SpendSmart", code: 400, userInfo: [NSLocalizedDescriptionKey: "No current user found"])
                }

                let supabaseClient = SupabaseClient(
                    supabaseURL: URL(string: supabaseURL)!,
                    supabaseKey: supabaseServiceRoleKey
                )

                // First, delete all receipts associated with this user
                try await supabase
                    .from("receipts")
                    .delete()
                    .eq("user_id", value: user.id)
                    .execute()
                print("✅ Successfully deleted all user receipts!")

                // Then delete the user account
                try await supabaseClient.auth.admin.deleteUser(id: user.id.uuidString)
                print("✅ Successfully deleted account!")

                try await supabase.auth.signOut()

                DispatchQueue.main.async {
                    appState.resetState()
                }
            } catch {
                print("❌ Account deletion failed: \(error.localizedDescription)")

                DispatchQueue.main.async {
                    deleteErrorMessage = "Failed to delete account: \(error.localizedDescription)"
                    showingDeleteError = true
                }
            }
        }
    }
}
