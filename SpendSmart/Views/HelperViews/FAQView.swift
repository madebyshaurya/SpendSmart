//
//  FAQView.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-03-18.
//

import SwiftUI

struct FAQView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Title removed as requested

                // General Questions
                AccordionFAQItem(question: "Is SpendSmart free to use?",
                       answer: "Yes, SpendSmart is completely free to use with no in-app purchases or subscriptions. We don't show ads either.")

                AccordionFAQItem(question: "What's the difference between guest mode and Apple sign-in?",
                       answer: "With guest mode, your receipts are stored locally on your device. With Apple sign-in, your data is securely stored in the cloud and can be accessed across multiple devices. Both options provide the same app features.")

                AccordionFAQItem(question: "Will I lose my data if I switch from guest to Apple sign-in?",
                       answer: "Currently, data doesn't transfer between guest mode and Apple sign-in. We recommend starting with Apple sign-in if you plan to use the app long-term.")

                AccordionFAQItem(question: "Does SpendSmart require internet access?",
                       answer: "Yes, SpendSmart requires an internet connection to function properly as it needs to communicate with our servers. Make sure you have a stable internet connection when using the app.")
            }
            .padding()
        }
        .navigationTitle("FAQ")
    }
}

struct AccordionFAQItem: View {
    var question: String
    var answer: String

    @State private var isExpanded: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(question)
                        .font(.instrumentSans(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "3B82F6"))
                        .rotationEffect(.degrees(isExpanded ? 0 : 0))
                }
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                Text(answer)
                    .font(.instrumentSans(size: 15))
                    .foregroundColor(colorScheme == .dark ? .gray : Color(hex: "64748B"))
                    .padding(.bottom, 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white.opacity(0.7))
                .shadow(color: colorScheme == .dark ? Color.clear : Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.1) : Color.gray.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}
