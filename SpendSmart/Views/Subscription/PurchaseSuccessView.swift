//
//  PurchaseSuccessView.swift
//  SpendSmart
//
//  Celebratory success screen shown after upgrading to Plus.
//  Features confetti animation, animated badge, and staggered feature reveals.
//

import SwiftUI
import Foundation

struct PurchaseSuccessView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var haptics = HapticManager.shared
    
    let onDismiss: () -> Void
    
    @State private var showConfetti = false
    @State private var badgeScale: CGFloat = 0
    @State private var badgeRotation: Double = -180
    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var featuresRevealed = false
    @State private var buttonOpacity: Double = 0
    @State private var confettiParticles: [ConfettiParticle] = []
    
    var body: some View {
        ZStack {
            // Background
            backgroundGradient
            
            // Confetti layer
            confettiOverlay
            
            // Content
            VStack(spacing: 32) {
                Spacer()
                
                // Animated Plus badge
                plusBadge
                
                // Title & subtitle
                VStack(spacing: 12) {
                    Text("Welcome to Plus!")
                        .font(.instrumentSerif(size: 36))
                        .foregroundStyle(Color.brandTextPrimary)
                        .opacity(titleOpacity)
                    
                    Text("You've unlocked the full SpendSmart experience")
                        .font(.manrope(size: 16))
                        .foregroundStyle(Color.brandTextSecondary)
                        .multilineTextAlignment(.center)
                        .opacity(subtitleOpacity)
                }
                .padding(.horizontal, 24)
                
                // Features unlocked
                unlockedFeatures
                    .padding(.top, 16)
                
                Spacer()
                
                // Continue button
                Button {
                    haptics.buttonPress()
                    onDismiss()
                } label: {
                    HStack(spacing: 10) {
                        Text("Start Exploring")
                            .font(.manrope(size: 18, weight: .bold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        MeshGradient.brandButton
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.brandVibrantBlue.opacity(0.4), radius: 12, y: 6)
                }
                .opacity(buttonOpacity)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        MeshGradient.brandSoft
            .ignoresSafeArea()
    }
    
    // MARK: - Confetti Overlay
    
    private var confettiOverlay: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(confettiParticles) { particle in
                    ConfettiPiece(particle: particle, containerSize: geometry.size)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
    
    // MARK: - Plus Badge
    
    private var plusBadge: some View {
        ZStack {
            glowRings
            badgeCircle
            badgeContent
            sparkles
        }
    }
    
    private var glowRings: some View {
        ForEach(0..<3, id: \.self) { ring in
            let ringOpacity = 0.15 - Double(ring) * 0.05
            let ringSize: CGFloat = 140 + CGFloat(ring * 30)
            let ringDelay = 0.3 + Double(ring) * 0.1
            
            Circle()
                .stroke(Color.brandVibrantBlue.opacity(ringOpacity), lineWidth: 2)
                .frame(width: ringSize, height: ringSize)
                .scaleEffect(showConfetti ? 1 : 0.5)
                .opacity(showConfetti ? 1 : 0)
                .animation(.spring(duration: 0.8).delay(ringDelay), value: showConfetti)
        }
    }
    
    private var badgeCircle: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color.brandVibrantBlue, Color.brandSkyBlue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 120, height: 120)
            .shadow(color: Color.brandVibrantBlue.opacity(0.5), radius: 20, y: 10)
            .scaleEffect(badgeScale)
            .rotationEffect(.degrees(badgeRotation))
    }
    
    private var badgeContent: some View {
        VStack(spacing: 4) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.white)
            
            Text("PLUS")
                .font(.manrope(size: 14, weight: .black))
                .foregroundStyle(.white)
        }
        .scaleEffect(badgeScale)
        .rotationEffect(.degrees(badgeRotation))
    }
    
    private var sparkles: some View {
        ForEach(0..<8, id: \.self) { i in
            let sparkleDelay = 0.5 + Double(i) * 0.05
            
            SparkleShape()
                .fill(sparkleColor(for: i))
                .frame(width: 12, height: 12)
                .offset(sparkleOffset(for: i))
                .scaleEffect(showConfetti ? 1 : 0)
                .opacity(showConfetti ? 1 : 0)
                .animation(.spring(duration: 0.5).delay(sparkleDelay), value: showConfetti)
        }
    }
    
    // MARK: - Unlocked Features
    
    private var unlockedFeatures: some View {
        VStack(spacing: 14) {
            ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                UnlockedFeatureRow(
                    icon: feature.icon,
                    title: feature.title,
                    isRevealed: featuresRevealed,
                    delay: Double(index) * 0.1
                )
            }
        }
        .padding(.horizontal, 32)
    }
    
    private var features: [(icon: String, title: String)] {
        [
            ("infinity", "Unlimited receipt scans"),
            ("icloud.fill", "Cloud backup & sync"),
            ("chart.bar.fill", "Advanced analytics"),
            ("magnifyingglass", "Powerful search"),
            ("sparkles", "Priority AI processing")
        ]
    }
    
    // MARK: - Animation Helpers
    
    private func startAnimations() {
        // Generate confetti particles
        generateConfetti()
        
        // Haptic feedback burst
        haptics.celebration()
        
        // Badge entrance (pop & spin)
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
            badgeScale = 1.0
            badgeRotation = 0
        }
        
        // Title fade in
        withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
            titleOpacity = 1
        }
        
        // Subtitle fade in
        withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
            subtitleOpacity = 1
        }
        
        // Start confetti
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            showConfetti = true
            haptics.medium()
        }
        
        // Features reveal
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(duration: 0.5)) {
                featuresRevealed = true
            }
        }
        
        // Button fade in
        withAnimation(.easeOut(duration: 0.5).delay(1.0)) {
            buttonOpacity = 1
        }
    }
    
    private func generateConfetti() {
        confettiParticles = (0..<60).map { _ in
            ConfettiParticle(
                x: CGFloat.random(in: 0...1),
                delay: Double.random(in: 0...0.5),
                scale: CGFloat.random(in: 0.5...1.2),
                rotation: Double.random(in: 0...360),
                color: confettiColors.randomElement() ?? .brandVibrantBlue
            )
        }
    }
    
    private var confettiColors: [Color] {
        [
            .brandVibrantBlue, .brandSkyBlue, .brandRoyalBlue,
            .brandSuccess, .brandWarning, .brandPurple,
            .brandPink, .brandCyan
        ]
    }
    
    private func sparkleOffset(for index: Int) -> CGSize {
        let angle = (Double(index) / 8.0) * 2 * .pi
        let radius: Double = 85
        return CGSize(
            width: Foundation.cos(angle) * radius,
            height: Foundation.sin(angle) * radius
        )
    }
    
    private func sparkleColor(for index: Int) -> Color {
        let colors: [Color] = [
            .brandVibrantBlue, .brandWarning, .brandSkyBlue,
            .brandSuccess, .brandRoyalBlue, .brandPurple,
            .brandVibrantBlue, .brandPink
        ]
        return colors[index % colors.count]
    }
}

// MARK: - Confetti Particle Model

struct ConfettiParticle: Identifiable {
    let id = UUID()
    let x: CGFloat
    let delay: Double
    let scale: CGFloat
    let rotation: Double
    let color: Color
}

// MARK: - Confetti Piece View

struct ConfettiPiece: View {
    let particle: ConfettiParticle
    let containerSize: CGSize
    
    @State private var animate = false
    
    private var pieceWidth: CGFloat { 10 * particle.scale }
    private var pieceHeight: CGFloat { 10 * particle.scale }
    private var rotation: Double { animate ? particle.rotation + 720 : particle.rotation }
    private var xPosition: CGFloat { containerSize.width * particle.x }
    private var yPosition: CGFloat { animate ? containerSize.height + 50 : -50 }
    private var pieceOpacity: Double { animate ? 0 : 1 }
    
    var body: some View {
        Group {
            switch Int.random(in: 0...2) {
            case 0:
                Circle()
                    .fill(particle.color)
            case 1:
                Rectangle()
                    .fill(particle.color)
            default:
                RoundedRectangle(cornerRadius: 2)
                    .fill(particle.color)
            }
        }
        .frame(width: pieceWidth, height: pieceHeight)
        .rotationEffect(Angle.degrees(rotation))
        .position(x: xPosition, y: yPosition)
        .opacity(pieceOpacity)
        .onAppear {
            let duration = Double.random(in: 2.5...4.0)
            withAnimation(.easeIn(duration: duration).delay(particle.delay)) {
                animate = true
            }
        }
    }
}

// MARK: - Sparkle Shape

struct SparkleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let points = 4
        let innerRadius = rect.width * 0.2
        let outerRadius = rect.width * 0.5
        
        for i in 0..<(points * 2) {
            let angle = (Double(i) / Double(points * 2)) * 2 * .pi - .pi / 2
            let radius = i % 2 == 0 ? outerRadius : innerRadius
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            )
            
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Unlocked Feature Row

private struct UnlockedFeatureRow: View {
    let icon: String
    let title: String
    let isRevealed: Bool
    let delay: Double
    
    @State private var checkmarkScale: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.brandAccentLight)
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.brandVibrantBlue)
            }
            
            // Title
            Text(title)
                .font(.manrope(size: 16, weight: .medium))
                .foregroundStyle(Color.brandTextPrimary)
            
            Spacer()
            
            // Animated checkmark
            ZStack {
                Circle()
                    .fill(Color.brandSuccess)
                    .frame(width: 28, height: 28)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(checkmarkScale)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
        )
        .opacity(isRevealed ? 1 : 0)
        .offset(x: isRevealed ? 0 : -30)
        .animation(.spring(duration: 0.5).delay(delay), value: isRevealed)
        .onChange(of: isRevealed) { _, revealed in
            if revealed {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(delay + 0.2)) {
                    checkmarkScale = 1
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    PurchaseSuccessView {
        print("Dismissed")
    }
}
