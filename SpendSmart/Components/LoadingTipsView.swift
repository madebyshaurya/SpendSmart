//
//  LoadingTipsView.swift
//  SpendSmart
//
//  Educational micro-content displayed during loading states.
//  Makes waiting feel productive - users learn instead of getting frustrated.
//

import SwiftUI

// MARK: - Spending Tips

/// Collection of helpful spending tips and fun facts
struct SpendingTips {
    static let tips: [(icon: String, title: String, content: String)] = [
        ("chart.line.uptrend.xyaxis", "Track Patterns", "People who track their spending save an average of 20% more than those who don't."),
        ("camera.fill", "Scan Promptly", "Scan receipts right after purchase for the most accurate categorization."),
        ("tag.fill", "Watch for Savings", "SpendSmart automatically detects discounts and coupons on your receipts."),
        ("calendar", "Weekly Reviews", "Reviewing your spending weekly helps identify areas to cut back."),
        ("dollarsign.circle", "Budget Rule", "The 50/30/20 rule: 50% needs, 30% wants, 20% savings."),
        ("lightbulb.fill", "Smart Insight", "Your spending patterns can reveal habits you didn't know you had."),
        ("gift.fill", "Hidden Costs", "Small daily purchases can add up to thousands per year."),
        ("leaf.fill", "Sustainable Spending", "Tracking expenses helps reduce impulse purchases by 32%."),
        ("star.fill", "Pro Tip", "Categorizing purchases helps identify your biggest spending areas."),
        ("brain.head.profile", "Did You Know?", "Visual spending data improves financial decision-making by 40%."),
        ("clock.fill", "Timing Matters", "Most overspending happens between 6-9 PM. Plan ahead!"),
        ("sparkles", "AI Power", "Our AI can extract 15+ data points from a single receipt scan."),
    ]
    
    static func random() -> (icon: String, title: String, content: String) {
        tips.randomElement() ?? tips[0]
    }
    
    static func forIndex(_ index: Int) -> (icon: String, title: String, content: String) {
        tips[index % tips.count]
    }
}

// MARK: - Loading Tips View

/// Displays rotating educational tips during loading states
struct LoadingTipsView: View {
    @State private var currentTipIndex: Int = Int.random(in: 0..<SpendingTips.tips.count)
    @State private var isAnimating: Bool = false
    @State private var opacity: Double = 1.0
    
    let rotationInterval: TimeInterval
    let showProgressIndicator: Bool
    
    init(rotationInterval: TimeInterval = 4.0, showProgressIndicator: Bool = true) {
        self.rotationInterval = rotationInterval
        self.showProgressIndicator = showProgressIndicator
    }
    
    private var currentTip: (icon: String, title: String, content: String) {
        SpendingTips.forIndex(currentTipIndex)
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Optional progress indicator
            if showProgressIndicator {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .brandVibrantBlue))
                    .scaleEffect(1.2)
            }
            
            // Tip card
            tipCard
                .opacity(opacity)
                .animation(.easeInOut(duration: 0.3), value: opacity)
        }
        .onAppear {
            startRotation()
        }
    }
    
    private var tipCard: some View {
        VStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.brandVibrantBlue.opacity(0.1))
                    .frame(width: 56, height: 56)
                
                Image(systemName: currentTip.icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(Color.brandVibrantBlue)
            }
            
            // Title
            Text(currentTip.title)
                .font(.manrope(size: 14, weight: .bold))
                .foregroundStyle(Color.brandTextPrimary)
            
            // Content
            Text(currentTip.content)
                .font(.manrope(size: 13, weight: .regular))
                .foregroundStyle(Color.brandTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: 300)
    }
    
    private func startRotation() {
        Timer.scheduledTimer(withTimeInterval: rotationInterval, repeats: true) { _ in
            // Fade out
            withAnimation(.easeOut(duration: 0.3)) {
                opacity = 0
            }
            
            // Change tip and fade in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                currentTipIndex = (currentTipIndex + 1) % SpendingTips.tips.count
                withAnimation(.easeIn(duration: 0.3)) {
                    opacity = 1
                }
            }
        }
    }
}

// MARK: - Compact Loading Tip

/// A more compact version for inline use
struct CompactLoadingTip: View {
    @State private var currentTipIndex: Int = Int.random(in: 0..<SpendingTips.tips.count)
    
    private var currentTip: (icon: String, title: String, content: String) {
        SpendingTips.forIndex(currentTipIndex)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: currentTip.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.brandVibrantBlue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(currentTip.title)
                    .font(.manrope(size: 12, weight: .semibold))
                    .foregroundStyle(Color.brandTextPrimary)
                
                Text(currentTip.content)
                    .font(.manrope(size: 11, weight: .regular))
                    .foregroundStyle(Color.brandTextSecondary)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.brandAccentLight)
        )
    }
}

// MARK: - Processing Tips View

/// Shows tips specifically during receipt processing
struct ProcessingTipsView: View {
    let tips = [
        "Our AI is extracting text from your receipt...",
        "Identifying items and prices...",
        "Categorizing your purchases...",
        "Detecting discounts and savings...",
        "Calculating totals and taxes...",
    ]
    
    @State private var currentStep: Int = 0
    @State private var progress: Double = 0
    
    var body: some View {
        VStack(spacing: 20) {
            // Animated icon
            ZStack {
                Circle()
                    .fill(Color.brandAccentLight)
                    .frame(width: 100, height: 100)
                
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(Color.brandVibrantBlue)
                    .symbolEffect(.breathe)
            }
            
            // Progress text
            VStack(spacing: 8) {
                Text("Analyzing Receipt")
                    .font(.manrope(size: 18, weight: .bold))
                    .foregroundStyle(Color.brandTextPrimary)
                
                Text(tips[currentStep])
                    .font(.manrope(size: 14, weight: .regular))
                    .foregroundStyle(Color.brandTextSecondary)
                    .multilineTextAlignment(.center)
                    .animation(.easeInOut, value: currentStep)
            }
            
            // Progress bar
            VStack(spacing: 6) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.brandBorder)
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [Color.brandVibrantBlue, Color.brandSkyBlue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * progress, height: 6)
                            .animation(.easeInOut(duration: 0.3), value: progress)
                    }
                }
                .frame(height: 6)
                
                Text("\(Int(progress * 100))%")
                    .font(.ibmPlexMono(size: 12))
                    .foregroundStyle(Color.brandTextTertiary)
            }
            .frame(width: 200)
            
            // Tip of the day
            CompactLoadingTip()
                .padding(.top, 16)
        }
        .padding(24)
        .onAppear {
            startProgressSimulation()
        }
    }
    
    private func startProgressSimulation() {
        // Simulate progress through steps
        Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { timer in
            if currentStep < tips.count - 1 {
                withAnimation {
                    currentStep += 1
                    progress = Double(currentStep + 1) / Double(tips.count)
                }
            }
        }
        
        // Start initial progress
        withAnimation {
            progress = 0.2
        }
    }
}

// MARK: - Preview

#Preview("Loading Tips") {
    LoadingTipsView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.brandBackground)
}

#Preview("Compact Tip") {
    CompactLoadingTip()
        .padding()
}

#Preview("Processing Tips") {
    ProcessingTipsView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.brandBackground)
}
