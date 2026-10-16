import AppKit
import ScreenCaptureKit

struct ScreenSnapshot {
    let screen: NSScreen
    let image: CGImage
    let isDemo: Bool
}

@MainActor
enum ScreenCaptureService {
    static func capture() async throws -> [ScreenSnapshot] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let ownApplications = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
        var result: [ScreenSnapshot] = []
        for screen in NSScreen.screens {
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
                  let display = content.displays.first(where: { $0.displayID == id.uint32Value }) else { continue }
            let filter = SCContentFilter(display: display, excludingApplications: ownApplications, exceptingWindows: [])
            let config = SCStreamConfiguration()
            config.width = Int(screen.frame.width * screen.backingScaleFactor)
            config.height = Int(screen.frame.height * screen.backingScaleFactor)
            config.showsCursor = false
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            result.append(ScreenSnapshot(screen: screen, image: image, isDemo: false))
        }
        if result.isEmpty { throw CaptureFailure.noDisplay }
        return result
    }
}

enum CaptureFailure: LocalizedError {
    case noDisplay, rendering, clipboard
    var errorDescription: String? {
        switch self {
        case .noDisplay: return "No se encontró una pantalla disponible."
        case .rendering: return "No se pudo preparar la imagen. Intenta seleccionar el área de nuevo."
        case .clipboard: return "No se pudo copiar la imagen al portapapeles."
        }
    }
}
