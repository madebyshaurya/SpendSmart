//
//  EmptyStateView.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-03-31.
//

import SwiftUI

struct EmptyStateView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isAnimating = false
    var message: String = "No receipts found" // Added a message property

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "receipt")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
                .opacity(isAnimating ? 1 : 0.5)
                .scaleEffect(isAnimating ? 1.1 : 0.9)
                .animation(
                    Animation.easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )

            Text(message) // Use the dynamic message
                .font(.instrumentSerif(size: 24))
                .foregroundColor(.secondary)

            Text("Pull down to refresh or add a new receipt")
                .font(.instrumentSans(size: 16))
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white.opacity(0.7))
                .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.1),
                        radius: 10, x: 0, y: 5)
        )
        .onAppear {
            isAnimating = true
        }
    }
}
