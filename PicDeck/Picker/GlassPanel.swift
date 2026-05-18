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

        configureGlass(rootView)
    }

    private func configureGlass(_ rootView: NSView) {
        let glass = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        glass.blendingMode = .behindWindow
        glass.material = .hudWindow
        glass.state = .active
        glass.wantsLayer = true
        glass.layer?.cornerRadius = cornerRadius
        glass.layer?.masksToBounds = true

        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = NSColor.clear.cgColor
        rootView.layer?.cornerRadius = cornerRadius

        glass.addSubview(rootView)

        rootView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            rootView.leadingAnchor.constraint(equalTo: glass.leadingAnchor),
            rootView.trailingAnchor.constraint(equalTo: glass.trailingAnchor),
            rootView.topAnchor.constraint(equalTo: glass.topAnchor),
            rootView.bottomAnchor.constraint(equalTo: glass.bottomAnchor)
        ])

        contentView = glass
    }
}
