//
//  VersionUpdateAlert.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-05-01.
//

import SwiftUI

/// Custom alert view for version updates that matches the app's design language
struct VersionUpdateAlert: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let versionInfo: VersionInfo
    let onAction: (VersionUpdateAction) -> Void
    
    @State private var showReleaseNotes = false
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onAction(.dismiss)
                }
            
            // Alert content
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    // App icon or update icon
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("Update Available")
                        .font(.instrumentSans(size: 22, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    
                    Text("Version \(versionInfo.latestVersion) is now available")
                        .font(.instrumentSans(size: 16))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)
                .padding(.horizontal, 24)
                
                // Release notes section (if available)
                if let releaseNotes = versionInfo.releaseNotes, !releaseNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("What's New")
                                .font(.instrumentSans(size: 16, weight: .medium))
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                            
                            Spacer()
                            
                            Button(action: {
                                showReleaseNotes.toggle()
                            }) {
                                Image(systemName: showReleaseNotes ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        if showReleaseNotes {
                            ScrollView {
                                Text(releaseNotes)
                                    .font(.instrumentSans(size: 14))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 120)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                }
                
                // Action buttons
                VStack(spacing: 12) {
                    // Update Now button
                    Button(action: {
                        onAction(.updateNow)
                    }) {
                        HStack {
                            Spacer()
                            Text("Update Now")
                                .font(.instrumentSans(size: 16, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                    
                    // Secondary actions
                    HStack(spacing: 12) {
                        // Remind Later button
                        Button(action: {
                            onAction(.remindLater)
                        }) {
                            HStack {
                                Spacer()
                                Text("Remind Later")
                                    .font(.instrumentSans(size: 14, weight: .medium))
                                    .foregroundColor(.blue)
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                        }
                        
                        // Skip Version button
                        Button(action: {
                            onAction(.skipVersion)
                        }) {
                            HStack {
                                Spacer()
                                Text("Skip")
                                    .font(.instrumentSans(size: 14, weight: .medium))
                                    .foregroundColor(.gray)
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .background(Color.clear)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(colorScheme == .dark ? Color(hex: "1C1C1E") : Color.white)
                    .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 40)
        }
    }
}

// MARK: - Preview

#Preview {
    VersionUpdateAlert(
        versionInfo: VersionInfo(
            currentVersion: "1.0",
            latestVersion: "1.1",
            releaseNotes: "• Improved performance\n• Bug fixes\n• New features for better user experience\n• Enhanced security",
            releaseDate: Date(),
            appStoreURL: "https://apps.apple.com"
        ),
        onAction: { action in
            print("Action: \(action)")
        }
    )
    .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    VersionUpdateAlert(
        versionInfo: VersionInfo(
            currentVersion: "1.0",
            latestVersion: "1.1",
            releaseNotes: "• Improved performance\n• Bug fixes\n• New features for better user experience",
            releaseDate: Date(),
            appStoreURL: "https://apps.apple.com"
        ),
        onAction: { action in
            print("Action: \(action)")
        }
    )
    .preferredColorScheme(.dark)
}
