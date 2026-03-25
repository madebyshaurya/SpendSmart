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
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
