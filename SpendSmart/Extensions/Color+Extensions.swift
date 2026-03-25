import SwiftUI
import UIKit

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
    
    /// Create an adaptive color that automatically switches between light and dark mode
    static func adaptive(light: Color, dark: Color) -> Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }
    
    /// Create an adaptive color from hex values
    static func adaptiveHex(light: String, dark: String) -> Color {
        adaptive(light: Color(hex: light), dark: Color(hex: dark))
    }
    
    // MARK: - SpendSmart Brand Colors
    
    // Primary Brand Colors (Gradient Spectrum) - Same in both modes
    static let brandDeepNavy = Color(hex: "000B39")      // Darkest - depth, trust
    static let brandVibrantBlue = Color(hex: "4F6FF1")   // Primary - action, energy
    static let brandSkyBlue = Color(hex: "9EC4FF")       // Lightest - soft, friendly
    
    // Extended Palette (derived)
    static let brandMidnightBlue = Color(hex: "1A2B5C")  // Slightly lighter than navy
    static let brandRoyalBlue = Color(hex: "3B5BDB")     // Between navy and vibrant
    static let brandSoftBlue = Color(hex: "C7DBFF")      // Softer than sky
    static let brandIceBlue = Color(hex: "E8F1FF")       // Very light tint
    
    // Accent (single color for simple use cases)
    static let brandAccent = Color(hex: "4F6FF1")
    static let brandAccentLight = adaptiveHex(light: "E8F1FF", dark: "1A2B5C")
    
    // MARK: - Adaptive Backgrounds (Dark Mode Support)
    
    /// Main app background
    static let brandBackground = adaptiveHex(light: "FFFFFF", dark: "0A0F1E")
    
    /// Card/surface background
    static let brandSurface = adaptiveHex(light: "FAFBFC", dark: "141A2E")
    
    /// Elevated surface (sheets, modals)
    static let brandSurfaceElevated = adaptiveHex(light: "F8FAFF", dark: "1A2240")
    
    /// Border color
    static let brandBorder = adaptiveHex(light: "E5E9F2", dark: "2A3352")
    
    // MARK: - Adaptive Text Colors
    
    /// Primary text
    static let brandTextPrimary = adaptiveHex(light: "0A0F1E", dark: "F5F7FA")
    
    /// Secondary/muted text
    static let brandTextSecondary = adaptiveHex(light: "5C6584", dark: "9BA3BC")
    
    /// Tertiary/disabled text
    static let brandTextTertiary = adaptiveHex(light: "9BA3BC", dark: "5C6584")
    
    // MARK: - Semantic Colors (Adaptive)
    
    static let brandSuccess = Color(hex: "22C55E")
    static let brandSuccessLight = adaptiveHex(light: "ECFDF5", dark: "14532D")
    
    static let brandError = Color(hex: "EF4444")
    static let brandErrorLight = adaptiveHex(light: "FEF2F2", dark: "7F1D1D")
    
    static let brandWarning = Color(hex: "F59E0B")
    static let brandWarningLight = adaptiveHex(light: "FFFBEB", dark: "78350F")
    
    static let brandInfo = Color(hex: "3B82F6")
    static let brandInfoLight = adaptiveHex(light: "EFF6FF", dark: "1E3A5F")
    
    // MARK: - Chart Colors (Blue spectrum for data viz)
    
    static let chartBlue1 = Color(hex: "000B39")   // Darkest
    static let chartBlue2 = Color(hex: "2A3F8F")
    static let chartBlue3 = Color(hex: "4F6FF1")   // Primary
    static let chartBlue4 = Color(hex: "7B9BF7")
    static let chartBlue5 = Color(hex: "9EC4FF")   // Lightest
    
    // Extended chart palette for more data points
    static let chartColors: [Color] = [
        Color(hex: "4F6FF1"),  // Blue
        Color(hex: "22C55E"),  // Green
        Color(hex: "F59E0B"),  // Amber
        Color(hex: "EF4444"),  // Red
        Color(hex: "A855F7"),  // Purple
        Color(hex: "06B6D4"),  // Cyan
        Color(hex: "EC4899"),  // Pink
        Color(hex: "84CC16"),  // Lime
    ]
    
    // MARK: - Additional Brand Colors (centralized from scattered hex values)

    /// Purple accent used in illustrations and empty states
    static let brandPurple = Color(hex: "9333EA")

    /// Indigo accent used in category colors and charts
    static let brandIndigo = Color(hex: "6366F1")

    /// Dark navy variant used in gradient backgrounds (onboarding, login)
    static let brandDarkNavy = Color(hex: "0A1A4A")

    /// Roast feature colors (receipt detail view)
    static let brandRoastOrange = Color(hex: "FF4500")
    static let brandRoastDarkOrange = Color(hex: "FF8C00")

    /// Darker semantic color variants for shadows/edges
    static let brandSuccessDark = Color(hex: "16A34A")
    static let brandErrorDark = Color(hex: "DC2626")
    static let brandWarningDark = Color(hex: "D97706")

    static let brandPink = Color(hex: "EC4899")
    static let brandCyan = Color(hex: "06B6D4")

    // MARK: - Category Colors

    /// Standard category color mapping used across receipt views
    static func categoryColor(for category: String) -> Color {
        switch category.lowercased() {
        case "food", "groceries", "dining": return .brandSuccess
        case "shopping", "retail": return .brandInfo
        case "entertainment", "fun": return .brandPurple
        case "transport", "travel": return .brandWarning
        case "health", "medical": return .brandError
        default: return .brandIndigo
        }
    }

    // MARK: - Glassmorphism Colors
    
    /// Glass background for overlays
    static let glassBackground = adaptiveHex(light: "FFFFFF", dark: "1A2240").opacity(0.7)
    
    /// Glass border
    static let glassBorder = adaptiveHex(light: "FFFFFF", dark: "3A4562").opacity(0.5)
}

// MARK: - Brand Gradients

extension LinearGradient {
    /// Primary button gradient - vibrant and energetic
    static let brandPrimary = LinearGradient(
        colors: [Color(hex: "4F6FF1"), Color(hex: "3B5BDB")],
        startPoint: .top,
        endPoint: .bottom
    )
    
    /// Accent gradient for highlights
    static let brandAccent = LinearGradient(
        colors: [Color(hex: "9EC4FF"), Color(hex: "4F6FF1")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Subtle background gradient (adapts to dark mode)
    static var brandSubtle: LinearGradient {
        LinearGradient(
            colors: [
                Color.brandBackground,
                Color.brandSurfaceElevated
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    /// Deep gradient for premium feel
    static let brandDeep = LinearGradient(
        colors: [Color(hex: "1A2B5C"), Color(hex: "000B39")],
        startPoint: .top,
        endPoint: .bottom
    )
    
    /// Success gradient
    static let brandSuccessGradient = LinearGradient(
        colors: [Color(hex: "22C55E"), Color(hex: "16A34A")],
        startPoint: .top,
        endPoint: .bottom
    )
    
    /// Error/danger gradient
    static let brandDangerGradient = LinearGradient(
        colors: [Color(hex: "EF4444"), Color(hex: "DC2626")],
        startPoint: .top,
        endPoint: .bottom
    )
    
    /// Premium/gold gradient
    static let brandPremium = LinearGradient(
        colors: [Color(hex: "F59E0B"), Color(hex: "D97706")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Mesh Gradient

extension MeshGradient {
    /// Primary mesh gradient for buttons - 3D depth effect
    static var brandButton: MeshGradient {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                // Top row
                [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                // Middle row
                [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                // Bottom row
                [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
            ],
            colors: [
                // Top row - lighter (highlight)
                Color(hex: "7B9BF7"), Color(hex: "9EC4FF"), Color(hex: "7B9BF7"),
                // Middle row - primary
                Color(hex: "4F6FF1"), Color(hex: "5A7AF3"), Color(hex: "4F6FF1"),
                // Bottom row - darker (shadow)
                Color(hex: "3B5BDB"), Color(hex: "4F6FF1"), Color(hex: "3B5BDB")
            ]
        )
    }
    
    /// Pressed state mesh gradient - slightly darker
    static var brandButtonPressed: MeshGradient {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
            ],
            colors: [
                Color(hex: "4F6FF1"), Color(hex: "7B9BF7"), Color(hex: "4F6FF1"),
                Color(hex: "3B5BDB"), Color(hex: "4F6FF1"), Color(hex: "3B5BDB"),
                Color(hex: "2A3F8F"), Color(hex: "3B5BDB"), Color(hex: "2A3F8F")
            ]
        )
    }
    
    /// Hero/Feature mesh gradient - more dramatic
    static var brandHero: MeshGradient {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                [0.0, 0.5], [0.6, 0.4], [1.0, 0.5],
                [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
            ],
            colors: [
                Color(hex: "9EC4FF"), Color(hex: "C7DBFF"), Color(hex: "9EC4FF"),
                Color(hex: "4F6FF1"), Color(hex: "7B9BF7"), Color(hex: "4F6FF1"),
                Color(hex: "000B39"), Color(hex: "1A2B5C"), Color(hex: "000B39")
            ]
        )
    }
    
    /// Soft mesh for cards/backgrounds - adapts to theme
    static var brandSoft: MeshGradient {
        MeshGradient(
            width: 2,
            height: 2,
            points: [
                [0.0, 0.0], [1.0, 0.0],
                [0.0, 1.0], [1.0, 1.0]
            ],
            colors: [
                Color(hex: "FFFFFF"), Color(hex: "F8FAFF"),
                Color(hex: "F8FAFF"), Color(hex: "E8F1FF")
            ]
        )
    }

}

// MARK: - Card Styles

extension View {
    /// Apply brand card styling with optional elevation
    func brandCard(elevation: CardElevation = .low) -> some View {
        self
            .background(Color.brandSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(
                color: Color.black.opacity(elevation.shadowOpacity),
                radius: elevation.shadowRadius,
                y: elevation.shadowY
            )
    }
    
    /// Apply glass card styling (Liquid Glass deferred to iOS 26 adoption)
    func glassCard() -> some View {
        self
            .background(Color.brandSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    /// Apply clear glass card styling for media-rich contexts
    func glassCardClear() -> some View {
        self
            .background(Color.brandSurface.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

enum CardElevation {
    case none
    case low
    case medium
    case high
    
    var shadowOpacity: Double {
        switch self {
        case .none: return 0
        case .low: return 0.05
        case .medium: return 0.1
        case .high: return 0.15
        }
    }
    
    var shadowRadius: CGFloat {
        switch self {
        case .none: return 0
        case .low: return 4
        case .medium: return 8
        case .high: return 16
        }
    }
    
    var shadowY: CGFloat {
        switch self {
        case .none: return 0
        case .low: return 2
        case .medium: return 4
        case .high: return 8
        }
    }
}
