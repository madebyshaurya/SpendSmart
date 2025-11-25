//
//  EnhancedStreamingLoadingView.swift
//  SpendSmart
//
//  Created by AI Assistant on 2025-01-19.
//

import SwiftUI
import Shimmer

/// Enhanced streaming loading view with text shimmer effect
struct EnhancedStreamingLoadingView: View {
    let progress: AIStreamingProgress
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Backdrop (transparent to avoid black rectangle)
            Color.clear
                .ignoresSafeArea()

            VStack(spacing: 30) {
                // Progress indicator
                ZStack {
                    // Background circle
                    Circle()
                        .stroke((colorScheme == .dark ? Color.white : Color.black).opacity(0.2), lineWidth: 8)
                        .frame(width: 100, height: 100)
                    
                    // Progress circle
                    Circle()
                        .trim(from: 0, to: CGFloat(progress.progress))
                        .stroke(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: progress.progress)
                    
                    // Center icon
                    Image(systemName: iconForStage)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .scaleEffect(pulseScale)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                                pulseScale = 1.2
                            }
                        }
                }
                
                VStack(spacing: 12) {
                    // Stage title with shimmer effect
                    Text(progress.stage.displayName)
                        .font(.instrumentSans(size: 22, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .shimmering(
                            active: true,
                            animation: .easeInOut(duration: 2.0).repeatForever(autoreverses: false)
                        )
                    
                    // Progress percentage only (removed verbose message)
                    Text("\(Int(progress.progress * 100))%")
                        .font(.instrumentSans(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                        .shimmering(
                            active: true,
                            animation: .easeInOut(duration: 1.8).repeatForever(autoreverses: false)
                        )
                }
                .padding(.horizontal, 40)
                
                // Optional partial text display (removed to reduce text amount)
                // if !progress.partialText.isEmpty {
                //     ScrollView {
                //         Text(progress.partialText)
                //             .font(.instrumentSans(size: 14))
                //             .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.7))
                //             .padding()
                //             .background(
                //                 RoundedRectangle(cornerRadius: 12)
                //                     .fill(Color.black.opacity(0.3))
                //             )
                //     }
                //     .frame(maxHeight: 120)
                //     .padding(.horizontal, 20)
                // }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
            )
            .padding(.horizontal, 30)
        }
    }
    
    private var iconForStage: String {
        switch progress.stage {
        case .initializing:
            return "gearshape.2"
        case .analyzing:
            return "doc.text.magnifyingglass"
        case .extracting:
            return "text.viewfinder"
        case .processing:
            return "cpu"
        case .validating:
            return "checkmark.shield"
        case .complete:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
}


