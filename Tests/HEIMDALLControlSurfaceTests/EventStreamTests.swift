// Tests/HEIMDALLControlSurfaceTests/EventStreamTests.swift
// HCS-007: Event stream view tests

import Testing
import Foundation
@testable import HEIMDALLControlSurface

// MARK: - Event Severity Tests

@Suite("Event Severity Tests")
struct EventSeverityTests {
    @Test func heartbeatSeverityIsInfo() async throws {
        let event = WebSocketEvent(type: .heartbeat, timestamp: Date(), payload: Data())
        #expect(event.severity == .info)
    }

    @Test func escalationSeverityIsCritical() async throws {
        let event = WebSocketEvent(type: .escalation, timestamp: Date(), payload: Data())
        #expect(event.severity == .critical)
    }

    @Test func factoryUpdateSeverityIsInfo() async throws {
        let event = WebSocketEvent(type: .factoryUpdate, timestamp: Date(), payload: Data())
        #expect(event.severity == .info)
    }

    @Test func severityAllCasesExist() async throws {
        let cases = EventSeverity.allCases
        #expect(cases.count == 4)
        #expect(cases.contains(.info))
        #expect(cases.contains(.warning))
        #expect(cases.contains(.error))
        #expect(cases.contains(.critical))
    }
}

// MARK: - Event Type CaseIterable Tests

@Suite("Event Type CaseIterable Tests")
struct EventTypeCaseIterableTests {
    @Test func eventTypeHasAllCases() async throws {
        let cases = EventType.allCases
        #expect(cases.count == 6)
        #expect(cases.contains(.factoryUpdate))
        #expect(cases.contains(.verdict))
        #expect(cases.contains(.heartbeat))
        #expect(cases.contains(.pipelineUpdate))
        #expect(cases.contains(.agentStatus))
        #expect(cases.contains(.escalation))
    }
}

// MARK: - Mock Sound Service

final class MockSoundAlertService: SoundAlertServiceProtocol, @unchecked Sendable {
    var playedSounds: [EventType] = []
    var enabledTypes: Set<EventType> = Set(EventType.allCases)
    var customSoundNames: [EventType: String] = [:]

    func playSound(for eventType: EventType) {
        if enabledTypes.contains(eventType) {
            playedSounds.append(eventType)
        }
    }

    func isSoundEnabled(for eventType: EventType) -> Bool {
        enabledTypes.contains(eventType)
    }

    func setSoundEnabled(_ enabled: Bool, for eventType: EventType) {
        if enabled {
            enabledTypes.insert(eventType)
        } else {
            enabledTypes.remove(eventType)
        }
    }

    func soundName(for eventType: EventType) -> String {
        customSoundNames[eventType] ?? "Pop"
    }

    func setSoundName(_ name: String, for eventType: EventType) {
        customSoundNames[eventType] = name
    }
}

// MARK: - Sound Alert Service Tests

@Suite("Sound Alert Service Tests")
struct SoundAlertServiceTests {
    @Test func soundEnabledByDefaultForAllTypes() async throws {
        let service = SoundAlertService(defaults: UserDefaults(suiteName: "test-\(UUID())")!)
        for eventType in EventType.allCases {
            #expect(service.isSoundEnabled(for: eventType) == true)
        }
    }

    @Test func disableSoundForEventType() async throws {
        let defaults = UserDefaults(suiteName: "test-\(UUID())")!
        let service = SoundAlertService(defaults: defaults)
        service.setSoundEnabled(false, for: .heartbeat)
        #expect(service.isSoundEnabled(for: .heartbeat) == false)
        #expect(service.isSoundEnabled(for: .verdict) == true)
    }

    @Test func customSoundNamePersists() async throws {
        let defaults = UserDefaults(suiteName: "test-\(UUID())")!
        let service = SoundAlertService(defaults: defaults)
        service.setSoundName("Basso", for: .escalation)
        #expect(service.soundName(for: .escalation) == "Basso")
    }

    @Test func defaultSoundNamesExist() async throws {
        #expect(SoundAlertService.defaultSounds.count == 6)
        #expect(SoundAlertService.defaultSounds[.escalation] == "Sosumi")
    }

    @Test func availableSoundsListNotEmpty() async throws {
        #expect(SoundAlertService.availableSounds.count > 0)
        #expect(SoundAlertService.availableSounds.contains("Pop"))
    }
}

// MARK: - AppState Event Stream Tests (HCS-007)

@Suite("AppState Event Stream Tests")
struct AppStateEventStreamTests {
    @Test @MainActor func handleEventAppendsToEventsList() async throws {
        let appState = AppState()
        let mockSound = MockSoundAlertService()
        let mockNotification = MockNotificationService()
        let mockAPI = MockAPIClient()
        appState.configure(notificationService: mockNotification, apiClient: mockAPI, soundService: mockSound)

        let event = WebSocketEvent(type: .heartbeat, timestamp: Date(), payload: Data())
        appState.handleEvent(event)

        #expect(appState.events.count == 1)
        #expect(appState.events.first?.type == .heartbeat)
    }

    @Test @MainActor func handleEventTriggersSoundAlert() async throws {
        let appState = AppState()
        let mockSound = MockSoundAlertService()
        let mockNotification = MockNotificationService()
        let mockAPI = MockAPIClient()
        appState.configure(notificationService: mockNotification, apiClient: mockAPI, soundService: mockSound)

        let event = WebSocketEvent(type: .verdict, timestamp: Date(), payload: Data())
        appState.handleEvent(event)

        #expect(mockSound.playedSounds.count == 1)
        #expect(mockSound.playedSounds.first == .verdict)
    }

    @Test @MainActor func eventsAreCappedAtMaximum() async throws {
        let appState = AppState()
        let mockSound = MockSoundAlertService()
        let mockNotification = MockNotificationService()
        let mockAPI = MockAPIClient()
        appState.configure(notificationService: mockNotification, apiClient: mockAPI, soundService: mockSound)

        // Add 600 events (more than 500 cap)
        for _ in 0..<600 {
            appState.handleEvent(WebSocketEvent(type: .heartbeat, timestamp: Date(), payload: Data()))
        }

        #expect(appState.events.count == 500)
    }

    @Test @MainActor func soundNotPlayedWhenDisabled() async throws {
        let appState = AppState()
        let mockSound = MockSoundAlertService()
        mockSound.setSoundEnabled(false, for: .heartbeat)
        let mockNotification = MockNotificationService()
        let mockAPI = MockAPIClient()
        appState.configure(notificationService: mockNotification, apiClient: mockAPI, soundService: mockSound)

        appState.handleEvent(WebSocketEvent(type: .heartbeat, timestamp: Date(), payload: Data()))

        #expect(mockSound.playedSounds.isEmpty)
    }
}

// MARK: - Project Code Extraction Tests

@Suite("Project Code Extraction Tests")
struct ProjectCodeExtractionTests {
    @Test func extractProjectCodeFromIssueId() async throws {
        #expect(WebSocketEvent.extractProjectCode(from: "AASF-123") == "AASF")
        #expect(WebSocketEvent.extractProjectCode(from: "HCS-007") == "HCS")
        #expect(WebSocketEvent.extractProjectCode(from: "DEMO-1") == "DEMO")
    }

    @Test func extractProjectCodeReturnsNilForInvalid() async throws {
        #expect(WebSocketEvent.extractProjectCode(from: "invalid") == nil)
        #expect(WebSocketEvent.extractProjectCode(from: "") == nil)
    }

    @Test func heartbeatHasNoProjectCode() async throws {
        let event = WebSocketEvent(type: .heartbeat, timestamp: Date(), payload: Data())
        #expect(event.projectCode == nil)
    }

    @Test func agentStatusHasNoProjectCode() async throws {
        let event = WebSocketEvent(type: .agentStatus, timestamp: Date(), payload: Data())
        #expect(event.projectCode == nil)
    }
}

// MARK: - Event Row Helper Tests

@Suite("Event Row Helper Tests")
struct EventRowHelperTests {
    @Test @MainActor func iconMappingCoversAllEventTypes() async throws {
        for eventType in EventType.allCases {
            let icon = EventRow.icon(for: eventType)
            #expect(!icon.isEmpty)
        }
    }

    @Test @MainActor func colorMappingCoversAllSeverities() async throws {
        for severity in EventSeverity.allCases {
            // Just verify it doesn't crash and returns something
            _ = EventRow.color(for: severity)
        }
    }

    @Test @MainActor func escalationIconIsWarningTriangle() async throws {
        let icon = EventRow.icon(for: .escalation)
        #expect(icon == "exclamationmark.triangle.fill")
    }
}
