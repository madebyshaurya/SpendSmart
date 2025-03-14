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
    @State private var isLoggedIn = false
    @State private var userEmail: String = ""
    
    // Check for existing session when app starts
    var body: some View {
        if isLoggedIn {
            DashboardView(email: userEmail, onSignOut: {
                // This closure will be called when sign out is successful
                isLoggedIn = false
                userEmail = ""
            })
        } else {
            VStack {
                Text("SpendSmart")
                    .font(.largeTitle)
                    .bold()
                    .padding(.bottom, 30)
                
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    switch result {
                    case .success(let authResults):
                        handleSignInWithApple(authResults)
                    case .failure(let error):
                        print("Sign in with Apple failed: \(error.localizedDescription)")
                    }
                }
                .frame(width: 280, height: 50)
                .signInWithAppleButtonStyle(.black)
            }
            .onAppear {
                checkForExistingSession()
            }
        }
    }
    
    private func checkForExistingSession() {
        // Check if there's an active session
        if let user = supabase.auth.currentUser {
            DispatchQueue.main.async {
                self.userEmail = user.email ?? "No Email"
                self.isLoggedIn = true
            }
        }
    }
    
    private func handleSignInWithApple(_ authResults: ASAuthorization) {
        guard let credential = authResults.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            print("Error: Invalid Apple ID credentials")
            return
        }
        
        Task {
            do {
                let session = try await supabase.auth.signInWithIdToken(credentials: .init(provider: .apple, idToken: tokenString))
                
                if let user = supabase.auth.currentUser {
                    DispatchQueue.main.async {
                        self.userEmail = user.email ?? "No Email"
                        self.isLoggedIn = true
                    }
                }
                
                print("✅ Successfully signed in with Apple via Supabase!")
            } catch {
                print("❌ Supabase authentication failed: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    ContentView()
}
