import UIKit
import CoreImage
import Vision

class ReceiptImageProcessor {
    static let shared = ReceiptImageProcessor()
    private let context: CIContext
    
    private init() {
        if let d = MTLCreateSystemDefaultDevice() { context = CIContext(mtlDevice: d) }
        else { context = CIContext() }
    }
    
    func enhanceReceiptImage(_ image: UIImage) -> UIImage {
        guard let ci = CIImage(image: image) else { return image }
        let out = ci |> adjustExp |> enhanceContrast |> sharpen |> normalize |> reducedNoise
        let ui = render(out) ?? image
        ui.accessibilityHint = "enhanced_receipt"
        return ui
    }
    
    func processImageWithAnalysis(_ image: UIImage, processingType: String) async -> (image: UIImage, result: ImageProcessingResult) {
        let analysis = await analyze(image)
        let enhanced = enhanceReceiptImage(image)
        return (enhanced, ImageProcessingResult(overallConfidence: analysis.confidence, processingType: processingType, detectedRectangle: analysis.detectedRectangle, qualityIssues: analysis.issues, canAdjustManually: analysis.canAdjust, isStitched: false))
    }
    
    private func analyze(_ image: UIImage) async -> ImageQualityAnalysis {
        var issues: [String] = [], conf = 1.0
        let b = brightness(image)
        if b < 0.3 { issues.append("Dark"); conf -= 0.2 } else if b > 0.8 { issues.append("Bright"); conf -= 0.1 }
        if sharpness(image) < 0.4 { issues.append("Blurry"); conf -= 0.25 }
        let rect = await detectRect(image)
        if rect == nil { issues.append("No boundary"); conf -= 0.15 }
        return ImageQualityAnalysis(confidence: max(0, min(1, conf)), issues: issues, detectedRectangle: rect, canAdjust: rect != nil)
    }
    
    func cropToDocument(_ image: UIImage, with obs: VNRectangleObservation) -> UIImage {
        guard let ci = CIImage(image: image) else { return image }
        let sz = ci.extent.size
        let p = { (pt: CGPoint) in CGPoint(x: pt.x * sz.width, y: (1 - pt.y) * sz.height) }
        return render(perspective(ci, tl: p(obs.topLeft), tr: p(obs.topRight), bl: p(obs.bottomLeft), br: p(obs.bottomRight))) ?? image
    }
    
    func applyPerspectiveCorrection(_ image: UIImage, corners: [CGPoint]) -> UIImage {
        guard corners.count == 4, let ci = CIImage(image: image) else { return image }
        return render(perspective(ci, tl: corners[0], tr: corners[1], bl: corners[3], br: corners[2])) ?? image
    }
    
    func optimizeForAI(_ image: UIImage) -> UIImage {
        let resized = resize(image, maxDim: 2048)
        guard let ci = CIImage(image: resized) else { return resized }
        let opt = ci |> sharpen |> adjustForOCR
        let ui = render(opt) ?? resized
        ui.accessibilityHint = "enhanced_receipt"
        return ui
    }
    
    func processGalleryImages(_ images: [UIImage]) async -> [UIImage] {
        if images.count > 1 {
            let res = await MultiPartReceiptProcessor.shared.processMultiPartReceipt(images)
            return res.processedImages
        }
        guard let img = images.first else { return [] }
        let rect = await detectRect(img)
        let cropped = rect.map { cropToDocument(img, with: $0) } ?? img
        return [enhanceReceiptImage(cropped)]
    }
    
    private func detectRect(_ image: UIImage) async -> VNRectangleObservation? {
        guard let cg = image.cgImage else { return nil }
        return await withCheckedContinuation { c in
            let req = VNDetectRectanglesRequest { r, _ in
                c.resume(returning: (r.results as? [VNRectangleObservation])?.max { ($0.boundingBox.width * $0.boundingBox.height) < ($1.boundingBox.width * $1.boundingBox.height) })
            }
            req.maximumObservations = 5
            req.minimumAspectRatio = 0.2
            req.maximumAspectRatio = 5.0
            req.minimumSize = 0.3
            req.minimumConfidence = 0.7
            try? VNImageRequestHandler(cgImage: cg).perform([req])
        }
    }
    
    private func adjustExp(_ i: CIImage) -> CIImage {
        let f = CIFilter(name: "CIExposureAdjust")!
        f.setValue(i, forKey: kCIInputImageKey)
        f.setValue(0.5, forKey: kCIInputEVKey)
        let b = CIFilter(name: "CIColorControls")!
        b.setValue(f.outputImage ?? i, forKey: kCIInputImageKey)
        b.setValue(0.1, forKey: kCIInputBrightnessKey)
        return b.outputImage ?? f.outputImage ?? i
    }
    
    private func enhanceContrast(_ i: CIImage) -> CIImage {
        let f = CIFilter(name: "CIColorControls")!
        f.setValue(i, forKey: kCIInputImageKey)
        f.setValue(1.2, forKey: kCIInputContrastKey)
        return f.outputImage ?? i
    }
    
    private func sharpen(_ i: CIImage) -> CIImage {
        let f = CIFilter(name: "CISharpenLuminance")!
        f.setValue(i, forKey: kCIInputImageKey)
        f.setValue(0.6, forKey: kCIInputSharpnessKey)
        return f.outputImage ?? i
    }
    
    private func normalize(_ i: CIImage) -> CIImage {
        let f = CIFilter(name: "CIColorControls")!
        f.setValue(i, forKey: kCIInputImageKey)
        f.setValue(1.0, forKey: kCIInputSaturationKey)
        return f.outputImage ?? i
    }
    
    private func reducedNoise(_ i: CIImage) -> CIImage {
        let f = CIFilter(name: "CINoiseReduction")!
        f.setValue(i, forKey: kCIInputImageKey)
        f.setValue(0.02, forKey: "inputNoiseReductionAmount")
        return f.outputImage ?? i
    }
    
    private func adjustForOCR(_ i: CIImage) -> CIImage {
        let f = CIFilter(name: "CIColorControls")!
        f.setValue(i, forKey: kCIInputImageKey)
        f.setValue(1.3, forKey: kCIInputContrastKey)
        f.setValue(0.0, forKey: kCIInputSaturationKey)
        return f.outputImage ?? i
    }
    
    private func perspective(_ i: CIImage, tl: CGPoint, tr: CGPoint, bl: CGPoint, br: CGPoint) -> CIImage {
        let f = CIFilter(name: "CIPerspectiveCorrection")!
        f.setValue(i, forKey: kCIInputImageKey)
        f.setValue(CIVector(cgPoint: tl), forKey: "inputTopLeft")
        f.setValue(CIVector(cgPoint: tr), forKey: "inputTopRight")
        f.setValue(CIVector(cgPoint: bl), forKey: "inputBottomLeft")
        f.setValue(CIVector(cgPoint: br), forKey: "inputBottomRight")
        return f.outputImage ?? i
    }
    
    private func resize(_ i: UIImage, maxDim: CGFloat) -> UIImage {
        let s = i.size, sc = min(maxDim / s.width, maxDim / s.height)
        if sc >= 1 { return i }
        let ns = CGSize(width: s.width * sc, height: s.height * sc)
        return UIGraphicsImageRenderer(size: ns).image { _ in i.draw(in: CGRect(origin: .zero, size: ns)) }
    }
    
    private func render(_ ci: CIImage) -> UIImage? {
        guard let cg = context.createCGImage(ci, from: ci.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
    
    private func brightness(_ i: UIImage) -> Double {
        guard let cg = i.cgImage else { return 0.5 }
        let ci = CIImage(cgImage: cg), ex = ci.extent
        let f = CIFilter(name: "CIAreaAverage")!
        f.setValue(ci, forKey: kCIInputImageKey)
        f.setValue(CIVector(cgRect: CGRect(x: ex.midX - ex.width * 0.25, y: ex.midY - ex.height * 0.25, width: ex.width * 0.5, height: ex.height * 0.5)), forKey: kCIInputExtentKey)
        var b = [UInt8](repeating: 0, count: 4)
        context.render(f.outputImage!, toBitmap: &b, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        return (0.299 * Double(b[0]) + 0.587 * Double(b[1]) + 0.114 * Double(b[2])) / 255.0
    }
    
    private func sharpness(_ i: UIImage) -> Double {
        guard let cg = i.cgImage else { return 0.5 }
        let f = CIFilter(name: "CIConvolution3X3")!
        f.setValue(CIImage(cgImage: cg), forKey: kCIInputImageKey)
        f.setValue(CIVector(values: [0, -1, 0, -1, 4, -1, 0, -1, 0], count: 9), forKey: "inputWeights")
        let af = CIFilter(name: "CIAreaAverage")!
        af.setValue(f.outputImage!, forKey: kCIInputImageKey)
        af.setValue(CIVector(cgRect: f.outputImage!.extent), forKey: kCIInputExtentKey)
        var b = [UInt8](repeating: 0, count: 4)
        context.render(af.outputImage!, toBitmap: &b, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        return min(1, Double(b[0]) / 255.0 * 10)
    }
}

infix operator |>: AdditionPrecedence
private func |> (image: CIImage, transform: (CIImage) -> CIImage) -> CIImage { transform(image) }

struct ImageQualityAnalysis {
    let confidence: Double
    let issues: [String]
    let detectedRectangle: VNRectangleObservation?
    let canAdjust: Bool
}