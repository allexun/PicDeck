import AppKit
import UniformTypeIdentifiers

struct PasteboardService {
    func copy(_ item: MediaItem) throws {
        let pasteboard = NSPasteboard.general
        let pasteboardItem = NSPasteboardItem()
        let fileData = try Data(contentsOf: item.url)

        pasteboard.clearContents()

        if let contentType = contentType(for: item.fileExtension) {
            pasteboardItem.setData(fileData, forType: NSPasteboard.PasteboardType(contentType.identifier))
        }

        if let image = NSImage(contentsOf: item.url) {
            if let tiffData = image.tiffRepresentation {
                pasteboardItem.setData(tiffData, forType: .tiff)
            }

            if item.fileExtension != "png",
               let pngData = pngData(from: image) {
                pasteboardItem.setData(pngData, forType: .png)
            }
        }

        pasteboardItem.setString(item.url.absoluteString, forType: .fileURL)

        if !pasteboard.writeObjects([pasteboardItem]) {
            throw PasteboardError.copyFailed
        }
    }

    private func contentType(for fileExtension: String) -> UTType? {
        switch fileExtension.lowercased() {
        case "png":
            .png
        case "jpg", "jpeg":
            .jpeg
        case "gif":
            .gif
        case "webp":
            .webP
        case "heic":
            .heic
        case "tiff", "tif":
            .tiff
        default:
            nil
        }
    }

    private func pngData(from image: NSImage) -> Data? {
        guard
            let tiffData = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData)
        else {
            return nil
        }

        return bitmap.representation(using: .png, properties: [:])
    }
}

enum PasteboardError: LocalizedError {
    case copyFailed

    var errorDescription: String? {
        "Could not copy the selected file to the pasteboard."
    }
}
