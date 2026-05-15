import AppKit
import Combine
import SwiftUI

@MainActor
final class PickerPanelController: NSObject, NSWindowDelegate {
    private let libraryStore: MediaLibraryStore
    private let onPaste: (MediaItem) -> Void
    private let selection = PickerSelection()
    private var panel: KeyHandlingPanel?
    private var outsideClickMonitors: [Any] = []

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
        startOutsideClickMonitoring()
    }

    func close() {
        panel?.close()
    }

    private func makePanel() -> KeyHandlingPanel {
        let panel = KeyHandlingPanel(NSHostingView(
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
        ))

        panel.delegate = self

        panel.onEscape = { [weak self] in
            self?.close()
        }

        panel.onReturn = { [weak self] in
            guard let self, let item = self.selection.selectedItem else {
                return
            }

            self.paste(item)
        }

        return panel
    }

    private func paste(_ item: MediaItem) {
        close()
        onPaste(item)
    }

    func windowWillClose(_ notification: Notification) {
        stopOutsideClickMonitoring()
    }

    private func startOutsideClickMonitoring() {
        stopOutsideClickMonitoring()

        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]

        let localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.closeIfClickIsOutsidePanel()
            return event
        }

        let globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            self?.closeIfClickIsOutsidePanel()
        }

        outsideClickMonitors = [localMonitor as Any, globalMonitor as Any]
    }

    private func stopOutsideClickMonitoring() {
        outsideClickMonitors.forEach(NSEvent.removeMonitor)
        outsideClickMonitors.removeAll()
    }

    private func closeIfClickIsOutsidePanel() {
        guard let panel, panel.isVisible, !panel.frame.contains(NSEvent.mouseLocation) else {
            return
        }

        close()
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

final class KeyHandlingPanel: GlassPanel {
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

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }
}
