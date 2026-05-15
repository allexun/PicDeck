import AppKit

class GlassPanel: NSPanel {
    private let width = 720
    private let height = 520
    private let cornerRadius: CGFloat = 24

    init(_ rootView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [
                .borderless,
                .fullSizeContentView,
                .nonactivatingPanel,
            ],
            backing: .buffered,
            defer: false
        )

        titleVisibility = .hidden
        titlebarAppearsTransparent = true

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false

        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        isMovableByWindowBackground = true

        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        if #available(macOS 26, *) {
            configureGlass(rootView)
        } else {
            configureOld(rootView)
        }
    }

    private func configureGlass(_ rootView: NSView) {
        guard #available(macOS 26, *) else { return }

        let glass = NSGlassEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        glass.style = .regular
        glass.cornerRadius = cornerRadius

        rootView.layer?.backgroundColor = NSColor.clear.cgColor
        rootView.layer?.cornerRadius = cornerRadius

        glass.addSubview(rootView)

        rootView.wantsLayer = true
        rootView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            rootView.leadingAnchor.constraint(equalTo: glass.leadingAnchor),
            rootView.trailingAnchor.constraint(equalTo: glass.trailingAnchor),
            rootView.topAnchor.constraint(equalTo: glass.topAnchor),
            rootView.bottomAnchor.constraint(equalTo: glass.bottomAnchor)
        ])

        contentView = glass
    }

    private func configureOld(_ rootView: NSView) {
        rootView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        rootView.layer?.cornerRadius = cornerRadius

        hasShadow = true
        contentView = rootView
    }
}
