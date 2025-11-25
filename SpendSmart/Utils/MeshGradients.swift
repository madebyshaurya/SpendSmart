//
//  MeshGradients.swift
//  SpendSmart
//
//  Created by Claude on 2025-01-25.
//  Version-aware gradient system for iOS 18+ mesh gradients with fallbacks
//

import SwiftUI

// MARK: - Adaptive Gradient System
struct AdaptiveMeshGradient {
    
    // MARK: - Onboarding Gradient Presets
    
    /// Neutral, modern gradient for onboarding welcome screen
    @ViewBuilder
    static func onboardingWelcome() -> some View {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.08, blue: 0.10), // Near-black
                Color(red: 0.12, green: 0.13, blue: 0.16), // Graphite
                Color(red: 0.15, green: 0.16, blue: 0.20)  // Slate
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    /// Neutral gradient for general selection steps
    @ViewBuilder
    static func ageSelection() -> some View {
        LinearGradient(
            colors: [
                Color(red: 0.10, green: 0.11, blue: 0.14),
                Color(red: 0.12, green: 0.13, blue: 0.16)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    /// Gradient for preferences steps
    @ViewBuilder
    static func goalsSelection() -> some View {
        LinearGradient(
            colors: [
                Color(red: 0.09, green: 0.10, blue: 0.12),
                Color(red: 0.12, green: 0.13, blue: 0.16)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    /// Completion screen with personalization progress
    @ViewBuilder
    static func completion() -> some View {
        LinearGradient(
            colors: [
                Color(red: 0.10, green: 0.11, blue: 0.14),
                Color(red: 0.12, green: 0.13, blue: 0.16)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Animated Mesh Gradients
    
    /// Animated mesh gradient for enhanced visual appeal
    @available(iOS 18.0, *)
    struct AnimatedMeshGradient: View {
        @State private var phase: Double = 0
        
        private let baseColors: [Color] = [
            Color(red: 0.7, green: 0.5, blue: 0.9),
            Color(red: 0.4, green: 0.8, blue: 0.95),
            Color(red: 0.3, green: 0.9, blue: 0.8),
            Color(red: 0.5, green: 0.7, blue: 0.9),
            Color(red: 0.4, green: 0.85, blue: 0.8),
            Color(red: 0.6, green: 0.8, blue: 0.9),
            Color(red: 0.9, green: 0.7, blue: 0.5),
            Color(red: 0.7, green: 0.9, blue: 0.6),
            Color(red: 0.4, green: 0.9, blue: 0.9)
        ]
        
        var body: some View {
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                
                MeshGradient(
                    width: 3, height: 3,
                    points: animatedPoints(for: time),
                    colors: animatedColors(for: time)
                )
                .ignoresSafeArea()
            }
        }
        
        private func animatedPoints(for time: TimeInterval) -> [SIMD2<Float>] {
            let speed: Float = 0.3
            let amplitude: Float = 0.1
            
            return [
                SIMD2<Float>(0 + sin(Float(time) * speed) * amplitude * 0.5, 
                            0 + cos(Float(time) * speed * 0.7) * amplitude * 0.5),
                SIMD2<Float>(0.5 + sin(Float(time) * speed * 1.1) * amplitude, 0),
                SIMD2<Float>(1 - sin(Float(time) * speed * 0.9) * amplitude * 0.5, 
                            0 + cos(Float(time) * speed * 1.2) * amplitude * 0.5),
                            
                SIMD2<Float>(0, 0.5 + sin(Float(time) * speed * 0.8) * amplitude),
                SIMD2<Float>(0.5 + cos(Float(time) * speed * 1.3) * amplitude, 
                            0.5 + sin(Float(time) * speed * 0.6) * amplitude),
                SIMD2<Float>(1, 0.5 + cos(Float(time) * speed * 1.1) * amplitude),
                
                SIMD2<Float>(0 + sin(Float(time) * speed * 1.2) * amplitude * 0.5, 
                            1 - cos(Float(time) * speed * 0.9) * amplitude * 0.5),
                SIMD2<Float>(0.5 + cos(Float(time) * speed * 0.7) * amplitude, 1),
                SIMD2<Float>(1 - sin(Float(time) * speed * 1.4) * amplitude * 0.5, 
                            1 - cos(Float(time) * speed * 1.1) * amplitude * 0.5)
            ]
        }
        
        private func animatedColors(for time: TimeInterval) -> [Color] {
            // Subtle color transitions for smooth animation
            return baseColors
        }
    }
}

// MARK: - Gradient Step Enum
enum OnboardingGradientStep: CaseIterable {
    case welcome
    case preferences
    case currency
    case completion
    
    @ViewBuilder
    func gradient() -> some View {
        switch self {
        case .welcome:
            AdaptiveMeshGradient.onboardingWelcome()
        case .preferences:
            AdaptiveMeshGradient.goalsSelection()
        case .currency:
            AdaptiveMeshGradient.ageSelection()
        case .completion:
            AdaptiveMeshGradient.completion()
        }
    }
}

// MARK: - Helper Extensions
extension View {
    /// Apply adaptive gradient background based on onboarding step
    func onboardingBackground(step: OnboardingGradientStep) -> some View {
        ZStack {
            step.gradient()
            self
        }
    }
    
    /// Apply animated mesh gradient background (iOS 18+)
    @ViewBuilder
    func animatedMeshBackground() -> some View {
        if #available(iOS 18.0, *) {
            ZStack {
                AdaptiveMeshGradient.AnimatedMeshGradient()
                self
            }
        } else {
            ZStack {
                AdaptiveMeshGradient.onboardingWelcome()
                self
            }
        }
    }
}
