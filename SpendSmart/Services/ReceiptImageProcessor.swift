//
//  ReceiptImageProcessor.swift
//  SpendSmart
//
//  Created by Claude Code on 2025-01-09.
//

import UIKit
import CoreImage
import Vision

class ReceiptImageProcessor {
    static let shared = ReceiptImageProcessor()
    
    private let context: CIContext
    
    private init() {
        // Use Metal context if available for better performance
        if let device = MTLCreateSystemDefaultDevice() {
            self.context = CIContext(mtlDevice: device)
        } else {
            self.context = CIContext()
        }
    }
    
    // MARK: - Public Methods
    
    /// Enhance a receipt image for better AI processing with quality assessment
    /// - Parameter image: Original receipt image
    /// - Returns: Enhanced image optimized for text recognition
    func enhanceReceiptImage(_ image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        
        let enhancedImage = ciImage
            |> adjustExposureAndBrightness
            |> enhanceContrast
            |> sharpenForTextRecognition
            |> normalizeColors
            |> reduceNoise
        
        let enhancedUIImage = renderImage(enhancedImage) ?? image
        
        // Mark image as enhanced for optimized backend processing
        enhancedUIImage.accessibilityHint = "enhanced_receipt"
        
        return enhancedUIImage
    }
    
    /// Process image with full analysis and quality assessment
    /// - Parameters:
    ///   - image: Original image
    ///   - processingType: Type of processing (VisionKit, Gallery, Camera)
    /// - Returns: Processed image and quality analysis result
    func processImageWithAnalysis(_ image: UIImage, processingType: String) async -> (image: UIImage, result: ImageProcessingResult) {
        let analysis = await analyzeImageQuality(image)
        let processedImage = enhanceReceiptImage(image)
        
        let result = ImageProcessingResult(
            overallConfidence: analysis.confidence,
            processingType: processingType,
            detectedRectangle: analysis.detectedRectangle,
            qualityIssues: analysis.issues,
            canAdjustManually: analysis.canAdjust,
            isStitched: false
        )
        
        return (processedImage, result)
    }
    
    /// Analyze image quality and provide confidence metrics
    private func analyzeImageQuality(_ image: UIImage) async -> ImageQualityAnalysis {
        var issues: [String] = []
        var confidence: Double = 1.0
        var detectedRectangle: VNRectangleObservation?
        
        // Analyze image brightness
        let brightness = calculateImageBrightness(image)
        if brightness < 0.3 {
            issues.append("Low lighting detected - image may be too dark")
            confidence -= 0.2
        } else if brightness > 0.8 {
            issues.append("High brightness detected - image may be overexposed")
            confidence -= 0.1
        }
        
        // Analyze image sharpness
        let sharpness = calculateImageSharpness(image)
        if sharpness < 0.4 {
            issues.append("Image appears blurry - consider retaking")
            confidence -= 0.25
        }
        
        // Try to detect document rectangle
        detectedRectangle = await detectDocumentRectangle(in: image)
        if detectedRectangle == nil {
            issues.append("Could not detect document boundaries")
            confidence -= 0.15
        } else {
            // Analyze detection quality
            let rectangleQuality = analyzeRectangleQuality(detectedRectangle!)
            if rectangleQuality < 0.7 {
                issues.append("Low confidence document detection")
                confidence -= 0.1
            }
        }
        
        // Analyze image size and aspect ratio
        let aspectRatio = image.size.width / image.size.height
        if aspectRatio > 2.0 || aspectRatio < 0.5 {
            issues.append("Unusual aspect ratio detected")
            confidence -= 0.05
        }
        
        confidence = max(0.0, min(1.0, confidence))
        
        return ImageQualityAnalysis(
            confidence: confidence,
            issues: issues,
            detectedRectangle: detectedRectangle,
            canAdjust: detectedRectangle != nil
        )
    }
    
    /// Crop image to detected document rectangle
    /// - Parameters:
    ///   - image: Original image
    ///   - observation: Rectangle observation from Vision framework
    /// - Returns: Cropped and perspective-corrected image
    func cropToDocument(_ image: UIImage, with observation: VNRectangleObservation) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        
        // Convert normalized coordinates to image coordinates
        let imageSize = ciImage.extent.size
        let topLeft = CGPoint(
            x: observation.topLeft.x * imageSize.width,
            y: (1 - observation.topLeft.y) * imageSize.height
        )
        let topRight = CGPoint(
            x: observation.topRight.x * imageSize.width,
            y: (1 - observation.topRight.y) * imageSize.height
        )
        let bottomLeft = CGPoint(
            x: observation.bottomLeft.x * imageSize.width,
            y: (1 - observation.bottomLeft.y) * imageSize.height
        )
        let bottomRight = CGPoint(
            x: observation.bottomRight.x * imageSize.width,
            y: (1 - observation.bottomRight.y) * imageSize.height
        )
        
        let correctedImage = applyPerspectiveCorrection(
            ciImage,
            topLeft: topLeft,
            topRight: topRight,
            bottomLeft: bottomLeft,
            bottomRight: bottomRight
        )
        
        return renderImage(correctedImage) ?? image
    }
    
    /// Apply perspective correction using corner points
    /// - Parameters:
    ///   - image: Original image
    ///   - corners: Array of 4 corner points [topLeft, topRight, bottomRight, bottomLeft]
    /// - Returns: Perspective-corrected image
    func applyPerspectiveCorrection(_ image: UIImage, corners: [CGPoint]) -> UIImage {
        guard corners.count == 4, let ciImage = CIImage(image: image) else { return image }
        
        let correctedImage = applyPerspectiveCorrection(
            ciImage,
            topLeft: corners[0],
            topRight: corners[1],
            bottomLeft: corners[3],
            bottomRight: corners[2]
        )
        
        return renderImage(correctedImage) ?? image
    }
    
    /// Optimize image for AI processing (compression, format, etc.)
    /// - Parameter image: Enhanced receipt image
    /// - Returns: Optimized image for API transmission
    func optimizeForAI(_ image: UIImage) -> UIImage {
        // Resize if too large (max 2048px on longest side)
        let resizedImage = resizeForOptimalAI(image)
        
        // Apply final sharpening for OCR
        guard let ciImage = CIImage(image: resizedImage) else { return resizedImage }
        let optimizedCIImage = ciImage |> sharpenForTextRecognition |> adjustForOCR
        
        let optimizedUIImage = renderImage(optimizedCIImage) ?? resizedImage
        
        // Mark as optimized for AI processing
        optimizedUIImage.accessibilityHint = "enhanced_receipt"
        
        return optimizedUIImage
    }
    
    /// Process gallery-uploaded images with automatic document detection and cropping
    /// - Parameter images: Array of images from photo gallery
    /// - Returns: Processed images with document detection and enhancement
    func processGalleryImages(_ images: [UIImage]) async -> [UIImage] {
        print("📷 [GalleryProcessor] Processing \(images.count) images from gallery")
        
        // First check if this might be a multi-part receipt
        if images.count > 1 {
            let multiPartResult = await MultiPartReceiptProcessor.shared.processMultiPartReceipt(images)
            if multiPartResult.isStitched {
                print("📷 [GalleryProcessor] Successfully stitched multi-part receipt")
                return multiPartResult.processedImages
            } else {
                print("📷 [GalleryProcessor] Processing as separate images")
                return multiPartResult.processedImages
            }
        }
        
        // Single image processing with document detection
        guard let image = images.first else { return [] }
        return [await processGalleryImage(image)]
    }
    
    /// Process a single gallery image with document detection
    private func processGalleryImage(_ image: UIImage) async -> UIImage {
        print("📷 [GalleryProcessor] Processing single image with document detection")
        
        // Try to detect document rectangles in the image
        let detectedRectangle = await detectDocumentRectangle(in: image)
        
        var processedImage = image
        
        // If we found a document rectangle, crop to it
        if let rectangle = detectedRectangle {
            print("📷 [GalleryProcessor] Document rectangle detected - cropping")
            processedImage = cropToDocument(image, with: rectangle)
        } else {
            print("📷 [GalleryProcessor] No document rectangle detected - processing full image")
        }
        
        // Enhance the image (cropped or full)
        let enhancedImage = enhanceReceiptImage(processedImage)
        
        return enhancedImage
    }
    
    /// Detect document rectangle in an image using Vision framework
    private func detectDocumentRectangle(in image: UIImage) async -> VNRectangleObservation? {
        guard let cgImage = image.cgImage else { return nil }
        
        return await withCheckedContinuation { continuation in
            let request = VNDetectRectanglesRequest { request, error in
                let rectangles = request.results as? [VNRectangleObservation] ?? []
                
                // Find the largest rectangle (most likely to be a document)
                let largestRectangle = rectangles.max { rect1, rect2 in
                    let area1 = rect1.boundingBox.width * rect1.boundingBox.height
                    let area2 = rect2.boundingBox.width * rect2.boundingBox.height
                    return area1 < area2
                }
                
                continuation.resume(returning: largestRectangle)
            }
            
            // Configure for document detection
            request.maximumObservations = 5
            request.minimumAspectRatio = 0.2 // Allow tall receipts
            request.maximumAspectRatio = 5.0 // Allow wide receipts
            request.minimumSize = 0.3 // Must be at least 30% of image
            request.minimumConfidence = 0.7 // High confidence required
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("📷 [DocumentDetection] Error: \(error)")
                continuation.resume(returning: nil)
            }
        }
    }
    
    // MARK: - Private Enhancement Methods
    
    private func adjustExposureAndBrightness(_ image: CIImage) -> CIImage {
        let filter = CIFilter(name: "CIExposureAdjust")!
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(0.5, forKey: kCIInputEVKey) // Slightly brighten
        
        guard let output = filter.outputImage else { return image }
        
        let brightnessFilter = CIFilter(name: "CIColorControls")!
        brightnessFilter.setValue(output, forKey: kCIInputImageKey)
        brightnessFilter.setValue(0.1, forKey: kCIInputBrightnessKey) // Slight brightness boost
        
        return brightnessFilter.outputImage ?? output
    }
    
    private func enhanceContrast(_ image: CIImage) -> CIImage {
        let filter = CIFilter(name: "CIColorControls")!
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(1.2, forKey: kCIInputContrastKey) // Increase contrast for better text recognition
        
        return filter.outputImage ?? image
    }
    
    private func sharpenForTextRecognition(_ image: CIImage) -> CIImage {
        let filter = CIFilter(name: "CISharpenLuminance")!
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(0.6, forKey: kCIInputSharpnessKey) // Moderate sharpening
        
        return filter.outputImage ?? image
    }
    
    private func normalizeColors(_ image: CIImage) -> CIImage {
        let filter = CIFilter(name: "CIColorControls")!
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(1.0, forKey: kCIInputSaturationKey) // Keep natural saturation
        
        return filter.outputImage ?? image
    }
    
    private func reduceNoise(_ image: CIImage) -> CIImage {
        let filter = CIFilter(name: "CINoiseReduction")!
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(0.02, forKey: "inputNoiseReductionAmount") // Light noise reduction
        
        return filter.outputImage ?? image
    }
    
    private func adjustForOCR(_ image: CIImage) -> CIImage {
        // Final adjustments specifically for OCR performance
        let filter = CIFilter(name: "CIColorControls")!
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(1.3, forKey: kCIInputContrastKey) // Higher contrast for OCR
        filter.setValue(0.0, forKey: kCIInputSaturationKey) // Remove color for better text recognition
        
        return filter.outputImage ?? image
    }
    
    // MARK: - Private Perspective Correction
    
    private func applyPerspectiveCorrection(
        _ image: CIImage,
        topLeft: CGPoint,
        topRight: CGPoint,
        bottomLeft: CGPoint,
        bottomRight: CGPoint
    ) -> CIImage {
        let filter = CIFilter(name: "CIPerspectiveCorrection")!
        filter.setValue(image, forKey: kCIInputImageKey)
        
        // Convert points to CIVector
        filter.setValue(CIVector(cgPoint: topLeft), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: topRight), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: bottomLeft), forKey: "inputBottomLeft")
        filter.setValue(CIVector(cgPoint: bottomRight), forKey: "inputBottomRight")
        
        return filter.outputImage ?? image
    }
    
    // MARK: - Private Utility Methods
    
    private func resizeForOptimalAI(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 2048
        let size = image.size
        
        // Calculate scale factor
        let scale = min(maxDimension / size.width, maxDimension / size.height)
        
        // Only resize if image is too large
        guard scale < 1.0 else { return image }
        
        let newSize = CGSize(
            width: size.width * scale,
            height: size.height * scale
        )
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    private func renderImage(_ ciImage: CIImage) -> UIImage? {
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
    
    // MARK: - Image Quality Analysis Methods
    
    private func calculateImageBrightness(_ image: UIImage) -> Double {
        guard let cgImage = image.cgImage else { return 0.5 }
        
        let ciImage = CIImage(cgImage: cgImage)
        let extent = ciImage.extent
        
        // Sample brightness from center region
        let centerRect = CGRect(
            x: extent.midX - extent.width * 0.25,
            y: extent.midY - extent.height * 0.25,
            width: extent.width * 0.5,
            height: extent.height * 0.5
        )
        
        // Use area average filter to get average brightness
        let filter = CIFilter(name: "CIAreaAverage")!
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: centerRect), forKey: kCIInputExtentKey)
        
        guard let outputImage = filter.outputImage else { return 0.5 }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        
        // Calculate luminance
        let r = Double(bitmap[0]) / 255.0
        let g = Double(bitmap[1]) / 255.0
        let b = Double(bitmap[2]) / 255.0
        
        return 0.299 * r + 0.587 * g + 0.114 * b
    }
    
    private func calculateImageSharpness(_ image: UIImage) -> Double {
        guard let cgImage = image.cgImage else { return 0.5 }
        
        let ciImage = CIImage(cgImage: cgImage)
        
        // Apply Laplacian filter to detect edges
        let filter = CIFilter(name: "CIConvolution3X3")!
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        
        // Laplacian kernel for edge detection
        let laplacianKernel = CIVector(values: [0, -1, 0, -1, 4, -1, 0, -1, 0], count: 9)
        filter.setValue(laplacianKernel, forKey: "inputWeights")
        
        guard let outputImage = filter.outputImage else { return 0.5 }
        
        // Calculate variance of the filtered image as sharpness measure
        let extent = outputImage.extent
        let areaFilter = CIFilter(name: "CIAreaAverage")!
        areaFilter.setValue(outputImage, forKey: kCIInputImageKey)
        areaFilter.setValue(CIVector(cgRect: extent), forKey: kCIInputExtentKey)
        
        guard let avgImage = areaFilter.outputImage else { return 0.5 }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(avgImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        
        let variance = Double(bitmap[0]) / 255.0
        return min(1.0, variance * 10.0) // Scale to 0-1 range
    }
    
    private func analyzeRectangleQuality(_ rectangle: VNRectangleObservation) -> Double {
        // Calculate confidence based on rectangle properties
        var quality = Double(rectangle.confidence)
        
        // Check if rectangle is reasonably sized (not too small)
        let area = rectangle.boundingBox.width * rectangle.boundingBox.height
        if area < 0.1 { // Less than 10% of image
            quality *= 0.5
        }
        
        // Check aspect ratio is reasonable for a receipt
        let aspectRatio = rectangle.boundingBox.width / rectangle.boundingBox.height
        if aspectRatio > 3.0 || aspectRatio < 0.3 {
            quality *= 0.7
        }
        
        // Check if rectangle corners form a reasonable quadrilateral
        let corners = [rectangle.topLeft, rectangle.topRight, rectangle.bottomRight, rectangle.bottomLeft]
        let cornerDistances = zip(corners, corners.dropFirst() + corners.prefix(1)).map { point1, point2 in
            sqrt(pow(point1.x - point2.x, 2) + pow(point1.y - point2.y, 2))
        }
        
        let avgDistance = cornerDistances.reduce(0, +) / Double(cornerDistances.count)
        let distanceVariance = cornerDistances.map { abs($0 - avgDistance) }.reduce(0, +) / Double(cornerDistances.count)
        
        if distanceVariance > avgDistance * 0.5 {
            quality *= 0.8 // Irregular shape penalty
        }
        
        return quality
    }
}

// MARK: - Functional Programming Helper

infix operator |>: AdditionPrecedence

private func |> (image: CIImage, transform: (CIImage) -> CIImage) -> CIImage {
    return transform(image)
}

// MARK: - Image Enhancement Configuration

struct ImageEnhancementConfig {
    let exposureAdjustment: Float
    let brightnessBoost: Float
    let contrastMultiplier: Float
    let sharpnessAmount: Float
    let noiseReductionAmount: Float
    
    static let receipt = ImageEnhancementConfig(
        exposureAdjustment: 0.5,
        brightnessBoost: 0.1,
        contrastMultiplier: 1.2,
        sharpnessAmount: 0.6,
        noiseReductionAmount: 0.02
    )
    
    static let ocrOptimized = ImageEnhancementConfig(
        exposureAdjustment: 0.3,
        brightnessBoost: 0.15,
        contrastMultiplier: 1.4,
        sharpnessAmount: 0.8,
        noiseReductionAmount: 0.03
    )
}

// MARK: - Supporting Types for Quality Analysis

struct ImageQualityAnalysis {
    let confidence: Double
    let issues: [String]
    let detectedRectangle: VNRectangleObservation?
    let canAdjust: Bool
}