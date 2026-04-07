// Sources/HEIMDALLControlSurface/Services/HotkeyPreferences.swift
// HCS-008: UserDefaults-backed hotkey configuration

import Foundation
import Carbon.HIToolbox

/// Hotkey action identifiers
public enum HotkeyAction: String, CaseIterable, Sendable {
    case toggleDashboard = "toggleDashboard"
    case approveNext = "approveNext"
    case rejectNext = "rejectNext"
}

/// Stored key binding configuration
public struct HotkeyBinding: Codable, Sendable, Equatable {
    public let keyCode: UInt32
    public let modifiers: UInt32  // Carbon modifier flags

    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

/// UserDefaults-backed preferences for hotkey bindings
public final class HotkeyPreferences: @unchecked Sendable {
    private let defaults: UserDefaults
    private let keyPrefix = "com.heimdall.hcs.hotkey."

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Get binding for action (returns default if not set)
    public func binding(for action: HotkeyAction) -> HotkeyBinding {
        let key = keyPrefix + action.rawValue
        if let data = defaults.data(forKey: key),
           let binding = try? JSONDecoder().decode(HotkeyBinding.self, from: data) {
            return binding
        }
        return Self.defaultBindings[action]!
    }

    /// Set custom binding for action
    public func setBinding(_ binding: HotkeyBinding, for action: HotkeyAction) {
        let key = keyPrefix + action.rawValue
        if let data = try? JSONEncoder().encode(binding) {
            defaults.set(data, forKey: key)
        }
    }

    /// Reset action to default binding
    public func resetToDefault(for action: HotkeyAction) {
        let key = keyPrefix + action.rawValue
        defaults.removeObject(forKey: key)
    }

    /// Default hotkey bindings (Control+Option+Command + key)
    public static let defaultBindings: [HotkeyAction: HotkeyBinding] = [
        .toggleDashboard: HotkeyBinding(keyCode: 0x04, modifiers: UInt32(controlKey | optionKey | cmdKey)),  // H
        .approveNext: HotkeyBinding(keyCode: 0x00, modifiers: UInt32(controlKey | optionKey | cmdKey)),      // A
        .rejectNext: HotkeyBinding(keyCode: 0x0F, modifiers: UInt32(controlKey | optionKey | cmdKey))        // R
    ]
}
