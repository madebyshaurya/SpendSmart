//
//  EnhancedReceiptPreviewView.swift
//  SpendSmart
//
//  Created by Claude Code on 2025-01-09.
//

import SwiftUI
import Vision

struct EnhancedReceiptPreviewView: View {
    let originalImage: UIImage
    let processedImage: UIImage
    let processingResult: ImageProcessingResult
    let onAccept: (UIImage) -> Void
    let onReject: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var showingManualAdjustment = false
    @State private var useOriginal = false
    @State private var currentImage: UIImage
    @State private var manuallyAdjustedImage: UIImage?
    
    init(originalImage: UIImage, processedImage: UIImage, processingResult: ImageProcessingResult, onAccept: @escaping (UIImage) -> Void, onReject: @escaping () -> Void) {
        self.originalImage = originalImage
        self.processedImage = processedImage
        self.processingResult = processingResult
        self.onAccept = onAccept
        self.onReject = onReject
        self._currentImage = State(initialValue: processedImage)
    }
    
    var displayedImage: UIImage {
        if let adjusted = manuallyAdjustedImage {
            return adjusted
        }
        return useOriginal ? originalImage : currentImage
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Preview Area
                ScrollView([.horizontal, .vertical]) {
                    Image(uiImage: displayedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding()
                }
                .background(Color.black)
                .overlay(alignment: .topTrailing) {
                    ConfidenceIndicatorView(result: processingResult)
                        .padding()
                }
                
                // Controls Section
                VStack(spacing: 20) {
                    // Quality Assessment
                    QualityAssessmentView(result: processingResult)
                    
                    // Toggle Controls
                    HStack(spacing: 20) {
                        Button(action: {
                            useOriginal.toggle()
                            manuallyAdjustedImage = nil
                        }) {
                            HStack {
                                Image(systemName: useOriginal ? "checkmark.circle.fill" : "circle")
                                Text("Use Original")
                            }
                            .foregroundColor(useOriginal ? .blue : .primary)
                        }
                        
                        if !useOriginal && processingResult.canAdjustManually {
                            Button(action: {
                                showingManualAdjustment = true
                            }) {
                                HStack {
                                    Image(systemName: "crop.rotate")
                                    Text("Adjust")
                                }
                                .foregroundColor(.blue)
                            }
                        }
                    }
                    .font(.system(size: 16, weight: .medium))
                    
                    // Action Buttons
                    HStack(spacing: 30) {
                        Button("Cancel") {
                            onReject()
                            dismiss()
                        }
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.red, lineWidth: 1)
                        )
                        
                        Button("Use This Image") {
                            let finalImage = manuallyAdjustedImage ?? (useOriginal ? originalImage : currentImage)
                            onAccept(finalImage)
                            dismiss()
                        }
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.blue)
                        )
                    }
                }
                .padding()
                .background(Color(.systemBackground))
            }
            .navigationTitle("Preview & Adjust")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip Preview") {
                        onAccept(currentImage)
                        dismiss()
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                }
            }
        }
        .sheet(isPresented: $showingManualAdjustment) {
            ManualCropAdjustmentView(
                originalImage: originalImage,
                initialCrop: processingResult.detectedRectangle,
                onComplete: { adjustedImage in
                    manuallyAdjustedImage = adjustedImage
                    useOriginal = false
                }
            )
        }
    }
}

// MARK: - Quality Assessment View

struct QualityAssessmentView: View {
    let result: ImageProcessingResult
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Processing Quality")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                qualityBadge
            }
            
            if result.hasIssues {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(result.qualityIssues, id: \.self) { issue in
                        HStack {
                            Image(systemName: issueIcon(for: issue))
                                .foregroundColor(issueColor(for: issue))
                                .font(.system(size: 12))
                            Text(issue)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private var qualityBadge: some View {
        Text(result.qualityText)
            .font(.system(size: 14, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(result.qualityColor)
            )
            .foregroundColor(.white)
    }
    
    private func issueIcon(for issue: String) -> String {
        if issue.contains("lighting") { return "sun.max" }
        if issue.contains("angle") { return "rotate.3d" }
        if issue.contains("blur") { return "eye.slash" }
        if issue.contains("detection") { return "viewfinder" }
        return "exclamationmark.triangle"
    }
    
    private func issueColor(for issue: String) -> Color {
        if issue.contains("Low confidence") { return .orange }
        return .yellow
    }
}

// MARK: - Confidence Indicator View

struct ConfidenceIndicatorView: View {
    let result: ImageProcessingResult
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            // Overall Confidence
            HStack(spacing: 8) {
                Circle()
                    .fill(result.confidenceColor)
                    .frame(width: 8, height: 8)
                Text("\(Int(result.overallConfidence * 100))%")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.7))
            )
            
            // Processing Type Indicator
            Text(result.processingType)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.blue.opacity(0.7))
                )
        }
    }
}

// MARK: - Manual Crop Adjustment View

struct ManualCropAdjustmentView: View {
    let originalImage: UIImage
    let initialCrop: VNRectangleObservation?
    let onComplete: (UIImage) -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var cropCorners: [CGPoint] = []
    @State private var imageSize: CGSize = .zero
    @State private var showInstructions = true
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack {
                    if showInstructions {
                        InstructionsBannerView(onDismiss: {
                            showInstructions = false
                        })
                    }
                    
                    Spacer()
                    
                    // Image with overlay
                    GeometryReader { geometry in
                        ZStack {
                            Image(uiImage: originalImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .onAppear {
                                    setupInitialCrop(in: geometry.size)
                                }
                            
                            if !cropCorners.isEmpty {
                                CropOverlayView(
                                    corners: $cropCorners,
                                    imageSize: imageSize,
                                    containerSize: geometry.size
                                )
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Control Buttons
                    HStack(spacing: 20) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .stroke(Color.white, lineWidth: 1)
                        )
                        
                        Button("Reset") {
                            setupInitialCrop(in: imageSize)
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.2))
                        )
                        
                        Button("Apply Crop") {
                            applyCropAndDismiss()
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.white)
                        )
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Adjust Crop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
    
    private func setupInitialCrop(in containerSize: CGSize) {
        let imageAspectRatio = originalImage.size.width / originalImage.size.height
        let containerAspectRatio = containerSize.width / containerSize.height
        
        if imageAspectRatio > containerAspectRatio {
            // Image is wider than container
            imageSize.width = containerSize.width
            imageSize.height = containerSize.width / imageAspectRatio
        } else {
            // Image is taller than container
            imageSize.height = containerSize.height
            imageSize.width = containerSize.height * imageAspectRatio
        }
        
        // Set initial corners from detection or default rectangle
        if let crop = initialCrop {
            let topLeft = CGPoint(x: crop.topLeft.x * imageSize.width, y: (1 - crop.topLeft.y) * imageSize.height)
            let topRight = CGPoint(x: crop.topRight.x * imageSize.width, y: (1 - crop.topRight.y) * imageSize.height)
            let bottomLeft = CGPoint(x: crop.bottomLeft.x * imageSize.width, y: (1 - crop.bottomLeft.y) * imageSize.height)
            let bottomRight = CGPoint(x: crop.bottomRight.x * imageSize.width, y: (1 - crop.bottomRight.y) * imageSize.height)
            
            cropCorners = [topLeft, topRight, bottomRight, bottomLeft]
        } else {
            // Default to 10% inset rectangle
            let inset: CGFloat = 0.1
            cropCorners = [
                CGPoint(x: imageSize.width * inset, y: imageSize.height * inset),
                CGPoint(x: imageSize.width * (1 - inset), y: imageSize.height * inset),
                CGPoint(x: imageSize.width * (1 - inset), y: imageSize.height * (1 - inset)),
                CGPoint(x: imageSize.width * inset, y: imageSize.height * (1 - inset))
            ]
        }
    }
    
    private func applyCropAndDismiss() {
        guard cropCorners.count == 4 else { return }
        
        let croppedImage = ReceiptImageProcessor.shared.applyPerspectiveCorrection(
            originalImage,
            corners: cropCorners
        )
        
        onComplete(croppedImage)
        dismiss()
    }
}

// MARK: - Instructions Banner

struct InstructionsBannerView: View {
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Adjust Receipt Corners")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Text("Drag the corner circles to fine-tune the crop area")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.blue.opacity(0.9))
        )
        .padding(.horizontal)
        .transition(.move(edge: .top))
    }
}

// MARK: - Crop Overlay

struct CropOverlayView: View {
    @Binding var corners: [CGPoint]
    let imageSize: CGSize
    let containerSize: CGSize
    
    @State private var dragOffset: CGSize = .zero
    @State private var draggedCornerIndex: Int? = nil
    
    private var imageOffset: CGPoint {
        CGPoint(
            x: (containerSize.width - imageSize.width) / 2,
            y: (containerSize.height - imageSize.height) / 2
        )
    }
    
    var body: some View {
        ZStack {
            // Overlay rectangle
            Path { path in
                guard corners.count == 4 else { return }
                
                let adjustedCorners = corners.map { corner in
                    CGPoint(x: corner.x + imageOffset.x, y: corner.y + imageOffset.y)
                }
                
                path.move(to: adjustedCorners[0])
                for i in 1..<adjustedCorners.count {
                    path.addLine(to: adjustedCorners[i])
                }
                path.closeSubpath()
            }
            .stroke(Color.blue, lineWidth: 2)
            
            // Corner handles
            ForEach(0..<corners.count, id: \.self) { index in
                Circle()
                    .fill(Color.blue)
                    .frame(width: 20, height: 20)
                    .position(x: corners[index].x + imageOffset.x, y: corners[index].y + imageOffset.y)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                draggedCornerIndex = index
                                let newPosition = CGPoint(
                                    x: max(0, min(imageSize.width, value.location.x - imageOffset.x)),
                                    y: max(0, min(imageSize.height, value.location.y - imageOffset.y))
                                )
                                corners[index] = newPosition
                            }
                            .onEnded { _ in
                                draggedCornerIndex = nil
                            }
                    )
            }
        }
    }
}

// MARK: - Supporting Types

struct ImageProcessingResult {
    let overallConfidence: Double
    let processingType: String
    let detectedRectangle: VNRectangleObservation?
    let qualityIssues: [String]
    let canAdjustManually: Bool
    let isStitched: Bool
    
    var hasIssues: Bool {
        !qualityIssues.isEmpty
    }
    
    var qualityText: String {
        if overallConfidence >= 0.9 { return "Excellent" }
        if overallConfidence >= 0.75 { return "Good" }
        if overallConfidence >= 0.6 { return "Fair" }
        return "Poor"
    }
    
    var qualityColor: Color {
        if overallConfidence >= 0.9 { return .green }
        if overallConfidence >= 0.75 { return .blue }
        if overallConfidence >= 0.6 { return .orange }
        return .red
    }
    
    var confidenceColor: Color {
        if overallConfidence >= 0.8 { return .green }
        if overallConfidence >= 0.6 { return .orange }
        return .red
    }
    
    static let example = ImageProcessingResult(
        overallConfidence: 0.85,
        processingType: "VisionKit Scan",
        detectedRectangle: nil,
        qualityIssues: ["Low lighting detected"],
        canAdjustManually: true,
        isStitched: false
    )
}

#Preview {
    EnhancedReceiptPreviewView(
        originalImage: UIImage(systemName: "doc.text") ?? UIImage(),
        processedImage: UIImage(systemName: "doc.text") ?? UIImage(),
        processingResult: .example,
        onAccept: { _ in },
        onReject: { }
    )
}