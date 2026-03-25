import Foundation
import UIKit

class ImageStorageService {
    static let shared = ImageStorageService()
    private let backendAPI = BackendAPIService.shared
    private init() {}

    func uploadImage(_ image: UIImage) async -> String {
        let resized = resize(image, to: CGSize(width: 1000, height: 1000))
        do {
            let res = try await backendAPI.uploadImages([resized])
            return res.images.first?.url ?? "placeholder_url"
        } catch {
            return await saveLocally(resized)
        }

    }

    func uploadImages(_ images: [UIImage]) async -> [String] {
        let resized = images.map { resize($0, to: CGSize(width: 1000, height: 1000)) }
        do {
            let res = try await backendAPI.uploadImages(resized)
            return res.images.compactMap { $0.success ? $0.url : nil }
        } catch {
            var urls: [String] = []
            for img in resized { urls.append(await saveLocally(img)) }
            return urls
        }
    }

    private func saveLocally(_ image: UIImage) async -> String {
        let name = "receipt_\(Int(Date().timeIntervalSince1970))_\(Int.random(in: 10000...99999)).jpg"
        guard let doc = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let data = image.jpegData(compressionQuality: 0.7) else { return "placeholder_url" }
        let url = doc.appendingPathComponent(name)
        do {
            try data.write(to: url)
            return "local://\(name)"
        } catch { return "placeholder_url" }
    }

    private func resize(_ image: UIImage, to target: CGSize) -> UIImage {
        let factor = min(target.width / image.size.width, target.height / image.size.height)
        if factor >= 1 { return image }
        let size = CGSize(width: image.size.width * factor, height: image.size.height * factor)
        return UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }
}
