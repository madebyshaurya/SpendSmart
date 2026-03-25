import SwiftUI

// MARK: - Empty State View

/// A beautiful, illustrated empty state view that can be customized for different screens
/// Now with rich animated illustrations for a delightful user experience
struct EmptyStateView: View {
    let type: EmptyStateType
    var action: (() -> Void)? = nil
    var actionTitle: String? = nil
    
    @State private var contentAppeared = false
    
    enum EmptyStateType {
        case receipts
        case receiptsSearch
        case dashboard
        case map
        case chat
        
        var animationType: AnimatedIllustration.IllustrationType {
            switch self {
            case .receipts: return .receipts
            case .receiptsSearch: return .receiptsSearch
            case .dashboard: return .dashboard
            case .map: return .map
            case .chat: return .chat
            }
        }
        
        var title: String {
            switch self {
            case .receipts: return "No Receipts Yet"
            case .receiptsSearch: return "No Results Found"
            case .dashboard: return "No Spending Data"
            case .map: return "No Store Visits"
            case .chat: return "Start a Conversation"
            }
        }
        
        var subtitle: String {
            switch self {
            case .receipts: return "Scan your first receipt to start tracking your spending"
            case .receiptsSearch: return "Try adjusting your search or filters"
            case .dashboard: return "Your spending insights will appear here once you scan some receipts"
            case .map: return "Your visited stores will appear on the map after scanning receipts with addresses"
            case .chat: return "Ask me anything about your spending, receipts, or get financial insights"
            }
        }
        
        var gradientColors: [Color] {
            switch self {
            case .receipts: return [Color.brandVibrantBlue, Color.brandSkyBlue]
            case .receiptsSearch: return [Color.brandRoyalBlue, Color.brandVibrantBlue]
            case .dashboard: return [Color.brandDeepNavy, Color.brandVibrantBlue]
            case .map: return [Color.brandSuccess, Color.brandVibrantBlue]
            case .chat: return [Color.brandVibrantBlue, Color.brandPurple]
            }
        }
        
        var defaultActionTitle: String? {
            switch self {
            case .receipts: return "Scan your first receipt"
            case .receiptsSearch: return "Clear Filters"
            case .dashboard: return "Scan a receipt to begin"
            case .map: return "Scan a receipt with an address"
            case .chat: return "Ask about your spending"
            }
        }

        var actionIcon: String {
            switch self {
            case .receipts: return "camera.fill"
            case .receiptsSearch: return "xmark.circle"
            case .dashboard: return "camera.fill"
            case .map: return "camera.fill"
            case .chat: return "sparkles"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            
            // Rich animated illustration
            AnimatedIllustration(type: type.animationType)
                .scaleEffect(contentAppeared ? 1.0 : 0.8)
                .opacity(contentAppeared ? 1 : 0)
            
            // Title and subtitle with staggered entrance
            VStack(spacing: 12) {
                Text(type.title)
                    .font(.instrumentSerifItalic(size: 28))
                    .foregroundStyle(Color.brandTextPrimary)
                    .multilineTextAlignment(.center)
                    .offset(y: contentAppeared ? 0 : 20)
                    .opacity(contentAppeared ? 1 : 0)
                
                Text(type.subtitle)
                    .font(.manrope(size: 15, weight: .regular))
                    .foregroundStyle(Color.brandTextSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
                    .offset(y: contentAppeared ? 0 : 15)
                    .opacity(contentAppeared ? 1 : 0)
            }
            .padding(.horizontal, 32)
            
            // Action button (optional) with delayed entrance
            if let action = action, let title = actionTitle ?? type.defaultActionTitle {
                Button(action: action) {
                    HStack(spacing: 8) {
                        Image(systemName: type.actionIcon)
                            .font(.system(size: 14, weight: .semibold))
                        Text(title)
                            .font(.manrope(size: 15, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(
                        MeshGradient.brandButton
                    )
                    .clipShape(Capsule())
                    .shadow(color: type.gradientColors[0].opacity(0.4), radius: 12, x: 0, y: 6)
                }
                .scaleEffect(contentAppeared ? 1.0 : 0.9)
                .opacity(contentAppeared ? 1 : 0)
                .padding(.top, 8)
            }
            
            Spacer()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                contentAppeared = true
            }
        }
    }
}

// MARK: - Compact Empty State

/// A more compact empty state for smaller areas or inline use
struct CompactEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String
    var color: Color = .brandVibrantBlue
    
    @State private var appeared = false
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Animated background ring
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 2)
                    .frame(width: 68, height: 68)
                    .scaleEffect(appeared ? 1.0 : 0.8)
                
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(color)
                    .scaleEffect(appeared ? 1.0 : 0.5)
            }
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.manrope(size: 16, weight: .semibold))
                    .foregroundStyle(Color.brandTextPrimary)
                
                Text(subtitle)
                    .font(.manrope(size: 13, weight: .regular))
                    .foregroundStyle(Color.brandTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .offset(y: appeared ? 0 : 10)
            .opacity(appeared ? 1 : 0)
        }
        .padding()
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appeared = true
            }
        }
    }
}

// MARK: - Empty Card State

/// An empty state designed to fit within a card container
struct EmptyCardState: View {
    let icon: String
    let message: String
    var iconColor: Color = .brandVibrantBlue
    
    @State private var iconPulse = false
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Subtle pulse effect
                Circle()
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 50, height: 50)
                    .scaleEffect(iconPulse ? 1.2 : 1.0)
                    .opacity(iconPulse ? 0 : 0.5)
                
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(iconColor.opacity(0.6))
            }
            
            Text(message)
                .font(.manrope(size: 14, weight: .medium))
                .foregroundStyle(Color.brandTextTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                iconPulse = true
            }
        }
    }
}

// MARK: - Mini Empty State

/// A minimal empty state for very small containers
struct MiniEmptyState: View {
    let icon: String
    let message: String
    var iconColor: Color = .brandTextTertiary
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(iconColor)
            
            Text(message)
                .font(.manrope(size: 13, weight: .medium))
                .foregroundStyle(Color.brandTextSecondary)
        }
        .padding(.vertical, 16)
    }
}

// MARK: - Preview

#Preview("Receipts Empty") {
    EmptyStateView(type: .receipts, action: {}, actionTitle: "Scan Receipt")
}

#Preview("Dashboard Empty") {
    EmptyStateView(type: .dashboard)
}

#Preview("Map Empty") {
    EmptyStateView(type: .map)
}

#Preview("Search Empty") {
    EmptyStateView(type: .receiptsSearch, action: {}, actionTitle: "Clear Filters")
}

#Preview("Chat Empty") {
    EmptyStateView(type: .chat)
}

#Preview("Compact") {
    CompactEmptyState(
        icon: "tag.fill",
        title: "No Savings",
        subtitle: "Your savings will appear here"
    )
}

#Preview("Card Empty") {
    EmptyCardState(
        icon: "chart.bar",
        message: "No data available"
    )
    .padding()
    .background(Color.brandSurface)
    .cornerRadius(16)
    .padding()
}

#Preview("All Empty States") {
    ScrollView {
        VStack(spacing: 60) {
            EmptyStateView(type: .receipts, action: {}, actionTitle: "Scan Receipt")
                .frame(height: 400)
            
            Divider()
            
            EmptyStateView(type: .receiptsSearch, action: {}, actionTitle: "Clear Filters")
                .frame(height: 400)
            
            Divider()
            
            EmptyStateView(type: .dashboard)
                .frame(height: 400)
            
            Divider()
            
            EmptyStateView(type: .map)
                .frame(height: 400)
            
            Divider()
            
            EmptyStateView(type: .chat)
                .frame(height: 400)
        }
    }
}
