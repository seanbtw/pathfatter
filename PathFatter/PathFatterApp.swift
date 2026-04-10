import SwiftUI

@main
struct PathFatterApp: App {
    @StateObject private var mappingStore = PathMappingStore()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showOnboarding = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(mappingStore)
                .onOpenURL { url in
                    mappingStore.handleIncomingURL(url)
                }
                .onAppear {
                    if !hasSeenOnboarding {
                        showOnboarding = true
                    }
                }
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView()
                        .environmentObject(mappingStore)
                        .onDisappear {
                            hasSeenOnboarding = true
                        }
                }
        }
        .windowResizability(.automatic)
        .windowStyle(.hiddenTitleBar)

        Settings {
            SettingsView()
                .environmentObject(mappingStore)
        }
    }
}
