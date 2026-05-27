import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
final class MediaLibraryStore: ObservableObject {
    @Published private(set) var items: [MediaItem] = []
    @Published private(set) var errorMessage: String?

    let libraryFolderURL: URL

    private let supportedExtensions: Set<String> = [
        "png",
        "jpg",
        "jpeg",
        "gif",
        "webp",
        "heic",
        "tiff"
    ]

    init(fileManager: FileManager = .default) {
        self.libraryFolderURL = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Pictures", isDirectory: true)
            .appendingPathComponent("PicDeck Library", isDirectory: true)
    }

    func refresh() {
        do {
            try createLibraryFolderIfNeeded()

            let urls = try FileManager.default.contentsOfDirectory(
                at: libraryFolderURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )

            items = try urls
                .filter(isSupportedMediaFile)
                .sorted { first, second in
                    first.lastPathComponent.localizedCaseInsensitiveCompare(second.lastPathComponent) == .orderedAscending
                }
                .map { MediaItem(url: $0) }

            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func importImageFromClipboard() throws -> MediaItem {
        try createLibraryFolderIfNeeded()

        let pasteboard = NSPasteboard.general
        let destinationURL: URL

        if let fileURL = supportedFileURL(on: pasteboard) {
            destinationURL = uniqueDestinationURL(
                preferredName: fileURL.lastPathComponent,
                fallbackExtension: fileURL.pathExtension
            )
            try FileManager.default.copyItem(at: fileURL, to: destinationURL)
        } else if let payload = imageData(on: pasteboard) {
            destinationURL = uniqueDestinationURL(
                preferredName: clipboardImageFilename(fileExtension: payload.fileExtension),
                fallbackExtension: payload.fileExtension
            )
            try payload.data.write(to: destinationURL, options: .atomic)
        } else if let image = NSImage(pasteboard: pasteboard), let data = pngData(from: image) {
            destinationURL = uniqueDestinationURL(
                preferredName: clipboardImageFilename(fileExtension: "png"),
                fallbackExtension: "png"
            )
            try data.write(to: destinationURL, options: .atomic)
        } else {
            throw MediaLibraryImportError.noImageFound
        }

        refresh()

        return items.first { $0.url == destinationURL } ?? MediaItem(url: destinationURL)
    }

    @discardableResult
    func importGiphyGIF(_ gif: GiphyGIF) async throws -> MediaItem {
        try createLibraryFolderIfNeeded()

        let destinationURL = uniqueDestinationURL(
            preferredName: "\(MediaItem(giphyGIF: gif).filenameStem).gif",
            fallbackExtension: "gif"
        )

        let (temporaryURL, response) = try await URLSession.shared.download(from: gif.originalGIFURL)

        if let httpResponse = response as? HTTPURLResponse,
           !(200 ... 299).contains(httpResponse.statusCode) {
            throw GiphyImportError.downloadFailed
        }

        try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
        refresh()

        return items.first { $0.url == destinationURL } ?? MediaItem(url: destinationURL)
    }

    @discardableResult
    func rename(_ item: MediaItem, toBaseName proposedBaseName: String) throws -> MediaItem {
        try createLibraryFolderIfNeeded()

        let baseName = try normalizedBaseName(proposedBaseName, fileExtension: item.fileExtension)
        let destinationURL = libraryFolderURL
            .appendingPathComponent(baseName)
            .appendingPathExtension(item.fileExtension)

        guard item.url.path != destinationURL.path else {
            return item
        }

        guard FileManager.default.fileExists(atPath: item.url.path) else {
            throw MediaLibraryRenameError.originalFileMissing
        }

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            guard item.url.path.caseInsensitiveCompare(destinationURL.path) == .orderedSame else {
                throw MediaLibraryRenameError.nameAlreadyExists(destinationURL.lastPathComponent)
            }

            let temporaryURL = libraryFolderURL
                .appendingPathComponent(".picdeck-rename-\(UUID().uuidString)")
                .appendingPathExtension(item.fileExtension)

            try FileManager.default.moveItem(at: item.url, to: temporaryURL)

            do {
                try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
            } catch {
                if FileManager.default.fileExists(atPath: temporaryURL.path) {
                    try? FileManager.default.moveItem(at: temporaryURL, to: item.url)
                }

                throw error
            }
        } else {
            try FileManager.default.moveItem(at: item.url, to: destinationURL)
        }

        refresh()

        return items.first { $0.url == destinationURL } ?? MediaItem(url: destinationURL)
    }

    private func createLibraryFolderIfNeeded() throws {
        try FileManager.default.createDirectory(
            at: libraryFolderURL,
            withIntermediateDirectories: true
        )
    }

    private func isSupportedMediaFile(_ url: URL) throws -> Bool {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey])
        return values.isRegularFile == true && supportedExtensions.contains(url.pathExtension.lowercased())
    }

    private func supportedFileURL(on pasteboard: NSPasteboard) -> URL? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]

        let urls = pasteboard
            .readObjects(forClasses: [NSURL.self], options: options)?
            .compactMap { object -> URL? in
                if let url = object as? URL {
                    return url
                }

                if let url = object as? NSURL {
                    return url as URL
                }

                return nil
            } ?? []

        return urls.first { url in
            (try? isSupportedMediaFile(url)) == true
        }
    }

    private func imageData(on pasteboard: NSPasteboard) -> ClipboardImagePayload? {
        let types: [(UTType, String)] = [
            (.png, "png"),
            (.jpeg, "jpg"),
            (.gif, "gif"),
            (.webP, "webp"),
            (.heic, "heic"),
            (.tiff, "tiff")
        ]

        for (type, fileExtension) in types {
            let pasteboardType = NSPasteboard.PasteboardType(type.identifier)

            if let data = pasteboard.data(forType: pasteboardType) {
                return ClipboardImagePayload(data: data, fileExtension: fileExtension)
            }
        }

        return nil
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

    private func clipboardImageFilename(fileExtension: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return "Clipboard Image \(formatter.string(from: Date())).\(fileExtension)"
    }

    private func normalizedBaseName(_ proposedBaseName: String, fileExtension: String) throws -> String {
        var baseName = proposedBaseName.trimmingCharacters(in: .whitespacesAndNewlines)

        if baseName.lowercased().hasSuffix(".\(fileExtension.lowercased())") {
            baseName = String(baseName.dropLast(fileExtension.count + 1))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var invalidCharacters = CharacterSet(charactersIn: "/:")
        invalidCharacters.formUnion(.newlines)

        guard !baseName.isEmpty else {
            throw MediaLibraryRenameError.emptyName
        }

        guard baseName != "." && baseName != ".." && baseName.rangeOfCharacter(from: invalidCharacters) == nil else {
            throw MediaLibraryRenameError.invalidName
        }

        return baseName
    }

    private func uniqueDestinationURL(preferredName: String, fallbackExtension: String) -> URL {
        let fallbackExtension = fallbackExtension.isEmpty ? "png" : fallbackExtension.lowercased()
        let preferredURL = URL(fileURLWithPath: preferredName)
        var baseName = preferredURL.deletingPathExtension().lastPathComponent
        let fileExtension = preferredURL.pathExtension.isEmpty ? fallbackExtension : preferredURL.pathExtension.lowercased()

        if baseName.isEmpty {
            baseName = "Clipboard Image"
        }

        var url = libraryFolderURL.appendingPathComponent(baseName).appendingPathExtension(fileExtension)
        var suffix = 2

        while FileManager.default.fileExists(atPath: url.path) {
            url = libraryFolderURL
                .appendingPathComponent("\(baseName) \(suffix)")
                .appendingPathExtension(fileExtension)
            suffix += 1
        }

        return url
    }
}

enum MediaLibraryRenameError: LocalizedError {
    case emptyName
    case invalidName
    case nameAlreadyExists(String)
    case originalFileMissing

    var errorDescription: String? {
        switch self {
        case .emptyName:
            "Enter a filename."
        case .invalidName:
            "Filenames cannot be '.', '..', or contain '/', ':', or line breaks."
        case .nameAlreadyExists(let filename):
            "A file named \(filename) already exists."
        case .originalFileMissing:
            "The selected file is no longer in the PicDeck library."
        }
    }
}

private struct ClipboardImagePayload {
    let data: Data
    let fileExtension: String
}

enum MediaLibraryImportError: LocalizedError {
    case noImageFound

    var errorDescription: String? {
        switch self {
        case .noImageFound:
            "The clipboard does not contain an image PicDeck can import."
        }
    }
}

enum GiphyImportError: LocalizedError {
    case downloadFailed

    var errorDescription: String? {
        switch self {
        case .downloadFailed:
            "Could not download the selected GIF from Giphy."
        }
    }
}
