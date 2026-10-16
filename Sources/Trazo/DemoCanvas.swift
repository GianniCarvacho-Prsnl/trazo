import AppKit

@MainActor
enum DemoCanvas {
    static func image(size: CGSize, scale: CGFloat) -> CGImage? {
        guard let context = CGContext(data: nil, width: Int(size.width * scale), height: Int(size.height * scale),
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.scaleBy(x: scale, y: scale)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        defer { NSGraphicsContext.restoreGraphicsState() }
        let bounds = NSRect(origin: .zero, size: size)
        NSGradient(starting: NSColor(srgbRed: 0.77, green: 0.8, blue: 0.92, alpha: 1),
                   ending: NSColor(srgbRed: 0.91, green: 0.87, blue: 0.96, alpha: 1))!.draw(in: bounds, angle: 30)
        let card = NSRect(x: size.width * 0.2, y: size.height * 0.24,
                          width: size.width * 0.6, height: size.height * 0.57)
        let shadow = NSShadow(); shadow.shadowBlurRadius = 36; shadow.shadowOffset = NSSize(width: 0, height: -10)
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.15)
        NSGraphicsContext.saveGraphicsState(); shadow.set()
        NSColor.white.setFill()
        NSBezierPath(roundedRect: card, xRadius: 18, yRadius: 18).fill()
        NSGraphicsContext.restoreGraphicsState()
        let left = card.minX + 38
        func text(_ value: String, x: CGFloat, y: CGFloat, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
            (value as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [
                .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color
            ])
        }
        text("ESPACIO DE PRUEBA", x: left, y: card.maxY - 55, size: 11, weight: .bold, color: .systemPurple)
        text("Las buenas ideas se entienden mejor.", x: left, y: card.maxY - 104,
             size: min(28, card.width / 23), weight: .bold, color: NSColor(calibratedWhite: 0.15, alpha: 1))
        text("Señala lo importante con una flecha, una figura o unas palabras.", x: left,
             y: card.maxY - 137, size: min(14, card.width / 48), weight: .regular, color: .gray)
        for (index, title) in ["Seleccionar un área", "Añadir una anotación", "Copiar o guardar la imagen"].enumerated() {
            let y = card.maxY - 200 - CGFloat(index) * 58
            let circle = NSRect(x: left, y: y, width: 30, height: 30)
            NSColor(srgbRed: 0.94, green: 0.92, blue: 1, alpha: 1).setFill()
            NSBezierPath(ovalIn: circle).fill()
            text("\(index + 1)", x: left + 10, y: y + 7, size: 13, weight: .semibold, color: .systemPurple)
            text(title, x: left + 46, y: y + 6, size: 16, weight: .medium,
                 color: NSColor(calibratedWhite: 0.25, alpha: 1))
        }
        text("Imagen de prueba · sin capturar tu pantalla", x: left, y: card.minY + 25,
             size: 11, weight: .regular, color: .gray)
        return context.makeImage()
    }
}
