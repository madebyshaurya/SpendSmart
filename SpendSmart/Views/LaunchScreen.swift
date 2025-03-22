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
    
    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea(.all)
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("SpendSmart")
                        .font(.instrumentSerifItalic(size: 42))
                        .bold()
                        .foregroundColor(colorScheme == .dark ? .white : Color(hex: "1E293B"))
                    Text("Less clutter, more clarity.")
                        .font(.instrumentSans(size: 16))
                        .foregroundColor(colorScheme == .dark ? .gray : Color(hex: "64748B"))
                        .padding(.bottom, 20)
                    
                    // AI Pill Badge
                    Text("AI-POWERED • 100% FREE")
                        .font(.instrumentSans(size: 12))
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(colorScheme == .dark ? Color(hex: "3B82F6").opacity(0.2) : Color(hex: "DBEAFE"))
                        )
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
                .padding(.top, 80)
                
                // Feature carousel
                TabView(selection: $currentPage) {
                    ForEach(0..<features.count, id: \.self) { index in
                        FeatureView(feature: features[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(height: 400)
                .padding(.top, 24)
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
                .padding(.top, 20)
                
                Spacer()
                
                // Sign in button - at bottom
                VStack(spacing: 20) {
                    CustomSignInWithAppleButton { result in
                        switch result {
                        case .success(let authResults):
                            handleSignInWithApple(authResults)
                        case .failure(let error):
                            print("Sign in with Apple failed: \(error.localizedDescription)")
                        }
                    }
                    .shadow(color: colorScheme == .dark ? .white.opacity(0.1) : .black.opacity(0.05), radius: 10, x: 0, y: 4)
                    
                    Text("No in-app purchases or ads. We respect your privacy.")
                        .font(.instrumentSans(size: 12))
                        .foregroundColor(colorScheme == .dark ? .gray : Color(hex: "64748B"))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
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
    }
    
    private var backgroundColor: some View {
        colorScheme == .dark ?
        Color(hex: "0A0A0A").edgesIgnoringSafeArea(.all) :
        Color(hex: "F8FAFC").edgesIgnoringSafeArea(.all)
    }
    
    private func checkForExistingSession() {
        // Check if there's an active session
        if let user = supabase.auth.currentUser {
            DispatchQueue.main.async {
                appState.userEmail = user.email ?? "No Email"
                appState.isLoggedIn = true
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
                
                print(session.user.id)
//                self.userId = session.user.id
                
                if let user = supabase.auth.currentUser {
                    DispatchQueue.main.async {
                        appState.userEmail = user.email ?? "No Email"
                        appState.isLoggedIn = true
                    }
                }
                
                print("✅ Successfully signed in with Apple via Supabase!")
                
            } catch {
                print("❌ Supabase authentication failed: \(error.localizedDescription)")
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
}
