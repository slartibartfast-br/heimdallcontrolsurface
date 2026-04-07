// Sources/HEIMDALLControlSurface/Services/SoundAlertService.swift
// HCS-007: Sound alert service for event notifications

import Foundation
import AppKit

// MARK: - Protocol

public protocol SoundAlertServiceProtocol: Sendable {
    func playSound(for eventType: EventType)
    func isSoundEnabled(for eventType: EventType) -> Bool
    func setSoundEnabled(_ enabled: Bool, for eventType: EventType)
    func soundName(for eventType: EventType) -> String
    func setSoundName(_ name: String, for eventType: EventType)
}

// MARK: - Implementation

public final class SoundAlertService: SoundAlertServiceProtocol, @unchecked Sendable {
    private let defaults: UserDefaults
    private let keyPrefix = "HCS.SoundAlert"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func playSound(for eventType: EventType) {
        guard isSoundEnabled(for: eventType) else { return }
        let name = soundName(for: eventType)
        NSSound(named: NSSound.Name(name))?.play()
    }

    public func isSoundEnabled(for eventType: EventType) -> Bool {
        let key = "\(keyPrefix).\(eventType.rawValue).enabled"
        // Default to true if not set
        return defaults.object(forKey: key) as? Bool ?? true
    }

    public func setSoundEnabled(_ enabled: Bool, for eventType: EventType) {
        let key = "\(keyPrefix).\(eventType.rawValue).enabled"
        defaults.set(enabled, forKey: key)
    }

    public func soundName(for eventType: EventType) -> String {
        let key = "\(keyPrefix).\(eventType.rawValue).sound"
        return defaults.string(forKey: key) ?? Self.defaultSounds[eventType] ?? "Pop"
    }

    public func setSoundName(_ name: String, for eventType: EventType) {
        let key = "\(keyPrefix).\(eventType.rawValue).sound"
        defaults.set(name, forKey: key)
    }
}

// MARK: - Default Sound Names

extension SoundAlertService {
    /// Default system sounds per event type
    static let defaultSounds: [EventType: String] = [
        .factoryUpdate: "Pop",
        .verdict: "Glass",
        .heartbeat: "Tink",
        .pipelineUpdate: "Pop",
        .agentStatus: "Ping",
        .escalation: "Sosumi"
    ]

    /// Available macOS system sounds
    static let availableSounds: [String] = [
        "Basso", "Blow", "Bottle", "Frog", "Funk",
        "Glass", "Hero", "Morse", "Ping", "Pop",
        "Purr", "Sosumi", "Submarine", "Tink"
    ]
}
