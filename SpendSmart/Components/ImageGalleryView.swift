import SwiftUI

/// Full-screen image gallery with pinch-to-zoom, swipe navigation, and share functionality
/// Used for viewing receipt images in detail
struct ImageGalleryView: View {
    let imageURLs: [String]
    let initialIndex: Int
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int
    @State private var showControls = true
    @StateObject private var haptics = HapticManager.shared
    
    init(imageURLs: [String], initialIndex: Int = 0) {
        self.imageURLs = imageURLs
        self.initialIndex = initialIndex
        self._currentIndex = State(initialValue: initialIndex)
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            // Image pager
            TabView(selection: $currentIndex) {
                ForEach(imageURLs.indices, id: \.self) { index in
                    ZoomableImageView(url: imageURLs[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: currentIndex) { _, _ in
                haptics.scrollSnap()
            }
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showControls.toggle()
                }
            }
            
            // Controls overlay
            if showControls {
                VStack {
                    // Top bar
                    HStack {
                        Button {
                            haptics.buttonPress()
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.white.opacity(0.9))
                                .shadow(radius: 4)
                        }
                        
                        Spacer()
                        
                        // Page indicator text
                        if imageURLs.count > 1 {
                            Text("\(currentIndex + 1) / \(imageURLs.count)")
                                .font(.manrope(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial.opacity(0.8))
                                .clipShape(Capsule())
                        }
                        
                        Spacer()
                        
                        // Share button
                        ShareLink(item: URL(string: imageURLs[currentIndex]) ?? URL(string: "https://example.com")!) {
                            Image(systemName: "square.and.arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.white.opacity(0.9))
                                .shadow(radius: 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    Spacer()
                    
                    // Bottom page dots
                    if imageURLs.count > 1 {
                        HStack(spacing: 8) {
                            ForEach(imageURLs.indices, id: \.self) { index in
                                Circle()
                                    .fill(currentIndex == index ? Color.white : Color.white.opacity(0.4))
                                    .frame(width: 8, height: 8)
                                    .scaleEffect(currentIndex == index ? 1.2 : 1.0)
                                    .animation(.spring(duration: 0.3), value: currentIndex)
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
                .transition(.opacity)
            }
        }
        .statusBar(hidden: !showControls)
        .persistentSystemOverlays(showControls ? .automatic : .hidden)
    }
}

/// Individual zoomable image view with gesture support
struct ZoomableImageView: View {
    let url: String
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var imageSize: CGSize = .zero
    
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 5.0
    
    var body: some View {
        GeometryReader { geometry in
            AsyncImage(url: URL(string: url)) { phase in
                switch phase {
                case .empty:
                    loadingView
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            SimultaneousGesture(
                                // Magnification gesture
                                MagnificationGesture()
                                    .onChanged { value in
                                        let delta = value / lastScale
                                        lastScale = value
                                        let newScale = scale * delta
                                        scale = min(maxScale, max(minScale, newScale))
                                    }
                                    .onEnded { _ in
                                        lastScale = 1.0
                                        withAnimation(.spring(duration: 0.3)) {
                                            if scale < minScale {
                                                scale = minScale
                                                offset = .zero
                                            }
                                        }
                                    },
                                // Drag gesture (only when zoomed)
                                DragGesture()
                                    .onChanged { value in
                                        if scale > 1 {
                                            offset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                        }
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                        // Bounce back if out of bounds
                                        withAnimation(.spring(duration: 0.3)) {
                                            constrainOffset(in: geometry.size)
                                        }
                                    }
                            )
                        )
                        .gesture(
                            // Double tap to zoom
                            TapGesture(count: 2)
                                .onEnded {
                                    withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                                        if scale > 1.5 {
                                            scale = 1.0
                                            offset = .zero
                                            lastOffset = .zero
                                        } else {
                                            scale = 2.5
                                        }
                                    }
                                    HapticManager.shared.medium()
                                }
                        )
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        
                case .failure:
                    errorView
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            Text("Loading image...")
                .font(.manrope(size: 14))
                .foregroundStyle(.white.opacity(0.7))
        }
    }
    
    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Failed to load image")
                .font(.manrope(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
        }
    }
    
    private func constrainOffset(in size: CGSize) {
        // Calculate max offset based on scale
        let scaledWidth = size.width * scale
        let scaledHeight = size.height * scale
        
        let maxOffsetX = max(0, (scaledWidth - size.width) / 2)
        let maxOffsetY = max(0, (scaledHeight - size.height) / 2)
        
        offset.width = min(maxOffsetX, max(-maxOffsetX, offset.width))
        offset.height = min(maxOffsetY, max(-maxOffsetY, offset.height))
        lastOffset = offset
        
        // Reset if scale is 1
        if scale <= 1.0 {
            offset = .zero
            lastOffset = .zero
        }
    }
}

// MARK: - UIImage Gallery (for local images)

struct UIImageGalleryView: View {
    let images: [UIImage]
    let initialIndex: Int
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int
    @State private var showControls = true
    @StateObject private var haptics = HapticManager.shared
    
    init(images: [UIImage], initialIndex: Int = 0) {
        self.images = images
        self.initialIndex = initialIndex
        self._currentIndex = State(initialValue: initialIndex)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            TabView(selection: $currentIndex) {
                ForEach(images.indices, id: \.self) { index in
                    ZoomableUIImageView(image: images[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: currentIndex) { _, _ in
                haptics.scrollSnap()
            }
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showControls.toggle()
                }
            }
            
            if showControls {
                VStack {
                    HStack {
                        Button {
                            haptics.buttonPress()
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.white.opacity(0.9))
                                .shadow(radius: 4)
                        }
                        
                        Spacer()
                        
                        if images.count > 1 {
                            Text("\(currentIndex + 1) / \(images.count)")
                                .font(.manrope(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial.opacity(0.8))
                                .clipShape(Capsule())
                        }
                        
                        Spacer()
                        
                        ShareLink(item: Image(uiImage: images[currentIndex]), preview: SharePreview("Receipt Image", image: Image(uiImage: images[currentIndex]))) {
                            Image(systemName: "square.and.arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.white.opacity(0.9))
                                .shadow(radius: 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    Spacer()
                    
                    if images.count > 1 {
                        HStack(spacing: 8) {
                            ForEach(images.indices, id: \.self) { index in
                                Circle()
                                    .fill(currentIndex == index ? Color.white : Color.white.opacity(0.4))
                                    .frame(width: 8, height: 8)
                                    .scaleEffect(currentIndex == index ? 1.2 : 1.0)
                                    .animation(.spring(duration: 0.3), value: currentIndex)
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
                .transition(.opacity)
            }
        }
        .statusBar(hidden: !showControls)
        .persistentSystemOverlays(showControls ? .automatic : .hidden)
    }
}

struct ZoomableUIImageView: View {
    let image: UIImage
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 5.0
    
    var body: some View {
        GeometryReader { geometry in
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / lastScale
                                lastScale = value
                                let newScale = scale * delta
                                scale = min(maxScale, max(minScale, newScale))
                            }
                            .onEnded { _ in
                                lastScale = 1.0
                                withAnimation(.spring(duration: 0.3)) {
                                    if scale < minScale {
                                        scale = minScale
                                        offset = .zero
                                    }
                                }
                            },
                        DragGesture()
                            .onChanged { value in
                                if scale > 1 {
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                            }
                            .onEnded { _ in
                                lastOffset = offset
                                withAnimation(.spring(duration: 0.3)) {
                                    constrainOffset(in: geometry.size)
                                }
                            }
                    )
                )
                .gesture(
                    TapGesture(count: 2)
                        .onEnded {
                            withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                                if scale > 1.5 {
                                    scale = 1.0
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    scale = 2.5
                                }
                            }
                            HapticManager.shared.medium()
                        }
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
    
    private func constrainOffset(in size: CGSize) {
        let scaledWidth = size.width * scale
        let scaledHeight = size.height * scale
        
        let maxOffsetX = max(0, (scaledWidth - size.width) / 2)
        let maxOffsetY = max(0, (scaledHeight - size.height) / 2)
        
        offset.width = min(maxOffsetX, max(-maxOffsetX, offset.width))
        offset.height = min(maxOffsetY, max(-maxOffsetY, offset.height))
        lastOffset = offset
        
        if scale <= 1.0 {
            offset = .zero
            lastOffset = .zero
        }
    }
}

// MARK: - Receipt Image Thumbnail Row

/// Tappable receipt image thumbnails that open the gallery
struct ReceiptImageRow: View {
    let imageURLs: [String]
    @State private var showGallery = false
    @State private var selectedIndex = 0
    @StateObject private var haptics = HapticManager.shared
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(imageURLs.indices, id: \.self) { index in
                    Button {
                        selectedIndex = index
                        showGallery = true
                        haptics.medium()
                    } label: {
                        AsyncImage(url: URL(string: imageURLs[index])) { phase in
                            switch phase {
                            case .empty:
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.brandSurface)
                                    .frame(width: 100, height: 140)
                                    .overlay(
                                        ProgressView()
                                    )
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 140)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.brandBorder, lineWidth: 1)
                                    )
                                    .overlay(alignment: .bottomTrailing) {
                                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.white)
                                            .padding(6)
                                            .background(.black.opacity(0.5))
                                            .clipShape(Circle())
                                            .padding(6)
                                    }
                            case .failure:
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.brandSurface)
                                    .frame(width: 100, height: 140)
                                    .overlay(
                                        Image(systemName: "exclamationmark.triangle")
                                            .foregroundStyle(.orange)
                                    )
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)
        }
        .fullScreenCover(isPresented: $showGallery) {
            ImageGalleryView(imageURLs: imageURLs, initialIndex: selectedIndex)
        }
    }
}

#Preview("Gallery") {
    ImageGalleryView(imageURLs: [
        "https://via.placeholder.com/600x800",
        "https://via.placeholder.com/600x900",
        "https://via.placeholder.com/600x1000"
    ])
}

#Preview("Thumbnail Row") {
    ReceiptImageRow(imageURLs: [
        "https://via.placeholder.com/300x400",
        "https://via.placeholder.com/300x500"
    ])
    .padding()
}
