//
//  NewExpenseView.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-03-19.
//

import SwiftUI
import PhotosUI
import AVFoundation
import Vision

struct NewExpenseView: View {
    var onReceiptAdded: (Receipt) -> Void
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var selectedImage: UIImage?
    @State private var isAddingExpense = false // For loading indicator

    var body: some View {
        NavigationView {
            VStack {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(12)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(colorScheme == .dark ? Color(hex: "282828") : Color(hex: "F0F0F0"))
                                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                        )
                        .padding()
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "receipt")
                            .font(.system(size: 64))
                            .foregroundColor(colorScheme == .dark ? Color(hex: "DDDDDD") : Color(hex: "555555"))

                        Text("Select a Receipt Image")
                            .font(.instrumentSans(size: 24, weight: .medium))
                            .foregroundColor(colorScheme == .dark ? .white : .black)

                        Text("Take a photo of your receipt or select one from your gallery")
                            .font(.instrumentSans(size: 16))
                            .foregroundColor(colorScheme == .dark ? Color(hex: "AAAAAA") : Color(hex: "666666"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.vertical, 40)
                    .transition(.opacity) // Add transition
                }

                Spacer()

                HStack(spacing: 20) {
                    Button {
                        showCamera = true
                    } label: {
                        HStack {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 18))
                            Text("Camera")
                                .font(.instrumentSans(size: 18, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.gradient)
                        )
                        .foregroundColor(.white)
                    }

                    Button {
                        showImagePicker = true
                    } label: {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 18))
                            Text("Gallery")
                                .font(.instrumentSans(size: 18, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.green.gradient)
                        )
                        .foregroundColor(.white)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 10)

                if selectedImage != nil {
                    Button {
                        isAddingExpense = true
                        let dummyReceipt = Receipt(
                            id: UUID(),
                            user_id: supabase.auth.currentUser?.id ?? UUID(),
                            image_url: "placeholder_url",
                            total_amount: 50.00,
                            items: [ReceiptItem(id: UUID(), name: "Example Item", price: 50.00, category: "Food")],
                            store_name: "Example Store",
                            store_address: "123 Main St",
                            receipt_name: "My Receipt",
                            purchase_date: Date(),
                            currency: "USD",
                            payment_method: "Credit Card",
                            total_tax: 5.00
                        )
                        onReceiptAdded(dummyReceipt)
                        dismiss()
                    } label: {
                        HStack {
                            if isAddingExpense {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 18))
                                Text("Add Expense")
                                    .font(.instrumentSans(size: 18, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.orange.gradient)
                        )
                        .foregroundColor(.white)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                    .disabled(isAddingExpense)
                }
            }
            .padding()
            .background(colorScheme == .dark ? Color(hex: "121212") : Color(hex: "F4F4F4"))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage)
            }
            .sheet(isPresented: $showCamera) {
                ImageCaptureView(image: $selectedImage)
            }
        }
    }
}

struct ImageCaptureView: UIViewControllerRepresentable {
    @Binding var image: UIImage?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var parent: ImageCaptureView

        init(_ parent: ImageCaptureView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        var parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let provider = results.first?.itemProvider else { return }

            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    DispatchQueue.main.async {
                        self.parent.image = image as? UIImage
                    }
                }
            }
        }
    }
}

// Preview
struct NewExpenseView_Previews: PreviewProvider {
    static var previews: some View {
        NewExpenseView(onReceiptAdded: { _ in })
            .preferredColorScheme(.dark)
    }
}
