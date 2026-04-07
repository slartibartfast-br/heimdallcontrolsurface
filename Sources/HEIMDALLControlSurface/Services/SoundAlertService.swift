// Sources/HEIMDALLControlSurface/Services/SoundAlertService.swift
// HCS-007: Configurable sound alerts per event type

import AppKit
import Foundation

/// Protocol for sound alert service (enables mocking)
public protocol SoundAlertServiceProtocol: Sendable {
    func playSound(for eventType: EventType)
    func isSoundEnabled(for eventType: EventType) -> Bool
    func setSoundEnabled(_ enabled: Bool, for eventType: EventType)
    func soundName(for eventType: EventType) -> String
    func setSoundName(_ name: String, for eventType: EventType)
}

/// System sound-based alert service with per-event-type configuration
public final class SoundAlertService: SoundAlertServiceProtocol, @unchecked Sendable {
    private let defaults: UserDefaults
    private let enabledKeyPrefix = "com.heimdall.hcs.sound.enabled."
    private let soundNameKeyPrefix = "com.heimdall.hcs.sound.name."

    /// Default sound names per event type
    public static let defaultSounds: [EventType: String] = [
        .verdict: "Glass",
        .escalation: "Sosumi",
        .pipelineUpdate: "Pop",
        .factoryUpdate: "Morse",
        .agentStatus: "Tink",
        .heartbeat: ""  // No sound for heartbeat by default
    ]

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Play sound for event type if enabled
    public func playSound(for eventType: EventType) {
        guard isSoundEnabled(for: eventType) else { return }
        let name = soundName(for: eventType)
        guard !name.isEmpty else { return }
        NSSound(named: NSSound.Name(name))?.play()
    }

    /// Check if sound is enabled for event type
    public func isSoundEnabled(for eventType: EventType) -> Bool {
        let key = enabledKeyPrefix + eventType.rawValue
        // Default to enabled for escalation/verdict, disabled for others
        if defaults.object(forKey: key) == nil {
            return eventType == .escalation || eventType == .verdict
        }
        return defaults.bool(forKey: key)
    }

    /// Enable/disable sound for event type
    public func setSoundEnabled(_ enabled: Bool, for eventType: EventType) {
        let key = enabledKeyPrefix + eventType.rawValue
        defaults.set(enabled, forKey: key)
    }

    /// Get configured sound name for event type
    public func soundName(for eventType: EventType) -> String {
        let key = soundNameKeyPrefix + eventType.rawValue
        if let name = defaults.string(forKey: key) {
            return name
        }
        return Self.defaultSounds[eventType] ?? ""
    }

    /// Set sound name for event type
    public func setSoundName(_ name: String, for eventType: EventType) {
        let key = soundNameKeyPrefix + eventType.rawValue
        defaults.set(name, forKey: key)
    }
}
