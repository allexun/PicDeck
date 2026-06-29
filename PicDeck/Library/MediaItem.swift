import Foundation

struct MediaItem: Identifiable, Hashable {
    let id: String
    let url: URL
    let filename: String
    let filenameStem: String
    let fileExtension: String
    let isGIF: Bool
    let previewURL: URL?
    let source: MediaItemSource

    init(url: URL) {
        let fileExtension = url.pathExtension.lowercased()

        self.id = "library:\(url.standardizedFileURL.path)"
        self.url = url
        self.filename = url.lastPathComponent
        self.filenameStem = url.deletingPathExtension().lastPathComponent
        self.fileExtension = fileExtension
        self.isGIF = fileExtension == "gif"
        self.previewURL = nil
        self.source = .library
    }

    init(giphyGIF: GiphyGIF) {
        let normalizedTitle = Self.normalizedRemoteFilenameStem(from: giphyGIF.title, fallbackID: giphyGIF.id, prefix: "Giphy")

        self.id = "giphy:\(giphyGIF.id)"
        self.url = giphyGIF.originalGIFURL
        self.filename = "\(normalizedTitle).gif"
        self.filenameStem = normalizedTitle
        self.fileExtension = "gif"
        self.isGIF = true
        self.previewURL = giphyGIF.previewImageURL
        self.source = .giphy(giphyGIF)
    }

    init(klipyGIF: KlipyGIF) {
        let normalizedTitle = Self.normalizedRemoteFilenameStem(from: klipyGIF.title, fallbackID: klipyGIF.id, prefix: "Klipy")

        self.id = "klipy:\(klipyGIF.id)"
        self.url = klipyGIF.originalGIFURL
        self.filename = "\(normalizedTitle).gif"
        self.filenameStem = normalizedTitle
        self.fileExtension = "gif"
        self.isGIF = true
        self.previewURL = klipyGIF.previewImageURL
        self.source = .klipy(klipyGIF)
    }

    var isLibraryItem: Bool {
        if case .library = source {
            return true
        }

        return false
    }

    private static func normalizedRemoteFilenameStem(from title: String, fallbackID: String, prefix: String) -> String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let filteredScalars = trimmedTitle.unicodeScalars.map { scalar -> Character in
            let invalidCharacters = CharacterSet(charactersIn: "/:\\\n\r\t")
            return invalidCharacters.contains(scalar) ? "-" : Character(scalar)
        }
        let collapsedTitle = String(filteredScalars)
            .replacingOccurrences(of: #"[\s-]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return collapsedTitle.isEmpty ? "\(prefix) \(fallbackID)" : collapsedTitle
    }
}

enum MediaItemSource: Hashable {
    case library
    case giphy(GiphyGIF)
    case klipy(KlipyGIF)
}

struct GiphyGIF: Hashable {
    let id: String
    let title: String
    let previewImageURL: URL
    let originalGIFURL: URL
}

struct KlipyGIF: Hashable {
    let id: String
    let title: String
    let previewImageURL: URL
    let originalGIFURL: URL
}
