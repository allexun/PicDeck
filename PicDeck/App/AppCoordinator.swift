import AppKit
import Combine

@MainActor
final class AppCoordinator: ObservableObject {
    let libraryStore = MediaLibraryStore()
    let giphySearchStore: GiphySearchStore
    let klipySearchStore: KlipySearchStore

    private let pasteboardService = PasteboardService()
    private lazy var pasteController = PasteController(pasteboardService: pasteboardService)
    private lazy var pickerPanelController = PickerPanelController(
        libraryStore: libraryStore,
        giphySearchStore: giphySearchStore,
        klipySearchStore: klipySearchStore
    ) { [weak self] item in
        self?.paste(item)
    }

    private var shortcutController: GlobalShortcutController?

    init() {
        let giphyConfigurationURL = libraryStore.libraryFolderURL
            .appendingPathComponent("giphy-config")
            .appendingPathExtension("json")
        giphySearchStore = GiphySearchStore(configurationFileURL: giphyConfigurationURL)

        let klipyConfigurationURL = libraryStore.libraryFolderURL
            .appendingPathComponent("klipy-config")
            .appendingPathExtension("json")
        klipySearchStore = KlipySearchStore(configurationFileURL: klipyConfigurationURL)

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

    func importImageFromClipboard() {
        do {
            try libraryStore.importImageFromClipboard()
        } catch {
            presentImportError(error)
        }
    }

    func requestAccessibilityPermission() {
        AccessibilityPermission.request()
    }

    func quit() {
        NSApp.terminate(nil)
    }

    private func paste(_ item: MediaItem) {
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            do {
                let resolvedItem: MediaItem

                switch item.source {
                case .library:
                    resolvedItem = item
                case .giphy(let gif):
                    resolvedItem = try await libraryStore.importGiphyGIF(gif)
                case .klipy(let gif):
                    resolvedItem = try await libraryStore.importKlipyGIF(gif)
                }

                pasteController.paste(resolvedItem)
            } catch {
                presentRemoteImportError(error)
            }
        }
    }

    private func presentImportError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Could not import image"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func presentRemoteImportError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Could not import GIF"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }
}
