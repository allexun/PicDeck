import Combine
import Foundation

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
}
