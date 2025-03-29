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
import GoogleGenerativeAI

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
                            .font(.instrumentSans(size: 28, weight: .medium))
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
                        Task {
                            let receipt = await extractDataFromImage(receiptImage: selectedImage!)
                            if let receipt = receipt {
                                onReceiptAdded(receipt)
                            } else {
                                print("Error receipt found nil")
                            }
                        }
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
    
    func extractDataFromImage(receiptImage: UIImage) async -> Receipt? {
        do {
            let systemPrompt = """
            ### **SpendSmart Receipt Extraction System**

            #### **Extraction Rules:**
            - No missing values – every field must be correctly populated.
            - Ensure calculations are accurate – total_amount = sum(items) + total_tax.
            - Detect currency based on store location or tax rate.
            - Extract payment method if present (e.g., "Credit Card", "Cash", "Mobile Payment").

            #### **Item Categorization:**
            Each item must be placed in the most appropriate category:
            - Groceries → Food, beverages, household essentials, cleaning supplies, snacks, dairy, bakery items, frozen foods, and fresh produce.
            - Dining → Any prepared meals, fast food, takeout, restaurant purchases, coffee shops, and catering.
            - Shopping → Clothing, electronics, accessories, home decor, appliances, books, and general retail items.
            - Health → Medicine, supplements, pharmacy purchases, hygiene products, skincare, and personal care items.
            - Transport → Gasoline, electric vehicle charging, public transit fares, tolls, ride-sharing services, and parking fees.
            - Services → Repairs, maintenance, haircuts, subscriptions (e.g., streaming, software), utilities, and professional services.
            - Entertainment → Movie tickets, gaming, concerts, amusement parks, hobbies, toys, and streaming rentals.
            - Other → Only if no category fits. Avoid overusing this category.

            #### **Quality Check Before Output:**
            Ensure totals are correct – verify sum of items + tax.
            Use logical tax rates based on region/currency.
            Extract store name, address, and date accurately.
            
            Goal: Fully automate receipt scanning for a seamless user experience.
            """
            
            let config = GenerationConfig(
              temperature: 1,
              topP: 0.95,
              topK: 40,
              maxOutputTokens: 8192,
              responseMIMEType: "application/json"
            )

            let model = GenerativeModel(
                name: "gemini-2.0-flash",
                apiKey: geminiAPIKey,
                generationConfig: config,
                systemInstruction: systemPrompt
            )
            
            let structuredSchema = """
            {
              "type": "object",
              "properties": {
                "id": {
                  "type": "string"
                },
                "user_id": {
                  "type": "string"
                },
                "image_url": {
                  "type": "string"
                },
                "total_amount": {
                  "type": "number"
                },
                "total_tax": {
                  "type": "number"
                },
                "currency": {
                  "type": "string"
                },
                "payment_method": {
                  "type": "string"
                },
                "purchase_date": {
                  "type": "string",
                  "format": "date"
                },
                "store_name": {
                  "type": "string"
                },
                "store_address": {
                  "type": "string"
                },
                "receipt_name": {
                  "type": "string"
                },
                "items": {
                  "type": "array",
                  "items": {
                    "type": "object",
                    "properties": {
                      "id": {
                        "type": "string"
                      },
                      "name": {
                        "type": "string"
                      },
                      "price": {
                        "type": "number"
                      },
                      "category": {
                        "type": "string"
                      }
                    },
                    "required": [
                      "id",
                      "name",
                      "price",
                      "category"
                    ]
                  }
                }
              },
              "required": [
                "total_amount",
                "total_tax",
                "currency",
                "payment_method",
                "purchase_date",
                "store_name",
                "store_address",
                "receipt_name",
                "items"
              ]
            }
            """
            
            let prompt = "Extract all receipt details from this image and return in this format: \(structuredSchema)."
            let response = try await model.generateContent(prompt, receiptImage)
            print(response.text ?? "No response received")
            
            // TODO: Parse response.text JSON into a Receipt object.
            let parsedReceipt = parseReceipt(from: response.text)  // Implement this parsing function
            return parsedReceipt
        } catch {
            print("Error extracting data from image: \(error)")
            return nil
        }
    }

    func parseReceipt(from jsonString: String?) -> Receipt? {
        guard let jsonString = jsonString, let data = jsonString.data(using: .utf8) else {
            print("Invalid JSON string")
            return nil  // ✅ Ensure the function returns nil if jsonString is invalid
        }

        do {
            let decoder = JSONDecoder()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd" // Matches the format in JSON

            decoder.dateDecodingStrategy = .formatted(dateFormatter)


            let parsedData = try decoder.decode(TemporaryReceipt.self, from: data)
            print("Date: \(parsedData.purchase_date)")
            print("IS08601 Date: \(parsedData.purchase_date.ISO8601Format())")

            let receipt = Receipt(
                id: UUID(),
                user_id: supabase.auth.currentUser?.id ?? UUID(),
                image_url: "placeholder_url",
                total_amount: parsedData.total_amount,
                items: parsedData.items.map { item in
                    ReceiptItem(
                        id: UUID(),
                        name: item.name,
                        price: item.price,
                        category: item.category
                    )
                },
                store_name: parsedData.store_name,
                store_address: parsedData.store_address,
                receipt_name: parsedData.receipt_name,
                purchase_date: parsedData.purchase_date,
                currency: parsedData.currency,
                payment_method: parsedData.payment_method,
                total_tax: parsedData.total_tax
            )

            return receipt
        } catch {
            print("JSON Parsing Error: \(error)")
            return nil  // ✅ Ensure the function returns nil if parsing fails
        }
    }


    // Temporary struct to decode the JSON structure before transforming it into a `Receipt` object
    private struct TemporaryReceipt: Codable {
        var total_amount: Double
        var total_tax: Double
        var currency: String
        var payment_method: String
        var purchase_date: Date
        var store_name: String
        var store_address: String
        var receipt_name: String
        var items: [TemporaryReceiptItem]
    }

    private struct TemporaryReceiptItem: Codable {
        var name: String
        var price: Double
        var category: String
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
