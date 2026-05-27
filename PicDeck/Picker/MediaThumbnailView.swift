import SwiftUI

struct MediaThumbnailView: View {
    let item: MediaItem
    let isSelected: Bool
    let onRename: () -> Void

    @State private var image: NSImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                } else {
                    Image(systemName: item.isGIF ? "livephoto" : "photo")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                }

                if item.isGIF {
                    Text("GIF")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.55), in: Capsule())
                        .foregroundStyle(.white)
                        .padding(7)
                }
            }
            .frame(height: 104)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(item.filename)
                .font(.caption)
                .lineLimit(2)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .frame(minHeight: 152)
        .background(.quaternary.opacity(isSelected ? 0.95 : 0.38), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contextMenu {
            Button {
                onRename()
            } label: {
                Label("Rename", systemImage: "pencil")
            }
        }
        .onAppear {
            image = NSImage(contentsOf: item.url)
        }
        .onChange(of: item.url) {
            image = NSImage(contentsOf: item.url)
        }
    }
}
