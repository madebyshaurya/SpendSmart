//
//  LaunchScreen.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-03-17.
//

import SwiftUI
import AuthenticationServices
import Supabase

struct LaunchScreen: View {
    @ObservedObject var appState: AppState
    @State private var currentPage = 0
    @Environment(\.colorScheme) private var colorScheme

    // Onboarding feature pages
    private let features = [
        FeatureItem(
            icon: "doc.text.viewfinder",
            title: "Scan Receipts Instantly",
            description: "Just snap a photo and our AI does the rest. No manual data entry needed."
        ),
        FeatureItem(
            icon: "folder.badge.gearshape",
            title: "Automatic Organization",
            description: "Receipts are automatically categorized and sorted for easy retrieval."
        ),
        FeatureItem(
            icon: "chart.pie.fill",
            title: "Smart Spending Insights",
            description: "Track spending patterns and see where your money goes each month."
        ),
        FeatureItem(
            icon: "arrow.counterclockwise.circle.fill",
            title: "Easy Returns",
            description: "Find receipts quickly when you need to return items or file warranty claims."
        )
    ]

    // Add timer for auto-scrolling
    @State private var autoScrollTimer: Timer?

    // Add gradient animation state
    @State private var gradientStart = UnitPoint(x: -1, y: 0.5)
    @State private var gradientEnd = UnitPoint(x: 0, y: 0.5)

    // Add button animation state
    @State private var isButtonHovered = false

    // Alert state
    @State private var showGuestModeAlert = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundColor
                    .ignoresSafeArea(.all)

                VStack(spacing: 0) {
                    // Header - responsive sizing
                    heroHeader(geometry: geometry)

                    // Feature carousel - responsive height
                    TabView(selection: $currentPage) {
                        ForEach(0..<features.count, id: \.self) { index in
                            FeatureView(feature: features[index])
                                .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .frame(height: adaptiveCarouselHeight(geometry: geometry))
                    .padding(.top, adaptiveSpacing(base: 24, geometry: geometry))
                    .animation(.easeInOut(duration: 0.3), value: currentPage)

                    // Page indicator
                    HStack(spacing: 12) {
                        ForEach(0..<features.count, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(currentPage == index ?
                                      (colorScheme == .dark ? Color.white : Color(hex: "3B82F6")) :
                                        (colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2)))
                                .frame(width: currentPage == index ? 20 : 12, height: 4)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                        }
                    }
                    .padding(.top, adaptiveSpacing(base: 20, geometry: geometry))

                    Spacer(minLength: adaptiveSpacing(base: 20, geometry: geometry))

                    // Sign in button - at bottom
                    VStack(spacing: 16) {
                        Group {
                            CustomSignInWithAppleButton { result in
                                switch result {
                                case .success(let authResults):
                                    handleSignInWithApple(authResults)
                                case .failure(let error):
                                    print("Sign in with Apple failed: \(error.localizedDescription)")
                                }
                            }
                        }
                        .modifier(
                            ConditionalGlassButtonModifier()
                        )

                        // Skip for now button - COMMENTED OUT
                        // Button {
                        //     showGuestModeAlert = true
                        // } label: {
                        //     HStack(spacing: 8) {
                        //         Text("Skip for now")
                        //             .font(.instrumentSans(size: 14, weight: .medium))
                        //     }
                        //     .foregroundColor(colorScheme == .dark ? .white : Color(hex: "3B82F6"))
                        //     .frame(maxWidth: .infinity)
                        // }
                        // .padding(.top, 8)

                        Text("No in-app purchases or ads. We respect your privacy.")
                            .font(.instrumentSans(size: adaptiveFontSize(base: 12, geometry: geometry)))
                            .foregroundColor(colorScheme == .dark ? .gray : Color(hex: "64748B"))
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, adaptiveBottomPadding(geometry: geometry))
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            checkForExistingSession()
            startAutoScroll()
        }
        .onDisappear {
            stopAutoScroll()
        }
        // GUEST MODE ALERT - COMMENTED OUT
        // .alert("Skip Sign In", isPresented: $showGuestModeAlert) {
        //     Button("Skip", role: .none) {
        //         enableGuestMode()
        //     }
        //     Button("Cancel", role: .cancel) {}
        // } message: {
        //     Text("Your receipts will be saved on this device only. To save receipts in the cloud, please sign in with Apple.")
        // }
    }

    private var backgroundColor: some View {
        colorScheme == .dark ?
        Color(hex: "0A0A0A").edgesIgnoringSafeArea(.all) :
        Color(hex: "F8FAFC").edgesIgnoringSafeArea(.all)
    }

    @ViewBuilder
    private func heroHeader(geometry: GeometryProxy) -> some View {
        let badgeTint = colorScheme == .dark ? Color(hex: "3B82F6") : Color(hex: "DBEAFE")

        VStack(spacing: adaptiveSpacing(base: 8, geometry: geometry)) {
            Text("SpendSmart")
                .font(.instrumentSerifItalic(size: adaptiveFontSize(base: 42, geometry: geometry)))
                .bold()
                .foregroundColor(colorScheme == .dark ? .white : Color(hex: "1E293B"))
            Text("Less clutter, more clarity.")
                .font(.instrumentSans(size: adaptiveFontSize(base: 16, geometry: geometry)))
                .foregroundColor(colorScheme == .dark ? .gray : Color(hex: "64748B"))
                .padding(.bottom, adaptiveSpacing(base: 20, geometry: geometry))

            Text("AI-POWERED • 100% FREE")
                .font(.instrumentSans(size: adaptiveFontSize(base: 12, geometry: geometry)))
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .glassCompatCapsule(tint: badgeTint, interactive: true)
                .overlay(
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(hex: "60A5FA").opacity(0.2),
                                    Color(hex: "818CF8").opacity(0.8),
                                    Color(hex: "C084FC").opacity(0.8),
                                    Color(hex: "60A5FA").opacity(0.2)
                                ]),
                                startPoint: gradientStart,
                                endPoint: gradientEnd
                            ),
                            lineWidth: 1
                        )
                        .animation(
                            Animation.linear(duration: 3)
                                .repeatForever(autoreverses: false),
                            value: gradientStart
                        )
                )
                .foregroundColor(colorScheme == .dark ? Color(hex: "60A5FA") : Color(hex: "2563EB"))
                .onAppear {
                    withAnimation(Animation.linear(duration: 3).repeatForever(autoreverses: false)) {
                        gradientStart = UnitPoint(x: 1, y: 0.5)
                        gradientEnd = UnitPoint(x: 2, y: 0.5)
                    }
                }
        }
        .padding(24)
        .glassCompatRect(cornerRadius: 28, interactive: true)
        .padding(.horizontal, 24)
        .padding(.top, adaptiveSpacing(base: 24, geometry: geometry))
    }

    private func checkForExistingSession() {
        // Initialize backend detection on app launch
        Task {
            let backendStatus = await BackendAPIService.shared.getBackendStatus()
            print("🌐 [iOS] Backend initialized: \(backendStatus.url)")
            print("🏠 [iOS] Using localhost: \(backendStatus.isLocalhost)")
        }
        
        // Session restoration is now handled centrally in AppState.init()
        // This just initializes the backend connection
        print("🔄 [LaunchScreen] Backend initialization completed")
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
                print("🔐 [iOS] Starting Apple Sign-In process...")
                
                // Try backend API first (new method)
                do {
                    let backendResponse = try await BackendAPIService.shared.signInWithApple(idToken: tokenString, userEmail: credential.email)
                    print("✅ [iOS] Backend API sign-in successful!")
                    print("👤 [iOS] User ID: \(backendResponse.data.user?.id ?? "No ID")")
                    print("📧 [iOS] User Email: \(backendResponse.data.user?.email ?? "No Email")")
                    
                    // Sync the BackendAPIService authentication token
                    await BackendAPIService.shared.syncAuthTokenFromSupabase()
                    
                    DispatchQueue.main.async {
                        print("🔄 [iOS] Updating app state from backend API...")
                        
                        // Check if this is a new user (first login)
                        let isNewUser = credential.user == backendResponse.data.user?.id && credential.email != nil
                        print("🆕 [iOS] Is new user: \(isNewUser)")
                        
                        // Use the actual email from Apple credential if available, otherwise fall back to backend response
                        let userEmail = credential.email ?? backendResponse.data.user?.email ?? "Apple ID User"
                        appState.userEmail = userEmail
                        print("📧 [iOS] Set userEmail to: \(appState.userEmail)")
                        
                        // Store the actual email in UserDefaults for session restoration
                        UserDefaults.standard.set(userEmail, forKey: "backend_user_email")
                        print("📧 [iOS] Stored email in UserDefaults: \(userEmail)")

                        appState.isLoggedIn = true
                        appState.isGuestUser = false
                        appState.useLocalStorage = false
                        appState.isFirstLogin = isNewUser
                        
                        print("✅ [iOS] Backend API session restored successfully")
                    }
                    
                    print("✅ Successfully signed in with Apple via Backend API!")
                    return
                    
                } catch {
                    print("⚠️ [iOS] Backend API sign-in failed, falling back to Supabase: \(error.localizedDescription)")
                }
                
                // Fallback to Supabase (legacy method)
                let response = try await supabase.signInWithApple(idToken: tokenString)

                print("🔐 [iOS] Received session from Supabase")
                print("👤 [iOS] User ID: \(response.data.user?.id ?? "No ID")")
                print("📧 [iOS] User Email: \(response.data.user?.email ?? "No Email")")

                // Sync the BackendAPIService authentication token
                await BackendAPIService.shared.syncAuthTokenFromSupabase()

                DispatchQueue.main.async {
                    print("🔄 [iOS] Updating app state from Supabase...")

                    // Check if this is a new user (first login)
                    let isNewUser = credential.user == response.data.user?.id && credential.email != nil
                    print("🆕 [iOS] Is new user: \(isNewUser)")

                    // Use the actual email from Apple credential if available, otherwise fall back to Supabase response
                    let userEmail = credential.email ?? response.data.user?.email ?? "Apple ID User"
                    appState.userEmail = userEmail
                    print("📧 [iOS] Set userEmail to: \(appState.userEmail)")
                    
                    // Store the actual email in UserDefaults for session restoration
                    UserDefaults.standard.set(userEmail, forKey: "backend_user_email")
                    print("📧 [iOS] Stored email in UserDefaults: \(userEmail)")

                    appState.isLoggedIn = true
                    appState.isGuestUser = false
                    appState.useLocalStorage = false
                    appState.isFirstLogin = isNewUser
                    
                    print("✅ [iOS] Supabase session restored successfully")
                }

                print("✅ Successfully signed in with Apple via Supabase!")

            } catch {
                print("❌ Apple Sign-In failed completely: \(error.localizedDescription)")
                print("🔍 [iOS] Error details: \(error)")
            }
        }
    }

    // Add auto-scroll functions
    private func startAutoScroll() {
        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            withAnimation {
                currentPage = (currentPage + 1) % features.count
            }
        }
    }

    private func stopAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
    }

    // Enable guest mode
    private func enableGuestMode() {
        Task {
            do {
                // Try backend API first (new method)
                do {
                    let backendResponse = try await BackendAPIService.shared.createGuestAccount()
                    print("✅ [iOS] Created guest user via backend API with ID: \(backendResponse.data.user?.id ?? "No ID")")
                    
                    // Enable guest mode in app state with the user ID
                    DispatchQueue.main.async {
                        if let userId = backendResponse.data.user?.id {
                            appState.enableGuestMode(userId: UUID(uuidString: userId) ?? UUID())
                        } else {
                            appState.enableGuestMode()
                        }
                        
                        // Set first login flag to trigger onboarding for new guest users
                        appState.isFirstLogin = true
                    }
                    
                    print("✅ Successfully created guest account via Backend API!")
                    return
                    
                } catch {
                    print("⚠️ [iOS] Backend API guest creation failed, falling back to Supabase: \(error.localizedDescription)")
                }
                
                // Fallback to Supabase (legacy method)
                let response = try await supabase.createGuestAccount()

                print("✅ Created guest user via Supabase with ID: \(response.data.user?.id ?? "No ID")")

                // Enable guest mode in app state with the user ID
                DispatchQueue.main.async {
                    if let userId = response.data.user?.id {
                        appState.enableGuestMode(userId: UUID(uuidString: userId) ?? UUID())
                    } else {
                        appState.enableGuestMode()
                    }

                    // Set first login flag to trigger onboarding for new guest users
                    appState.isFirstLogin = true
                }

            } catch {
                print("❌ Failed to create guest user completely: \(error.localizedDescription)")

                // Try a different approach - create a local-only guest mode
                print("Falling back to local-only guest mode")
                DispatchQueue.main.async {
                    appState.enableGuestMode()
                    appState.isFirstLogin = true
                }
            }
        }
    }

    // MARK: - Adaptive Layout Helpers

    /// Calculate adaptive font size based on screen height
    private func adaptiveFontSize(base: CGFloat, geometry: GeometryProxy) -> CGFloat {
        let screenHeight = geometry.size.height
        let scaleFactor = screenHeight / 844.0 // iPhone 14 Pro height as baseline
        return max(base * scaleFactor, base * 0.8) // Minimum 80% of base size
    }

    /// Calculate adaptive spacing based on screen height
    private func adaptiveSpacing(base: CGFloat, geometry: GeometryProxy) -> CGFloat {
        let screenHeight = geometry.size.height
        let scaleFactor = screenHeight / 844.0
        return max(base * scaleFactor, base * 0.6) // Minimum 60% of base spacing
    }

    /// Calculate adaptive top padding
    private func adaptiveTopPadding(geometry: GeometryProxy) -> CGFloat {
        let screenHeight = geometry.size.height
        let safeAreaTop = geometry.safeAreaInsets.top

        // For shorter screens (like 16:9), reduce top padding significantly
        if screenHeight < 750 {
            return max(safeAreaTop + 20, 40)
        } else if screenHeight < 800 {
            return max(safeAreaTop + 40, 60)
        } else {
            return max(safeAreaTop + 60, 80)
        }
    }

    /// Calculate adaptive bottom padding
    private func adaptiveBottomPadding(geometry: GeometryProxy) -> CGFloat {
        let screenHeight = geometry.size.height
        let safeAreaBottom = geometry.safeAreaInsets.bottom

        // For shorter screens, reduce bottom padding
        if screenHeight < 750 {
            return max(safeAreaBottom + 20, 30)
        } else {
            return max(safeAreaBottom + 30, 40)
        }
    }

    /// Calculate adaptive carousel height
    private func adaptiveCarouselHeight(geometry: GeometryProxy) -> CGFloat {
        let screenHeight = geometry.size.height

        // Adjust carousel height based on available screen space
        if screenHeight < 750 {
            // For 16:9 displays and shorter screens
            return min(screenHeight * 0.35, 280)
        } else if screenHeight < 800 {
            return min(screenHeight * 0.4, 320)
        } else {
            return min(screenHeight * 0.45, 400)
        }
    }
}

private struct ConditionalGlassButtonModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .buttonStyle(GlassProminentButtonStyle())
                .shadow(color: colorScheme == .dark ? .white.opacity(0.1) : .black.opacity(0.05), radius: 10, x: 0, y: 4)
        } else {
            content
                .buttonStyle(.borderedProminent)
                .tint(colorScheme == .dark ? Color(hex: "1F2937") : Color(hex: "3B82F6"))
                .shadow(color: colorScheme == .dark ? .white.opacity(0.1) : .black.opacity(0.05), radius: 10, x: 0, y: 4)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}
