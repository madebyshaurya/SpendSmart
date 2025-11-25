//
//  DesignTokens.swift
//  SpendSmart
//
//  Apple Human Interface Guidelines Design System
//  Centralized design tokens for consistent UI/UX
//

import SwiftUI

// MARK: - Design Tokens
struct DesignTokens {
    
    // MARK: - Spacing Scale (Apple HIG 8pt grid system)
    struct Spacing {
        static let xxs: CGFloat = 2    // Micro spacing
        static let xs: CGFloat = 4     // Hairline spacing
        static let sm: CGFloat = 8     // Extra small
        static let md: CGFloat = 12    // Small
        static let lg: CGFloat = 16    // Medium (base unit)
        static let xl: CGFloat = 20    // Large
        static let xxl: CGFloat = 24   // Extra large
        static let xxxl: CGFloat = 32  // Jumbo
        static let huge: CGFloat = 48  // Hero sections
        static let massive: CGFloat = 64 // Landing areas
        
        // Semantic spacing
        static let cardPadding: CGFloat = lg
        static let sectionSpacing: CGFloat = xxl
        static let contentMargin: CGFloat = lg
        static let minimumTouchTarget: CGFloat = 44 // Apple minimum
        
        // Hierarchy Spacing
        static let page: CGFloat = 32
        static let section: CGFloat = 24
        static let content: CGFloat = 16
        static let element: CGFloat = 12
        static let detail: CGFloat = 8
    }
    
    // MARK: - Padding System
    struct Padding {
        // Card Padding
        static let cardInner = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        static let cardOuter = EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        static let listItem = EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        static let section = EdgeInsets(top: 24, leading: 0, bottom: 8, trailing: 0)
        static let page = EdgeInsets(top: 20, leading: 16, bottom: 20, trailing: 16)
    }
    
    // MARK: - Container System
    struct Container {
        // Primary Container
        static let primaryHorizontal: CGFloat = 16
        static let primaryVertical: CGFloat = 20
        static let primaryCorner: CGFloat = 16
        
        // Secondary Container
        static let secondaryHorizontal: CGFloat = 12
        static let secondaryVertical: CGFloat = 16
        static let secondaryCorner: CGFloat = 12
        
        // Tertiary Container
        static let tertiaryHorizontal: CGFloat = 8
        static let tertiaryVertical: CGFloat = 12
        static let tertiaryCorner: CGFloat = 8
    }
    
    // MARK: - Border Radius (Apple's rounded corner system)
    struct CornerRadius {
        static let xs: CGFloat = 4     // Micro elements
        static let sm: CGFloat = 8     // Small components
        static let md: CGFloat = 12    // Cards and buttons
        static let lg: CGFloat = 16    // Large cards
        static let xl: CGFloat = 20    // Prominent elements
        static let xxl: CGFloat = 24   // Hero cards
        static let continuous: CGFloat = 28 // iOS-style continuous curves
    }
    
    // MARK: - Typography Scale (Apple HIG Dynamic Type inspired)
    struct Typography {
        // Hierarchy Display Sizes
        struct HierarchyDisplay {
            static let level1: CGFloat = 36
            static let level2: CGFloat = 30
            static let level3: CGFloat = 26
            static let level4: CGFloat = 22
        }
        
        // Hierarchy Title Sizes
        struct HierarchyTitle {
            static let level1: CGFloat = 22
            static let level2: CGFloat = 20
            static let level3: CGFloat = 18
            static let level4: CGFloat = 16
        }
        
        // Body Text Sizes
        struct Body {
            static let base: CGFloat = 17
        }
        
        // Caption Sizes
        struct Caption {
            static let base: CGFloat = 13
        }
        
        // Data Display Sizes
        struct Data {
            static let small: CGFloat = 20
            static let medium: CGFloat = 28
            static let large: CGFloat = 36
            static let xlarge: CGFloat = 48
        }
        
        // Display sizes (for headers and heroes)
        static func largeTitle(weight: Font.Weight = .bold) -> Font {
            .instrumentSans(size: 34, weight: weight)
        }
        
        static func title1(weight: Font.Weight = .bold) -> Font {
            .instrumentSans(size: 28, weight: weight)
        }
        
        static func title2(weight: Font.Weight = .bold) -> Font {
            .instrumentSans(size: 22, weight: weight)
        }
        
        static func title3(weight: Font.Weight = .semibold) -> Font {
            .instrumentSans(size: 20, weight: weight)
        }
        
        // Body text
        static func headline(weight: Font.Weight = .semibold) -> Font {
            .instrumentSans(size: 17, weight: weight)
        }
        
        static func body(weight: Font.Weight = .regular) -> Font {
            .instrumentSans(size: 17, weight: weight)
        }
        
        static func callout(weight: Font.Weight = .regular) -> Font {
            .instrumentSans(size: 16, weight: weight)
        }
        
        static func subheadline(weight: Font.Weight = .regular) -> Font {
            .instrumentSans(size: 15, weight: weight)
        }
        
        static func footnote(weight: Font.Weight = .regular) -> Font {
            .instrumentSans(size: 13, weight: weight)
        }
        
        static func caption1(weight: Font.Weight = .regular) -> Font {
            .instrumentSans(size: 12, weight: weight)
        }
        
        static func caption2(weight: Font.Weight = .regular) -> Font {
            .instrumentSans(size: 11, weight: weight)
        }
        
        // Numbers and data display
        static func dataDisplay(size: CGFloat, weight: Font.Weight = .bold) -> Font {
            .spaceGrotesk(size: size, weight: weight)
        }
        
        // Brand typography
        static func brandTitle(size: CGFloat) -> Font {
            .instrumentSerifItalic(size: size)
        }
    }
    
    // MARK: - Color Palette (Apple HIG Semantic Colors)
    struct Colors {
        // System colors that adapt to light/dark mode
        struct Primary {
            static let blue = Color.blue
            static let teal = Color.teal
            static let mint = Color.mint
            static let green = Color.green
            static let orange = Color.orange
            static let red = Color.red
            static let purple = Color.purple
            static let indigo = Color.indigo
        }
        
        // Neutral colors
        struct Neutral {
            static let primary = Color.primary
            static let secondary = Color.secondary
            static let tertiary = Color(UIColor.tertiaryLabel)
            static let quaternary = Color(UIColor.quaternaryLabel)
        }
        
        // Background colors
        struct Background {
            static let primary = Color(UIColor.systemBackground)
            static let secondary = Color(UIColor.secondarySystemBackground)
            static let tertiary = Color(UIColor.tertiarySystemBackground)
            static let grouped = Color(UIColor.systemGroupedBackground)
            static let secondaryGrouped = Color(UIColor.secondarySystemGroupedBackground)
        }
        
        // Fill colors for components
        struct Fill {
            static let primary = Color(UIColor.systemFill)
            static let secondary = Color(UIColor.secondarySystemFill)
            static let tertiary = Color(UIColor.tertiarySystemFill)
            static let quaternary = Color(UIColor.quaternarySystemFill)
        }
        
        // Semantic colors for specific purposes
        struct Semantic {
            static let success = Color.green
            static let warning = Color.orange
            static let error = Color.red
            static let info = Color.blue
            
            // Financial colors
            static let expense = Color.red
            static let income = Color.green
            static let savings = Color.mint
            static let investment = Color.purple
        }

        // MARK: - iOS 26 Liquid Glass Tints
        // Tinted glass backgrounds for cards and UI elements
        struct GlassTints {
            static let blue = Color.blue.opacity(0.08)
            static let green = Color.green.opacity(0.08)
            static let red = Color.red.opacity(0.08)
            static let orange = Color.orange.opacity(0.08)
            static let purple = Color.purple.opacity(0.08)
            static let yellow = Color.yellow.opacity(0.08)
            static let teal = Color.teal.opacity(0.08)
            static let mint = Color.mint.opacity(0.08)
            static let indigo = Color.indigo.opacity(0.08)
            static let pink = Color.pink.opacity(0.08)
        }

        // MARK: - Vibrant Fills (Premium UI)
        // Enhanced fills for premium features and highlights
        struct Vibrant {
            static let primary = Color.accentColor.opacity(0.15)
            static let success = Color.green.opacity(0.12)
            static let warning = Color.orange.opacity(0.12)
            static let error = Color.red.opacity(0.12)
            static let info = Color.blue.opacity(0.12)
            static let premium = Color.yellow.opacity(0.15)
        }

        // MARK: - Premium Gradients
        // Gradients for premium badges and call-to-actions
        struct PremiumGradients {
            static let gold = LinearGradient(
                colors: [Color.yellow, Color.orange],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            static let premium = LinearGradient(
                colors: [Color.purple, Color.blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            static let success = LinearGradient(
                colors: [Color.green, Color.teal],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - Shadow System (Apple's elevation layers)
    struct Shadow {
        // Subtle shadows for light elevation
        static let sm = Shadow(
            color: Color.black.opacity(0.04),
            radius: 2,
            x: 0,
            y: 1
        )
        
        // Medium shadows for cards
        static let md = Shadow(
            color: Color.black.opacity(0.08),
            radius: 8,
            x: 0,
            y: 4
        )
        
        // Prominent shadows for modals
        static let lg = Shadow(
            color: Color.black.opacity(0.12),
            radius: 16,
            x: 0,
            y: 8
        )
        
        // Hero shadows for primary actions
        static let xl = Shadow(
            color: Color.black.opacity(0.16),
            radius: 24,
            x: 0,
            y: 12
        )

        // MARK: - iOS 26 Glass Shadows
        // Specialized shadows for Liquid Glass UI elements

        /// Floating glass shadow for elevated cards
        static let glassFloating = Shadow(
            color: Color.black.opacity(0.12),
            radius: 16,
            x: 0,
            y: 8
        )

        /// Pressed glass shadow (reduced elevation)
        static let glassPressed = Shadow(
            color: Color.black.opacity(0.06),
            radius: 4,
            x: 0,
            y: 2
        )

        /// Elevated glass shadow for modals
        static let glassElevated = Shadow(
            color: Color.black.opacity(0.18),
            radius: 24,
            x: 0,
            y: 12
        )

        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
    
    // MARK: - Animation Timings (Apple's standard durations)
    struct Animation {
        static let fast: Double = 0.2
        static let normal: Double = 0.3
        static let slow: Double = 0.5
        static let spring = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.8)
        static let easeInOut = SwiftUI.Animation.easeInOut(duration: normal)
        static let bouncy = SwiftUI.Animation.spring(
            response: 0.6,
            dampingFraction: 0.7,
            blendDuration: 0.0
        )
    }
    
    // MARK: - Text Scaling Constants
    struct TextScaling {
        // Minimum scale factors for different text types
        static let titleMinScale: CGFloat = 0.7
        static let headlineMinScale: CGFloat = 0.6
        static let bodyMinScale: CGFloat = 0.5
        static let captionMinScale: CGFloat = 0.4
        static let numberMinScale: CGFloat = 0.8  // Numbers need higher readability
        
        // Maximum scale factors for responsive design
        static let maxScaleFactor: CGFloat = 1.2
        static let minScaleFactor: CGFloat = 0.3
        
        // Font size ranges for adaptive typography
        struct FontSizeRange {
            static let titleRange: ClosedRange<CGFloat> = 16...34
            static let headlineRange: ClosedRange<CGFloat> = 14...22
            static let bodyRange: ClosedRange<CGFloat> = 12...17
            static let captionRange: ClosedRange<CGFloat> = 10...13
            static let numberRange: ClosedRange<CGFloat> = 14...32
        }
        
        // Line height multipliers for better readability
        static let titleLineHeight: CGFloat = 1.2
        static let bodyLineHeight: CGFloat = 1.4
        static let captionLineHeight: CGFloat = 1.3
    }
    
    // MARK: - Component Sizing
    struct ComponentSize {
        static let buttonHeight: CGFloat = 50
        static let smallButtonHeight: CGFloat = 36
        static let textFieldHeight: CGFloat = 44
        static let cardMinHeight: CGFloat = 80
        static let iconSize: CGFloat = 24
        static let smallIconSize: CGFloat = 16
        static let largeIconSize: CGFloat = 32
        
        // Compact form sizing
        static let compactFieldHeight: CGFloat = 36
        static let inlineFieldHeight: CGFloat = 32
        static let minimumTouchTarget: CGFloat = 44
    }
}

// MARK: - View Extensions for Easy Access
extension View {
    func designSystemShadow(_ shadow: DesignTokens.Shadow) -> some View {
        self.shadow(
            color: shadow.color,
            radius: shadow.radius,
            x: shadow.x,
            y: shadow.y
        )
    }
    
    func cardStyle() -> some View {
        self
            .background(DesignTokens.Colors.Background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md))
            .designSystemShadow(DesignTokens.Shadow.md)
    }
    
    func primaryButtonStyle() -> some View {
        self
            .frame(height: DesignTokens.ComponentSize.buttonHeight)
            .background(DesignTokens.Colors.Primary.blue)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md))
            .designSystemShadow(DesignTokens.Shadow.sm)
    }
}