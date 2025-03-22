//
//  SupportView.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-03-18.
//

import SwiftUI

struct SupportView: View {
    @State private var subject = ""
    @State private var message = ""
    @State private var showingConfirmation = false
    
    var body: some View {
        Form {
            Section(header: Text("How can we help?")) {
                TextField("Subject", text: $subject)
                    .font(.instrumentSans(size: 16))
                
                ZStack(alignment: .topLeading) {
                    if message.isEmpty {
                        Text("Describe your issue...")
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
                Button("Submit") {
                    // In a real app, this would send the support request
                    showingConfirmation = true
                    
                    // Reset fields
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        subject = ""
                        message = ""
                    }
                }
                .font(.instrumentSans(size: 16, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundColor(.white)
                .padding()
                .background(Color(hex: "3B82F6"))
                .cornerRadius(10)
                .alert("Message Sent", isPresented: $showingConfirmation) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("Thank you for contacting us. We'll get back to you within 24 hours.")
                }
            }
        }
        .navigationTitle("Contact Support")
    }
}
