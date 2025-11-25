//
//  CreditsView.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-03-30.
//

import SwiftUI

struct CreditsView: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            // Plain Background (Adaptive for Light/Dark Mode)
            Color(.systemBackground)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                Text("Credits")
                    .font(.instrumentSerif(size: 36))
                    .foregroundColor(.primary)

                Text("All third-party services and APIs used in this app are properly licensed.")
                    .font(.instrumentSans(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                    .opacity(animate ? 1 : 0)
                    .animation(.easeInOut(duration: 0.5), value: animate)
                    .onAppear { self.animate = true }

                Spacer()
            }
            .padding()
        }
    }
}

#Preview {
    CreditsView()
}
