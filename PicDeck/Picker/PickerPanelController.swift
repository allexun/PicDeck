import AppKit
import Combine
import Carbon
import SwiftUI

@MainActor
final class PickerPanelController: NSObject, NSWindowDelegate {
    private let libraryStore: MediaLibraryStore
    private let giphySearchStore: GiphySearchStore
    private let klipySearchStore: KlipySearchStore
    private let onPaste: (MediaItem) -> Void
    private let selection = PickerSelection()
    private var panel: KeyHandlingPanel?
    private var outsideClickMonitors: [Any] = []
    private var keyDownMonitor: Any?
    private var shortcutHotKeyRefs: [EventHotKeyRef] = []
    private var shortcutHandlerRef: EventHandlerRef?

    init(libraryStore: MediaLibraryStore, giphySearchStore: GiphySearchStore, klipySearchStore: KlipySearchStore, onPaste: @escaping (MediaItem) -> Void) {
        self.libraryStore = libraryStore
        self.giphySearchStore = giphySearchStore
        self.klipySearchStore = klipySearchStore
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
        startKeyboardMonitoring()
    }

    func close() {
        panel?.close()
    }

    private func makePanel() -> KeyHandlingPanel {
        let panel = KeyHandlingPanel(NSHostingView(
            rootView: PickerView(
                store: libraryStore,
                giphySearchStore: giphySearchStore,
                klipySearchStore: klipySearchStore,
                selection: selection,
                onCancel: { [weak self] in
                    self?.close()
                },
                onImportFromClipboard: { [libraryStore] in
                    try libraryStore.importImageFromClipboard()
                },
                onRename: { [weak self] item in
                    self?.rename(item)
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

        panel.onNavigation = { [weak self] direction in
            self?.selection.select(direction)
        }

        panel.onRename = { [weak self] in
            self?.selection.requestRename()
        }

        panel.onSwitchSearchMode = { [weak self] in
            self?.selection.requestSearchModeSwitch()
        }

        panel.onPreview = { [weak self] in
            self?.selection.requestPreview()
        }

        return panel
    }

    private func rename(_ item: MediaItem) -> MediaItem? {
        guard item.isLibraryItem else {
            return nil
        }

        stopOutsideClickMonitoring()
        stopKeyboardMonitoring()

        defer {
            if panel?.isVisible == true {
                startOutsideClickMonitoring()
                startKeyboardMonitoring()
            }
        }

        var proposedName = item.filenameStem

        while true {
            guard let newName = promptForRename(proposedName: proposedName) else {
                return nil
            }

            do {
                return try libraryStore.rename(item, toBaseName: newName)
            } catch {
                proposedName = newName
                presentRenameError(error)
            }
        }
    }

    private func promptForRename(proposedName: String) -> String? {
        let textField = NSTextField(string: proposedName)
        textField.frame = NSRect(x: 0, y: 0, width: 360, height: 24)

        let alert = NSAlert()
        alert.messageText = "Rename File"
        alert.accessoryView = textField
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = textField

        let response = alert.runModal()

        guard response == .alertFirstButtonReturn else {
            return nil
        }

        return textField.stringValue
    }

    private func presentRenameError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Could not rename file"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func paste(_ item: MediaItem) {
        close()
        onPaste(item)
    }

    func windowWillClose(_ notification: Notification) {
        stopOutsideClickMonitoring()
        stopKeyboardMonitoring()
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

    private func startKeyboardMonitoring() {
        stopKeyboardMonitoring()

        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard self?.handleCommandShortcut(event) == true else {
                return event
            }

            return nil
        }

        registerKeyboardShortcuts()
    }

    private func stopKeyboardMonitoring() {
        if let keyDownMonitor {
            NSEvent.removeMonitor(keyDownMonitor)
            self.keyDownMonitor = nil
        }

        unregisterKeyboardShortcuts()
    }

    private func registerKeyboardShortcuts() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else {
                    return OSStatus(eventNotHandledErr)
                }

                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard hotKeyID.signature == pickerFourCharacterCode("PDKS") else {
                    return OSStatus(eventNotHandledErr)
                }

                let controller = Unmanaged<PickerPanelController>.fromOpaque(userData).takeUnretainedValue()

                DispatchQueue.main.async {
                    controller.handleRegisteredShortcut(id: hotKeyID.id)
                }

                return noErr
            },
            1,
            &eventType,
            userData,
            &shortcutHandlerRef
        )

        registerKeyboardShortcut(id: 1, keyCode: kVK_LeftArrow)
        registerKeyboardShortcut(id: 2, keyCode: kVK_RightArrow)
        registerKeyboardShortcut(id: 3, keyCode: kVK_DownArrow)
        registerKeyboardShortcut(id: 4, keyCode: kVK_UpArrow)
        registerKeyboardShortcut(id: 5, keyCode: kVK_ANSI_R)
        registerKeyboardShortcut(id: 6, keyCode: kVK_ANSI_P)
    }

    private func registerKeyboardShortcut(id: UInt32, keyCode: Int) {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: pickerFourCharacterCode("PDKS"), id: id)

        let status = RegisterEventHotKey(
            UInt32(keyCode),
            UInt32(cmdKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr, let hotKeyRef {
            shortcutHotKeyRefs.append(hotKeyRef)
        }
    }

    private func unregisterKeyboardShortcuts() {
        for hotKeyRef in shortcutHotKeyRefs {
            UnregisterEventHotKey(hotKeyRef)
        }

        shortcutHotKeyRefs.removeAll()

        if let shortcutHandlerRef {
            RemoveEventHandler(shortcutHandlerRef)
            self.shortcutHandlerRef = nil
        }
    }

    private func handleRegisteredShortcut(id: UInt32) {
        guard panel?.isVisible == true else {
            return
        }

        switch id {
        case 1:
            selection.select(.left)
        case 2:
            selection.select(.right)
        case 3:
            selection.select(.down)
        case 4:
            selection.select(.up)
        case 5:
            selection.requestRename()
        case 6:
            selection.requestPreview()
        default:
            break
        }
    }

    private func handleCommandShortcut(_ event: NSEvent) -> Bool {
        guard panel?.isVisible == true else {
            return false
        }

        let shortcutModifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])

        guard shortcutModifiers == .command else {
            return false
        }

        switch event.keyCode {
        case 123:
            selection.select(.left)
        case 124:
            selection.select(.right)
        case 125:
            selection.select(.down)
        case 126:
            selection.select(.up)
        case 15:
            selection.requestRename()
        case 35:
            selection.requestPreview()
        default:
            return false
        }

        return true
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

private func pickerFourCharacterCode(_ string: String) -> OSType {
    string.utf8.reduce(0) { result, byte in
        (result << 8) + OSType(byte)
    }
}

final class PickerSelection: ObservableObject {
    @Published var selectedItem: MediaItem?
    @Published var renameRequest: MediaItem?
    @Published var searchModeSwitchRequest = 0
    @Published var previewRequest = 0

    var visibleItems: [MediaItem] = []
    var columnCount = 5

    func select(_ direction: PickerNavigationDirection) {
        guard !visibleItems.isEmpty else {
            selectedItem = nil
            return
        }

        let currentIndex = selectedItem.flatMap { visibleItems.firstIndex(of: $0) } ?? 0
        let offset: Int

        switch direction {
        case .left:
            offset = -1
        case .right:
            offset = 1
        case .up:
            offset = -max(1, columnCount)
        case .down:
            offset = max(1, columnCount)
        }

        let nextIndex = min(max(currentIndex + offset, 0), visibleItems.count - 1)
        selectedItem = visibleItems[nextIndex]
    }

    func requestRename() {
        renameRequest = selectedItem
    }

    func requestSearchModeSwitch() {
        searchModeSwitchRequest += 1
    }

    func requestPreview() {
        previewRequest += 1
    }
}

enum PickerNavigationDirection {
    case left
    case right
    case up
    case down
}

final class KeyHandlingPanel: GlassPanel {
    var onEscape: (() -> Void)?
    var onReturn: (() -> Void)?
    var onNavigation: ((PickerNavigationDirection) -> Void)?
    var onRename: (() -> Void)?
    var onSwitchSearchMode: (() -> Void)?
    var onPreview: (() -> Void)?

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }

    override func sendEvent(_ event: NSEvent) {
        if handleCommandShortcut(event) {
            return
        }

        super.sendEvent(event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if handleCommandShortcut(event) {
            return true
        }

        return super.performKeyEquivalent(with: event)
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

    private func handleCommandShortcut(_ event: NSEvent) -> Bool {
        guard event.type == .keyDown else {
            return false
        }

        let shortcutModifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])

        if event.keyCode == 48, shortcutModifiers.isEmpty, attachedSheet == nil {
            onSwitchSearchMode?()
            return true
        }

        guard shortcutModifiers == .command else {
            return false
        }

        switch event.keyCode {
        case 123:
            onNavigation?(.left)
        case 124:
            onNavigation?(.right)
        case 125:
            onNavigation?(.down)
        case 126:
            onNavigation?(.up)
        case 15:
            onRename?()
        case 35:
            onPreview?()
        default:
            return false
        }

        return true
    }
}
