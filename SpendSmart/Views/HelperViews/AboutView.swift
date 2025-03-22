//
//  AboutView.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-03-18.
//

import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 60))
                    .foregroundColor(Color(hex: "3B82F6"))
                    .padding(.top, 30)
                
                Text("SpendSmart")
                    .font(.instrumentSerifItalic(size: 30))
                    .bold()
                
                Text("Version 1.0.0")
                    .font(.instrumentSans(size: 16))
                    .foregroundColor(.gray)
                
                VStack(alignment: .leading, spacing: 15) {
                    Text("SpendSmart is an AI-powered receipt scanner that helps you organize your expenses effortlessly.")
                        .font(.instrumentSans(size: 16))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Text("Developed by Shaurya Gupta")
                        .font(.instrumentSans(size: 16))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)
                    
                    Text("© 2025 SpendSmart. All rights reserved.")
                        .font(.instrumentSans(size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .padding()
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("About")
    }
}
