// Sources/HEIMDALLControlSurface/Services/HotkeyService.swift
// HCS-008: Carbon/CGEvent global hotkey registration

import Carbon.HIToolbox
import ApplicationServices

/// Protocol for hotkey service (enables mocking)
public protocol HotkeyServiceProtocol: AnyObject {
    var isAccessibilityEnabled: Bool { get }
    func registerHotkeys(actionHandler: @escaping (UInt32) -> Void)
    func unregisterHotkeys()
}

/// Global singleton for C callback access
/// Using nonisolated(unsafe) because this is accessed from C callback which is synchronized externally
nonisolated(unsafe) private var sharedActionHandler: ((UInt32) -> Void)?

/// Carbon-based global hotkey registration service
public final class HotkeyService: HotkeyServiceProtocol {
    private let preferences: HotkeyPreferences
    private var hotkeyRefs: [EventHotKeyRef] = []
    private var eventHandler: EventHandlerRef?

    public init(preferences: HotkeyPreferences = HotkeyPreferences()) {
        self.preferences = preferences
    }

    /// Check if accessibility permission is granted
    public var isAccessibilityEnabled: Bool {
        AXIsProcessTrusted()
    }

    /// Request accessibility permission with system prompt
    public func requestAccessibilityPermission() {
        // Use string constant directly to avoid concurrency issues with C global
        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options = [promptKey: kCFBooleanTrue!] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// Register all hotkeys from preferences
    public func registerHotkeys(actionHandler: @escaping (UInt32) -> Void) {
        // Store handler for C callback
        sharedActionHandler = actionHandler

        // Request accessibility if needed
        if !isAccessibilityEnabled {
            requestAccessibilityPermission()
        }

        // Install event handler
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyEventCallback,
            1, &eventType, nil, &eventHandler
        )
        guard status == noErr else { return }

        // Register each hotkey
        registerHotkeyBindings()
    }

    /// Register individual hotkey bindings
    private func registerHotkeyBindings() {
        for (index, binding) in preferences.bindings.enumerated() {
            let hotkeyID = EventHotKeyID(
                signature: fourCharCode("HDAL"),
                id: UInt32(index + 1)
            )
            var hotKeyRef: EventHotKeyRef?
            RegisterEventHotKey(
                binding.keyCode,
                binding.modifiers,
                hotkeyID,
                GetApplicationEventTarget(),
                0,
                &hotKeyRef
            )
            if let ref = hotKeyRef {
                hotkeyRefs.append(ref)
            }
        }
    }

    /// Unregister all hotkeys and cleanup
    public func unregisterHotkeys() {
        for ref in hotkeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotkeyRefs.removeAll()

        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
        sharedActionHandler = nil
    }
}

/// Convert 4-char string to OSType
private func fourCharCode(_ string: String) -> OSType {
    var result: OSType = 0
    for char in string.utf8.prefix(4) {
        result = (result << 8) + OSType(char)
    }
    return result
}

/// C callback for hotkey events
private func hotkeyEventCallback(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event = event else { return OSStatus(eventNotHandledErr) }

    var hotkeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotkeyID
    )
    guard status == noErr else { return status }

    DispatchQueue.main.async {
        sharedActionHandler?(hotkeyID.id)
    }
    return noErr
}
