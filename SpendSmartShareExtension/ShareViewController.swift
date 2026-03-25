import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        handleSharedImage()
    }

    private func handleSharedImage() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            completeRequest()
            return
        }

        for item in extensionItems {
            guard let attachments = item.attachments else { continue }

            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] data, error in
                        guard error == nil else {
                            self?.completeRequest()
                            return
                        }

                        var imageData: Data?

                        if let url = data as? URL {
                            imageData = try? Data(contentsOf: url)
                        } else if let image = data as? UIImage {
                            imageData = image.jpegData(compressionQuality: 0.9)
                        } else if let rawData = data as? Data {
                            imageData = rawData
                        }

                        guard let finalData = imageData else {
                            self?.completeRequest()
                            return
                        }

                        self?.saveAndOpenApp(imageData: finalData)
                    }
                    return
                }
            }
        }

        completeRequest()
    }

    private func saveAndOpenApp(imageData: Data) {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.spendsmart.shared"
        ) else {
            completeRequest()
            return
        }

        let fileURL = containerURL.appendingPathComponent("shared_receipt_image.jpg")

        do {
            try imageData.write(to: fileURL)

            if let sharedDefaults = UserDefaults(suiteName: "group.com.spendsmart.shared") {
                sharedDefaults.set(fileURL.path, forKey: "pendingShareImagePath")
                sharedDefaults.set(Date().timeIntervalSince1970, forKey: "pendingShareTimestamp")
                sharedDefaults.synchronize()
            }

            openMainApp()
        } catch {
            completeRequest()
        }
    }

    private func openMainApp() {
        guard let url = URL(string: "spendsmart://share/scan") else {
            completeRequest()
            return
        }

        var responder: UIResponder? = self
        while let nextResponder = responder?.next {
            if let application = nextResponder as? UIApplication {
                application.open(url, options: [:]) { [weak self] _ in
                    self?.completeRequest()
                }
                return
            }
            responder = nextResponder
        }

        completeRequest()
    }

    private func completeRequest() {
        DispatchQueue.main.async {
            self.extensionContext?.completeRequest(returningItems: nil)
        }
    }
}
