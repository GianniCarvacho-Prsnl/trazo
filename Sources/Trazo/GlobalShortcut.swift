import Carbon
import Foundation

extension Notification.Name {
    static let captureShortcut = Notification.Name("TrazoCaptureShortcut")
}

final class GlobalShortcut {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?

    init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { NotificationCenter.default.post(name: .captureShortcut, object: nil) }
            return noErr
        }, 1, &spec, nil, &handler)
        let id = EventHotKeyID(signature: 0x54525A4F, id: 1)
        if RegisterEventHotKey(UInt32(kVK_ANSI_2), UInt32(cmdKey | shiftKey), id,
                               GetApplicationEventTarget(), 0, &hotKey) != noErr {
            hotKey = nil
        }
    }

    var registered: Bool { hotKey != nil }
    deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
    }
}
