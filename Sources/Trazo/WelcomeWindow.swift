import AppKit

@MainActor
final class WelcomeWindow {
    let window: NSWindow
    var onCapture: (() -> Void)?
    var onDemo: (() -> Void)?
    private let information = label("", size: 12, color: .secondaryLabelColor)
    private var captureButton: ActionButton!

    init() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 610, height: 465),
                          styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Trazo"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(srgbRed: 0.075, green: 0.08, blue: 0.105, alpha: 1)
        window.center()
        guard let content = window.contentView else { return }

        let brand = NSStackView()
        brand.orientation = .horizontal; brand.spacing = 10
        let icon = NSImageView(image: NSImage(systemSymbolName: "viewfinder", accessibilityDescription: nil)!)
        icon.contentTintColor = NSColor(srgbRed: 0.68, green: 0.59, blue: 1, alpha: 1)
        icon.widthAnchor.constraint(equalToConstant: 26).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 26).isActive = true
        brand.addArrangedSubview(icon)
        brand.addArrangedSubview(label("trazo", size: 23, weight: .bold))
        brand.addArrangedSubview(label("  CAPTURA Y ANOTA", size: 10, weight: .semibold, color: .secondaryLabelColor))

        let title = label("Una captura.\nTu punto, más claro.", size: 35, weight: .bold)
        title.maximumNumberOfLines = 2
        let subtitle = label("Selecciona un área, añade tus marcas y llévala donde quieras.", size: 14, color: .secondaryLabelColor)

        let features = NSStackView()
        features.orientation = .horizontal; features.spacing = 28
        for (symbol, title) in [("crop", "Selecciona"), ("arrow.up.right", "Marca"), ("doc.on.doc", "Copia o guarda")] {
            let image = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil)!)
            image.contentTintColor = NSColor(srgbRed: 0.68, green: 0.59, blue: 1, alpha: 1)
            image.widthAnchor.constraint(equalToConstant: 18).isActive = true
            image.heightAnchor.constraint(equalToConstant: 18).isActive = true
            let row = NSStackView(views: [image, label(title, size: 12, weight: .medium)])
            row.spacing = 8
            features.addArrangedSubview(row)
        }

        captureButton = ActionButton(title: "Nueva captura", symbol: "plus") { [weak self] in self?.onCapture?() }
        captureButton.font = .systemFont(ofSize: 14, weight: .semibold)
        captureButton.controlSize = .large
        captureButton.bezelColor = NSColor(srgbRed: 0.48, green: 0.36, blue: 0.94, alpha: 1)
        captureButton.keyEquivalent = "\r"
        captureButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
        captureButton.widthAnchor.constraint(equalToConstant: 185).isActive = true
        let demo = ActionButton(title: "Probar editor") { [weak self] in self?.onDemo?() }
        demo.controlSize = .large
        let actions = NSStackView(views: [captureButton, demo])
        actions.spacing = 12

        information.stringValue = "⌘⇧2 desde cualquier app  ·  Las imágenes se quedan en tu Mac."
        information.maximumNumberOfLines = 2
        let privacy = label("macOS pedirá permiso para capturar la pantalla al usar Nueva captura.",
                            size: 11, color: .tertiaryLabelColor)

        let stack = NSStackView(views: [brand, title, subtitle, features, actions, information, privacy])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 19
        stack.setCustomSpacing(25, after: brand)
        stack.setCustomSpacing(8, after: title)
        stack.setCustomSpacing(24, after: subtitle)
        stack.setCustomSpacing(25, after: features)
        stack.setCustomSpacing(9, after: information)
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 38),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -24),
            stack.centerYAnchor.constraint(equalTo: content.centerYAnchor, constant: 2)
        ])
    }

    func show(message: String? = nil) {
        if let message { information.stringValue = message }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func setBusy(_ busy: Bool) {
        captureButton.isEnabled = !busy
        captureButton.title = busy ? "Preparando…" : "Nueva captura"
    }
}
