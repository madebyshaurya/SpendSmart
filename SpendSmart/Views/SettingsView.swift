//
//  SettingsView.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-03-17.
//

import SwiftUI
import Supabase

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme

    // Environment object to handle app-wide state
    @EnvironmentObject var appState: AppState

    // State for alerts
    @State private var showingSignOutConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteError = false
    @State private var deleteErrorMessage = ""

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

            // Other section
            Section(header: SectionHeaderView(title: "Other", icon: "ellipsis.circle.fill")) {
                NavigationLink(destination: CreditsView()) {
                    Text("Credits")
                        .font(.instrumentSans(size: 16))
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(colorScheme == .dark ? Color(hex: "0A0A0A") : Color(hex: "F8FAFC"))
        .scrollContentBackground(.hidden)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
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
