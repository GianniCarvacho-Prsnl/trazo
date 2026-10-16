import AppKit

public enum DrawingTool: String, CaseIterable {
    case select, pen, highlighter, arrow, line, rectangle, ellipse, text

    public var title: String {
        switch self {
        case .select: return "Selección"
        case .pen: return "Lápiz"
        case .highlighter: return "Resaltador"
        case .arrow: return "Flecha"
        case .line: return "Línea"
        case .rectangle: return "Rectángulo"
        case .ellipse: return "Elipse"
        case .text: return "Texto"
        }
    }

    public var symbol: String {
        switch self {
        case .select: return "cursorarrow"
        case .pen: return "pencil.tip"
        case .highlighter: return "highlighter"
        case .arrow: return "arrow.up.right"
        case .line: return "line.diagonal"
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        case .text: return "textformat"
        }
    }

    public var key: String {
        switch self {
        case .select: return "v"
        case .pen: return "p"
        case .highlighter: return "h"
        case .arrow: return "a"
        case .line: return "l"
        case .rectangle: return "r"
        case .ellipse: return "o"
        case .text: return "t"
        }
    }
}

public struct InkColor: Equatable {
    public let red: CGFloat
    public let green: CGFloat
    public let blue: CGFloat

    public init(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) {
        self.red = red; self.green = green; self.blue = blue
    }

    public var nsColor: NSColor { NSColor(srgbRed: red, green: green, blue: blue, alpha: 1) }
    public static let palette: [InkColor] = [
        InkColor(0.98, 0.27, 0.34), InkColor(1, 0.79, 0.22),
        InkColor(0.24, 0.85, 0.62), InkColor(0.35, 0.63, 1), InkColor(1, 1, 1)
    ]
}

public struct Annotation {
    public let tool: DrawingTool
    public var points: [CGPoint]
    public let color: InkColor
    public let width: CGFloat
    public var text: String

    public init(tool: DrawingTool, points: [CGPoint], color: InkColor, width: CGFloat, text: String = "") {
        self.tool = tool; self.points = points; self.color = color; self.width = width; self.text = text
    }

    public var isVisible: Bool {
        guard let first = points.first else { return false }
        if tool == .text { return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return points.contains { hypot($0.x - first.x, $0.y - first.y) > 1 }
    }
}

public struct AnnotationDocument {
    public private(set) var annotations: [Annotation] = []
    private var undone: [Annotation] = []
    public var canUndo: Bool { !annotations.isEmpty }
    public var canRedo: Bool { !undone.isEmpty }

    public init() {}
    public mutating func append(_ annotation: Annotation) {
        guard annotation.isVisible else { return }
        annotations.append(annotation)
        undone.removeAll()
    }
    public mutating func undo() {
        if let last = annotations.popLast() { undone.append(last) }
    }
    public mutating func redo() {
        if let last = undone.popLast() { annotations.append(last) }
    }
}
