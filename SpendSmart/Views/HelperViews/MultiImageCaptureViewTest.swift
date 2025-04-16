//
//  MultiImageCaptureViewTest.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-04-10.
//

import SwiftUI

struct MultiImageCaptureViewTest: View {
    @State private var capturedImages: [UIImage] = []
    @State private var showMultiCamera = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Multi-Image Capture Test")
                .font(.instrumentSerif(size: 24))
                .padding()

            if capturedImages.isEmpty {
                Text("No images captured yet")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                // Display captured images in a carousel
                TabView {
                    ForEach(0..<capturedImages.count, id: \.self) { index in
                        Image(uiImage: capturedImages[index])
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(12)
                            .padding()
                    }
                }
                .tabViewStyle(PageTabViewStyle())
                .frame(height: 300)

                Text("Captured \(capturedImages.count) image\(capturedImages.count == 1 ? "" : "s")")
                    .foregroundColor(.secondary)
            }

            Button {
                showMultiCamera = true
            } label: {
                HStack {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 18))
                    Text("Capture Multiple Images")
                        .font(.instrumentSans(size: 18, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color(hex: "3B82F6"), Color(hex: "1D4ED8")]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .foregroundColor(.white)
            }
            .padding(.horizontal)

            if !capturedImages.isEmpty {
                Button {
                    capturedImages = []
                } label: {
                    Text("Clear Images")
                        .font(.instrumentSans(size: 16))
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 24)
                        .background(
                            Capsule()
                                .fill(Color.red)
                        )
                }
            }
        }
        .padding()
        .sheet(isPresented: $showMultiCamera) {
            MultiImageCaptureView(capturedImages: $capturedImages)
        }
    }
}

struct MultiImageCaptureViewTest_Previews: PreviewProvider {
    static var previews: some View {
        MultiImageCaptureViewTest()
    }
}
