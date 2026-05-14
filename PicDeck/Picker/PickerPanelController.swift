import AppKit
import Combine
import SwiftUI

@MainActor
final class PickerPanelController: NSObject, NSWindowDelegate {
    private let libraryStore: MediaLibraryStore
    private let onPaste: (MediaItem) -> Void
    private let selection = PickerSelection()
    private var panel: KeyHandlingPanel?

    init(libraryStore: MediaLibraryStore, onPaste: @escaping (MediaItem) -> Void) {
        self.libraryStore = libraryStore
        self.onPaste = onPaste
    }

    func show() {
        let panel = panel ?? makePanel()
        self.panel = panel

        center(panel)
        NSApp.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        panel?.close()
    }

    private func makePanel() -> KeyHandlingPanel {
        let panel = KeyHandlingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.delegate = self
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true

        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        panel.onEscape = { [weak self] in
            self?.close()
        }

        panel.onReturn = { [weak self] in
            guard let self, let item = self.selection.selectedItem else {
                return
            }

            self.paste(item)
        }

        panel.contentView = NSHostingView(
            rootView: PickerView(
                store: libraryStore,
                selection: selection,
                onCancel: { [weak self] in
                    self?.close()
                },
                onImportFromClipboard: { [libraryStore] in
                    try libraryStore.importImageFromClipboard()
                },
                onPaste: { [weak self] item in
                    self?.paste(item)
                }
            )
        )

        return panel
    }

    private func paste(_ item: MediaItem) {
        close()
        onPaste(item)
    }

    private func center(_ panel: NSPanel) {
        let screen = NSScreen.screens.first { screen in
            screen.frame.contains(NSEvent.mouseLocation)
        } ?? NSScreen.main

        guard let visibleFrame = screen?.visibleFrame else {
            panel.center()
            return
        }

        let size = panel.frame.size
        let origin = NSPoint(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.midY - size.height / 2
        )

        panel.setFrameOrigin(origin)
    }
}

final class PickerSelection: ObservableObject {
    @Published var selectedItem: MediaItem?
}

final class KeyHandlingPanel: NSPanel {
    var onEscape: (() -> Void)?
    var onReturn: (() -> Void)?

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76:
            onReturn?()
        case 53:
            onEscape?()
        default:
            super.keyDown(with: event)
        }
    }
}
