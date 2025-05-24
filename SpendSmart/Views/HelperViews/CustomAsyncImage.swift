//
//  CustomAsyncImage.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-05-15.
//

import SwiftUI

/// A custom AsyncImage component that can handle both remote and local URLs
struct CustomAsyncImage<Content: View, Placeholder: View>: View {
    private let urlString: String
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var isLoading = true

    /// Initialize with a URL string (can be remote or local)
    /// - Parameters:
    ///   - urlString: The URL string (supports "local://" prefix for local files)
    ///   - content: A closure that takes an Image and returns a Content view
    ///   - placeholder: A closure that returns a Placeholder view
    init(urlString: String, @ViewBuilder content: @escaping (Image) -> Content, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.urlString = urlString
        self.content = content
        self.placeholder = placeholder
    }

    /// Initialize with a URL (for remote images only)
    /// - Parameters:
    ///   - url: The URL
    ///   - content: A closure that takes an Image and returns a Content view
    ///   - placeholder: A closure that returns a Placeholder view
    init(url: URL?, @ViewBuilder content: @escaping (Image) -> Content, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.urlString = url?.absoluteString ?? ""
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image = image {
                content(Image(uiImage: image))
            } else {
                placeholder()
            }
        }
        .onAppear {
            loadImage()
        }
        .onChange(of: urlString) { oldValue, newValue in
            loadImage()
        }
    }

    private func loadImage() {
        // Reset state
        isLoading = true
        image = nil

        // Skip loading if URL is empty or placeholder
        if urlString.isEmpty || urlString == "placeholder_url" {
            isLoading = false
            return
        }

        Task {
            if let loadedImage = await NewExpenseView.loadImage(from: urlString) {
                await MainActor.run {
                    self.image = loadedImage
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

// Convenience initializer that mimics SwiftUI's AsyncImage
extension CustomAsyncImage where Content == Image, Placeholder == ProgressView<EmptyView, EmptyView> {
    init(url: URL?) {
        self.init(
            urlString: url?.absoluteString ?? "",
            content: { $0 },
            placeholder: { ProgressView() }
        )
    }

    init(urlString: String) {
        self.init(
            urlString: urlString,
            content: { $0 },
            placeholder: { ProgressView() }
        )
    }
}

// Preview
struct CustomAsyncImage_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Remote image
            CustomAsyncImage(urlString: "https://example.com/image.jpg") { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200, height: 200)
            } placeholder: {
                ProgressView()
                    .frame(width: 200, height: 200)
            }

            // Local image (would work in a real app)
            CustomAsyncImage(urlString: "local://sample.jpg") { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200, height: 200)
            } placeholder: {
                ProgressView()
                    .frame(width: 200, height: 200)
            }

            // Placeholder
            CustomAsyncImage(urlString: "placeholder_url") { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200, height: 200)
            } placeholder: {
                Text("No Image")
                    .frame(width: 200, height: 200)
                    .background(Color.gray.opacity(0.2))
            }
        }
        .padding()
    }
}
