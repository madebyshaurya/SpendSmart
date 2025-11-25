//
//  MultiPartReceiptProcessor.swift
//  SpendSmart
//
//  Created by Claude Code on 2025-01-09.
//

import UIKit
import Vision
import CoreImage

class MultiPartReceiptProcessor {
    static let shared = MultiPartReceiptProcessor()
    
    private init() {}
    
    // MARK: - Multi-Part Receipt Processing
    
    /// Process multiple images that may be parts of the same receipt
    /// - Parameter images: Array of images that could be parts of one receipt
    /// - Returns: Processed images with potential stitching and enhancement
    func processMultiPartReceipt(_ images: [UIImage]) async -> MultiPartReceiptResult {
        print("🧩 [MultiPartReceipt] Processing \(images.count) images for potential stitching")
        
        // Step 1: Analyze each image for receipt content
        let analyzedParts = await analyzeReceiptParts(images)
        
        // Step 2: Detect if images are parts of the same receipt
        let stitchingPlan = detectReceiptParts(analyzedParts)
        
        // Step 3: Process based on analysis
        if stitchingPlan.shouldStitch {
            print("🧩 [MultiPartReceipt] Detected multi-part receipt - attempting to stitch")
            return await stitchReceiptParts(analyzedParts, plan: stitchingPlan)
        } else {
            print("🧩 [MultiPartReceipt] Processing as separate receipts")
            return await processSeparateReceipts(analyzedParts)
        }
    }
    
    // MARK: - Receipt Part Analysis
    
    private func analyzeReceiptParts(_ images: [UIImage]) async -> [ReceiptPartAnalysis] {
        var analyses: [ReceiptPartAnalysis] = []
        
        for (index, image) in images.enumerated() {
            print("🔍 [ReceiptAnalysis] Analyzing part \(index + 1)/\(images.count)")
            
            let analysis = await analyzeReceiptPart(image, index: index)
            analyses.append(analysis)
        }
        
        return analyses
    }
    
    private func analyzeReceiptPart(_ image: UIImage, index: Int) async -> ReceiptPartAnalysis {
        let analysis = ReceiptPartAnalysis(
            image: image,
            index: index,
            hasReceiptContent: await detectReceiptContent(image),
            detectedText: await extractSampleText(image),
            aspectRatio: image.size.width / image.size.height,
            dominantColors: analyzeDominantColors(image)
        )
        
        return analysis
    }
    
    private func detectReceiptContent(_ image: UIImage) async -> Bool {
        // Use Vision framework to detect if image contains receipt-like content
        guard let cgImage = image.cgImage else { return false }
        
        return await withCheckedContinuation { continuation in
            let request = VNDetectTextRectanglesRequest { request, error in
                let rectangles = request.results as? [VNTextObservation] ?? []
                // Consider it receipt content if we have multiple text regions
                let hasReceiptContent = rectangles.count >= 3
                continuation.resume(returning: hasReceiptContent)
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
    
    private func extractSampleText(_ image: UIImage) async -> String {
        // Extract sample text to help determine if images are related
        guard let cgImage = image.cgImage else { return "" }
        
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations.compactMap { 
                    $0.topCandidates(1).first?.string 
                }.prefix(3).joined(separator: " ")
                continuation.resume(returning: text)
            }
            
            request.recognitionLevel = .fast
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
    
    private func analyzeDominantColors(_ image: UIImage) -> [UIColor] {
        // Simple dominant color analysis for receipt similarity
        guard let cgImage = image.cgImage else { return [] }
        
        let ciImage = CIImage(cgImage: cgImage)
        let extent = ciImage.extent
        
        // Sample colors from different regions (currently simplified)
        let _ = [
            CGPoint(x: extent.midX, y: extent.height * 0.1), // Top
            CGPoint(x: extent.midX, y: extent.midY), // Middle
            CGPoint(x: extent.midX, y: extent.height * 0.9)  // Bottom
        ]
        
        // This is a simplified implementation
        // In practice, you'd want more sophisticated color analysis
        return [UIColor.white] // Placeholder
    }
    
    // MARK: - Receipt Part Detection
    
    private func detectReceiptParts(_ analyses: [ReceiptPartAnalysis]) -> ReceiptStitchingPlan {
        print("🔍 [ReceiptParts] Analyzing \(analyses.count) parts for stitching potential")
        
        // Only consider stitching if we have 2-4 images
        guard analyses.count >= 2, analyses.count <= 4 else {
            return ReceiptStitchingPlan(shouldStitch: false, reason: "Invalid count for stitching")
        }
        
        // Check if all images have receipt content
        let receiptImages = analyses.filter { $0.hasReceiptContent }
        guard receiptImages.count == analyses.count else {
            return ReceiptStitchingPlan(shouldStitch: false, reason: "Not all images contain receipt content")
        }
        
        // Check aspect ratios (vertical receipts should be tall)
        let aspectRatios = analyses.map { $0.aspectRatio }
        let areVertical = aspectRatios.allSatisfy { $0 < 1.0 } // Width < Height
        
        if areVertical {
            // Analyze text overlap/continuation patterns
            let hasTextContinuation = analyzeTextContinuation(analyses)
            if hasTextContinuation {
                return ReceiptStitchingPlan(
                    shouldStitch: true, 
                    stitchOrder: analyses.sorted(by: { $0.index < $1.index }),
                    reason: "Detected vertical receipt parts with text continuation"
                )
            }
        }
        
        return ReceiptStitchingPlan(shouldStitch: false, reason: "No clear stitching pattern detected")
    }
    
    private func analyzeTextContinuation(_ analyses: [ReceiptPartAnalysis]) -> Bool {
        // Simple heuristic: if we have similar text patterns, likely same receipt
        let textSamples = analyses.map { $0.detectedText.lowercased() }
        
        // Look for common receipt keywords
        let receiptKeywords = ["total", "subtotal", "tax", "receipt", "store", "$", "thank you"]
        let hasReceiptKeywords = textSamples.contains { text in
            receiptKeywords.contains { keyword in text.contains(keyword) }
        }
        
        return hasReceiptKeywords
    }
    
    // MARK: - Receipt Stitching
    
    private func stitchReceiptParts(_ analyses: [ReceiptPartAnalysis], plan: ReceiptStitchingPlan) async -> MultiPartReceiptResult {
        print("🧩 [Stitching] Combining \(analyses.count) receipt parts")
        
        // Enhance each part first
        let enhancedParts = analyses.map { analysis in
            ReceiptImageProcessor.shared.enhanceReceiptImage(analysis.image)
        }
        
        // Create vertical stitched image
        let stitchedImage = createVerticalStitch(enhancedParts)
        
        // Calculate stitching quality confidence
        let stitchingConfidence = calculateStitchingConfidence(analyses, plan: plan)
        
        return MultiPartReceiptResult(
            processedImages: [stitchedImage],
            isStitched: true,
            originalCount: analyses.count,
            processingNote: "Combined \(analyses.count) receipt parts into single image",
            stitchingConfidence: stitchingConfidence
        )
    }
    
    private func processSeparateReceipts(_ analyses: [ReceiptPartAnalysis]) async -> MultiPartReceiptResult {
        print("📄 [SeparateReceipts] Processing \(analyses.count) individual receipts")
        
        // Enhance each image separately
        let enhancedImages = analyses.map { analysis in
            ReceiptImageProcessor.shared.enhanceReceiptImage(analysis.image)
        }
        
        return MultiPartReceiptResult(
            processedImages: enhancedImages,
            isStitched: false,
            originalCount: analyses.count,
            processingNote: "Processed \(analyses.count) separate receipts",
            stitchingConfidence: 0.0
        )
    }
    
    private func createVerticalStitch(_ images: [UIImage]) -> UIImage {
        guard !images.isEmpty else { return UIImage() }
        guard images.count > 1 else { return images[0] }
        
        // Calculate total height and max width
        let maxWidth = images.map { $0.size.width }.max() ?? 0
        let totalHeight = images.map { $0.size.height }.reduce(0, +)
        
        let stitchedSize = CGSize(width: maxWidth, height: totalHeight)
        
        // Create stitched image
        let renderer = UIGraphicsImageRenderer(size: stitchedSize)
        return renderer.image { context in
            var yOffset: CGFloat = 0
            
            for image in images {
                let rect = CGRect(x: 0, y: yOffset, width: image.size.width, height: image.size.height)
                image.draw(in: rect)
                yOffset += image.size.height
            }
        }
    }
    
    // MARK: - Quality Assessment
    
    private func calculateStitchingConfidence(_ analyses: [ReceiptPartAnalysis], plan: ReceiptStitchingPlan) -> Double {
        var confidence = 0.8 // Base confidence for stitching
        
        // Reduce confidence based on issues
        let receiptContentRatio = Double(analyses.filter { $0.hasReceiptContent }.count) / Double(analyses.count)
        if receiptContentRatio < 1.0 {
            confidence *= receiptContentRatio
        }
        
        // Check aspect ratios consistency
        let aspectRatios = analyses.map { $0.aspectRatio }
        let avgAspectRatio = aspectRatios.reduce(0, +) / Double(aspectRatios.count)
        let aspectVariance = aspectRatios.map { abs($0 - avgAspectRatio) }.reduce(0, +) / Double(aspectRatios.count)
        
        if aspectVariance > 0.3 {
            confidence *= 0.85 // Inconsistent aspect ratios
        }
        
        // Text continuity bonus
        let textSamples = analyses.map { $0.detectedText.lowercased() }
        let receiptKeywords = ["total", "subtotal", "tax", "receipt", "store", "$"]
        let keywordMatches = textSamples.flatMap { text in
            receiptKeywords.filter { text.contains($0) }
        }.count
        
        if keywordMatches >= 2 {
            confidence = min(1.0, confidence * 1.1)
        }
        
        return confidence
    }
}

// MARK: - Supporting Types

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
    let stitchOrder: [ReceiptPartAnalysis]?
    let reason: String
    
    init(shouldStitch: Bool, stitchOrder: [ReceiptPartAnalysis]? = nil, reason: String) {
        self.shouldStitch = shouldStitch
        self.stitchOrder = stitchOrder
        self.reason = reason
    }
}

struct MultiPartReceiptResult {
    let processedImages: [UIImage]
    let isStitched: Bool
    let originalCount: Int
    let processingNote: String
    let stitchingConfidence: Double
    
    func toImageProcessingResult() -> ImageProcessingResult {
        return ImageProcessingResult(
            overallConfidence: isStitched ? stitchingConfidence : 0.95, // High confidence for separate processing
            processingType: isStitched ? "Multi-Part Stitch" : "Gallery Upload",
            detectedRectangle: nil,
            qualityIssues: isStitched && stitchingConfidence < 0.7 ? ["Low confidence stitching"] : [],
            canAdjustManually: false, // Can't manually adjust stitched images
            isStitched: isStitched
        )
    }
}