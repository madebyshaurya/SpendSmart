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

                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Image(systemName: "square.and.pencil")
                            .foregroundColor(.primary)
                        Text("SwiftUI - Building beautiful UIs")
                            .foregroundColor(.primary)
                    }
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.primary)
                        Text("Logos provided by Logo.dev")
                            .foregroundColor(.primary)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(20)
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
