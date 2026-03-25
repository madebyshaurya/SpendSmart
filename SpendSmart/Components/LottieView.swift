import SwiftUI
import Lottie

// MARK: - LottieView SwiftUI Wrapper

/// A SwiftUI wrapper for Lottie animations
/// Supports loading from bundle, URL, or inline JSON data
struct LottieView: UIViewRepresentable {
    let animation: LottieAnimation?
    var loopMode: LottieLoopMode = .loop
    var contentMode: UIView.ContentMode = .scaleAspectFit
    var animationSpeed: CGFloat = 1.0
    var playOnAppear: Bool = true
    
    // MARK: - Initializers
    
    /// Initialize with an animation name from the bundle
    init(
        name: String,
        bundle: Bundle = .main,
        loopMode: LottieLoopMode = .loop,
        contentMode: UIView.ContentMode = .scaleAspectFit,
        animationSpeed: CGFloat = 1.0,
        playOnAppear: Bool = true
    ) {
        self.animation = LottieAnimation.named(name, bundle: bundle)
        self.loopMode = loopMode
        self.contentMode = contentMode
        self.animationSpeed = animationSpeed
        self.playOnAppear = playOnAppear
    }
    
    /// Initialize with a Lottie animation object directly
    init(
        animation: LottieAnimation?,
        loopMode: LottieLoopMode = .loop,
        contentMode: UIView.ContentMode = .scaleAspectFit,
        animationSpeed: CGFloat = 1.0,
        playOnAppear: Bool = true
    ) {
        self.animation = animation
        self.loopMode = loopMode
        self.contentMode = contentMode
        self.animationSpeed = animationSpeed
        self.playOnAppear = playOnAppear
    }
    
    /// Initialize with JSON data
    init(
        jsonData: Data,
        loopMode: LottieLoopMode = .loop,
        contentMode: UIView.ContentMode = .scaleAspectFit,
        animationSpeed: CGFloat = 1.0,
        playOnAppear: Bool = true
    ) {
        self.animation = try? LottieAnimation.from(data: jsonData)
        self.loopMode = loopMode
        self.contentMode = contentMode
        self.animationSpeed = animationSpeed
        self.playOnAppear = playOnAppear
    }
    
    func makeUIView(context: Context) -> LottieAnimationView {
        let animationView = LottieAnimationView()
        animationView.animation = animation
        animationView.contentMode = contentMode
        animationView.loopMode = loopMode
        animationView.animationSpeed = animationSpeed
        animationView.backgroundBehavior = .pauseAndRestore
        
        // Ensure it sizes correctly
        animationView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        animationView.setContentHuggingPriority(.defaultLow, for: .vertical)
        animationView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        animationView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        
        if playOnAppear {
            animationView.play()
        }
        
        return animationView
    }
    
    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        uiView.animation = animation
        uiView.loopMode = loopMode
        uiView.animationSpeed = animationSpeed
        uiView.contentMode = contentMode
        
        if playOnAppear && !uiView.isAnimationPlaying {
            uiView.play()
        }
    }
}

// MARK: - LottieView with Color Override

/// A version of LottieView that supports color overrides for dynamic theming
struct ThemedLottieView: UIViewRepresentable {
    let animation: LottieAnimation?
    var loopMode: LottieLoopMode = .loop
    var contentMode: UIView.ContentMode = .scaleAspectFit
    var animationSpeed: CGFloat = 1.0
    var colorOverrides: [String: Color] = [:]
    var playOnAppear: Bool = true
    
    func makeUIView(context: Context) -> LottieAnimationView {
        let animationView = LottieAnimationView()
        animationView.animation = animation
        animationView.contentMode = contentMode
        animationView.loopMode = loopMode
        animationView.animationSpeed = animationSpeed
        animationView.backgroundBehavior = .pauseAndRestore
        
        applyColorOverrides(to: animationView)
        
        if playOnAppear {
            animationView.play()
        }
        
        return animationView
    }
    
    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        uiView.animation = animation
        uiView.loopMode = loopMode
        uiView.animationSpeed = animationSpeed
        
        applyColorOverrides(to: uiView)
        
        if playOnAppear && !uiView.isAnimationPlaying {
            uiView.play()
        }
    }
    
    private func applyColorOverrides(to animationView: LottieAnimationView) {
        for (keypath, color) in colorOverrides {
            let uiColor = UIColor(color)
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            let lottieColor = LottieColor(r: red, g: green, b: blue, a: alpha)
            let colorProvider = ColorValueProvider(lottieColor)
            animationView.setValueProvider(
                colorProvider,
                keypath: AnimationKeypath(keypath: keypath)
            )
        }
    }
}

// MARK: - Controllable Lottie View

/// A LottieView with external playback control
struct ControllableLottieView: UIViewRepresentable {
    let animation: LottieAnimation?
    @Binding var isPlaying: Bool
    @Binding var progress: CGFloat
    var loopMode: LottieLoopMode = .loop
    var contentMode: UIView.ContentMode = .scaleAspectFit
    var animationSpeed: CGFloat = 1.0
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> LottieAnimationView {
        let animationView = LottieAnimationView()
        animationView.animation = animation
        animationView.contentMode = contentMode
        animationView.loopMode = loopMode
        animationView.animationSpeed = animationSpeed
        animationView.backgroundBehavior = .pauseAndRestore
        
        context.coordinator.animationView = animationView
        
        return animationView
    }
    
    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        if isPlaying && !uiView.isAnimationPlaying {
            uiView.play { completed in
                if completed {
                    Task { @MainActor in
                        self.isPlaying = false
                    }
                }
            }
        } else if !isPlaying && uiView.isAnimationPlaying {
            uiView.pause()
        }
        
        // Sync progress if not playing
        if !isPlaying {
            uiView.currentProgress = progress
        }
    }
    
    class Coordinator: NSObject {
        var parent: ControllableLottieView
        weak var animationView: LottieAnimationView?
        
        init(_ parent: ControllableLottieView) {
            self.parent = parent
        }
    }
}

// MARK: - Preview

#Preview("LottieView") {
    VStack(spacing: 20) {
        Text("Lottie View Wrapper")
            .font(.headline)
        
        Text("Add Lottie JSON files to the bundle to use this component")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding()
    }
    .padding()
}
