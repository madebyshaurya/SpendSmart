//
//  VersionUpdateAlert.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-05-01.
//

import SwiftUI

struct VersionUpdateAlert: View {
    @Environment(\.colorScheme) private var colorScheme
    let versionInfo: VersionInfo
    let onAction: (VersionUpdateAction) -> Void
    @State private var showReleaseNotes = false
    @State private var isUpdating = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    if !versionInfo.isForced { onAction(.dismiss) }
                }
            
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    Image(systemName: versionInfo.isForced ? "exclamationmark.triangle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(versionInfo.isForced ? .orange : .blue)
                    
                    Text(versionInfo.isForced ? "Required Update" : "Update Available")
                        .font(.instrumentSans(size: 22, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    
                    Text("Version \(versionInfo.latestVersion) is \(versionInfo.isForced ? "required to continue using the app" : "now available")")
                        .font(.instrumentSans(size: 16))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)
                .padding(.horizontal, 24)
                
                if let releaseNotes = versionInfo.releaseNotes, !releaseNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("What's New")
                                .font(.instrumentSans(size: 16, weight: .medium))
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                            Spacer()
                            Button(action: { showReleaseNotes.toggle() }) {
                                Image(systemName: showReleaseNotes ? "chevron.up" : "chevron.down")
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        if showReleaseNotes {
                            ScrollView {
                                Text(releaseNotes)
                                    .font(.instrumentSans(size: 14))
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 120)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                }
                
                VStack(spacing: 12) {
                    Button(action: { onAction(.updateNow) }) {
                        Text("Update Now")
                            .font(.instrumentSans(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(versionInfo.isForced ? Color.orange : Color.blue)
                            .cornerRadius(10)
                    }
                    
                    if !versionInfo.isForced {
                        Button(action: { onAction(.remindLater) }) {
                            Text("Remind Later")
                                .font(.instrumentSans(size: 14, weight: .medium))
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue))
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
                    .shadow(radius: 20)
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
