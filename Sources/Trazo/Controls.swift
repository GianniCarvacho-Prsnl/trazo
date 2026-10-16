import AppKit
import CaptureCore

@MainActor
final class ActionButton: NSButton {
    var onAction: (() -> Void)?

    init(title: String = "", symbol: String? = nil, action: @escaping () -> Void) {
        super.init(frame: .zero)
        self.title = title
        if let symbol { image = NSImage(systemSymbolName: symbol, accessibilityDescription: title) }
        imagePosition = title.isEmpty ? .imageOnly : .imageLeading
        bezelStyle = .rounded
        controlSize = .regular
        font = .systemFont(ofSize: 12, weight: .medium)
        focusRingType = .none
        onAction = action
        target = self
        self.action = #selector(performAction)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    @objc private func performAction() { onAction?() }
}

@MainActor
final class ColorSwatch: NSView {
    let color: InkColor
    var selected = false { didSet { needsDisplay = true } }
    var onAction: (() -> Void)?

    init(color: InkColor, name: String) {
        self.color = color
        super.init(frame: NSRect(x: 0, y: 0, width: 25, height: 30))
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 25).isActive = true
        heightAnchor.constraint(equalToConstant: 30).isActive = true
        toolTip = name
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(name)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func draw(_ dirtyRect: NSRect) {
        if selected {
            NSColor.white.withAlphaComponent(0.9).setStroke()
            let ring = NSBezierPath(ovalIn: bounds.insetBy(dx: 1, dy: 4))
            ring.lineWidth = 1.5; ring.stroke()
        }
        color.nsColor.setFill()
        NSBezierPath(ovalIn: bounds.insetBy(dx: 5, dy: 8)).fill()
    }
    override func mouseDown(with event: NSEvent) { onAction?() }
    override func accessibilityPerformPress() -> Bool { onAction?(); return true }
}

@MainActor
func separator() -> NSView {
    let view = NSBox()
    view.boxType = .separator
    view.widthAnchor.constraint(equalToConstant: 1).isActive = true
    view.heightAnchor.constraint(equalToConstant: 20).isActive = true
    return view
}

@MainActor
func label(_ text: String, size: CGFloat = 13, weight: NSFont.Weight = .regular,
           color: NSColor = .labelColor) -> NSTextField {
    let view = NSTextField(labelWithString: text)
    view.font = .systemFont(ofSize: size, weight: weight)
    view.textColor = color
    return view
}
