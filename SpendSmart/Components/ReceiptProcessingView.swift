//
//  ReceiptProcessingView.swift
//  SpendSmart
//
//  Contextual progress indicator for receipt processing.
//  Shows specific steps instead of generic "loading..." - users want to know what's happening.
//

import SwiftUI

// MARK: - Processing Step

enum ProcessingStep: Int, CaseIterable {
    case scanning = 0
    case extracting = 1
    case identifying = 2
    case categorizing = 3
    case calculating = 4
    case complete = 5
    
    var title: String {
        switch self {
        case .scanning: return "Scanning receipt..."
        case .extracting: return "Extracting text..."
        case .identifying: return "Identifying items..."
        case .categorizing: return "Categorizing purchases..."
        case .calculating: return "Calculating totals..."
        case .complete: return "Almost done!"
        }
    }
    
    var icon: String {
        switch self {
        case .scanning: return "doc.viewfinder"
        case .extracting: return "text.viewfinder"
        case .identifying: return "list.bullet.rectangle"
        case .categorizing: return "tag"
        case .calculating: return "sum"
        case .complete: return "checkmark.circle"
        }
    }
    
    var progress: Double {
        Double(rawValue + 1) / Double(ProcessingStep.allCases.count)
    }
}

// MARK: - Receipt Processing View

/// Enhanced processing view with contextual progress steps
struct ReceiptProcessingView: View {
    let pageCount: Int
    @State private var currentStep: ProcessingStep = .scanning
    @State private var animateIcon: Bool = false
    @State private var tipIndex: Int = Int.random(in: 0..<SpendingTips.tips.count)
    
    private var currentTip: (icon: String, title: String, content: String) {
        SpendingTips.forIndex(tipIndex)
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Animated icon with rings
            iconSection
            
            // Title
            Text("Analyzing Receipt")
                .font(.instrumentSerifItalic(size: 28))
                .foregroundStyle(Color.brandTextPrimary)
            
            // Step progress
            stepProgressSection
            
            // Page count
            if pageCount > 1 {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: 12))
                    Text("\(pageCount) pages captured")
                        .font(.manrope(size: 13, weight: .medium))
                }
                .foregroundStyle(Color.brandTextTertiary)
            }
            
            Spacer()
            
            // Educational tip
            tipCard
                .padding(.bottom, 40)
        }
        .padding(.horizontal, 24)
        .onAppear {
            startProgressSimulation()
        }
    }
    
    // MARK: - Icon Section
    
    private var iconSection: some View {
        ZStack {
            // Outer pulsing ring
            Circle()
                .stroke(Color.brandVibrantBlue.opacity(0.2), lineWidth: 2)
                .frame(width: 140, height: 140)
                .scaleEffect(animateIcon ? 1.1 : 1.0)
                .opacity(animateIcon ? 0.5 : 1.0)
            
            // Inner ring
            Circle()
                .fill(Color.brandAccentLight)
                .frame(width: 120, height: 120)
            
            // Progress ring
            Circle()
                .trim(from: 0, to: currentStep.progress)
                .stroke(
                    LinearGradient(
                        colors: [Color.brandVibrantBlue, Color.brandSkyBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: currentStep)
            
            // Icon
            Image(systemName: currentStep.icon)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Color.brandVibrantBlue)
                .symbolEffect(.variableColor.iterative)
                .contentTransition(.symbolEffect(.replace))
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                animateIcon = true
            }
        }
    }
    
    // MARK: - Step Progress Section
    
    private var stepProgressSection: some View {
        VStack(spacing: 16) {
            // Current step text
            HStack(spacing: 8) {
                Image(systemName: currentStep.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.brandVibrantBlue)
                
                Text(currentStep.title)
                    .font(.manrope(size: 15, weight: .medium))
                    .foregroundStyle(Color.brandTextSecondary)
                    .animation(.easeInOut, value: currentStep)
            }
            
            // Progress bar with percentage
            VStack(spacing: 6) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.brandBorder)
                            .frame(height: 8)
                        
                        // Progress
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [Color.brandVibrantBlue, Color.brandSkyBlue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * currentStep.progress, height: 8)
                            .animation(.easeInOut(duration: 0.5), value: currentStep)
                    }
                }
                .frame(height: 8)
                .frame(width: 220)
                
                Text("\(Int(currentStep.progress * 100))% complete")
                    .font(.ibmPlexMono(size: 12))
                    .foregroundStyle(Color.brandTextTertiary)
            }
            
            // Step indicators
            HStack(spacing: 8) {
                ForEach(ProcessingStep.allCases.dropLast(), id: \.rawValue) { step in
                    Circle()
                        .fill(step.rawValue <= currentStep.rawValue ? Color.brandVibrantBlue : Color.brandBorder)
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                }
            }
        }
    }
    
    // MARK: - Tip Card
    
    private var tipCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.brandVibrantBlue.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: currentTip.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.brandVibrantBlue)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(currentTip.title)
                    .font(.manrope(size: 12, weight: .bold))
                    .foregroundStyle(Color.brandTextPrimary)
                
                Text(currentTip.content)
                    .font(.manrope(size: 11, weight: .regular))
                    .foregroundStyle(Color.brandTextSecondary)
                    .lineLimit(2)
            }
            
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.brandSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.brandBorder, lineWidth: 1)
                )
        )
    }
    
    // MARK: - Progress Simulation
    
    private func startProgressSimulation() {
        // Simulate realistic processing steps
        // In real use, this would be tied to actual processing callbacks
        let stepDurations: [TimeInterval] = [0.8, 1.2, 1.5, 1.0, 0.8]
        var totalDelay: TimeInterval = 0
        
        for (index, duration) in stepDurations.enumerated() {
            totalDelay += duration
            DispatchQueue.main.asyncAfter(deadline: .now() + totalDelay) {
                if let nextStep = ProcessingStep(rawValue: index + 1) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep = nextStep
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Receipt Processing") {
    ReceiptProcessingView(pageCount: 1)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.brandBackground)
}

#Preview("Multi-page Processing") {
    ReceiptProcessingView(pageCount: 3)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.brandBackground)
}
