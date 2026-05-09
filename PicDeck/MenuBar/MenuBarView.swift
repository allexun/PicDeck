import SwiftUI

struct MenuBarView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        Button("Open Picker") {
            coordinator.openPicker()
        }
        .keyboardShortcut(" ", modifiers: .option)

        Button("Open Library Folder") {
            coordinator.openLibraryFolder()
        }

        Button("Request Accessibility Permission") {
            coordinator.requestAccessibilityPermission()
        }

        Divider()

        Button("Quit") {
            coordinator.quit()
        }
        .keyboardShortcut("q")
    }
}

