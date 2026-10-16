import AppKit
import CaptureCore

final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class CaptureOverlayView: NSView, NSTextFieldDelegate {
    let snapshot: ScreenSnapshot
    var selection: CGRect?
    private(set) var document = AnnotationDocument()
    var tool: DrawingTool = .arrow { didSet { updateCursor(); needsDisplay = true } }
    var color = InkColor.palette[0]
    var lineWidth: CGFloat = 4
    var onSelection: (() -> Void)?
    var onChange: (() -> Void)?
    var onCopy: (() -> Void)?
    var onSave: (() -> Void)?
    var onCancel: (() -> Void)?

    private var draft: Annotation?
    private var textEntry: NSTextField?
    private var textOrigin: CGPoint?
    private var textStyle: (InkColor, CGFloat)?
    private var drag: Drag?

    private enum Drag {
        case selecting(CGPoint)
        case moving(CGPoint, CGRect)
        case resizing(CGPoint)
        case drawing
    }

    init(snapshot: ScreenSnapshot) {
        self.snapshot = snapshot
        super.init(frame: NSRect(origin: .zero, size: snapshot.screen.frame.size))
        autoresizingMask = [.width, .height]
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.draw(snapshot.image, in: bounds)
        if let selection {
            context.saveGState()
            context.clip(to: selection)
            for annotation in document.annotations { ImageRenderer.draw(annotation, in: context) }
            if let draft { ImageRenderer.draw(draft, in: context) }
            context.restoreGState()
        }
        let shade = NSBezierPath(rect: bounds)
        if let selection { shade.appendRect(selection) }
        shade.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.48).setFill()
        shade.fill()

        if let selection, selection.width > 0, selection.height > 0 {
            context.saveGState()
            context.setStrokeColor(NSColor.white.cgColor)
            context.setLineWidth(1)
            context.stroke(selection.insetBy(dx: -0.5, dy: -0.5))
            for corner in SelectionCorner.allCases {
                let p = corner.point(in: selection)
                let handle = CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6)
                context.setFillColor(NSColor.white.cgColor)
                context.fillEllipse(in: handle)
            }
            context.restoreGState()
            let pixelSize = exportedSize
            drawBadge("\(Int(pixelSize.width)) × \(Int(pixelSize.height))", at: CGPoint(
                x: max(12, min(selection.minX, bounds.maxX - 140)),
                y: min(bounds.maxY - 34, selection.maxY + 10)))
        } else {
            drawBadge("Arrastra para seleccionar un área  ·  Esc para salir", at: CGPoint(
                x: max(16, bounds.midX - 187), y: bounds.midY + 90))
        }
    }

    private func drawBadge(_ text: String, at point: CGPoint) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium), .foregroundColor: NSColor.white
        ]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let rect = NSRect(origin: point, size: NSSize(width: textSize.width + 20, height: 27))
        NSColor(calibratedWhite: 0.08, alpha: 0.92).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7).fill()
        (text as NSString).draw(at: NSPoint(x: rect.minX + 10, y: rect.minY + 6), withAttributes: attributes)
    }

    var exportedSize: CGSize {
        guard let selection,
              let rect = SelectionGeometry.pixelRect(for: selection, canvas: bounds.size,
                  pixels: CGSize(width: snapshot.image.width, height: snapshot.image.height)) else { return .zero }
        return rect.size
    }

    func updateCursor() {
        window?.invalidateCursorRects(for: self)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: selection == nil || tool != .select ? .crosshair : .arrow)
    }

    override func mouseDown(with event: NSEvent) {
        commitText()
        window?.makeFirstResponder(self)
        let point = SelectionGeometry.clamp(convert(event.locationInWindow, from: nil), to: bounds)
        guard let selection else {
            drag = .selecting(point)
            self.selection = CGRect(origin: point, size: .zero)
            needsDisplay = true
            return
        }
        if tool == .select {
            if let corner = SelectionCorner.allCases.first(where: {
                let p = $0.point(in: selection)
                return hypot(p.x - point.x, p.y - point.y) < 12
            }) {
                drag = .resizing(corner.opposite.point(in: selection))
            } else if selection.contains(point) {
                drag = .moving(point, selection)
            }
            return
        }
        guard selection.contains(point) else { return }
        if tool == .text { beginText(at: point); return }
        draft = Annotation(tool: tool, points: [point, point], color: color, width: lineWidth)
        drag = .drawing
    }

    override func mouseDragged(with event: NSEvent) {
        let point = SelectionGeometry.clamp(convert(event.locationInWindow, from: nil), to: bounds)
        switch drag {
        case .selecting(let start), .resizing(let start):
            selection = SelectionGeometry.rectangle(from: start, to: point, in: bounds)
        case .moving(let start, let original):
            selection = SelectionGeometry.moving(original, by: CGPoint(x: point.x - start.x, y: point.y - start.y), in: bounds)
        case .drawing:
            if draft?.tool == .pen || draft?.tool == .highlighter {
                if let last = draft?.points.last, hypot(last.x - point.x, last.y - point.y) < 0.5 { return }
                draft?.points.append(point)
            } else if let start = draft?.points.first {
                draft?.points = [start, point]
            }
        case nil: break
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        let wasSelecting: Bool
        if case .selecting = drag { wasSelecting = true } else { wasSelecting = false }
        if let draft { document.append(draft); self.draft = nil }
        drag = nil
        if let selection, selection.width < 8 || selection.height < 8 {
            self.selection = nil
        }
        if wasSelecting, selection != nil { onSelection?() }
        updateCursor()
        needsDisplay = true
        onChange?()
    }

    private func beginText(at point: CGPoint) {
        guard let selection else { return }
        let font = ImageRenderer.textFont(width: lineWidth)
        let origin = CGPoint(x: min(point.x, max(selection.minX, selection.maxX - 120)),
                             y: max(selection.minY, min(point.y - font.pointSize, selection.maxY - font.pointSize - 10)))
        let field = NSTextField(frame: NSRect(x: origin.x - 2, y: origin.y - 2,
            width: max(40, selection.maxX - origin.x), height: font.pointSize + 12))
        field.font = font; field.textColor = color.nsColor
        field.backgroundColor = NSColor.black.withAlphaComponent(0.65)
        field.isBordered = false; field.focusRingType = .none
        field.placeholderString = "Escribe aquí"
        field.delegate = self
        textEntry = field; textOrigin = origin; textStyle = (color, lineWidth)
        addSubview(field)
        window?.makeFirstResponder(field)
    }

    func commitText() {
        guard let field = textEntry, let origin = textOrigin, let style = textStyle else { return }
        let text = field.stringValue
        textEntry = nil; textOrigin = nil; textStyle = nil
        field.delegate = nil; field.removeFromSuperview()
        document.append(Annotation(tool: .text, points: [origin], color: style.0, width: style.1, text: text))
        needsDisplay = true
        onChange?()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            commitText(); window?.makeFirstResponder(self); return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            textEntry?.stringValue = ""
            commitText(); window?.makeFirstResponder(self); return true
        }
        return false
    }

    func undo() { commitText(); document.undo(); needsDisplay = true; onChange?() }
    func redo() { commitText(); document.redo(); needsDisplay = true; onChange?() }

    func renderedImage() -> CGImage? {
        commitText()
        guard let selection else { return nil }
        return ImageRenderer.render(image: snapshot.image, canvas: bounds.size,
                                    selection: selection, annotations: document.annotations)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onCancel?(); return }
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers.contains(.command) {
            if key == "c" { onCopy?(); return }
            if key == "s" { onSave?(); return }
            if key == "z" {
                if modifiers.contains(.shift) { redo() } else { undo() }
                return
            }
            if key == "q" { NSApp.terminate(nil); return }
        } else if let tool = DrawingTool.allCases.first(where: { $0.key == key }) {
            self.tool = tool; onChange?(); return
        }
        super.keyDown(with: event)
    }
}
