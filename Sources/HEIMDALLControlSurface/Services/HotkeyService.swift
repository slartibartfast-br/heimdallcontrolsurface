// Sources/HEIMDALLControlSurface/Services/HotkeyService.swift
// HCS-008: Carbon API global hotkey registration

import AppKit
import Carbon.HIToolbox

/// Protocol for testability - MainActor isolated
@MainActor
public protocol HotkeyServiceProtocol: Sendable {
    func registerHotkeys()
    func unregisterAll()
    func setHandler(for action: HotkeyAction, handler: @escaping @Sendable () -> Void)
}

/// Global hotkey service using Carbon Event APIs
@MainActor
public final class HotkeyService: HotkeyServiceProtocol {
    private let preferences: HotkeyPreferences
    private var hotkeyRefs: [HotkeyAction: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?
    private var actionHandlers: [UInt32: @Sendable () -> Void] = [:]

    /// Shared instance for C callback access
    nonisolated(unsafe) fileprivate static var shared: HotkeyService?

    public init(preferences: HotkeyPreferences = HotkeyPreferences()) {
        self.preferences = preferences
        Self.shared = self
    }

    /// Check and request accessibility permission
    @discardableResult
    public func checkAccessibility() -> Bool {
        // Use string key directly to avoid concurrency issues with the global constant
        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options = [promptKey: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Register all configured hotkeys
    public func registerHotkeys() {
        guard checkAccessibility() else { return }
        installEventHandler()
        for (index, action) in HotkeyAction.allCases.enumerated() {
            registerHotkey(for: action, id: UInt32(index + 1))
        }
    }

    /// Unregister all hotkeys and cleanup
    public func unregisterAll() {
        for (_, ref) in hotkeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotkeyRefs.removeAll()
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }

    /// Set handler for specific action
    public func setHandler(for action: HotkeyAction, handler: @escaping @Sendable () -> Void) {
        let index = HotkeyAction.allCases.firstIndex(of: action)!
        actionHandlers[UInt32(index + 1)] = handler
    }

    // MARK: - Private

    private func installEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyCallback,
            1, &eventType, nil, &eventHandler
        )
    }

    private func registerHotkey(for action: HotkeyAction, id: UInt32) {
        let binding = preferences.binding(for: action)
        let hotkeyID = EventHotKeyID(signature: fourCharCode("HDAL"), id: id)
        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            binding.keyCode, binding.modifiers, hotkeyID,
            GetApplicationEventTarget(), 0, &hotKeyRef
        )
        if status == noErr, let ref = hotKeyRef {
            hotkeyRefs[action] = ref
        }
    }

    /// Dispatch hotkey event to appropriate handler
    fileprivate func handleHotkeyEvent(id: UInt32) {
        if let handler = actionHandlers[id] {
            handler()
        }
    }
}

// MARK: - C Callback

private func hotkeyCallback(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event else { return OSStatus(eventNotHandledErr) }
    var hotkeyID = EventHotKeyID()
    GetEventParameter(
        event, EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID), nil,
        MemoryLayout<EventHotKeyID>.size, nil, &hotkeyID
    )
    DispatchQueue.main.async {
        HotkeyService.shared?.handleHotkeyEvent(id: hotkeyID.id)
    }
    return noErr
}

/// Converts 4-char string to OSType
private func fourCharCode(_ string: String) -> OSType {
    var result: OSType = 0
    for char in string.utf8.prefix(4) {
        result = (result << 8) + OSType(char)
    }
    return result
}
