import SwiftUI

@main
struct PathFatterApp: App {
    @StateObject private var mappingStore = PathMappingStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(mappingStore)
                .onOpenURL { url in
                    mappingStore.handleIncomingURL(url)
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
