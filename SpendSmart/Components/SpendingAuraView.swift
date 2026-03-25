import SwiftUI
import UIKit

struct SpendingAuraView: View {
    let topCategory: String
    let totalSpent: Double
    let primaryColor: Color
    let secondaryColor: Color
    
    @State private var animate = false
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    
    @Environment(\.displayScale) var displayScale
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Your Finance Aura")
                    .font(.instrumentSerifItalic(size: 24))
                    .foregroundStyle(Color.brandTextPrimary)
                Spacer()
                ShareButton {
                    generateShareImage()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Aura Blob
            ZStack {
                // Background Glow
                Circle()
                    .fill(primaryColor.opacity(0.2))
                    .frame(width: 240, height: 240)
                    .blur(radius: 40)
                    .scaleEffect(animate ? 1.1 : 0.9)
                
                // Core Aura
                TimelineView(.animation) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    
                    Canvas { context, size in
                        let center = CGPoint(x: size.width / 2, y: size.height / 2)
                        
                        // Layer 1: Primary Blob
                        var path1 = Path()
                        path1.addArc(center: center, radius: 80 + sin(time * 1.5) * 10, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
                        
                        context.fill(
                            path1,
                            with: .linearGradient(
                                Gradient(colors: [primaryColor, secondaryColor]),
                                startPoint: CGPoint(x: 0, y: 0),
                                endPoint: CGPoint(x: size.width, y: size.height)
                            )
                        )
                        
                        // Layer 2: Orbiting Blob
                        let orbitX = center.x + cos(time) * 50
                        let orbitY = center.y + sin(time) * 30
                        var path2 = Path()
                        path2.addArc(center: CGPoint(x: orbitX, y: orbitY), radius: 40, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
                        
                        context.fill(path2, with: .color(secondaryColor.opacity(0.6)))
                        context.addFilter(.blur(radius: 20))
                    }
                }
                .frame(height: 250)
                
                // Vibe Label
                VStack(spacing: 8) {
                    Text(vibeTitle)
                        .font(.ibmPlexMono(size: 24))
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    
                    Text(vibeSubtitle)
                        .font(.manrope(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(.black.opacity(0.2))
                                .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
                        )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            
            // Footer Stats
            HStack {
                VStack(alignment: .leading) {
                    Text("Top Category")
                        .font(.manrope(size: 11))
                        .foregroundStyle(Color.brandTextTertiary)
                    Text(topCategory)
                        .font(.manrope(size: 14, weight: .semibold))
                        .foregroundStyle(Color.brandTextPrimary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Intensity")
                        .font(.manrope(size: 11))
                        .foregroundStyle(Color.brandTextTertiary)
                    Text(intensityLabel)
                        .font(.manrope(size: 14, weight: .semibold))
                        .foregroundStyle(primaryColor)
                }
            }
            .padding(20)
            .background(Color.brandSurface.opacity(0.5))
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.brandSurface)
                .shadow(color: primaryColor.opacity(0.15), radius: 20, x: 0, y: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [primaryColor.opacity(0.5), secondaryColor.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let shareImage {
                LocalShareSheet(items: [shareImage])
            }
        }
    }
    
    // MARK: - Logic
    
    private var vibeTitle: String {
        switch topCategory.lowercased() {
        case "dining": return "The Foodie"
        case "groceries": return "The Chef"
        case "shopping": return "The Curator"
        case "transport": return "The Nomad"
        case "entertainment": return "The Vibe"
        case "health": return "The Healer"
        case "services": return "The Boss"
        default: return "The Enigma"
        }
    }
    
    private var vibeSubtitle: String {
        if totalSpent > 2000 { return "High Roller Energy 💎" }
        if totalSpent > 1000 { return "Balanced Flow 🌊" }
        if totalSpent > 500 { return "Steady & Focused 🎯" }
        return "Minimalist Soul 🍃"
    }
    
    private var intensityLabel: String {
        if totalSpent > 2000 { return "Radiant" }
        if totalSpent > 1000 { return "Bright" }
        return "Soft"
    }
    
    @MainActor
    private func generateShareImage() {
        let renderer = ImageRenderer(content: self.frame(width: 350))
        renderer.scale = displayScale
        if let image = renderer.uiImage {
            shareImage = image
            showShareSheet = true
        }
    }
}

private struct ShareButton: View {
    let action: () -> Void
    
    var body: some View {
        Button {
            HapticManager.shared.medium()
            action()
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.brandTextSecondary)
                .padding(8)
                .background(
                    Circle()
                        .fill(Color.brandBackground)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                )
        }
    }
}

private struct LocalShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    var activities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: activities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
