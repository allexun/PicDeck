import AppKit
import Combine

@MainActor
final class AppCoordinator: ObservableObject {
    let libraryStore = MediaLibraryStore()

    private let pasteboardService = PasteboardService()
    private lazy var pasteController = PasteController(pasteboardService: pasteboardService)
    private lazy var pickerPanelController = PickerPanelController(libraryStore: libraryStore) { [weak self] item in
        self?.pasteController.paste(item)
    }

    private var shortcutController: GlobalShortcutController?

    init() {
        libraryStore.refresh()
        shortcutController = GlobalShortcutController { [weak self] in
            self?.openPicker()
        }
    }

    func openPicker() {
        pasteController.captureFrontmostApplication()
        libraryStore.refresh()
        pickerPanelController.show()
    }

    func openLibraryFolder() {
        libraryStore.refresh()
        NSWorkspace.shared.open(libraryStore.libraryFolderURL)
    }

    func requestAccessibilityPermission() {
        AccessibilityPermission.request()
    }

    func quit() {
        NSApp.terminate(nil)
    }
}
