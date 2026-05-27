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

        let targetApplication = previouslyFocusedApplication
        targetApplication?.activate(options: [.activateAllWindows])

        guard AccessibilityPermission.isTrusted else {
            return
        }

        Self.sendCommandV(whenFrontmost: targetApplication)
    }

    private static func sendCommandV(whenFrontmost application: NSRunningApplication?, attemptsRemaining: Int = 8) {
        guard
            let application,
            NSWorkspace.shared.frontmostApplication?.processIdentifier != application.processIdentifier,
            attemptsRemaining > 0
        else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                sendCommandV()
            }
            return
        }

        application.activate(options: [.activateAllWindows])

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            sendCommandV(whenFrontmost: application, attemptsRemaining: attemptsRemaining - 1)
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
