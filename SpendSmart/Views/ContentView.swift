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
        if isLoggedIn {
            DashboardView(email: userEmail, onSignOut: {
                isLoggedIn = false
                userEmail = ""
            })
        } else {
            ZStack {
                backgroundColor
                
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
                
                print(session)
                
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

// Add this struct for custom Apple button style
struct CustomSignInWithAppleButton: View {
    let action: (Result<ASAuthorization, Error>) -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        if colorScheme == .dark {
            SignInWithAppleButton(.continue) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                action(result)
            }
            .signInWithAppleButtonStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .cornerRadius(12)
        } else {
            SignInWithAppleButton(.continue) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                action(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .cornerRadius(12)
        }
    }
}

// Feature item model
struct FeatureItem {
    let icon: String
    let title: String
    let description: String
}

// Feature card view
struct FeatureView: View {
    let feature: FeatureItem
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon with background
            ZStack {
                Circle()
                    .fill(colorScheme == .dark ? Color(hex: "1E293B") : Color(hex: "F1F5F9"))
                    .frame(width: 100, height: 100)
                
                Image(systemName: feature.icon)
                    .font(.system(size: 40))
                    .foregroundColor(colorScheme == .dark ? Color(hex: "60A5FA") : Color(hex: "3B82F6"))
            }
            .padding(.bottom, 6)
            
            Text(feature.title)
                .font(.instrumentSans(size: 22))
                .fontWeight(.semibold)
                .foregroundColor(colorScheme == .dark ? .white : Color(hex: "1E293B"))
                .multilineTextAlignment(.center)
            
            Text(feature.description)
                .font(.instrumentSans(size: 16))
                .foregroundColor(colorScheme == .dark ? Color.gray : Color(hex: "64748B"))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 270)
            
            // Visual illustration specific to the feature
            featureIllustration
                .padding(.top, 15)
        }
        .padding(.horizontal, 20)
    }
    
    // Different illustration for each feature
    private var featureIllustration: some View {
        VStack {
            if feature.icon == "doc.text.viewfinder" {
                // Receipt scanning illustration
                HStack(spacing: 15) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 42))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 24))
                    Image(systemName: "checklist")
                        .font(.system(size: 42))
                }
                .foregroundColor(colorScheme == .dark ? Color(hex: "94A3B8") : Color(hex: "64748B"))
            } else if feature.icon == "folder.badge.gearshape" {
                // Organization illustration
                HStack(spacing: 10) {
                    ForEach(0..<3) { i in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(colorScheme == .dark ? Color(hex: "334155") : Color(hex: "E2E8F0"))
                            .frame(width: 70, height: 90)
                            .overlay(
                                VStack {
                                    Image(systemName: ["cart", "fork.knife", "car"][i])
                                        .font(.system(size: 24))
                                        .padding(.bottom, 5)
                                    Text(["Groceries", "Dining", "Transport"][i])
                                        .font(.instrumentSans(size: 12))
                                }
                                .foregroundColor(colorScheme == .dark ? Color(hex: "94A3B8") : Color(hex: "64748B"))
                            )
                    }
                }
            } else if feature.icon == "chart.pie.fill" {
                // Analytics illustration
                HStack(spacing: 15) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colorScheme == .dark ? Color(hex: "334155") : Color(hex: "E2E8F0"))
                        .frame(width: 90, height: 90)
                        .overlay(
                            Image(systemName: "chart.pie.fill")
                                .font(.system(size: 42))
                                .foregroundColor(colorScheme == .dark ? Color(hex: "94A3B8") : Color(hex: "64748B"))
                        )
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colorScheme == .dark ? Color(hex: "334155") : Color(hex: "E2E8F0"))
                        .frame(width: 90, height: 90)
                        .overlay(
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 42))
                                .foregroundColor(colorScheme == .dark ? Color(hex: "94A3B8") : Color(hex: "64748B"))
                        )
                }
            } else {
                // Returns illustration
                HStack(spacing: 15) {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 42))
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 24))
                    Image(systemName: "creditcard")
                        .font(.system(size: 42))
                }
                .foregroundColor(colorScheme == .dark ? Color(hex: "94A3B8") : Color(hex: "64748B"))
            }
        }
    }
}

// Extension for hex color support
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    ContentView()
}
