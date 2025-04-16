//
//  SupportView.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-03-18.
//

import SwiftUI

struct SupportView: View {
    @State private var name = ""
    @State private var email = ""
    @State private var subject = ""
    @State private var message = ""
    @State private var isSubmitting = false
    @State private var showingConfirmation = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @Environment(\.colorScheme) private var colorScheme

    // FormSubmit endpoint - this is a free service that forwards form submissions to an email
    private let formSubmitEndpoint = "https://formsubmit.co/shaurya50211@gmail.com"

    var body: some View {
        ZStack {
            Form {
                Section(header: Text("Contact Information").font(.instrumentSans(size: 14))) {
                    TextField("Your Name", text: $name)
                        .font(.instrumentSans(size: 16))
                        .autocapitalization(.words)
                        .disableAutocorrection(true)

                    TextField("Your Email", text: $email)
                        .font(.instrumentSans(size: 16))
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }

                Section(header: Text("Message Details").font(.instrumentSans(size: 14))) {
                    TextField("Subject", text: $subject)
                        .font(.instrumentSans(size: 16))

                    ZStack(alignment: .topLeading) {
                        if message.isEmpty {
                            Text("Describe your issue or feedback...")
                                .foregroundColor(.gray)
                                .font(.instrumentSans(size: 16))
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }

                        TextEditor(text: $message)
                            .font(.instrumentSans(size: 16))
                            .frame(minHeight: 150)
                    }
                }

                Section {
                    Button(action: submitForm) {
                        HStack {
                            Spacer()

                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .padding(.trailing, 10)
                            }

                            Text(isSubmitting ? "Sending..." : "Submit Feedback")
                                .font(.instrumentSans(size: 16, weight: .medium))

                            Spacer()
                        }
                    }
                    .disabled(isSubmitting || !isFormValid)
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .padding()
                    .background(isFormValid ? Color(hex: "3B82F6") : Color.gray.opacity(0.5))
                    .cornerRadius(10)
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("We value your feedback!")
                            .font(.instrumentSans(size: 16, weight: .medium))

                        Text("Your message will be sent directly to our support team. We typically respond within 24-48 hours on business days.")
                            .font(.instrumentSans(size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 8)
                }
            }
            .alert("Message Sent", isPresented: $showingConfirmation) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Thank you for contacting us. We'll get back to you as soon as possible.")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .navigationTitle("Contact Support")
            .disabled(isSubmitting)
        }
    }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        isValidEmail(email) &&
        !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }

    private func submitForm() {
        guard isFormValid else { return }

        isSubmitting = true

        // Create URL request to FormSubmit
        guard let url = URL(string: formSubmitEndpoint) else {
            handleError("Invalid form submission URL")
            return
        }

        // Create form data
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // Create form body
        let formData = [
            "name": name,
            "email": email,
            "_subject": "SpendSmart Support: \(subject)",
            "message": message,
            "_template": "table", // Use FormSubmit's table template
            "_captcha": "false" // Disable captcha for better UX
        ]

        let formBody = formData.map { key, value in
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            return "\(encodedKey)=\(encodedValue)"
        }.joined(separator: "&")

        request.httpBody = formBody.data(using: .utf8)

        // Submit the form
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isSubmitting = false

                if let error = error {
                    handleError("Failed to send: \(error.localizedDescription)")
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    handleError("Invalid response from server")
                    return
                }

                if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                    // Success
                    showingConfirmation = true

                    // Reset form
                    name = ""
                    email = ""
                    subject = ""
                    message = ""
                } else {
                    // Error
                    handleError("Server returned error code: \(httpResponse.statusCode)")
                }
            }
        }.resume()
    }

    private func handleError(_ message: String) {
        isSubmitting = false
        errorMessage = message
        showingError = true
    }
}
