import AppKit
import CaptureCore
import Testing

@Test func reverseSelectionClipsToScreen() {
    let selection = SelectionGeometry.rectangle(from: CGPoint(x: 90, y: 80), to: CGPoint(x: -10, y: 20),
                                                 in: CGRect(x: 0, y: 0, width: 100, height: 100))
    #expect(selection == CGRect(x: 0, y: 20, width: 90, height: 60))
}

@Test func movingSelectionPreservesSizeAtDisplayEdges() {
    let moved = SelectionGeometry.moving(CGRect(x: 20, y: 20, width: 50, height: 30),
        by: CGPoint(x: 200, y: -80), in: CGRect(x: 0, y: 0, width: 100, height: 100))
    #expect(moved == CGRect(x: 50, y: 0, width: 50, height: 30))
}

@Test func cropConvertsOriginAndIndependentPixelScales() {
    let crop = SelectionGeometry.pixelRect(for: CGRect(x: 10, y: 20, width: 40, height: 30),
        canvas: CGSize(width: 200, height: 100), pixels: CGSize(width: 400, height: 300))
    #expect(crop == CGRect(x: 20, y: 150, width: 80, height: 90))
    #expect(SelectionGeometry.pixelRect(for: .zero, canvas: CGSize(width: 100, height: 100),
                                        pixels: CGSize(width: 200, height: 200)) == nil)
}

@Test func undoRedoAndNewEditsHaveIndependentHistory() {
    var document = AnnotationDocument()
    let arrow = Annotation(tool: .arrow, points: [.zero, CGPoint(x: 10, y: 10)], color: InkColor.palette[0], width: 4)
    let text = Annotation(tool: .text, points: [.zero], color: InkColor.palette[1], width: 2, text: "Revisar")
    document.append(arrow); document.append(text)
    document.undo()
    #expect(document.annotations.count == 1)
    #expect(document.canRedo)
    document.redo()
    #expect(document.annotations.last?.text == "Revisar")
    document.undo(); document.append(arrow)
    #expect(!document.canRedo)
    #expect(document.annotations.count == 2)
}

@Test func emptyMarksDoNotConsumeUndoHistory() {
    var document = AnnotationDocument()
    document.append(Annotation(tool: .line, points: [.zero, .zero], color: InkColor.palette[0], width: 4))
    document.append(Annotation(tool: .text, points: [.zero], color: InkColor.palette[0], width: 4, text: "   "))
    #expect(!document.canUndo)
}

private func fixture(width: Int = 16, height: Int = 16) -> CGImage {
    var bytes = [UInt8](repeating: 255, count: width * height * 4)
    for row in 0..<height {
        for column in 0..<width {
            let offset = (row * width + column) * 4
            bytes[offset] = row < height / 2 ? 255 : 0
            bytes[offset + 1] = 0
            bytes[offset + 2] = row < height / 2 ? 0 : 255
        }
    }
    let provider = CGDataProvider(data: Data(bytes) as CFData)!
    return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                   bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                   bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                   provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
}

@Test @MainActor func bottomSelectionExportsBottomPixelsAtRetinaResolution() throws {
    let image = try #require(ImageRenderer.render(image: fixture(), canvas: CGSize(width: 8, height: 8),
        selection: CGRect(x: 1, y: 0, width: 5, height: 3), annotations: []))
    #expect(image.width == 10)
    #expect(image.height == 6)
    let rep = NSBitmapImageRep(cgImage: image)
    let color = try #require(rep.colorAt(x: 5, y: 2)?.usingColorSpace(.sRGB))
    #expect(color.blueComponent > 0.95)
    #expect(color.redComponent < 0.05)
    let png = try #require(ImageRenderer.png(image))
    let decoded = try #require(NSBitmapImageRep(data: png))
    #expect(decoded.pixelsWide == 10)
    #expect(decoded.pixelsHigh == 6)
}

@Test @MainActor func annotationsAreCompositedInTheSameCoordinateSystemAsTheCrop() throws {
    let annotation = Annotation(tool: .line, points: [CGPoint(x: 2, y: 1), CGPoint(x: 6, y: 1)],
                                 color: InkColor(0, 1, 0), width: 1)
    let image = try #require(ImageRenderer.render(image: fixture(), canvas: CGSize(width: 8, height: 8),
        selection: CGRect(x: 1, y: 0, width: 6, height: 4), annotations: [annotation]))
    let rep = NSBitmapImageRep(cgImage: image)
    // y=1 point is two pixels from the bottom, not from the top of the crop.
    let bottom = try #require(rep.colorAt(x: 5, y: 6)?.usingColorSpace(.sRGB))
    let top = try #require(rep.colorAt(x: 5, y: 1)?.usingColorSpace(.sRGB))
    #expect(bottom.greenComponent > 0.9)
    #expect(top.blueComponent > 0.9)
}

@Test @MainActor func fractionalCropIncludesBoundaryPixels() throws {
    let image = try #require(ImageRenderer.render(image: fixture(), canvas: CGSize(width: 8, height: 8),
        selection: CGRect(x: 1.25, y: 1.25, width: 2.5, height: 2.5), annotations: []))
    #expect(image.width == 6)
    #expect(image.height == 6)
}
