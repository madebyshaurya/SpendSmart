//
//  BrandLoadingIndicator.swift
//  SpendSmart
//
//  Beautiful loading indicators with brand styling.
//

import SwiftUI

// MARK: - Brand Loading Indicator

struct BrandLoadingIndicator: View {
    var size: CGFloat = 48
    var lineWidth: CGFloat = 4
    var color: Color = .brandVibrantBlue
    
    @State private var rotation: Double = 0
    @State private var trimEnd: CGFloat = 0.3
    
    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)
                .frame(width: size, height: size)
            
            // Animated arc
            Circle()
                .trim(from: 0, to: trimEnd)
                .stroke(
                    AngularGradient(
                        colors: [color.opacity(0.1), color],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(rotation))
        }
        .onAppear {
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                trimEnd = 0.7
            }
        }
    }
}

// MARK: - Dots Loading Indicator

struct DotsLoadingIndicator: View {
    var dotSize: CGFloat = 10
    var spacing: CGFloat = 8
    var color: Color = .brandVibrantBlue
    
    @State private var animatingIndex = 0
    
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(color)
                    .frame(width: dotSize, height: dotSize)
                    .scaleEffect(animatingIndex == index ? 1.3 : 0.8)
                    .opacity(animatingIndex == index ? 1.0 : 0.4)
            }
        }
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        withAnimation(.easeInOut(duration: 0.3)) {
            animatingIndex = 0
        }
        
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { timer in
            withAnimation(.easeInOut(duration: 0.3)) {
                animatingIndex = (animatingIndex + 1) % 3
            }
        }
    }
}

// MARK: - Pulse Loading Indicator

struct PulseLoadingIndicator: View {
    var size: CGFloat = 60
    var color: Color = .brandVibrantBlue
    
    @State private var scale1: CGFloat = 0.5
    @State private var scale2: CGFloat = 0.5
    @State private var opacity1: Double = 0.8
    @State private var opacity2: Double = 0.8
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .scaleEffect(scale1)
                .opacity(opacity1)
            
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .scaleEffect(scale2)
                .opacity(opacity2)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                scale1 = 1.5
                opacity1 = 0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                    scale2 = 1.5
                    opacity2 = 0
                }
            }
        }
    }
}

// MARK: - Full Screen Loading

struct FullScreenLoading: View {
    var title: String = "Loading..."
    var message: String? = nil
    
    @State private var dotCount = 0
    
    var body: some View {
        ZStack {
            Color.brandBackground
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                BrandLoadingIndicator(size: 56, lineWidth: 5)
                
                VStack(spacing: 8) {
                    Text(animatedTitle)
                        .font(.manrope(size: 18, weight: .semibold))
                        .foregroundStyle(Color.brandTextPrimary)
                    
                    if let message = message {
                        Text(message)
                            .font(.manrope(size: 14))
                            .foregroundStyle(Color.brandTextSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
        .onAppear {
            startDotAnimation()
        }
    }
    
    private var animatedTitle: String {
        let dots = String(repeating: ".", count: dotCount)
        return title + dots
    }
    
    private func startDotAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            dotCount = (dotCount + 1) % 4
        }
    }
}

// MARK: - Inline Loading

struct InlineLoading: View {
    var text: String = "Loading"
    var size: CGFloat = 16
    
    var body: some View {
        HStack(spacing: 10) {
            BrandLoadingIndicator(size: size, lineWidth: 2)
            
            Text(text)
                .font(.manrope(size: 14, weight: .medium))
                .foregroundStyle(Color.brandTextSecondary)
        }
    }
}

// MARK: - Previews

#Preview("Loading Indicators") {
    VStack(spacing: 40) {
        BrandLoadingIndicator()
        
        DotsLoadingIndicator()
        
        PulseLoadingIndicator()
        
        InlineLoading(text: "Saving receipt")
    }
    .padding()
    .background(Color.brandBackground)
}

#Preview("Full Screen") {
    FullScreenLoading(
        title: "Processing",
        message: "Analyzing your receipt with AI"
    )
}

#Preview("Skeleton") {
    VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 12) {
            SkeletonCircle()
            VStack(alignment: .leading, spacing: 8) {
                SkeletonRect(width: 150, height: 16)
                SkeletonRect(width: 100, height: 12)
            }
        }
        
        SkeletonRect(height: 120, cornerRadius: 12)
        
        HStack(spacing: 12) {
            SkeletonRect(height: 80, cornerRadius: 8)
            SkeletonRect(height: 80, cornerRadius: 8)
        }
    }
    .padding()
}
