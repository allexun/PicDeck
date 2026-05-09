import AppKit

struct PasteboardService {
    func copy(_ item: MediaItem) throws {
        let pasteboard = NSPasteboard.general

        pasteboard.clearContents()

        if !pasteboard.writeObjects([item.url as NSURL]) {
            throw PasteboardError.copyFailed
        }
    }
}

enum PasteboardError: LocalizedError {
    case copyFailed

    var errorDescription: String? {
        "Could not copy the selected file to the pasteboard."
    }
}

