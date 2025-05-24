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
        GeometryReader { geometry in
            VStack(spacing: adaptiveSpacing(geometry: geometry)) {
                // Icon with background
                ZStack {
                    Circle()
                        .fill(colorScheme == .dark ? Color(hex: "1E293B") : Color(hex: "F1F5F9"))
                        .frame(width: adaptiveIconSize(geometry: geometry), height: adaptiveIconSize(geometry: geometry))

                    Image(systemName: feature.icon)
                        .font(.system(size: adaptiveIconFontSize(geometry: geometry)))
                        .foregroundColor(colorScheme == .dark ? Color(hex: "60A5FA") : Color(hex: "3B82F6"))
                }
                .padding(.bottom, adaptiveSpacing(geometry: geometry) * 0.3)

                Text(feature.title)
                    .font(.instrumentSans(size: adaptiveTitleSize(geometry: geometry)))
                    .fontWeight(.semibold)
                    .foregroundColor(colorScheme == .dark ? .white : Color(hex: "1E293B"))
                    .multilineTextAlignment(.center)

                Text(feature.description)
                    .font(.instrumentSans(size: adaptiveDescriptionSize(geometry: geometry)))
                    .foregroundColor(colorScheme == .dark ? Color.gray : Color(hex: "64748B"))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: adaptiveMaxWidth(geometry: geometry))

                // Visual illustration specific to the feature
                featureIllustration(geometry: geometry)
                    .padding(.top, adaptiveSpacing(geometry: geometry) * 0.75)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Adaptive Layout Helpers

    private func adaptiveSpacing(geometry: GeometryProxy) -> CGFloat {
        let screenHeight = geometry.size.height
        if screenHeight < 300 {
            return 12
        } else if screenHeight < 350 {
            return 16
        } else {
            return 20
        }
    }

    private func adaptiveIconSize(geometry: GeometryProxy) -> CGFloat {
        let screenHeight = geometry.size.height
        if screenHeight < 300 {
            return 70
        } else if screenHeight < 350 {
            return 85
        } else {
            return 100
        }
    }

    private func adaptiveIconFontSize(geometry: GeometryProxy) -> CGFloat {
        let screenHeight = geometry.size.height
        if screenHeight < 300 {
            return 28
        } else if screenHeight < 350 {
            return 34
        } else {
            return 40
        }
    }

    private func adaptiveTitleSize(geometry: GeometryProxy) -> CGFloat {
        let screenHeight = geometry.size.height
        if screenHeight < 300 {
            return 18
        } else if screenHeight < 350 {
            return 20
        } else {
            return 22
        }
    }

    private func adaptiveDescriptionSize(geometry: GeometryProxy) -> CGFloat {
        let screenHeight = geometry.size.height
        if screenHeight < 300 {
            return 14
        } else if screenHeight < 350 {
            return 15
        } else {
            return 16
        }
    }

    private func adaptiveMaxWidth(geometry: GeometryProxy) -> CGFloat {
        let screenWidth = geometry.size.width
        return min(screenWidth * 0.85, 270)
    }

    // Different illustration for each feature
    private func featureIllustration(geometry: GeometryProxy) -> some View {
        VStack {
            if feature.icon == "doc.text.viewfinder" {
                // Receipt scanning illustration
                HStack(spacing: adaptiveIllustrationSpacing(geometry: geometry)) {
                    Image(systemName: "doc.text")
                        .font(.system(size: adaptiveIllustrationIconSize(geometry: geometry)))
                    Image(systemName: "arrow.right")
                        .font(.system(size: adaptiveIllustrationIconSize(geometry: geometry) * 0.6))
                    Image(systemName: "checklist")
                        .font(.system(size: adaptiveIllustrationIconSize(geometry: geometry)))
                }
                .foregroundColor(colorScheme == .dark ? Color(hex: "94A3B8") : Color(hex: "64748B"))
            } else if feature.icon == "folder.badge.gearshape" {
                // Organization illustration
                HStack(spacing: adaptiveIllustrationSpacing(geometry: geometry) * 0.7) {
                    ForEach(0..<3) { i in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(colorScheme == .dark ? Color(hex: "334155") : Color(hex: "E2E8F0"))
                            .frame(width: adaptiveCardWidth(geometry: geometry), height: adaptiveCardHeight(geometry: geometry))
                            .overlay(
                                VStack {
                                    Image(systemName: ["cart", "fork.knife", "car"][i])
                                        .font(.system(size: adaptiveIllustrationIconSize(geometry: geometry) * 0.6))
                                        .padding(.bottom, 5)
                                    Text(["Groceries", "Dining", "Transport"][i])
                                        .font(.instrumentSans(size: adaptiveIllustrationTextSize(geometry: geometry)))
                                }
                                .foregroundColor(colorScheme == .dark ? Color(hex: "94A3B8") : Color(hex: "64748B"))
                            )
                    }
                }
            } else if feature.icon == "chart.pie.fill" {
                // Analytics illustration
                HStack(spacing: adaptiveIllustrationSpacing(geometry: geometry)) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colorScheme == .dark ? Color(hex: "334155") : Color(hex: "E2E8F0"))
                        .frame(width: adaptiveCardWidth(geometry: geometry) * 1.3, height: adaptiveCardHeight(geometry: geometry))
                        .overlay(
                            Image(systemName: "chart.pie.fill")
                                .font(.system(size: adaptiveIllustrationIconSize(geometry: geometry)))
                                .foregroundColor(colorScheme == .dark ? Color(hex: "94A3B8") : Color(hex: "64748B"))
                        )

                    RoundedRectangle(cornerRadius: 8)
                        .fill(colorScheme == .dark ? Color(hex: "334155") : Color(hex: "E2E8F0"))
                        .frame(width: adaptiveCardWidth(geometry: geometry) * 1.3, height: adaptiveCardHeight(geometry: geometry))
                        .overlay(
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: adaptiveIllustrationIconSize(geometry: geometry)))
                                .foregroundColor(colorScheme == .dark ? Color(hex: "94A3B8") : Color(hex: "64748B"))
                        )
                }
            } else {
                // Returns illustration
                HStack(spacing: adaptiveIllustrationSpacing(geometry: geometry)) {
                    Image(systemName: "shippingbox")
                        .font(.system(size: adaptiveIllustrationIconSize(geometry: geometry)))
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: adaptiveIllustrationIconSize(geometry: geometry) * 0.6))
                    Image(systemName: "creditcard")
                        .font(.system(size: adaptiveIllustrationIconSize(geometry: geometry)))
                }
                .foregroundColor(colorScheme == .dark ? Color(hex: "94A3B8") : Color(hex: "64748B"))
            }
        }
    }

    private func adaptiveIllustrationSpacing(geometry: GeometryProxy) -> CGFloat {
        let screenHeight = geometry.size.height
        if screenHeight < 300 {
            return 10
        } else if screenHeight < 350 {
            return 12
        } else {
            return 15
        }
    }

    private func adaptiveIllustrationIconSize(geometry: GeometryProxy) -> CGFloat {
        let screenHeight = geometry.size.height
        if screenHeight < 300 {
            return 28
        } else if screenHeight < 350 {
            return 35
        } else {
            return 42
        }
    }

    private func adaptiveCardWidth(geometry: GeometryProxy) -> CGFloat {
        let screenHeight = geometry.size.height
        if screenHeight < 300 {
            return 50
        } else if screenHeight < 350 {
            return 60
        } else {
            return 70
        }
    }

    private func adaptiveCardHeight(geometry: GeometryProxy) -> CGFloat {
        let screenHeight = geometry.size.height
        if screenHeight < 300 {
            return 65
        } else if screenHeight < 350 {
            return 75
        } else {
            return 90
        }
    }

    private func adaptiveIllustrationTextSize(geometry: GeometryProxy) -> CGFloat {
        let screenHeight = geometry.size.height
        if screenHeight < 300 {
            return 10
        } else if screenHeight < 350 {
            return 11
        } else {
            return 12
        }
    }
}
