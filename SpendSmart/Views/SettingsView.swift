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
        List {
            // Account Section
            Section(header: SectionHeaderView(title: "Account", icon: "person.circle.fill")) {
                if let user = supabase.auth.currentUser {
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
                }
            }
            
            // Help & Support Section
            Section(header: SectionHeaderView(title: "Help & Support", icon: "questionmark.circle.fill")) {
                NavigationLink(destination: FAQView()) {
                    Text("FAQs")
                        .font(.instrumentSans(size: 16))
                }
                
                NavigationLink(destination: SupportView()) {
                    Text("Contact Support")
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
        }
        .listStyle(.insetGrouped)
        .background(colorScheme == .dark ? Color(hex: "0A0A0A") : Color(hex: "F8FAFC"))
        .scrollContentBackground(.hidden)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
    }
    
    private func signOut() {
        Task {
            do {
                try await supabase.auth.signOut()
                print("✅ Successfully signed out!")
                
                DispatchQueue.main.async {
                    appState.isLoggedIn = false
                    appState.userEmail = ""
                }
            } catch {
                print("❌ Sign out failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func deleteAccount() {
        Task {
            do {
                guard let user = supabase.auth.currentUser else {
                    throw NSError(domain: "SpendSmart", code: 400, userInfo: [NSLocalizedDescriptionKey: "No current user found"])
                }
                
                let supabaseClient = SupabaseClient(
                    supabaseURL: URL(string: supabaseURL)!,
                    supabaseKey: supabaseServiceRoleKey
                )

                try await supabaseClient.auth.admin.deleteUser(id: user.id.uuidString)
                print("✅ Successfully deleted account!")
                
                try await supabase.auth.signOut()
                
                DispatchQueue.main.async {
                    appState.isLoggedIn = false
                    appState.userEmail = ""
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
