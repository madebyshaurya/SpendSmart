//
//  Extensions.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-03-14.
//

import SwiftUI

extension Font {
    static func spaceGrotesk(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .medium:
            return Font.custom("SpaceGrotesk-Light_Medium", size: size)
        case .bold:
            return Font.custom("SpaceGrotesk-Light_Bold", size: size)
        default:
            return Font.custom("SpaceGrotesk-Light_Regular", size: size)
        }
    }

    static func instrumentSans(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .medium:
            return Font.custom("InstrumentSans-Regular_Medium", size: size)
        case .semibold:
            return Font.custom("InstrumentSans-Regular_SemiBold", size: size)
        case .bold:
            return Font.custom("InstrumentSans-Regular_Bold", size: size)
        default:
            return Font.custom("InstrumentSans-Regular", size: size)
        }
    }

    static func instrumentSerif(size: CGFloat) -> Font {
        Font.custom("InstrumentSerif-Regular", size: size)
    }

    static func instrumentSerifItalic(size: CGFloat) -> Font {
        Font.custom("InstrumentSerif-Italic", size: size)
    }
    
    // Enhanced typography system with dynamic scaling and visual hierarchy
    static func hierarchyDisplay(level: Int = 1) -> Font {
        switch level {
        case 1: return .instrumentSans(size: UIFontMetrics.default.scaledValue(for: DesignTokens.Typography.HierarchyDisplay.level1), weight: .bold)
        case 2: return .instrumentSans(size: UIFontMetrics.default.scaledValue(for: DesignTokens.Typography.HierarchyDisplay.level2), weight: .bold)
        case 3: return .instrumentSans(size: UIFontMetrics.default.scaledValue(for: DesignTokens.Typography.HierarchyDisplay.level3), weight: .bold)
        default: return .instrumentSans(size: UIFontMetrics.default.scaledValue(for: DesignTokens.Typography.HierarchyDisplay.level4), weight: .bold)
        }
    }
    
    static func hierarchyTitle(level: Int = 1) -> Font {
        switch level {
        case 1: return .instrumentSans(size: UIFontMetrics.default.scaledValue(for: DesignTokens.Typography.HierarchyTitle.level1), weight: .semibold)
        case 2: return .instrumentSans(size: UIFontMetrics.default.scaledValue(for: DesignTokens.Typography.HierarchyTitle.level2), weight: .semibold)
        case 3: return .instrumentSans(size: UIFontMetrics.default.scaledValue(for: DesignTokens.Typography.HierarchyTitle.level3), weight: .semibold)
        default: return .instrumentSans(size: UIFontMetrics.default.scaledValue(for: DesignTokens.Typography.HierarchyTitle.level4), weight: .semibold)
        }
    }
    
    static func hierarchyBody(emphasis: BodyEmphasis = .regular) -> Font {
        switch emphasis {
        case .regular: return .instrumentSans(size: UIFontMetrics.default.scaledValue(for: DesignTokens.Typography.Body.base), weight: .regular)
        case .medium: return .instrumentSans(size: UIFontMetrics.default.scaledValue(for: DesignTokens.Typography.Body.base), weight: .medium)
        case .emphasis: return .instrumentSans(size: UIFontMetrics.default.scaledValue(for: DesignTokens.Typography.Body.base), weight: .semibold)
        }
    }
    
    static func hierarchyCaption(emphasis: CaptionEmphasis = .regular) -> Font {
        switch emphasis {
        case .regular: return .instrumentSans(size: UIFontMetrics.default.scaledValue(for: DesignTokens.Typography.Caption.base), weight: .regular)
        case .medium: return .instrumentSans(size: UIFontMetrics.default.scaledValue(for: DesignTokens.Typography.Caption.base), weight: .medium)
        }
    }
    
    static func hierarchyData(size: DataSize = .medium, weight: Font.Weight = .bold) -> Font {
        let fontSize: CGFloat
        switch size {
        case .small: fontSize = DesignTokens.Typography.Data.small
        case .medium: fontSize = DesignTokens.Typography.Data.medium
        case .large: fontSize = DesignTokens.Typography.Data.large
        case .xlarge: fontSize = DesignTokens.Typography.Data.xlarge
        }
        return .spaceGrotesk(size: UIFontMetrics.default.scaledValue(for: fontSize), weight: weight)
    }
    
    enum BodyEmphasis {
        case regular, medium, emphasis
    }
    
    enum CaptionEmphasis {
        case regular, medium
    }
    
    enum DataSize {
        case small, medium, large, xlarge
    }
}

// MARK: - Global font helpers for easy application
extension View {
    /// Applies Instrument Sans to the entire subtree (good as a screen-level default)
    func useInstrumentSans(size: CGFloat = UIFontMetrics.default.scaledValue(for: DesignTokens.Typography.Body.base),
                           weight: Font.Weight = .regular) -> some View {
        self.font(.instrumentSans(size: size, weight: weight))
    }
    
    /// Applies Instrument Serif Italic to the subtree (great for logos/hero headlines)
    func useInstrumentSerifItalic(size: CGFloat) -> some View {
        self.font(.instrumentSerifItalic(size: size))
    }

    /// Adds a soft bottom fade to help content blend into the safe-area/CTA
    func bottomSafeAreaFade(height: CGFloat = 100) -> some View {
        self.overlay(alignment: .bottom) {
            LinearGradient(
                colors: [Color.clear, Color(uiColor: .systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: height)
            .allowsHitTesting(false)
        }
    }
}

// Extension for hex color support
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension UIImage {
    func dominantColors(count: Int = 3) -> [Color] {
        guard let cgImage = self.cgImage else { return [.gray] }

        let colorSpace = CGColorSpaceCreateDeviceRGB()

        // Create a thumbnail to speed up processing
        let thumbnailSize = CGSize(width: 50, height: 50)
        let thumbnailContext = CGContext(
            data: nil,
            width: Int(thumbnailSize.width),
            height: Int(thumbnailSize.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(thumbnailSize.width) * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        )

        thumbnailContext?.draw(cgImage, in: CGRect(origin: .zero, size: thumbnailSize))

        guard let thumbnailData = thumbnailContext?.data else { return [.gray] }

        var pixelData = [UInt32](repeating: 0, count: Int(thumbnailSize.width * thumbnailSize.height))

        // Get pixel data
        for y in 0..<Int(thumbnailSize.height) {
            for x in 0..<Int(thumbnailSize.width) {
                let offset = y * Int(thumbnailSize.width) + x
                pixelData[offset] = thumbnailData.load(fromByteOffset: offset * 4, as: UInt32.self)
            }
        }

        // Convert pixel data to RGB values
        var colorCounts: [UInt32: Int] = [:]
        for pixel in pixelData {
            colorCounts[pixel, default: 0] += 1
        }

        // Sort by frequency
        let sortedColors = colorCounts.sorted { $0.value > $1.value }

        // Convert to SwiftUI colors, skipping purely black/white
        var colors: [Color] = []
        for (pixel, _) in sortedColors.prefix(count * 2) {
            let r = CGFloat((pixel & 0x00FF0000) >> 16) / 255
            let g = CGFloat((pixel & 0x0000FF00) >> 8) / 255
            let b = CGFloat(pixel & 0x000000FF) / 255

            // Skip colors that are too close to black or white
            if (r + g + b > 0.2 && r + g + b < 2.7) {
                colors.append(Color(red: r, green: g, blue: b))
                if colors.count >= count {
                    break
                }
            }
        }

        return colors.isEmpty ? [.gray] : colors
    }
}

// MARK: - View Extensions for Improved Layout & Hierarchy
extension View {
    /// Applies consistent spacing patterns for visual hierarchy
    func hierarchySpacing(_ level: HierarchyLevel = .content) -> some View {
        let spacing: CGFloat
        switch level {
        case .page: spacing = DesignTokens.Spacing.page
        case .section: spacing = DesignTokens.Spacing.section
        case .content: spacing = DesignTokens.Spacing.content
        case .element: spacing = DesignTokens.Spacing.element
        case .detail: spacing = DesignTokens.Spacing.detail
        }
        return self.padding(.vertical, spacing)
    }
    
    /// Applies semantic spacing based on content type
    func semanticSpacing(_ type: SemanticSpacing) -> some View {
        let spacing: EdgeInsets
        switch type {
        case .cardInner: spacing = DesignTokens.Padding.cardInner
        case .cardOuter: spacing = DesignTokens.Padding.cardOuter
        case .listItem: spacing = DesignTokens.Padding.listItem
        case .section: spacing = DesignTokens.Padding.section
        case .page: spacing = DesignTokens.Padding.page
        }
        return self.padding(spacing)
    }
    
    /// Creates a content container with proper hierarchy
    func contentContainer(level: ContainerLevel = .primary) -> some View {
        Group {
            switch level {
            case .primary:
                self
                    .padding(.horizontal, DesignTokens.Container.primaryHorizontal)
                    .padding(.vertical, DesignTokens.Container.primaryVertical)
                    .background(Color(.systemBackground))
                    .cornerRadius(DesignTokens.Container.primaryCorner)
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                    
            case .secondary:
                self
                    .padding(.horizontal, DesignTokens.Container.secondaryHorizontal)
                    .padding(.vertical, DesignTokens.Container.secondaryVertical)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(DesignTokens.Container.secondaryCorner)
                    .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                    
            case .tertiary:
                self
                    .padding(.horizontal, DesignTokens.Container.tertiaryHorizontal)
                    .padding(.vertical, DesignTokens.Container.tertiaryVertical)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(DesignTokens.Container.tertiaryCorner)
            }
        }
    }
    
    /// Applies consistent text hierarchy styling
    func textHierarchy(_ level: TextHierarchy, color: Color? = nil) -> some View {
        Group {
            switch level {
            case .pageTitle:
                self
                    .font(.hierarchyDisplay(level: 1))
                    .foregroundColor(color ?? .primary)
                    .multilineTextAlignment(.leading)
                    
            case .sectionTitle:
                self
                    .font(.hierarchyTitle(level: 1))
                    .foregroundColor(color ?? .primary)
                    .multilineTextAlignment(.leading)
                    
            case .cardTitle:
                self
                    .font(.hierarchyTitle(level: 2))
                    .foregroundColor(color ?? .primary)
                    .multilineTextAlignment(.leading)
                    
            case .dataValue:
                self
                    .font(.hierarchyData(size: .medium))
                    .foregroundColor(color ?? .primary)
                    .multilineTextAlignment(.leading)
                    
            case .body:
                self
                    .font(.hierarchyBody())
                    .foregroundColor(color ?? .primary)
                    .multilineTextAlignment(.leading)
                    
            case .caption:
                self
                    .font(.hierarchyCaption())
                    .foregroundColor(color ?? .secondary)
                    .multilineTextAlignment(.leading)
                    
            case .metadata:
                self
                    .font(.hierarchyCaption(emphasis: .medium))
                    .foregroundColor(color ?? .secondary)
                    .multilineTextAlignment(.leading)
            }
        }
    }
    
    /// Creates a semantic divider for visual separation
    func semanticDivider(_ style: DividerStyle = .subtle) -> some View {
        VStack(spacing: 0) {
            self
            
            Rectangle()
                .fill(dividerColor(for: style))
                .frame(height: dividerHeight(for: style))
                .padding(.horizontal, dividerPadding(for: style))
        }
    }
    
    private func dividerColor(for style: DividerStyle) -> Color {
        switch style {
        case .subtle: return Color(.separator).opacity(0.5)
        case .standard: return Color(.separator)
        case .emphasized: return Color(.separator).opacity(0.8)
        }
    }
    
    private func dividerHeight(for style: DividerStyle) -> CGFloat {
        switch style {
        case .subtle: return 0.5
        case .standard: return 1
        case .emphasized: return 2
        }
    }
    
    private func dividerPadding(for style: DividerStyle) -> CGFloat {
        switch style {
        case .subtle: return DesignTokens.Spacing.xl
        case .standard: return DesignTokens.Spacing.lg
        case .emphasized: return 0
        }
    }
}

// MARK: - Supporting Types
enum HierarchyLevel {
    case page, section, content, element, detail
}

enum SemanticSpacing {
    case cardInner, cardOuter, listItem, section, page
}

enum ContainerLevel {
    case primary, secondary, tertiary
}

enum TextHierarchy {
    case pageTitle, sectionTitle, cardTitle, dataValue, body, caption, metadata
}

enum DividerStyle {
    case subtle, standard, emphasized
}
