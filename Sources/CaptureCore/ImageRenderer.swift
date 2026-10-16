import AppKit

@MainActor
public enum ImageRenderer {
    public static func draw(_ annotation: Annotation, in context: CGContext) {
        guard let first = annotation.points.first else { return }
        let last = annotation.points.last ?? first
        context.saveGState()
        defer { context.restoreGState() }
        context.setStrokeColor(annotation.color.nsColor.cgColor)
        context.setFillColor(annotation.color.nsColor.cgColor)
        context.setLineWidth(annotation.width)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        switch annotation.tool {
        case .select: break
        case .pen, .highlighter:
            if annotation.tool == .highlighter {
                context.setAlpha(0.3)
                context.setLineWidth(annotation.width * 6)
                context.setLineCap(.butt)
            }
            context.beginPath()
            context.addLines(between: annotation.points)
            context.strokePath()
        case .line, .arrow:
            context.move(to: first); context.addLine(to: last); context.strokePath()
            if annotation.tool == .arrow {
                let angle = atan2(last.y - first.y, last.x - first.x)
                let length = min(max(annotation.width * 4, 14), hypot(last.x - first.x, last.y - first.y) * 0.6)
                context.move(to: CGPoint(x: last.x - length * cos(angle - .pi / 6),
                                        y: last.y - length * sin(angle - .pi / 6)))
                context.addLine(to: last)
                context.addLine(to: CGPoint(x: last.x - length * cos(angle + .pi / 6),
                                           y: last.y - length * sin(angle + .pi / 6)))
                context.strokePath()
            }
        case .rectangle, .ellipse:
            let rect = CGRect(x: min(first.x, last.x), y: min(first.y, last.y),
                              width: abs(last.x - first.x), height: abs(last.y - first.y))
            if annotation.tool == .rectangle { context.stroke(rect) }
            else { context.strokeEllipse(in: rect) }
        case .text:
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: textFont(width: annotation.width), .foregroundColor: annotation.color.nsColor
            ]
            (annotation.text as NSString).draw(at: first, withAttributes: attributes)
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    public static func textFont(width: CGFloat) -> NSFont {
        NSFont.systemFont(ofSize: 20 + width * 1.5, weight: .semibold)
    }

    public static func render(image: CGImage, canvas: CGSize, selection: CGRect,
                              annotations: [Annotation]) -> CGImage? {
        let pixels = CGSize(width: image.width, height: image.height)
        guard let crop = SelectionGeometry.pixelRect(for: selection, canvas: canvas, pixels: pixels),
              let base = image.cropping(to: crop),
              let context = CGContext(data: nil, width: base.width, height: base.height,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.draw(base, in: CGRect(x: 0, y: 0, width: base.width, height: base.height))
        let scaleX = pixels.width / canvas.width
        let scaleY = pixels.height / canvas.height
        context.scaleBy(x: scaleX, y: scaleY)
        // Preserve the integral pixel crop's exact origin, including fractional selections.
        context.translateBy(x: -crop.minX / scaleX,
                            y: -(pixels.height - crop.maxY) / scaleY)
        for annotation in annotations { draw(annotation, in: context) }
        return context.makeImage()
    }

    public static func png(_ image: CGImage) -> Data? {
        NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }
}
