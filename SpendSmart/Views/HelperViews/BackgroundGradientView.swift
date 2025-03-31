//
//  BackgroundGradientView.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-03-31.
//

import SwiftUI

struct BackgroundGradientView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var animationPhase: Double = 0
    
    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let phase = now.truncatingRemainder(dividingBy: 10) / 10
            
            Canvas { context, size in
                context.addFilter(.blur(radius: 60))
                
                let gradientColors: [Color] = colorScheme == .dark
                ? [.blue.opacity(0.2), .purple.opacity(0.2), .indigo.opacity(0.2)]
                : [.blue.opacity(0.1), .teal.opacity(0.1), .mint.opacity(0.1)]
                
                for i in 0..<3 {
                    var path = Path()
                    let centerX = size.width * 0.5 + sin(phase * .pi * 2 + Double(i) * 2) * size.width * 0.3
                    let centerY = size.height * 0.5 + cos(phase * .pi * 2 + Double(i) * 1.5) * size.height * 0.3
                    let radius = min(size.width, size.height) * 0.3
                    
                    path.addEllipse(in: CGRect(x: centerX - radius, y: centerY - radius,
                                               width: radius * 2, height: radius * 2))
                    
                    context.fill(path, with: .color(gradientColors[i]))
                }
            }
        }
        .ignoresSafeArea()
    }
}
