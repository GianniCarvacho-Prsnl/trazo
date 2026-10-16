import AppKit
import CaptureCore
import UniformTypeIdentifiers

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var welcome: WelcomeWindow!
    private var shortcut: GlobalShortcut?
    private var overlays: [(window: OverlayWindow, view: CaptureOverlayView)] = []
    private var activeView: CaptureOverlayView?
    private var toolbar: FloatingToolbar?
    private var captureTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var capturing = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        makeMenus()
        welcome = WelcomeWindow()
        welcome.onCapture = { [weak self] in self?.beginCapture() }
        welcome.onDemo = { [weak self] in self?.beginDemo() }
        shortcut = GlobalShortcut()
        observers.append(NotificationCenter.default.addObserver(forName: .captureShortcut, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.beginCapture() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.cancelCapture() }
            })
        if CommandLine.arguments.contains("--demo") { beginDemo() }
        else {
            welcome.show(message: shortcut?.registered == true ? nil : "Usa Nueva captura o el menú de Trazo; ⌘⇧2 ya está ocupado.")
        }
    }

    private func makeMenus() {
        let menu = NSMenu()
        let capture = NSMenuItem(title: "Nueva captura", action: #selector(captureAction), keyEquivalent: "2")
        capture.keyEquivalentModifierMask = [.command, .shift]; capture.target = self
        menu.addItem(capture)
        let show = NSMenuItem(title: "Abrir Trazo…", action: #selector(showWelcome), keyEquivalent: "")
        show.target = self; menu.addItem(show)
        let demo = NSMenuItem(title: "Probar editor…", action: #selector(demoAction), keyEquivalent: "")
        demo.target = self; menu.addItem(demo)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Salir de Trazo", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "viewfinder", accessibilityDescription: "Trazo")
        statusItem.button?.toolTip = "Trazo · captura y anota"
        statusItem.menu = menu

        let main = NSMenu()
        let application = NSMenuItem()
        let applicationMenu = NSMenu()
        applicationMenu.addItem(withTitle: "Salir de Trazo", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        application.submenu = applicationMenu; main.addItem(application)
        let edit = NSMenuItem()
        let editMenu = NSMenu(title: "Edición")
        for (title, action, key) in [("Cortar", #selector(NSText.cut(_:)), "x"),
                                     ("Copiar", #selector(NSText.copy(_:)), "c"),
                                     ("Pegar", #selector(NSText.paste(_:)), "v"),
                                     ("Seleccionar todo", #selector(NSText.selectAll(_:)), "a")] {
            editMenu.addItem(withTitle: title, action: action, keyEquivalent: key)
        }
        edit.submenu = editMenu; main.addItem(edit)
        NSApp.mainMenu = main
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if overlays.isEmpty { welcome.show() }
        return true
    }

    @objc private func captureAction() { beginCapture() }
    @objc private func demoAction() { beginDemo() }
    @objc private func showWelcome() { cancelCapture(); welcome.show() }

    private func beginCapture() {
        guard !capturing else { return }
        cancelCapture()
        capturing = true
        welcome.setBusy(true)
        welcome.window.orderOut(nil)
        captureTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: .milliseconds(180))
                let snapshots = try await ScreenCaptureService.capture()
                try Task.checkCancellation()
                capturing = false; welcome.setBusy(false)
                present(snapshots)
            } catch is CancellationError {
                // cancelCapture already resets the UI; a newer capture may now own it.
                return
            } catch {
                guard !Task.isCancelled else { return }
                capturing = false; welcome.setBusy(false)
                showCaptureError(error)
            }
        }
    }

    private func beginDemo() {
        cancelCapture()
        guard let screen = NSScreen.main ?? NSScreen.screens.first,
              let image = DemoCanvas.image(size: screen.frame.size, scale: screen.backingScaleFactor) else { return }
        welcome.window.orderOut(nil)
        present([ScreenSnapshot(screen: screen, image: image, isDemo: true)])
    }

    private func present(_ snapshots: [ScreenSnapshot]) {
        for snapshot in snapshots {
            let window = OverlayWindow(contentRect: snapshot.screen.frame, styleMask: .borderless,
                                       backing: .buffered, defer: false)
            window.level = .screenSaver
            window.title = snapshot.isDemo ? "Editor de Trazo · Prueba" : "Editor de Trazo"
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.isReleasedWhenClosed = false
            window.isOpaque = true; window.backgroundColor = .black
            window.acceptsMouseMovedEvents = true
            window.ignoresMouseEvents = false
            let view = CaptureOverlayView(snapshot: snapshot)
            window.contentView = view
            view.onSelection = { [weak self, weak view] in
                guard let view else { return }; self?.select(view)
            }
            view.onChange = { [weak self, weak view] in
                guard let self, let view, activeView === view else { return }; updateToolbar()
            }
            view.onCopy = { [weak self] in self?.copySelection() }
            view.onSave = { [weak self] in self?.saveSelection() }
            view.onCancel = { [weak self] in self?.cancelCapture() }
            overlays.append((window, view))
        }
        NSApp.activate(ignoringOtherApps: true)
        overlays.forEach { $0.window.orderFrontRegardless() }
        let pointer = NSEvent.mouseLocation
        let focused = overlays.first { $0.window.frame.contains(pointer) } ?? overlays.first
        focused?.window.makeKeyAndOrderFront(nil)
        if let focused { focused.window.makeFirstResponder(focused.view) }
    }

    private func select(_ view: CaptureOverlayView) {
        activeView = view
        for overlay in overlays where overlay.view !== view { overlay.window.orderOut(nil) }
        if toolbar == nil {
            let toolbar = FloatingToolbar(isDemo: view.snapshot.isDemo)
            toolbar.onTool = { [weak self] tool in
                self?.activeView?.commitText(); self?.activeView?.tool = tool; self?.updateToolbar()
            }
            toolbar.onColor = { [weak self] color in
                self?.activeView?.commitText(); self?.activeView?.color = color; self?.updateToolbar()
            }
            toolbar.onWidth = { [weak self] width in
                self?.activeView?.commitText(); self?.activeView?.lineWidth = width
            }
            toolbar.onUndo = { [weak self] in self?.activeView?.undo() }
            toolbar.onRedo = { [weak self] in self?.activeView?.redo() }
            toolbar.onCopy = { [weak self] in self?.copySelection() }
            toolbar.onSave = { [weak self] in self?.saveSelection() }
            toolbar.onCancel = { [weak self] in self?.cancelCapture() }
            self.toolbar = toolbar
        }
        updateToolbar()
        view.window?.makeKeyAndOrderFront(nil)
    }

    private func updateToolbar() {
        guard let view = activeView, let selection = view.selection else { toolbar?.hide(); return }
        toolbar?.update(tool: view.tool, color: view.color, document: view.document, size: view.exportedSize)
        toolbar?.show(near: selection, in: view)
    }

    private func copySelection() {
        guard activeView?.selection != nil else { return }
        guard let image = activeView?.renderedImage(), let png = ImageRenderer.png(image) else {
            showExportError(CaptureFailure.rendering); return
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let wrotePNG = pasteboard.setData(png, forType: .png)
        let tiff = NSBitmapImageRep(cgImage: image).tiffRepresentation
        if let tiff { pasteboard.setData(tiff, forType: .tiff) }
        guard wrotePNG else { showExportError(CaptureFailure.clipboard); return }
        cancelCapture()
        welcome.show(message: "Imagen copiada. Pégala con ⌘V donde quieras.")
    }

    private func saveSelection() {
        guard activeView?.selection != nil else { return }
        guard let image = activeView?.renderedImage(), let data = ImageRenderer.png(image) else {
            showExportError(CaptureFailure.rendering); return
        }
        hideEditor()
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        let dateFormat = DateFormatter()
        dateFormat.locale = Locale(identifier: "en_US_POSIX")
        dateFormat.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        panel.nameFieldStringValue = "Trazo-\(dateFormat.string(from: .now)).png"
        panel.title = "Guardar captura"
        panel.prompt = "Guardar"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { restoreEditor(); return }
        do {
            try data.write(to: url, options: .atomic)
            cancelCapture()
            welcome.show(message: "Guardada: \(url.lastPathComponent)")
        } catch { showExportError(error) }
    }

    private func hideEditor() {
        toolbar?.hide()
        overlays.forEach { $0.window.orderOut(nil) }
    }

    private func restoreEditor() {
        guard let view = activeView else { return }
        view.window?.makeKeyAndOrderFront(nil)
        view.window?.makeFirstResponder(view)
        updateToolbar()
    }

    private func showExportError(_ error: Error) {
        hideEditor()
        let alert = NSAlert()
        alert.messageText = "No se pudo exportar la captura"
        alert.informativeText = error.localizedDescription
        alert.runModal()
        restoreEditor()
    }

    private func showCaptureError(_ error: Error) {
        welcome.show()
        let alert = NSAlert()
        alert.messageText = "No se pudo capturar la pantalla"
        alert.informativeText = "Revisa el permiso de Trazo en Ajustes del Sistema → Privacidad y seguridad → Grabación de pantalla. Si acabas de activarlo, puede ser necesario cerrar y volver a abrir Trazo.\n\n\(error.localizedDescription)"
        alert.addButton(withTitle: "Abrir ajustes")
        alert.addButton(withTitle: "Aceptar")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    func cancelCapture() {
        captureTask?.cancel(); captureTask = nil
        capturing = false
        welcome?.setBusy(false)
        toolbar?.view.removeFromSuperview(); toolbar = nil
        activeView = nil
        for overlay in overlays { overlay.window.close() }
        overlays.removeAll()
    }

    func applicationWillTerminate(_ notification: Notification) {
        cancelCapture()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}
