//
//  MultiImageCaptureView.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-04-10.
//

import SwiftUI
import AVFoundation
import UIKit

// Camera components

// Camera preview view with loading indicator
fileprivate struct CameraPreviewView: View {
    @ObservedObject var cameraController: CameraController

    var body: some View {
        ZStack {
            // Camera preview layer
            CameraPreviewLayer(cameraController: cameraController)
                .ignoresSafeArea()

            // Loading indicator
            if !cameraController.isInitialized {
                ZStack {
                    Color.black.opacity(0.7)
                        .ignoresSafeArea()

                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)

                        Text("Initializing camera...")
                            .font(.instrumentSans(size: 16))
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
}

// UIViewRepresentable for camera preview layer
fileprivate struct CameraPreviewLayer: UIViewRepresentable {
    @ObservedObject var cameraController: CameraController

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .darkGray
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        if let session = cameraController.captureSession, uiView.videoPreviewLayer.session != session {
            print("Updating preview layer with session")
            DispatchQueue.main.async {
                uiView.videoPreviewLayer.session = session
            }
        }
    }

    // Custom UIView subclass that uses AVCaptureVideoPreviewLayer as its backing layer
    class PreviewView: UIView {
        override class var layerClass: AnyClass {
            return AVCaptureVideoPreviewLayer.self
        }

        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            return layer as! AVCaptureVideoPreviewLayer
        }
    }
}

// Camera controller class to handle AVFoundation camera operations
fileprivate class CameraController: NSObject, AVCapturePhotoCaptureDelegate, ObservableObject {
    @Published var isInitialized = false
    @Published var isCapturing = false

    var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var photoOutput: AVCapturePhotoOutput?
    var photoCaptureCompletionBlock: ((UIImage?) -> Void)?

    func prepare(completionHandler: @escaping (Error?) -> Void) {
        // First, check if we're already initialized
        if isInitialized && captureSession?.isRunning == true {
            completionHandler(nil)
            return
        }

        // Reset state
        captureSession?.stopRunning()
        captureSession = nil
        previewLayer = nil
        photoOutput = nil

        // Set up camera on a high priority background thread
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self = self else { return }

            do {
                // Create and configure the capture session
                let session = AVCaptureSession()
                session.sessionPreset = .photo
                self.captureSession = session

                // Get the back camera
                guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                    DispatchQueue.main.async {
                        completionHandler(NSError(domain: "CameraController", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not find a camera"]))
                    }
                    return
                }

                // Configure camera for better performance
                try backCamera.lockForConfiguration()
                if backCamera.isAutoFocusRangeRestrictionSupported {
                    backCamera.autoFocusRangeRestriction = .near
                }
                if backCamera.isFocusModeSupported(.continuousAutoFocus) {
                    backCamera.focusMode = .continuousAutoFocus
                }
                backCamera.unlockForConfiguration()

                // Create and add camera input
                let input = try AVCaptureDeviceInput(device: backCamera)
                if session.canAddInput(input) {
                    session.addInput(input)
                } else {
                    throw NSError(domain: "CameraController", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not add camera input"])
                }

                // Create and add photo output
                let output = AVCapturePhotoOutput()
                if #available(iOS 16.0, *) {
                    // Use the new API for iOS 16+
                    output.maxPhotoDimensions = CMVideoDimensions(width: 4032, height: 3024) // High resolution
                } else {
                    // Use the deprecated API for older iOS versions
                    output.isHighResolutionCaptureEnabled = true
                }
                if session.canAddOutput(output) {
                    session.addOutput(output)
                    self.photoOutput = output
                } else {
                    throw NSError(domain: "CameraController", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not add photo output"])
                }

                // Create preview layer
                let previewLayer = AVCaptureVideoPreviewLayer(session: session)
                previewLayer.videoGravity = .resizeAspectFill
                self.previewLayer = previewLayer

                // Start the session
                session.startRunning()

                // Update UI on main thread
                DispatchQueue.main.async {
                    print("Camera initialized successfully")
                    self.isInitialized = true
                    completionHandler(nil)
                }
            } catch {
                print("Camera initialization error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completionHandler(error)
                }
            }
        }
    }

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        photoCaptureCompletionBlock = completion
        isCapturing = true

        let settings = AVCapturePhotoSettings()
        photoOutput?.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        DispatchQueue.main.async {
            self.isCapturing = false
        }

        if let error = error {
            print("Error capturing photo: \(error.localizedDescription)")
            photoCaptureCompletionBlock?(nil)
            return
        }

        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            photoCaptureCompletionBlock?(nil)
            return
        }

        photoCaptureCompletionBlock?(image)
    }

    func stopSession() {
        captureSession?.stopRunning()
    }
}

// Custom button style for scale animation
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct MultiImageCaptureView: View {
    @Binding var capturedImages: [UIImage]
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var cameraController = CameraController()
    @State private var isFlashOn = false
    @State private var showPreview = false
    @State private var previewImage: UIImage?
    @State private var showingGuide = true
    @State private var showingConfirmation = false
    @State private var animateCapture = false
    @State private var animateFlash = false

    // Animation properties
    @State private var captureScale: CGFloat = 1.0
    @State private var thumbnailOffset: CGFloat = 100

    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(cameraController: cameraController)
                .ignoresSafeArea()
                .overlay(
                    // Flash overlay
                    Rectangle()
                        .fill(Color.white)
                        .ignoresSafeArea()
                        .opacity(animateFlash ? 0.3 : 0)
                )

            // UI overlay
            VStack {
                // Top bar with controls
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }

                    Spacer()

                    Button {
                        isFlashOn.toggle()
                    } label: {
                        Image(systemName: isFlashOn ? "bolt.fill" : "bolt.slash")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                }
                .padding()

                Spacer()

                // Receipt guide overlay (only shown initially)
                if showingGuide {
                    VStack {
                        // Receipt frame guide
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                Color.white,
                                style: StrokeStyle(lineWidth: 2, dash: [10, 10])
                            )
                            .frame(width: UIScreen.main.bounds.width * 0.8, height: UIScreen.main.bounds.height * 0.6)
                            .padding(.bottom, 20)

                        Text("Position your receipt within the frame")
                            .font(.instrumentSans(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.black.opacity(0.6))
                            )

                        Text("Take multiple photos for long receipts")
                            .font(.instrumentSans(size: 14))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.black.opacity(0.6))
                            )
                    }
                    .transition(.opacity)
                    .onAppear {
                        // Hide guide after 3 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation {
                                showingGuide = false
                            }
                        }
                    }
                }

                // Bottom controls
                VStack(spacing: 20) {
                    // Thumbnail gallery of captured images
                    if !capturedImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(0..<capturedImages.count, id: \.self) { index in
                                    Image(uiImage: capturedImages[index])
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 60, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.white, lineWidth: 2)
                                        )
                                        .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                                        .onTapGesture {
                                            previewImage = capturedImages[index]
                                            showPreview = true
                                        }
                                        .transition(.asymmetric(
                                            insertion: .scale(scale: 0.5).combined(with: .offset(x: thumbnailOffset)),
                                            removal: .opacity
                                        ))
                                }
                            }
                            .padding(.horizontal)
                        }
                        .frame(height: 90)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.5))
                                .padding(.horizontal, 8)
                        )
                    }

                    HStack(spacing: 30) {
                        // Done button
                        Button {
                            showingConfirmation = true
                        } label: {
                            Text("Done")
                                .font(.instrumentSans(size: 18, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 24)
                                .background(
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color(hex: "4CAF50"), Color(hex: "2E7D32")]),
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                )
                                .opacity(capturedImages.isEmpty ? 0.5 : 1)
                        }
                        .disabled(capturedImages.isEmpty)

                        // Capture button
                        Button {
                            capturePhoto()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 70, height: 70)
                                    .scaleEffect(captureScale)

                                Circle()
                                    .stroke(Color.white, lineWidth: 4)
                                    .frame(width: 80, height: 80)
                            }
                        }
                        .buttonStyle(MultiImageScaleButtonStyle())

                        // Gallery button (if needed)
                        Button {
                            // Show image picker or gallery
                        } label: {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color(hex: "2196F3"), Color(hex: "1565C0")]),
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                )
                        }
                    }
                    .padding(.bottom, 30)
                }
                .padding(.bottom)
            }

            // Image preview overlay
            if showPreview, let previewImage = previewImage {
                ZStack {
                    Color.black.opacity(0.8)
                        .ignoresSafeArea()
                        .onTapGesture {
                            showPreview = false
                        }

                    VStack {
                        Image(uiImage: previewImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(12)
                            .padding()

                        HStack(spacing: 40) {
                            Button {
                                if let index = capturedImages.firstIndex(where: { $0 == previewImage }) {
                                    capturedImages.remove(at: index)
                                }
                                showPreview = false
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Delete")
                                }
                                .font(.instrumentSans(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 20)
                                .background(
                                    Capsule()
                                        .fill(Color.red.opacity(0.8))
                                )
                            }

                            Button {
                                showPreview = false
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark")
                                    Text("Keep")
                                }
                                .font(.instrumentSans(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 20)
                                .background(
                                    Capsule()
                                        .fill(Color.green.opacity(0.8))
                                )
                            }
                        }
                        .padding(.bottom, 30)
                    }
                }
                .transition(.opacity)
            }

            // Confirmation dialog
            if showingConfirmation {
                ZStack {
                    Color.black.opacity(0.7)
                        .ignoresSafeArea()
                        .onTapGesture {
                            showingConfirmation = false
                        }

                    VStack(spacing: 20) {
                        Text("Finish Capturing?")
                            .font(.instrumentSerif(size: 24))
                            .foregroundColor(.white)

                        Text("You've captured \(capturedImages.count) image\(capturedImages.count == 1 ? "" : "s").")
                            .font(.instrumentSans(size: 16))
                            .foregroundColor(.white.opacity(0.8))

                        HStack(spacing: 20) {
                            Button {
                                showingConfirmation = false
                            } label: {
                                Text("Continue Capturing")
                                    .font(.instrumentSans(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 20)
                                    .background(
                                        Capsule()
                                            .fill(Color.gray.opacity(0.6))
                                    )
                            }

                            Button {
                                dismiss()
                            } label: {
                                Text("Done")
                                    .font(.instrumentSans(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 20)
                                    .background(
                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [Color(hex: "4CAF50"), Color(hex: "2E7D32")]),
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                    )
                            }
                        }
                    }
                    .padding(30)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(hex: "1E293B"))
                    )
                    .padding(.horizontal, 40)
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            cameraController.prepare { error in
                if let error = error {
                    print("Camera error: \(error.localizedDescription)")
                }
            }
        }
        .onDisappear {
            cameraController.stopSession()
        }
    }

    private func capturePhoto() {
        // Animate the capture button
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            captureScale = 0.8
            animateFlash = true
        }

        // Reset the animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                captureScale = 1.0
            }
        }

        // Reset flash animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            animateFlash = false
        }

        // Capture the photo
        cameraController.capturePhoto { image in
            guard let image = image else { return }

            // Add the captured image to the array
            withAnimation {
                capturedImages.append(image)
                thumbnailOffset = 100 // Reset for next animation
            }
        }
    }
}

// Custom button style for scale animation
fileprivate struct MultiImageScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}



struct MultiImageCaptureView_Previews: PreviewProvider {
    static var previews: some View {
        MultiImageCaptureView(capturedImages: .constant([]))
    }
}
