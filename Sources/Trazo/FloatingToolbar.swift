import AppKit
import CaptureCore

@MainActor
final class FloatingToolbar {
    let view: NSVisualEffectView
    var onTool: ((DrawingTool) -> Void)?
    var onColor: ((InkColor) -> Void)?
    var onWidth: ((CGFloat) -> Void)?
    var onUndo: (() -> Void)?
    var onRedo: (() -> Void)?
    var onCopy: (() -> Void)?
    var onSave: (() -> Void)?
    var onCancel: (() -> Void)?

    private var tools: [DrawingTool: ActionButton] = [:]
    private var swatches: [ColorSwatch] = []
    private var undoButton: ActionButton!
    private var redoButton: ActionButton!
    private var widthButton: ActionButton!
    private var widthIndex = 1
    private let widths: [CGFloat] = [2, 4, 7]
    private let dimensions = label("", size: 11, color: .secondaryLabelColor)

    init(isDemo: Bool) {
        let background = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 748, height: 100))
        view = background
        background.appearance = NSAppearance(named: .darkAqua)
        background.material = .hudWindow
        background.blendingMode = .withinWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 14
        background.layer?.borderWidth = 1
        background.layer?.borderColor = NSColor.white.withAlphaComponent(0.15).cgColor

        let top = NSStackView()
        top.orientation = .horizontal; top.spacing = 5; top.alignment = .centerY
        for tool in DrawingTool.allCases {
            let button = ActionButton(symbol: tool.symbol) { [weak self] in self?.onTool?(tool) }
            button.toolTip = "\(tool.title) (\(tool.key.uppercased()))"
            button.setAccessibilityLabel(tool.title)
            button.bezelStyle = .texturedRounded
            button.setButtonType(.toggle)
            button.widthAnchor.constraint(equalToConstant: 32).isActive = true
            button.heightAnchor.constraint(equalToConstant: 30).isActive = true
            tools[tool] = button
            top.addArrangedSubview(button)
        }
        top.addArrangedSubview(separator())
        let names = ["Rojo", "Amarillo", "Verde", "Azul", "Blanco"]
        for (index, color) in InkColor.palette.enumerated() {
            let swatch = ColorSwatch(color: color, name: names[index])
            swatch.onAction = { [weak self] in self?.onColor?(color) }
            swatches.append(swatch)
            top.addArrangedSubview(swatch)
        }
        top.addArrangedSubview(separator())
        widthButton = ActionButton(title: "4 pt", symbol: "lineweight") { [weak self] in
            guard let self else { return }
            widthIndex = (widthIndex + 1) % widths.count
            let width = widths[widthIndex]
            widthButton.title = "\(Int(width)) pt"
            onWidth?(width)
        }
        widthButton.toolTip = "Cambiar grosor: fino, medio o grueso"
        top.addArrangedSubview(widthButton)
        top.addArrangedSubview(separator())
        undoButton = ActionButton(symbol: "arrow.uturn.backward") { [weak self] in self?.onUndo?() }
        undoButton.toolTip = "Deshacer (⌘Z)"; undoButton.setAccessibilityLabel("Deshacer")
        redoButton = ActionButton(symbol: "arrow.uturn.forward") { [weak self] in self?.onRedo?() }
        redoButton.toolTip = "Rehacer (⇧⌘Z)"; redoButton.setAccessibilityLabel("Rehacer")
        top.addArrangedSubview(undoButton); top.addArrangedSubview(redoButton)

        let bottom = NSStackView()
        bottom.orientation = .horizontal; bottom.spacing = 10; bottom.alignment = .centerY
        bottom.addArrangedSubview(label(isDemo ? "PRUEBA DEL EDITOR" : "TRAZO", size: 10,
                                       weight: .bold, color: NSColor.white.withAlphaComponent(0.75)))
        bottom.addArrangedSubview(dimensions)
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        bottom.addArrangedSubview(spacer)
        let cancel = ActionButton(title: "Cerrar", symbol: "xmark") { [weak self] in self?.onCancel?() }
        cancel.toolTip = "Cancelar (Esc)"
        bottom.addArrangedSubview(cancel)
        let save = ActionButton(title: "Guardar  ⌘S", symbol: "square.and.arrow.down") { [weak self] in self?.onSave?() }
        bottom.addArrangedSubview(save)
        let copy = ActionButton(title: "Copiar  ⌘C", symbol: "doc.on.doc") { [weak self] in self?.onCopy?() }
        copy.bezelColor = NSColor(srgbRed: 0.46, green: 0.35, blue: 0.95, alpha: 1)
        bottom.addArrangedSubview(copy)

        let stack = NSStackView(views: [top, bottom])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -14),
            stack.centerYAnchor.constraint(equalTo: background.centerYAnchor),
            top.widthAnchor.constraint(equalTo: stack.widthAnchor),
            bottom.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    func update(tool: DrawingTool, color: InkColor, document: AnnotationDocument, size: CGSize) {
        for (candidate, button) in tools {
            button.contentTintColor = candidate == tool ? .white : .secondaryLabelColor
            button.state = candidate == tool ? .on : .off
        }
        swatches.forEach { $0.selected = $0.color == color }
        undoButton.isEnabled = document.canUndo
        redoButton.isEnabled = document.canRedo
        dimensions.stringValue = "\(Int(size.width)) × \(Int(size.height)) px"
    }

    func hide() { view.isHidden = true }

    func show(near selection: CGRect, in host: NSView) {
        let screenBounds = host.bounds
        let rect = selection
        let size = view.frame.size
        let x = max(screenBounds.minX + 12, min(rect.midX - size.width / 2, screenBounds.maxX - size.width - 12))
        var y = rect.minY - size.height - 14
        if y < screenBounds.minY + 12 { y = rect.maxY + 14 }
        if y + size.height > screenBounds.maxY - 12 { y = screenBounds.minY + 12 }
        view.setFrameOrigin(NSPoint(x: x, y: y))
        if view.superview !== host { host.addSubview(view) }
        view.isHidden = false
    }
}
