import SwiftUI
import UIKit
import ImageIO

struct GifView: UIViewRepresentable {
    let name: String
    let speedMultiplier: Double
    
    init(name: String, speedMultiplier: Double = 1.0) {
        self.name = name
        self.speedMultiplier = speedMultiplier
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        
        // Try to load from Assets first (Dataset)
        guard let asset = NSDataAsset(name: name) else {
            print("GifView Error: Asset '\(name)' not found.")
            return view
        }
        
        let data = asset.data
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            print("GifView Error: Could not create image source.")
            return view
        }
        
        var images: [UIImage] = []
        var totalDuration: Double = 0
        
        let count = CGImageSourceGetCount(source)
        for i in 0..<count {
            if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                images.append(UIImage(cgImage: cgImage))
                
                // Get frame duration
                var frameDuration: Double = 0.1 // Default fallback
                if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
                   let gifProperties = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
                    
                    if let delayTime = gifProperties[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double {
                        frameDuration = delayTime
                    } else if let delayTime = gifProperties[kCGImagePropertyGIFDelayTime as String] as? Double {
                        frameDuration = delayTime
                    }
                }
                
                // Fix for very short frames which some browsers/devices ignore
                if frameDuration < 0.011 {
                    frameDuration = 0.100
                }
                
                totalDuration += frameDuration
            }
        }
        
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.animationImages = images
        imageView.animationDuration = totalDuration / speedMultiplier
        imageView.startAnimating()
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}
