// Tests/HEIMDALLControlSurfaceTests/EventStreamTests.swift
// HCS-007: Unit tests for event filtering logic and sound configuration

import Testing
import Foundation
@testable import HEIMDALLControlSurface

// MARK: - Mock Sound Service

final class MockSoundAlertService: SoundAlertServiceProtocol, @unchecked Sendable {
    var playedSounds: [EventType] = []
    var enabledTypes: Set<EventType> = [.verdict, .escalation]
    var soundNames: [EventType: String] = [:]

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
        soundNames[eventType] ?? SoundAlertService.defaultSounds[eventType] ?? ""
    }

    func setSoundName(_ name: String, for eventType: EventType) {
        soundNames[eventType] = name
    }
}

// MARK: - Test Helpers

func createTestEvent(
    type: EventType,
    issueId: String = "TEST-123",
    outcome: VerdictOutcome = .pass
) -> WebSocketEvent {
    let payload: Data
    switch type {
    case .verdict, .escalation:
        let verdict = VerdictEntry(
            timestamp: Date(),
            issueId: issueId,
            gate: "review",
            outcome: outcome,
            reason: "Test reason",
            agent: "test-agent"
        )
        let verdictPayload = VerdictPayload(verdict: verdict)
        payload = (try? JSONEncoder().encode(verdictPayload)) ?? Data()
    default:
        payload = Data()
    }
    return WebSocketEvent(type: type, timestamp: Date(), payload: payload)
}

// MARK: - Event Severity Tests

@Suite("Event Severity Tests")
struct EventSeverityTests {
    @Test func heartbeatSeverityIsInfo() async throws {
        let event = createTestEvent(type: .heartbeat)
        #expect(event.severity == .info)
    }

    @Test func verdictPassSeverityIsInfo() async throws {
        let event = createTestEvent(type: .verdict, outcome: .pass)
        #expect(event.severity == .info)
    }

    @Test func verdictFailSeverityIsWarning() async throws {
        let event = createTestEvent(type: .verdict, outcome: .fail)
        #expect(event.severity == .warning)
    }

    @Test func verdictEscalateSeverityIsCritical() async throws {
        let event = createTestEvent(type: .verdict, outcome: .escalate)
        #expect(event.severity == .critical)
    }

    @Test func escalationSeverityIsCritical() async throws {
        let event = createTestEvent(type: .escalation)
        #expect(event.severity == .critical)
    }
}

// MARK: - Project Code Extraction Tests

@Suite("Project Code Extraction Tests")
struct ProjectCodeExtractionTests {
    @Test func extractsProjectCodeFromVerdictEvent() async throws {
        let event = createTestEvent(type: .verdict, issueId: "AASF-123")
        #expect(event.projectCode == "AASF")
    }

    @Test func extractsProjectCodeFromEscalationEvent() async throws {
        let event = createTestEvent(type: .escalation, issueId: "HCS-456")
        #expect(event.projectCode == "HCS")
    }

    @Test func heartbeatHasNoProjectCode() async throws {
        let event = createTestEvent(type: .heartbeat)
        #expect(event.projectCode == nil)
    }

    @Test func factoryUpdateHasNoProjectCode() async throws {
        let event = createTestEvent(type: .factoryUpdate)
        #expect(event.projectCode == nil)
    }
}

// MARK: - Event Filtering Tests

@Suite("Event Filtering Tests")
struct EventFilteringTests {
    @Test @MainActor func filtersEventsByType() async throws {
        let mockSound = MockSoundAlertService()
        let viewModel = EventStreamViewModel(soundService: mockSound)

        viewModel.addEvent(createTestEvent(type: .verdict))
        viewModel.addEvent(createTestEvent(type: .heartbeat))
        viewModel.addEvent(createTestEvent(type: .escalation))

        var filterState = EventFilterState()
        filterState.selectedEventTypes = [.verdict]

        let filtered = viewModel.filteredEvents(with: filterState)
        #expect(filtered.count == 1)
        #expect(filtered.first?.type == .verdict)
    }

    @Test @MainActor func filtersEventsByProject() async throws {
        let mockSound = MockSoundAlertService()
        let viewModel = EventStreamViewModel(soundService: mockSound)

        viewModel.addEvent(createTestEvent(type: .verdict, issueId: "AASF-100"))
        viewModel.addEvent(createTestEvent(type: .verdict, issueId: "HCS-200"))
        viewModel.addEvent(createTestEvent(type: .verdict, issueId: "AASF-300"))

        var filterState = EventFilterState()
        filterState.selectedProjectCode = "AASF"

        let filtered = viewModel.filteredEvents(with: filterState)
        #expect(filtered.count == 2)
        #expect(filtered.allSatisfy { $0.projectCode == "AASF" })
    }

    @Test @MainActor func filtersEventsBySeverity() async throws {
        let mockSound = MockSoundAlertService()
        let viewModel = EventStreamViewModel(soundService: mockSound)

        viewModel.addEvent(createTestEvent(type: .verdict, outcome: .pass))
        viewModel.addEvent(createTestEvent(type: .verdict, outcome: .fail))
        viewModel.addEvent(createTestEvent(type: .verdict, outcome: .escalate))

        var filterState = EventFilterState()
        filterState.selectedSeverities = [.critical]

        let filtered = viewModel.filteredEvents(with: filterState)
        #expect(filtered.count == 1)
        #expect(filtered.first?.severity == .critical)
    }

    @Test @MainActor func combinesMultipleFilters() async throws {
        let mockSound = MockSoundAlertService()
        let viewModel = EventStreamViewModel(soundService: mockSound)

        viewModel.addEvent(createTestEvent(type: .verdict, issueId: "AASF-100", outcome: .pass))
        viewModel.addEvent(createTestEvent(type: .verdict, issueId: "AASF-200", outcome: .escalate))
        viewModel.addEvent(createTestEvent(type: .verdict, issueId: "HCS-300", outcome: .escalate))
        viewModel.addEvent(createTestEvent(type: .escalation, issueId: "AASF-400"))

        var filterState = EventFilterState()
        filterState.selectedProjectCode = "AASF"
        filterState.selectedSeverities = [.critical]
        filterState.selectedEventTypes = [.verdict]

        let filtered = viewModel.filteredEvents(with: filterState)
        #expect(filtered.count == 1)
        #expect(filtered.first?.projectCode == "AASF")
        #expect(filtered.first?.severity == .critical)
        #expect(filtered.first?.type == .verdict)
    }

    @Test @MainActor func nilProjectFilterShowsAllProjects() async throws {
        let mockSound = MockSoundAlertService()
        let viewModel = EventStreamViewModel(soundService: mockSound)

        viewModel.addEvent(createTestEvent(type: .verdict, issueId: "AASF-100"))
        viewModel.addEvent(createTestEvent(type: .verdict, issueId: "HCS-200"))
        viewModel.addEvent(createTestEvent(type: .verdict, issueId: "TEST-300"))

        var filterState = EventFilterState()
        filterState.selectedProjectCode = nil  // All projects

        let filtered = viewModel.filteredEvents(with: filterState)
        #expect(filtered.count == 3)
    }
}

// MARK: - Sound Alert Tests

@Suite("Sound Alert Tests")
struct SoundAlertTests {
    @Test func defaultSoundsConfigured() async throws {
        let service = SoundAlertService()
        #expect(service.soundName(for: .verdict) == "Glass")
        #expect(service.soundName(for: .escalation) == "Sosumi")
    }

    @Test func escalationAndVerdictEnabledByDefault() async throws {
        let testDefaults = UserDefaults(suiteName: "HCS007SoundTest")!
        testDefaults.removePersistentDomain(forName: "HCS007SoundTest")

        let service = SoundAlertService(defaults: testDefaults)
        #expect(service.isSoundEnabled(for: .escalation) == true)
        #expect(service.isSoundEnabled(for: .verdict) == true)
        #expect(service.isSoundEnabled(for: .heartbeat) == false)

        testDefaults.removePersistentDomain(forName: "HCS007SoundTest")
    }

    @Test func canDisableSoundForEventType() async throws {
        let testDefaults = UserDefaults(suiteName: "HCS007SoundDisableTest")!
        testDefaults.removePersistentDomain(forName: "HCS007SoundDisableTest")

        let service = SoundAlertService(defaults: testDefaults)
        service.setSoundEnabled(false, for: .verdict)
        #expect(service.isSoundEnabled(for: .verdict) == false)

        testDefaults.removePersistentDomain(forName: "HCS007SoundDisableTest")
    }

    @Test func canSetCustomSoundName() async throws {
        let testDefaults = UserDefaults(suiteName: "HCS007CustomSoundTest")!
        testDefaults.removePersistentDomain(forName: "HCS007CustomSoundTest")

        let service = SoundAlertService(defaults: testDefaults)
        service.setSoundName("Hero", for: .verdict)
        #expect(service.soundName(for: .verdict) == "Hero")

        testDefaults.removePersistentDomain(forName: "HCS007CustomSoundTest")
    }

    @Test @MainActor func viewModelPlaysSoundOnNewEvent() async throws {
        let mockSound = MockSoundAlertService()
        let viewModel = EventStreamViewModel(soundService: mockSound)

        viewModel.addEvent(createTestEvent(type: .verdict))

        #expect(mockSound.playedSounds.contains(.verdict))
    }

    @Test @MainActor func viewModelDoesNotPlayDisabledSound() async throws {
        let mockSound = MockSoundAlertService()
        mockSound.enabledTypes = []  // Disable all sounds
        let viewModel = EventStreamViewModel(soundService: mockSound)

        viewModel.addEvent(createTestEvent(type: .verdict))

        #expect(mockSound.playedSounds.isEmpty)
    }
}

// MARK: - Event Stream View Model Tests

@Suite("Event Stream View Model Tests")
struct EventStreamViewModelTests {
    @Test @MainActor func addsEventsToStream() async throws {
        let mockSound = MockSoundAlertService()
        let viewModel = EventStreamViewModel(soundService: mockSound)

        viewModel.addEvent(createTestEvent(type: .verdict))
        viewModel.addEvent(createTestEvent(type: .escalation))

        #expect(viewModel.events.count == 2)
    }

    @Test @MainActor func clearsAllEvents() async throws {
        let mockSound = MockSoundAlertService()
        let viewModel = EventStreamViewModel(soundService: mockSound)

        viewModel.addEvent(createTestEvent(type: .verdict))
        viewModel.addEvent(createTestEvent(type: .escalation))
        viewModel.clearEvents()

        #expect(viewModel.events.isEmpty)
    }

    @Test @MainActor func trimEventsWhenExceedingMax() async throws {
        let mockSound = MockSoundAlertService()
        let viewModel = EventStreamViewModel(soundService: mockSound, maxEvents: 5)

        for _ in 0..<10 {
            viewModel.addEvent(createTestEvent(type: .heartbeat))
        }

        #expect(viewModel.events.count == 5)
    }

    @Test @MainActor func extractsAvailableProjectsFromEvents() async throws {
        let mockSound = MockSoundAlertService()
        let viewModel = EventStreamViewModel(soundService: mockSound)

        viewModel.addEvent(createTestEvent(type: .verdict, issueId: "AASF-100"))
        viewModel.addEvent(createTestEvent(type: .verdict, issueId: "HCS-200"))
        viewModel.addEvent(createTestEvent(type: .verdict, issueId: "AASF-300"))

        #expect(viewModel.availableProjects.contains("AASF"))
        #expect(viewModel.availableProjects.contains("HCS"))
        #expect(viewModel.availableProjects.count == 2)
    }
}

// MARK: - EventFilterState Tests

@Suite("EventFilterState Tests")
struct EventFilterStateTests {
    @Test func defaultStateIncludesAllEventTypes() async throws {
        let state = EventFilterState()
        for eventType in EventType.allCases {
            #expect(state.selectedEventTypes.contains(eventType))
        }
    }

    @Test func defaultStateIncludesAllSeverities() async throws {
        let state = EventFilterState()
        for severity in EventSeverity.allCases {
            #expect(state.selectedSeverities.contains(severity))
        }
    }

    @Test func defaultProjectFilterIsNil() async throws {
        let state = EventFilterState()
        #expect(state.selectedProjectCode == nil)
    }
}
