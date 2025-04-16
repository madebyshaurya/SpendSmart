//
//  AboutView.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-03-18.
//

import SwiftUI

struct FeatureRow: View {
    var icon: String
    var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "3B82F6"))
                .frame(width: 24, height: 24)

            Text(text)
                .font(.instrumentSans(size: 16))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }
}

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 60))
                    .foregroundColor(Color(hex: "3B82F6"))
                    .padding(.top, 30)

                Text("SpendSmart")
                    .font(.instrumentSerifItalic(size: 30))
                    .bold()

                Text("Version 1.0.0")
                    .font(.instrumentSans(size: 16))
                    .foregroundColor(.gray)

                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("About SpendSmart")
                            .font(.instrumentSans(size: 20, weight: .semibold))
                            .frame(maxWidth: .infinity, alignment: .center)

                        Text("SpendSmart is an AI-powered receipt scanner that helps you organize your expenses effortlessly. Scan receipts, track spending, and gain insights into your financial habits.")
                            .font(.instrumentSans(size: 16))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Features")
                            .font(.instrumentSans(size: 20, weight: .semibold))
                            .frame(maxWidth: .infinity, alignment: .center)

                        FeatureRow(icon: "doc.text.viewfinder", text: "Instant receipt scanning with AI")
                        FeatureRow(icon: "folder.badge.gearshape", text: "Automatic categorization")
                        FeatureRow(icon: "chart.pie.fill", text: "Spending insights and analytics")
                        FeatureRow(icon: "person.2.fill", text: "Receipt sharing and expense splitting")
                        FeatureRow(icon: "icloud.fill", text: "Cloud sync with guest mode option")
                    }

                    Divider()
                        .padding(.vertical, 10)

                    VStack(alignment: .center, spacing: 10) {
                        Text("Developed by Shaurya Gupta")
                            .font(.instrumentSans(size: 16))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)

                        Text("© 2025 SpendSmart. All rights reserved.")
                            .font(.instrumentSans(size: 14))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding()

                Spacer()
            }
            .padding()
        }
        .navigationTitle("About")
    }
}
