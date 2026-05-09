import SwiftUI

@main
struct PicDeckApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var coordinator = AppCoordinator()

    var body: some Scene {
        MenuBarExtra("PicDeck", systemImage: "photo.on.rectangle.angled") {
            MenuBarView(coordinator: coordinator)
        }

        Settings {
            SettingsView()
        }
    }
}

