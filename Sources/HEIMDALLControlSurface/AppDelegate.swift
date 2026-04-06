// Sources/HEIMDALLControlSurface/AppDelegate.swift
// HCS-002: Lifecycle and global hotkey setup

import AppKit
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Hotkey reference for cleanup
    private var hotkeyRef: EventHotKeyRef?
    /// Event handler reference
    private var eventHandler: EventHandlerRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon for menu bar app
        NSApp.setActivationPolicy(.accessory)
        // Set up global hotkey (Cmd+Shift+H)
        setupGlobalHotkey()
    }

    func applicationWillTerminate(_ notification: Notification) {
        cleanupHotkey()
    }

    /// Registers Cmd+Shift+H as global hotkey to show dashboard
    private func setupGlobalHotkey() {
        let hotkeyID = EventHotKeyID(signature: fourCharCode("HDAL"), id: 1)
        let modifiers: UInt32 = UInt32(cmdKey | shiftKey)
        let keyCode: UInt32 = 0x04 // 'H' key

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                       eventKind: UInt32(kEventHotKeyPressed))

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyHandler,
            1, &eventType, nil, &eventHandler
        )
        guard status == noErr else { return }

        var hotKeyRef: EventHotKeyRef?
        RegisterEventHotKey(keyCode, modifiers, hotkeyID,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
        self.hotkeyRef = hotKeyRef
    }

    private func cleanupHotkey() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
    }
}

/// Converts 4-char string to OSType
private func fourCharCode(_ string: String) -> OSType {
    var result: OSType = 0
    for char in string.utf8.prefix(4) {
        result = (result << 8) + OSType(char)
    }
    return result
}

/// C callback for hotkey events - posts notification on main thread
private func hotkeyHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    DispatchQueue.main.async {
        NotificationCenter.default.post(name: .openDashboard, object: nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    return noErr
}

extension Notification.Name {
    static let openDashboard = Notification.Name("openDashboard")
}
