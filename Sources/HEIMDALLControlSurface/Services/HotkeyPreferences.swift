// Sources/HEIMDALLControlSurface/Services/HotkeyPreferences.swift
// HCS-008: Configurable hotkey bindings with UserDefaults persistence

import Foundation
import Carbon.HIToolbox

/// Hotkey action identifiers
public enum HotkeyAction: String, Codable, CaseIterable, Sendable {
    case toggleDashboard
    case approveNext
    case rejectNext
}

/// A single hotkey binding configuration
public struct HotkeyBinding: Codable, Equatable, Sendable {
    public let keyCode: UInt32
    public let modifiers: UInt32
    public let action: HotkeyAction

    public init(keyCode: UInt32, modifiers: UInt32, action: HotkeyAction) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.action = action
    }
}

/// Manages hotkey bindings with UserDefaults persistence
public final class HotkeyPreferences: @unchecked Sendable {
    private static let storageKey = "HCS.hotkeyBindings"

    /// Control + Option + Command modifier mask
    public static let defaultModifiers: UInt32 = UInt32(controlKey | optionKey | cmdKey)

    /// Default hotkey bindings
    public static let defaults: [HotkeyBinding] = [
        HotkeyBinding(keyCode: 0x04, modifiers: defaultModifiers, action: .toggleDashboard), // H
        HotkeyBinding(keyCode: 0x00, modifiers: defaultModifiers, action: .approveNext),     // A
        HotkeyBinding(keyCode: 0x0F, modifiers: defaultModifiers, action: .rejectNext)       // R
    ]

    /// Current bindings
    public private(set) var bindings: [HotkeyBinding]

    public init() {
        self.bindings = Self.defaults
        load()
    }

    /// Get binding for a specific action
    public func binding(for action: HotkeyAction) -> HotkeyBinding? {
        bindings.first { $0.action == action }
    }

    /// Update binding for an action
    public func setBinding(_ binding: HotkeyBinding, for action: HotkeyAction) {
        bindings.removeAll { $0.action == action }
        bindings.append(binding)
        save()
    }

    /// Reset all bindings to defaults
    public func resetToDefaults() {
        bindings = Self.defaults
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }

    /// Save bindings to UserDefaults
    public func save() {
        if let data = try? JSONEncoder().encode(bindings) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    /// Load bindings from UserDefaults
    public func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let loaded = try? JSONDecoder().decode([HotkeyBinding].self, from: data) else {
            return
        }
        bindings = loaded
    }
}
