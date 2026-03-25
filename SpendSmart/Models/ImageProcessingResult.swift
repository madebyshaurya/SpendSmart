import Foundation
import Vision

struct ImageProcessingResult {
    let overallConfidence: Double
    let processingType: String
    let detectedRectangle: VNRectangleObservation?
    let qualityIssues: [String]
    let canAdjustManually: Bool
    let isStitched: Bool
}
