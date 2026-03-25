import UIKit
import Vision
import CoreImage

class MultiPartReceiptProcessor {
    static let shared = MultiPartReceiptProcessor()
    private init() {}
    
    func processMultiPartReceipt(_ images: [UIImage]) async -> MultiPartReceiptResult {
        let items = await analyzeParts(images)
        let plan = detectPlan(items)
        if plan.shouldStitch { return await stitch(items, plan: plan) }
        return await processSeparate(items)
    }
    
    private func analyzeParts(_ images: [UIImage]) async -> [ReceiptPartAnalysis] {
        var results: [ReceiptPartAnalysis] = []
        for (i, img) in images.enumerated() {
            results.append(ReceiptPartAnalysis(image: img, index: i, hasReceiptContent: await detect(img), detectedText: await extract(img), aspectRatio: img.size.width / img.size.height, dominantColors: [UIColor.white]))
        }
        return results
    }
    
    private func detect(_ img: UIImage) async -> Bool {
        guard let cg = img.cgImage else { return false }
        return await withCheckedContinuation { c in
            let req = VNRecognizeTextRequest { r, _ in c.resume(returning: (r.results as? [VNRecognizedTextObservation])?.count ?? 0 >= 3) }
            try? VNImageRequestHandler(cgImage: cg).perform([req])
        }
    }
    
    private func extract(_ img: UIImage) async -> String {
        guard let cg = img.cgImage else { return "" }
        return await withCheckedContinuation { c in
            let req = VNRecognizeTextRequest { r, _ in
                c.resume(returning: (r.results as? [VNRecognizedTextObservation])?.compactMap { $0.topCandidates(1).first?.string }.prefix(3).joined(separator: " ") ?? "")
            }
            req.recognitionLevel = .fast
            try? VNImageRequestHandler(cgImage: cg).perform([req])
        }
    }
    
    private func detectPlan(_ items: [ReceiptPartAnalysis]) -> ReceiptStitchingPlan {
        guard items.count >= 2 && items.count <= 4 else { return ReceiptStitchingPlan(shouldStitch: false, reason: "Count") }
        if items.allSatisfy({ $0.hasReceiptContent && $0.aspectRatio < 1.0 }) {
            let keywords = ["total", "subtotal", "tax", "receipt", "store", "$", "thank you"]
            if items.contains(where: { item in keywords.contains(where: { item.detectedText.lowercased().contains($0) }) }) {
                return ReceiptStitchingPlan(shouldStitch: true, stitchOrder: items.sorted(by: { $0.index < $1.index }), reason: "Vertical")
            }
        }
        return ReceiptStitchingPlan(shouldStitch: false, reason: "None")
    }
    
    private func stitch(_ items: [ReceiptPartAnalysis], plan: ReceiptStitchingPlan) async -> MultiPartReceiptResult {
        let enhanced = items.map { ReceiptImageProcessor.shared.enhanceReceiptImage($0.image) }
        let size = CGSize(width: enhanced.map { $0.size.width }.max() ?? 0, height: enhanced.map { $0.size.height }.reduce(0, +))
        let img = UIGraphicsImageRenderer(size: size).image { _ in
            var y: CGFloat = 0
            for i in enhanced { i.draw(in: CGRect(x: 0, y: y, width: i.size.width, height: i.size.height)); y += i.size.height }
        }
        return MultiPartReceiptResult(processedImages: [img], isStitched: true, originalCount: items.count, processingNote: "Stitched", stitchingConfidence: 0.8)
    }
    
    private func processSeparate(_ items: [ReceiptPartAnalysis]) async -> MultiPartReceiptResult {
        MultiPartReceiptResult(processedImages: items.map { ReceiptImageProcessor.shared.enhanceReceiptImage($0.image) }, isStitched: false, originalCount: items.count, processingNote: "Separate", stitchingConfidence: 0)
    }
}

struct ReceiptPartAnalysis {
    let image: UIImage
    let index: Int
    let hasReceiptContent: Bool
    let detectedText: String
    let aspectRatio: CGFloat
    let dominantColors: [UIColor]
}

struct ReceiptStitchingPlan {
    let shouldStitch: Bool
    var stitchOrder: [ReceiptPartAnalysis]? = nil
    let reason: String
}

struct MultiPartReceiptResult {
    let processedImages: [UIImage]
    let isStitched: Bool
    let originalCount: Int
    let processingNote: String
    let stitchingConfidence: Double
    
    func toImageProcessingResult() -> ImageProcessingResult {
        ImageProcessingResult(overallConfidence: isStitched ? stitchingConfidence : 0.95, processingType: isStitched ? "Stitch" : "Gallery", detectedRectangle: nil, qualityIssues: [], canAdjustManually: false, isStitched: isStitched)
    }
}