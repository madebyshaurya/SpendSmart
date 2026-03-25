//
//  LoginView.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-12-31.
//

import AuthenticationServices
import PopupView  // Import PopupView
import Supabase
import SwiftUI

struct LoginView: View {
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showErrorToast: Bool = false  // State for popup
    @StateObject private var haptics = HapticManager.shared
    @EnvironmentObject var appState: AppState
    private let appleNameKeyPrefix = "apple_name_"

    var body: some View {
        ZStack {
            // Background gradient instead of full-screen video
            LinearGradient(
                colors: [
                    Color.brandDeepNavy,
                    Color.brandDarkNavy,
                    Color.brandMidnightBlue
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()
                
                // Feature carousel video in rounded rectangle
                featureCarouselView
                
                Spacer()
                    .frame(height: 20)
                
                // Tagline text
                VStack(alignment: .leading, spacing: 8) {
                    Text("Scan it, forget it.")
                        .font(.instrumentSerifItalic(size: 42))
                        .foregroundStyle(.white)
                    
                    Text("We remember so you don't have to.")
                        .font(.manrope(size: 22, weight: .regular))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)

                Spacer()
                    .frame(height: 16)

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .padding()
                }

                // Apple Sign In
                SignInWithAppleButton(.continue) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    handleSignInWithApple(result)
                }
                .frame(height: 52)
                .cornerRadius(100, corners: .allCorners)
                .padding(.horizontal, 24)
                .signInWithAppleButtonStyle(.white)
                
                // Terms text
                Text("By continuing, you agree to our Terms of Service and Privacy Policy")
                    .font(.manrope(size: 11, weight: .regular))
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
            }
        }
        .popup(isPresented: $showErrorToast) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.white)
                Text(errorMessage ?? "An error occurred")
                    .font(.manrope(size: 16))
                    .foregroundColor(.white)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .background(Color.black.opacity(0.8))
            .cornerRadius(30)
            .padding(.top, 60)  // Adjust for dynamic island / notch
        } customize: {
            $0
                .type(.floater())
                .position(.top)
                .animation(.spring())
                .autohideIn(3)
        }
    }
    
    // MARK: - Feature Carousel View
    
    private var featureCarouselView: some View {
        ZStack {
            // White rounded rectangle container
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.2), radius: 20, y: 10)
            
            // Video player (or placeholder if video not found)
            LoopingVideoView(name: "login_features")
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(4)
            
            // Fallback overlay if video doesn't load
            // This will be hidden once video plays
            featureCarouselPlaceholder
                .opacity(0) // Hidden when video is present
        }
        .frame(height: 340)
        .padding(.horizontal, 24)
    }
    
    // Placeholder shown if video isn't available yet
    private var featureCarouselPlaceholder: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.brandVibrantBlue)
            
            Text("Smart Receipt Scanning")
                .font(.instrumentSerif(size: 24))
                .foregroundStyle(Color.brandTextPrimary)
            
            Text("AI-powered expense tracking")
                .font(.manrope(size: 14, weight: .medium))
                .foregroundStyle(Color.brandTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.brandBackground)
        )
        .padding(4)
    }

    // MARK: - Auth Handling

    private func handleSignInWithApple(_ result: Result<ASAuthorization, Error>) {
        haptics.buttonPress()
        isLoading = true
        errorMessage = nil

        Task {
            do {
                switch result {
                case .success(let authorization):
                    if let appleIDCredential = authorization.credential
                        as? ASAuthorizationAppleIDCredential,
                        let idTokenData = appleIDCredential.identityToken,
                        let idTokenString = String(data: idTokenData, encoding: .utf8)
                    {

                        // 1. Sign in with Supabase
                        try await SupabaseManager.shared.signInWithApple(idToken: idTokenString)
                        let appleUserId = appleIDCredential.user
                        let nameString = resolvedAppleName(
                            from: appleIDCredential,
                            appleUserId: appleUserId
                        )
                        if let nameString, !nameString.isEmpty {
                            await MainActor.run { appState.pendingDisplayName = nameString }
                            await SupabaseManager.shared.ensureProfileNameExists(nameString)
                        }

                        haptics.signInSuccess()
                    } else {
                        throw NSError(
                            domain: "Auth", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Invalid Apple ID Credentials"])
                    }

                case .failure(let error):
                    print("Apple Sign In failed: \(error.localizedDescription)")
                    // Check for cancellation specifically if desired, but general error handling covers it too
                    haptics.error()
                    errorMessage = "Sign in cancelled or failed."
                    showErrorToast = true
                }
            } catch {
                print("Auth error: \(error)")
                haptics.error()
                errorMessage = "Authentication failed: \(error.localizedDescription)"
                showErrorToast = true
            }
            isLoading = false
        }
    }

    private func resolvedAppleName(
        from credential: ASAuthorizationAppleIDCredential,
        appleUserId: String
    ) -> String? {
        if let nameComponents = credential.fullName {
            let formatter = PersonNameComponentsFormatter()
            let nameString =
                formatter.string(from: nameComponents).trimmingCharacters(in: .whitespacesAndNewlines)
            if !nameString.isEmpty {
                cacheAppleName(nameString, for: appleUserId)
                return nameString
            }
        }

        return cachedAppleName(for: appleUserId)
    }

    private func cachedAppleName(for appleUserId: String) -> String? {
        UserDefaults.standard.string(forKey: appleNameKeyPrefix + appleUserId)
    }

    private func cacheAppleName(_ name: String, for appleUserId: String) {
        UserDefaults.standard.set(name, forKey: appleNameKeyPrefix + appleUserId)
    }
}

#Preview {
    LoginView()
}
