import Foundation

public enum SelectionCorner: CaseIterable {
    case bottomLeft, bottomRight, topLeft, topRight

    public func point(in rect: CGRect) -> CGPoint {
        switch self {
        case .bottomLeft: return CGPoint(x: rect.minX, y: rect.minY)
        case .bottomRight: return CGPoint(x: rect.maxX, y: rect.minY)
        case .topLeft: return CGPoint(x: rect.minX, y: rect.maxY)
        case .topRight: return CGPoint(x: rect.maxX, y: rect.maxY)
        }
    }

    public var opposite: SelectionCorner {
        switch self {
        case .bottomLeft: return .topRight
        case .bottomRight: return .topLeft
        case .topLeft: return .bottomRight
        case .topRight: return .bottomLeft
        }
    }
}

public enum SelectionGeometry {
    public static func clamp(_ point: CGPoint, to bounds: CGRect) -> CGPoint {
        CGPoint(x: min(max(point.x, bounds.minX), bounds.maxX),
                y: min(max(point.y, bounds.minY), bounds.maxY))
    }

    public static func rectangle(from start: CGPoint, to end: CGPoint, in bounds: CGRect) -> CGRect {
        let a = clamp(start, to: bounds)
        let b = clamp(end, to: bounds)
        return CGRect(x: min(a.x, b.x), y: min(a.y, b.y),
                      width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    public static func moving(_ rect: CGRect, by delta: CGPoint, in bounds: CGRect) -> CGRect {
        let x = min(max(rect.minX + delta.x, bounds.minX), bounds.maxX - rect.width)
        let y = min(max(rect.minY + delta.y, bounds.minY), bounds.maxY - rect.height)
        return CGRect(origin: CGPoint(x: x, y: y), size: rect.size)
    }

    /// AppKit uses a bottom-left origin; CGImage cropping uses a top-left origin.
    public static func pixelRect(for selection: CGRect, canvas: CGSize, pixels: CGSize) -> CGRect? {
        guard canvas.width > 0, canvas.height > 0, pixels.width > 0, pixels.height > 0 else { return nil }
        let clipped = selection.standardized.intersection(CGRect(origin: .zero, size: canvas))
        guard !clipped.isNull, clipped.width > 0, clipped.height > 0 else { return nil }
        let scaleX = pixels.width / canvas.width
        let scaleY = pixels.height / canvas.height
        let rect = CGRect(x: clipped.minX * scaleX,
                          y: (canvas.height - clipped.maxY) * scaleY,
                          width: clipped.width * scaleX, height: clipped.height * scaleY)
        return rect.integral.intersection(CGRect(origin: .zero, size: pixels))
    }
}
