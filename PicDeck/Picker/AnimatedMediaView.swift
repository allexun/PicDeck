import AppKit
import SwiftUI

struct AnimatedMediaView: View {
    let item: MediaItem

    @State private var image: NSImage?
    @State private var imageTask: Task<Void, Never>?

    var body: some View {
        AnimatedNSImageView(image: image)
            .onAppear {
                loadImage()
            }
            .onChange(of: item.id) {
                loadImage()
            }
            .onDisappear {
                imageTask?.cancel()
                imageTask = nil
            }
    }

    private func loadImage() {
        imageTask?.cancel()

        if item.isLibraryItem {
            image = NSImage(contentsOf: item.url)
            return
        }

        image = nil
        imageTask = Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: item.url)
                guard
                    !Task.isCancelled,
                    let httpResponse = response as? HTTPURLResponse,
                    (200 ... 299).contains(httpResponse.statusCode),
                    let image = NSImage(data: data)
                else {
                    return
                }

                await MainActor.run {
                    self.image = image
                }
            } catch {
                return
            }
        }
    }
}

private struct AnimatedNSImageView: NSViewRepresentable {
    let image: NSImage?

    func makeNSView(context: Context) -> NSImageView {
        let imageView = LayoutNeutralImageView()
        imageView.imageAlignment = .alignCenter
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.animates = true
        imageView.canDrawSubviewsIntoLayer = true
        imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        imageView.setContentHuggingPriority(.defaultLow, for: .vertical)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return imageView
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {
        nsView.image = image
        nsView.animates = true
    }
}

private final class LayoutNeutralImageView: NSImageView {
    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }
}
