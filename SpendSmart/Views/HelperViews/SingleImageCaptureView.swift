//
//  SingleImageCaptureView.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-04-10.
//

import SwiftUI
import AVFoundation
import UIKit

// Camera preview view with loading indicator
fileprivate struct CameraPreviewView: View {
    @ObservedObject var cameraController: CameraController

    var body: some View {
        // Camera preview layer
        CameraPreviewLayer(cameraController: cameraController)
            .ignoresSafeArea()
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

    // Initialize the camera session immediately when the controller is created
    override init() {
        super.init()
        setupCameraSession()
    }

    private func setupCameraSession() {
        // Create a capture session
        let session = AVCaptureSession()
        session.sessionPreset = .photo
        self.captureSession = session

        // Configure the session in the background
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // Get the back camera
            guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                return
            }

            // Create and add camera input
            do {
                let input = try AVCaptureDeviceInput(device: backCamera)
                if session.canAddInput(input) {
                    session.addInput(input)
                }

                // Create and add photo output
                let output = AVCapturePhotoOutput()
                if session.canAddOutput(output) {
                    session.addOutput(output)
                    self.photoOutput = output

                    // Start the session
                    session.startRunning()

                    // Update UI on main thread
                    DispatchQueue.main.async {
                        self.isInitialized = true
                    }
                }
            } catch {
                print("Failed to set up camera: \(error.localizedDescription)")
            }
        }
    }

    func prepare(completionHandler: @escaping (Error?) -> Void) {
        // If the session is already running, just call the completion handler
        if captureSession?.isRunning == true {
            completionHandler(nil)
            return
        }

        // Otherwise, start the session if it's not running
        if let session = captureSession, !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
                DispatchQueue.main.async {
                    self.isInitialized = true
                    completionHandler(nil)
                }
            }
        } else {
            // If there's no session, set up a new one
            setupCameraSession()
            completionHandler(nil)
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
fileprivate struct SingleImageScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct SingleImageCaptureView: View {
    @Binding var capturedImage: UIImage?
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var cameraController = CameraController()
    @State private var isFlashOn = false
    @State private var showPreview = false
    @State private var animateCapture = false
    @State private var animateFlash = false

    // Animation properties
    @State private var captureScale: CGFloat = 1.0

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

                // No receipt frame guide

                // Bottom controls
                VStack(spacing: 20) {
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
                    .buttonStyle(SingleImageScaleButtonStyle())
                    .padding(.bottom, 30)
                }
                .padding(.bottom)
            }

            // Preview overlay when image is captured
            if showPreview, let previewImage = capturedImage {
                ZStack {
                    Color.black.opacity(0.8)
                        .ignoresSafeArea()

                    VStack {
                        Image(uiImage: previewImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(12)
                            .padding()

                        HStack(spacing: 40) {
                            Button {
                                capturedImage = nil
                                showPreview = false
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("Retake")
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
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark")
                                    Text("Use Photo")
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
        }
        .onAppear {
            cameraController.prepare { _ in }
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

            // Set the captured image
            capturedImage = image

            // Show preview
            withAnimation {
                showPreview = true
            }
        }
    }
}

struct SingleImageCaptureView_Previews: PreviewProvider {
    static var previews: some View {
        SingleImageCaptureView(capturedImage: .constant(nil))
    }
}
