//
//  DashboardView.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-03-14.
//

import SwiftUI
import AuthenticationServices
import Supabase

struct DashboardView: View {
    var email: String
    var onSignOut: () -> Void
    
    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteError = false
    @State private var deleteErrorMessage = ""
    @State private var showingSignOutConfirmation = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome!")
                .font(.largeTitle)
                .bold()
            
            Text("Email: \(email)")
                .font(.title2)
                .padding()

            Button(action: {
                showingSignOutConfirmation = true
            }) {
                Text("Sign Out")
                    .foregroundColor(.white)
                    .padding()
                    .frame(width: 200)
                    .background(Color.red)
                    .cornerRadius(10)
            }
            .alert("Sign Out", isPresented: $showingSignOutConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    signOut()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            
            Divider()
                .padding(.vertical)
            
            Button(action: {
                showingDeleteConfirmation = true
            }) {
                Text("Delete Account")
                    .foregroundColor(.white)
                    .padding()
                    .frame(width: 200)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(10)
            }
            .alert("Delete Account", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteAccount()
                    signOut()
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
        .padding()
    }
    
    private func signOut() {
        Task {
            do {
                try await supabase.auth.signOut()
                
                // Call the onSignOut closure to update the parent view
                DispatchQueue.main.async {
                    onSignOut()
                    // Add any navigation action here if needed
                    // For example, navigate to the login screen or main view.
                }
                
                print("✅ Successfully signed out!")
            } catch {
                print("❌ Sign out failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func deleteAccount() {
        Task {
            do {
                // Get the current user
                guard let user = supabase.auth.currentUser else {
                    throw NSError(domain: "SpendSmart", code: 400, userInfo: [NSLocalizedDescriptionKey: "No current user found"])
                }
                print(user.id.uuidString)
                
                let supabaseClient = SupabaseClient(
                    supabaseURL: URL(string: supabaseURL)!,
                    supabaseKey: supabaseServiceRoleKey
                )

                // Try to delete the user from Supabase
                try await supabaseClient.auth.admin.deleteUser(id: user.id.uuidString)
                
                print("✅ Successfully deleted account!")
                
                // Handle sign-out and redirection after successful deletion
                DispatchQueue.main.async {
                    onSignOut()
                    // Add any navigation action here if needed
                    // For example, trigger navigation to the login screen or main view.
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

#Preview {
    DashboardView(email: "123@test.com", onSignOut: {})
}
