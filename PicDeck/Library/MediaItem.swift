import Foundation

struct MediaItem: Identifiable, Hashable {
    let id: UUID
    let url: URL
    let filename: String
    let filenameStem: String
    let fileExtension: String
    let isGIF: Bool

    init(id: UUID = UUID(), url: URL) {
        let fileExtension = url.pathExtension.lowercased()

        self.id = id
        self.url = url
        self.filename = url.lastPathComponent
        self.filenameStem = url.deletingPathExtension().lastPathComponent
        self.fileExtension = fileExtension
        self.isGIF = fileExtension == "gif"
    }
}
