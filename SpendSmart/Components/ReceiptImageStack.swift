import SwiftUI
import UIKit

struct ReceiptImageStack<AddButton: View>: View {
    @Binding var images: [UIImage]
    let onDelete: (Int) -> Void
    let showsAddButton: Bool
    @ViewBuilder let addButton: AddButton
    
    @State private var isGridMode = false
    @Namespace private var animation
    
    // Drag state for the top card
    @State private var offset: CGSize = .zero
    @State private var isDragging = false
    
    init(
        images: Binding<[UIImage]>,
        onDelete: @escaping (Int) -> Void,
        showsAddButton: Bool = true,
        @ViewBuilder addButton: () -> AddButton
    ) {
        self._images = images
        self.onDelete = onDelete
        self.showsAddButton = showsAddButton
        self.addButton = addButton()
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header with toggle
            HStack {
                Text("\(images.count) Photo\(images.count == 1 ? "" : "s")")
                    .font(.manrope(size: 14, weight: .medium))
                    .foregroundStyle(Color.brandTextSecondary)
                
                Spacer()
                
                if !images.isEmpty {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isGridMode.toggle()
                        }
                    } label: {
                        Image(systemName: isGridMode ? "rectangle.stack" : "square.grid.2x2")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.brandVibrantBlue)
                            .frame(width: 32, height: 32)
                            .background(Color.brandIceBlue)
                            .clipShape(Circle())
                    }
                }
            }
            .padding(.horizontal, 4)
            
            if isGridMode {
                gridView
            } else {
                stackView
            }
        }
    }
    
    // MARK: - Grid View
    
    private var gridView: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 12)], spacing: 12) {
            ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .matchedGeometryEffect(id: "image\(index)", in: animation)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
                    
                    // Size Badge
                    Text(image.fileSizeMB)
                        .font(.manrope(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Capsule())
                        .padding(6)
                    
                    // Delete Button
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            onDelete(index)
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Color.red.opacity(0.8))
                            .clipShape(Circle())
                    }
                    .offset(x: 6, y: -6)
                }
            }
            
            // Add Button in Grid
            if showsAddButton && images.count < 5 {
                addButton
                    .frame(height: 120)
            }
        }
        .padding(4)
        .transition(.opacity)
    }
    
    // MARK: - Stack View
    
    private var stackView: some View {
        ZStack {
            if images.isEmpty {
                // Empty State
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.brandTextTertiary)
                    Text("No images attached")
                        .font(.manrope(size: 14))
                        .foregroundStyle(Color.brandTextTertiary)
                    
                    if showsAddButton {
                        addButton
                            .frame(width: 120, height: 40)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .background(Color.brandSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
                        .foregroundStyle(Color.brandBorder)
                )
            } else {
                // Stack of cards
                ZStack {
                    // Add button underneath (visible when cards are swiped away or transparent)
                    if showsAddButton && images.count < 5 {
                        addButton
                            .frame(width: 200, height: 280)
                            .scaleEffect(0.9)
                            .offset(y: 20)
                            .opacity(0.5)
                    }
                    
                    // Reversed to show first item on top
                    ForEach(Array(images.enumerated().reversed()), id: \.offset) { index, image in
                        // Only show top 3 cards for performance/visuals
                        if index < 3 {
                            cardView(for: image, index: index)
                        }
                    }
                }
                .frame(height: 300)
            }
        }
    }
    
    private func cardView(for image: UIImage, index: Int) -> some View {
        let isTop = index == 0
        let yOffset = CGFloat(index) * 4
        let scale = 1.0 - (CGFloat(index) * 0.05)
        
        return ZStack(alignment: .bottom) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 220, height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .matchedGeometryEffect(id: "image\(index)", in: animation)
                .shadow(color: Color.black.opacity(0.15), radius: 10, y: 5)
            
            // Info Overlay
            HStack {
                Image(systemName: "doc.text.image")
                    .font(.system(size: 12))
                Text(image.fileSizeMB)
                    .font(.manrope(size: 12, weight: .bold))
                Spacer()
                Text("\(index + 1)/\(images.count)")
                    .font(.manrope(size: 12, weight: .medium))
            }
            .foregroundStyle(.white)
            .padding(12)
            .background(
                LinearGradient(
                    colors: [.black.opacity(0.7), .clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .clipShape(
                RoundedCornerShape(radius: 16, corners: [.bottomLeft, .bottomRight])
            )
            .frame(width: 220)
        }
        .offset(y: isTop ? offset.height : yOffset)
        .offset(x: isTop ? offset.width : 0)
        .scaleEffect(isTop ? 1.0 : scale)
        .rotationEffect(.degrees(isTop ? Double(offset.width / 20) : 0))
        .opacity(isTop && isDragging ? 1.0 : (1.0 - Double(index) * 0.2))
        .zIndex(Double(images.count - index))
        .gesture(
            isTop ?
            DragGesture()
                .onChanged { gesture in
                    isDragging = true
                    // Add resistance
                    let translation = gesture.translation
                    offset = CGSize(width: translation.width, height: translation.height)
                }
                .onEnded { gesture in
                    isDragging = false
                    let width = gesture.translation.width
                    let velocity = gesture.predictedEndLocation.x - gesture.location.x
                    
                    // Swipe Threshold
                    if abs(width) > 100 || abs(velocity) > 500 {
                        // Swipe away
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            offset.width = width > 0 ? 1000 : -1000
                        }
                        
                        // Wait for animation then delete
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onDelete(index) // Delete the top item
                            offset = .zero // Reset for next top item
                        }
                    } else {
                        // Snap back
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                            offset = .zero
                        }
                    }
                }
            : nil
        )
    }
}

// Helper for rounded corners on specific sides
private struct RoundedCornerShape: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
