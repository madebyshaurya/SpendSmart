//
//  FeatureView.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-03-17.
//

import SwiftUI

struct FeatureView: View {
    let feature: FeatureItem
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon with background
            ZStack {
                Circle()
                    .fill(colorScheme == .dark ? Color(hex: "1E293B") : Color(hex: "F1F5F9"))
                    .frame(width: 100, height: 100)
                
                Image(systemName: feature.icon)
                    .font(.system(size: 40))
                    .foregroundColor(colorScheme == .dark ? Color(hex: "60A5FA") : Color(hex: "3B82F6"))
            }
            .padding(.bottom, 6)
            
            Text(feature.title)
                .font(.instrumentSans(size: 22))
                .fontWeight(.semibold)
                .foregroundColor(colorScheme == .dark ? .white : Color(hex: "1E293B"))
                .multilineTextAlignment(.center)
            
            Text(feature.description)
                .font(.instrumentSans(size: 16))
                .foregroundColor(colorScheme == .dark ? Color.gray : Color(hex: "64748B"))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 270)
            
            // Visual illustration specific to the feature
            featureIllustration
                .padding(.top, 15)
        }
        .padding(.horizontal, 20)
    }
    
    // Different illustration for each feature
    private var featureIllustration: some View {
        VStack {
            if feature.icon == "doc.text.viewfinder" {
                // Receipt scanning illustration
                HStack(spacing: 15) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 42))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 24))
                    Image(systemName: "checklist")
                        .font(.system(size: 42))
                }
                .foregroundColor(colorScheme == .dark ? Color(hex: "94A3B8") : Color(hex: "64748B"))
            } else if feature.icon == "folder.badge.gearshape" {
                // Organization illustration
                HStack(spacing: 10) {
                    ForEach(0..<3) { i in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(colorScheme == .dark ? Color(hex: "334155") : Color(hex: "E2E8F0"))
                            .frame(width: 70, height: 90)
                            .overlay(
                                VStack {
                                    Image(systemName: ["cart", "fork.knife", "car"][i])
                                        .font(.system(size: 24))
                                        .padding(.bottom, 5)
                                    Text(["Groceries", "Dining", "Transport"][i])
                                        .font(.instrumentSans(size: 12))
                                }
                                .foregroundColor(colorScheme == .dark ? Color(hex: "94A3B8") : Color(hex: "64748B"))
                            )
                    }
                }
            } else if feature.icon == "chart.pie.fill" {
                // Analytics illustration
                HStack(spacing: 15) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colorScheme == .dark ? Color(hex: "334155") : Color(hex: "E2E8F0"))
                        .frame(width: 90, height: 90)
                        .overlay(
                            Image(systemName: "chart.pie.fill")
                                .font(.system(size: 42))
                                .foregroundColor(colorScheme == .dark ? Color(hex: "94A3B8") : Color(hex: "64748B"))
                        )
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colorScheme == .dark ? Color(hex: "334155") : Color(hex: "E2E8F0"))
                        .frame(width: 90, height: 90)
                        .overlay(
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 42))
                                .foregroundColor(colorScheme == .dark ? Color(hex: "94A3B8") : Color(hex: "64748B"))
                        )
                }
            } else {
                // Returns illustration
                HStack(spacing: 15) {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 42))
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 24))
                    Image(systemName: "creditcard")
                        .font(.system(size: 42))
                }
                .foregroundColor(colorScheme == .dark ? Color(hex: "94A3B8") : Color(hex: "64748B"))
            }
        }
    }
}
