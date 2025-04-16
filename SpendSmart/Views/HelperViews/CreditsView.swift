//
//  CreditsView.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-03-30.
//

import SwiftUI

struct CreditRow: View {
    var icon: String
    var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.primary)
                .frame(width: 24, height: 24)

            Text(text)
                .font(.instrumentSans(size: 16))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }
}

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

                VStack(alignment: .leading, spacing: 10) {
                    CreditRow(icon: "globe", text: "Logos provided by Logo.dev")
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
