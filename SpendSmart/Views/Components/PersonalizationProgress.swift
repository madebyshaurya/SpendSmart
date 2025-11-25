//
//  PersonalizationProgress.swift
//  SpendSmart
//
//  Created by Claude on 2025-01-25.
//  Personalization progress circle with smooth animations
//

import SwiftUI

// MARK: - Personalization Progress Circle
struct PersonalizationProgress: View {
    let progress: Double
    @State private var animatedProgress: Double = 0
    @State private var rotation: Double = 0
    
    private let circleSize: CGFloat = 160
    private let strokeWidth: CGFloat = 12
    
    var body: some View {
        VStack(spacing: 32) {
            // Progress Circle
            ZStack {
                // Background circle
                Circle()
                    .stroke(
                        Color.primary.opacity(0.12),
                        lineWidth: strokeWidth
                    )
                    .frame(width: circleSize, height: circleSize)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.primary,
                                Color.primary.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(
                            lineWidth: strokeWidth,
                            lineCap: .round
                        )
                    )
                    .frame(width: circleSize, height: circleSize)
                    .rotationEffect(.degrees(-90))
                    .animation(
                        .spring(response: 1.0, dampingFraction: 0.8),
                        value: animatedProgress
                    )
                
                // Center content
                VStack(spacing: 8) {
                    // Animated sparkle icon
                    Image(systemName: "sparkles")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(.primary)
                        .rotationEffect(.degrees(rotation))
                        .animation(
                            .linear(duration: 3)
                            .repeatForever(autoreverses: false),
                            value: rotation
                        )
                    
                    // Percentage text
                    Text("\(Int(progress * 100))%")
                        .font(.instrumentSans(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                        .contentTransition(.numericText())
                }
            }
            
            // Status text
            VStack(spacing: 12) {
                Text("Personalizing for you")
                    .font(.hierarchyTitle(level: 2))
                    .foregroundColor(.primary)
                
                Text(statusMessage(for: progress))
                    .font(.hierarchyBody(emphasis: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .animation(.easeInOut(duration: 0.5), value: statusMessage(for: progress))
            }
        }
        .onAppear {
            withAnimation(.spring(response: 1.2, dampingFraction: 0.8)) {
                animatedProgress = progress
            }
            
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                animatedProgress = newValue
            }
        }
    }
    
    private func statusMessage(for progress: Double) -> String {
        switch progress {
        case 0.0..<0.2:
            return "Analyzing your spending preferences..."
        case 0.2..<0.4:
            return "Setting up your financial goals..."
        case 0.4..<0.6:
            return "Customizing expense categories..."
        case 0.6..<0.8:
            return "Preparing personalized insights..."
        case 0.8..<1.0:
            return "Finalizing your experience..."
        default:
            return "Almost ready!"
        }
    }
}

// MARK: - Compact Progress Indicator
struct CompactProgress: View {
    let progress: Double
    let total: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index < Int(progress * Double(total)) ? Color.primary : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .scaleEffect(index < Int(progress * Double(total)) ? 1.2 : 1.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: progress)
            }
        }
    }
}

// MARK: - Step Progress Header
struct StepProgressHeader: View {
    let currentStep: Int
    let totalSteps: Int
    let title: String
    let subtitle: String?
    let onBack: () -> Void
    @Namespace private var progressNamespace
    
    var body: some View {
        VStack(spacing: 0) {
            // Top bar with back button and progress
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
                
                Spacer()
                // Invisible spacer for balance
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 44, height: 44)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            
            // Premium segmented progress (thin capsule)
            GeometryReader { proxy in
                let width = proxy.size.width
                let progress = max(0, min(1, Double(currentStep) / Double(max(totalSteps, 1))))
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.25))
                        .frame(height: 4)
                    Capsule()
                        .fill(Color.primary)
                        .frame(width: width * progress, height: 4)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            
            // Title and subtitle
            VStack(spacing: 12) {
                Text(title)
                    .font(.hierarchyTitle(level: 1))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.hierarchyBody(emphasis: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            .padding(.top, 32)
        }
    }
}

// MARK: - Preview Provider
#Preview("Personalization Progress") {
    VStack {
        PersonalizationProgress(progress: 0.7)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}

#Preview("Step Progress Header") {
    StepProgressHeader(
        currentStep: 3,
        totalSteps: 8,
        title: "What are your financial goals?",
        subtitle: "Select all that apply"
    ) {
        // Back action
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}
