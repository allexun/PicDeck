import AppKit
import ApplicationServices

@MainActor
final class PasteController {
    private let pasteboardService: PasteboardService
    private var previouslyFocusedApplication: NSRunningApplication?

    init(pasteboardService: PasteboardService) {
        self.pasteboardService = pasteboardService
    }

    func captureFrontmostApplication() {
        let currentProcessID = ProcessInfo.processInfo.processIdentifier
        previouslyFocusedApplication = NSWorkspace.shared.frontmostApplication.flatMap { application in
            application.processIdentifier == currentProcessID ? nil : application
        }
    }

    func paste(_ item: MediaItem) {
        do {
            try pasteboardService.copy(item)
        } catch {
            return
        }

        previouslyFocusedApplication?.activate(options: [.activateAllWindows])

        guard AccessibilityPermission.isTrusted else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            Self.sendCommandV()
        }
    }

    private static func sendCommandV() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyCodeForV = CGKeyCode(9)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCodeForV, keyDown: true)
        keyDown?.flags = .maskCommand

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCodeForV, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
