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
            VStack(alignment: .leading, spacing: 20) {
                FAQItem(question: "How do I scan a receipt?",
                       answer: "Open the app, tap the camera icon on the home screen, and take a clear photo of your receipt. Our AI will automatically process the receipt data.")
                
                FAQItem(question: "How accurate is the receipt scanning?",
                       answer: "Our AI recognition is highly accurate, but we recommend reviewing the scanned data to ensure everything was captured correctly.")
                
                FAQItem(question: "Is my data secure?",
                       answer: "Yes! All your data is encrypted and stored securely. We never share your personal information with third parties.")
                
                FAQItem(question: "Can I export my receipt data?",
                       answer: "We're currently working on an export feature that will be available in a future update.")
            }
            .padding()
        }
        .navigationTitle("Frequently Asked Questions")
    }
}

struct FAQItem: View {
    var question: String
    var answer: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question)
                .font(.instrumentSans(size: 18, weight: .medium))
            
            Text(answer)
                .font(.instrumentSans(size: 16))
                .foregroundColor(.gray)
        }
    }
}
