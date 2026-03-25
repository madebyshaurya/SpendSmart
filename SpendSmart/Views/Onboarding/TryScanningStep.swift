//
//  TryScanningStep.swift
//  SpendSmart
//
//  Onboarding step that lets users try scanning a sample receipt
//  to see how the AI extraction works.
//

import SwiftUI

// MARK: - Try Scanning Step

struct TryScanningStep: View {
    @Binding var shouldAdvance: Bool
    let onSkip: () -> Void
    
    @State private var selectedReceipt: SampleReceiptType? = nil
    @State private var currentPhase: ScanPhase = .selection
    @State private var processingProgress: Double = 0
    @State private var showResults = false
    
    @StateObject private var haptics = HapticManager.shared
    
    enum ScanPhase {
        case selection
        case processing
        case results
    }
    
    var body: some View {
        VStack(spacing: 0) {
            switch currentPhase {
            case .selection:
                selectionPhase
            case .processing:
                processingPhase
            case .results:
                resultsPhase
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: currentPhase)
    }
    
    // MARK: - Selection Phase
    
    private var selectionPhase: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Lottie placeholder (or SwiftUI animation)
            ZStack {
                Circle()
                    .fill(Color.brandSkyBlue.opacity(0.15))
                    .frame(width: 120, height: 120)
                
                Circle()
                    .fill(Color.brandSkyBlue.opacity(0.25))
                    .frame(width: 90, height: 90)
                
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(Color.brandSkyBlue)
            }
            
            VStack(spacing: 12) {
                Text("See How It Works")
                    .font(.instrumentSerif(size: 32))
                    .foregroundStyle(.white)
                
                Text("Try scanning a sample receipt and watch AI extract all the details automatically.")
                    .font(.manrope(size: 16, weight: .regular))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 24)
            
            // Receipt type selection
            VStack(spacing: 16) {
                Text("Choose a receipt type")
                    .font(.manrope(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                
                HStack(spacing: 16) {
                    ForEach(SampleReceiptType.allCases) { type in
                        SampleReceiptCard(
                            type: type,
                            isSelected: selectedReceipt == type
                        ) {
                            haptics.selection()
                            withAnimation(.spring(response: 0.3)) {
                                selectedReceipt = type
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 16) {
                // Try It button
                Button {
                    haptics.buttonPress()
                    startProcessing()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Try Scanning")
                            .font(.manrope(size: 16, weight: .bold))
                    }
                    .foregroundStyle(Color.brandDeepNavy)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(selectedReceipt != nil ? Color.white : Color.white.opacity(0.3))
                    )
                }
                .disabled(selectedReceipt == nil)
                .padding(.horizontal, 32)
                
                // Skip button
                Button {
                    haptics.selection()
                    onSkip()
                } label: {
                    Text("Skip for now")
                        .font(.manrope(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Processing Phase
    
    private var processingPhase: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Receipt image preview
            if let receiptType = selectedReceipt {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .frame(width: 200, height: 280)
                        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                    
                    // Try to load the actual image, fallback to placeholder
                    Image(receiptType.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 192, height: 272)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            // If image doesn't exist, show placeholder
                            receiptPlaceholder(for: receiptType)
                        )
                    
                    // Scanning overlay animation
                    scanningOverlay
                }
            }
            
            VStack(spacing: 16) {
                // Processing indicator
                HStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    
                    Text(processingText)
                        .font(.manrope(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                }
                
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.brandSkyBlue)
                            .frame(width: geo.size.width * processingProgress, height: 8)
                            .animation(.easeInOut(duration: 0.3), value: processingProgress)
                    }
                }
                .frame(height: 8)
                .padding(.horizontal, 60)
            }
            
            Spacer()
            Spacer()
        }
        .onAppear {
            simulateProcessing()
        }
    }
    
    private var processingText: String {
        switch processingProgress {
        case 0..<0.3: return "Analyzing receipt..."
        case 0.3..<0.5: return "Extracting items..."
        case 0.5..<0.7: return "Detecting prices..."
        case 0.7..<0.9: return "Categorizing items..."
        default: return "Almost done..."
        }
    }
    
    private var scanningOverlay: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.brandVibrantBlue.opacity(0.0),
                            Color.brandVibrantBlue.opacity(0.4),
                            Color.brandVibrantBlue.opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 40)
                .offset(y: scanLineOffset(in: geo.size.height))
                .animation(
                    .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                    value: processingProgress
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(width: 192, height: 272)
    }
    
    private func scanLineOffset(in height: CGFloat) -> CGFloat {
        let progress = (processingProgress * 2).truncatingRemainder(dividingBy: 1.0)
        return progress * (height - 40)
    }
    
    @ViewBuilder
    private func receiptPlaceholder(for type: SampleReceiptType) -> some View {
        // This shows if the image asset isn't found
        VStack(spacing: 8) {
            Text(type.emoji)
                .font(.system(size: 48))
            Text(type.displayName)
                .font(.manrope(size: 14, weight: .semibold))
                .foregroundStyle(Color.brandTextSecondary)
            Text("Sample Receipt")
                .font(.manrope(size: 11, weight: .medium))
                .foregroundStyle(Color.brandTextTertiary)
        }
        .frame(width: 192, height: 272)
        .background(Color.brandBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .opacity(UIImage(named: type.imageName) == nil ? 1 : 0) // Hide if image exists
    }
    
    // MARK: - Results Phase
    
    private var resultsPhase: some View {
        VStack(spacing: 0) {
            if let receiptType = selectedReceipt {
                let data = receiptType.sampleData
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Success header
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.brandSuccess.opacity(0.2))
                                    .frame(width: 70, height: 70)
                                
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(Color.brandSuccess)
                            }
                            
                            Text("AI Extracted Everything!")
                                .font(.instrumentSerif(size: 28))
                                .foregroundStyle(.white)
                            
                            Text("This is what SpendSmart captures from every receipt.")
                                .font(.manrope(size: 14, weight: .regular))
                                .foregroundStyle(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        
                        // Store info card
                        VStack(spacing: 16) {
                            HStack(spacing: 16) {
                                // Store logo
                                BrandLogoView(
                                    storeName: data.storeName,
                                    logoSearchTerm: data.logoSearchTerm
                                )
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(data.storeName)
                                        .font(.manrope(size: 18, weight: .bold))
                                        .foregroundStyle(Color.brandTextPrimary)
                                    
                                    Text(data.formattedDate)
                                        .font(.manrope(size: 13, weight: .medium))
                                        .foregroundStyle(Color.brandTextSecondary)
                                }
                                
                                Spacer()
                                
                                Text(formatCurrency(data.totalAmount))
                                    .font(.ibmPlexMono(size: 22))
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.brandVibrantBlue)
                            }
                            
                            Divider()
                            
                            // Items list
                            VStack(spacing: 8) {
                                ForEach(data.items) { item in
                                    HStack(spacing: 12) {
                                        Text(item.emoji)
                                            .font(.system(size: 20))
                                            .frame(width: 32)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.name)
                                                .font(.manrope(size: 14, weight: .medium))
                                                .foregroundStyle(item.isDiscount ? Color.brandSuccess : Color.brandTextPrimary)
                                                .lineLimit(1)
                                            
                                            Text(item.category)
                                                .font(.manrope(size: 11, weight: .medium))
                                                .foregroundStyle(Color.brandTextTertiary)
                                        }
                                        
                                        Spacer()
                                        
                                        Text(item.isDiscount ? "-\(formatCurrency(abs(item.price)))" : formatCurrency(item.price))
                                            .font(.ibmPlexMono(size: 14))
                                            .foregroundStyle(item.isDiscount ? Color.brandSuccess : Color.brandTextPrimary)
                                    }
                                    .padding(.vertical, 6)
                                }
                            }
                            
                            Divider()
                            
                            // Summary row
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(data.itemCount) items")
                                        .font(.manrope(size: 13, weight: .medium))
                                        .foregroundStyle(Color.brandTextSecondary)
                                    
                                    if data.savings > 0 {
                                        HStack(spacing: 4) {
                                            Image(systemName: "tag.fill")
                                                .font(.system(size: 10))
                                            Text("Saved \(formatCurrency(data.savings))")
                                                .font(.manrope(size: 12, weight: .semibold))
                                        }
                                        .foregroundStyle(Color.brandSuccess)
                                    }
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Tax: \(formatCurrency(data.totalTax))")
                                        .font(.manrope(size: 12, weight: .medium))
                                        .foregroundStyle(Color.brandTextTertiary)
                                    
                                    Text(data.paymentMethod)
                                        .font(.manrope(size: 12, weight: .medium))
                                        .foregroundStyle(Color.brandTextTertiary)
                                }
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.15), radius: 15, y: 8)
                        )
                        .padding(.horizontal, 24)
                        
                        // Note about demo
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 14))
                            Text("This is a demo - your real receipts will be saved to your dashboard.")
                                .font(.manrope(size: 12, weight: .medium))
                        }
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.horizontal, 32)
                        .padding(.top, 8)
                    }
                    .padding(.bottom, 100)
                }
                
                // Continue button
                VStack {
                    Spacer()
                    
                    Button {
                        haptics.success()
                        shouldAdvance = true
                    } label: {
                        HStack(spacing: 8) {
                            Text("Continue")
                                .font(.manrope(size: 16, weight: .bold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(Color.brandDeepNavy)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                        )
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
                }
                .background(
                    LinearGradient(
                        colors: [Color.clear, Color.brandDeepNavy.opacity(0.9), Color.brandDeepNavy],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 120)
                    .allowsHitTesting(false),
                    alignment: .bottom
                )
            }
        }
    }
    
    // MARK: - Helpers
    
    private func startProcessing() {
        currentPhase = .processing
    }
    
    private func simulateProcessing() {
        // Simulate AI processing with progress updates
        let steps: [(TimeInterval, Double)] = [
            (0.3, 0.15),
            (0.6, 0.3),
            (0.5, 0.5),
            (0.5, 0.7),
            (0.4, 0.85),
            (0.3, 1.0)
        ]
        
        var totalDelay: TimeInterval = 0
        
        for (delay, progress) in steps {
            totalDelay += delay
            DispatchQueue.main.asyncAfter(deadline: .now() + totalDelay) {
                withAnimation {
                    processingProgress = progress
                }
                haptics.light()
            }
        }
        
        // Show results after processing
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDelay + 0.5) {
            haptics.success()
            withAnimation(.spring(response: 0.5)) {
                currentPhase = .results
            }
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = AppFormatters.currency(code: "USD")
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

// MARK: - Sample Receipt Card

private struct SampleReceiptCard: View {
    let type: SampleReceiptType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                // Emoji
                Text(type.emoji)
                    .font(.system(size: 32))
                    .frame(width: 60, height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isSelected ? type.accentColor.opacity(0.2) : Color.white.opacity(0.1))
                    )
                
                // Label
                Text(type.displayName)
                    .font(.manrope(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.7))
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isSelected ? Color.white.opacity(0.5) : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        LinearGradient(
            colors: [Color.brandDeepNavy, Color.brandDarkNavy],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        TryScanningStep(
            shouldAdvance: .constant(false),
            onSkip: {}
        )
    }
}
