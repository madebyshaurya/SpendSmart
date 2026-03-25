import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            Group {
                if appState.isBootstrapping {
                    SplashView()
                } else if appState.isLoggedIn {
                    ZStack {
                        LoopingVideoView(name: "home_bg")
                            .ignoresSafeArea()
                            .allowsHitTesting(false)

                        if appState.isOnboardingComplete {
                            MainTabView()
                        } else {
                            OnboardingView()
                        }
                    }
                } else {
                    LoginView()
                }
            }
            .animation(.default, value: appState.isLoggedIn)
            .animation(.default, value: appState.isOnboardingComplete)
            .animation(.default, value: appState.isBootstrapping)

            // Undismissable forced update overlay — blocks the entire app
            if appState.isForceUpdateRequired && appState.showVersionUpdateAlert {
                ForceUpdateOverlay(
                    version: appState.availableVersion,
                    releaseNotes: appState.releaseNotes
                )
                .transition(.opacity)
                .zIndex(999)
            }
        }
        // Optional update sheet — dismissable
        .sheet(isPresented: Binding(
            get: { appState.showVersionUpdateAlert && !appState.isForceUpdateRequired },
            set: { if !$0 { appState.showVersionUpdateAlert = false } }
        )) {
            OptionalUpdateSheet(
                version: appState.availableVersion,
                releaseNotes: appState.releaseNotes,
                onUpdate: {
                    VersionUpdateManager.shared.handleAction(.updateNow, version: appState.availableVersion)
                },
                onDismiss: {
                    appState.showVersionUpdateAlert = false
                    VersionUpdateManager.shared.handleAction(.remindLater, version: appState.availableVersion)
                }
            )
            .presentationDetents([.medium])
        }
    }
}

// MARK: - Force Update Overlay (Undismissable)

private struct ForceUpdateOverlay: View {
    let version: String
    let releaseNotes: String

    var body: some View {
        ZStack {
            Color.brandDeepNavy.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(Color.brandVibrantBlue.opacity(0.15))
                        .frame(width: 100, height: 100)
                    Image(systemName: "arrow.down.app.fill")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundColor(.brandVibrantBlue)
                        .symbolEffect(.bounce, options: .repeating.speed(0.5))
                }

                // Title
                Text("Update Required")
                    .font(.instrumentSerifItalic(size: 32))
                    .foregroundColor(.white)

                // Subtitle
                Text("A new version of SpendSmart (v\(version)) is available. Please update to continue using the app.")
                    .font(.manrope(size: 16, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                // Release notes
                if !releaseNotes.isEmpty {
                    ScrollView {
                        Text(releaseNotes)
                            .font(.manrope(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.5))
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxHeight: 150)
                }

                Spacer()

                // Update button
                Brand3DButton(title: "Update Now", icon: "arrow.down.app", style: .primary) {
                    VersionUpdateManager.shared.handleAction(.updateNow, version: version, isForced: true)
                }
                .padding(.horizontal, 24)

                Text("This update is required to continue")
                    .font(.manrope(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))

                Spacer(minLength: 40)
            }
        }
    }
}

// MARK: - Optional Update Sheet (Dismissable)

private struct OptionalUpdateSheet: View {
    let version: String
    let releaseNotes: String
    let onUpdate: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Handle
            Capsule()
                .fill(Color.brandBorder)
                .frame(width: 40, height: 5)
                .padding(.top, 8)

            // Icon
            ZStack {
                Circle()
                    .fill(Color.brandVibrantBlue.opacity(0.1))
                    .frame(width: 64, height: 64)
                Image(systemName: "sparkles")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.brandVibrantBlue)
            }

            // Title
            Text("Update Available")
                .font(.instrumentSerifItalic(size: 26))
                .foregroundColor(.brandTextPrimary)

            Text("SpendSmart v\(version) is here with improvements.")
                .font(.manrope(size: 15, weight: .regular))
                .foregroundColor(.brandTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            // Release notes
            if !releaseNotes.isEmpty {
                ScrollView {
                    Text(releaseNotes)
                        .font(.manrope(size: 13, weight: .regular))
                        .foregroundColor(.brandTextTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                }
                .frame(maxHeight: 120)
            }

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                Brand3DButton(title: "Update Now", icon: "arrow.down.app", style: .primary) {
                    onUpdate()
                }
                Button("Remind Me Later") {
                    onDismiss()
                }
                .font(.manrope(size: 15, weight: .medium))
                .foregroundColor(.brandTextSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background(Color.brandBackground)
        .interactiveDismissDisabled(false)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
