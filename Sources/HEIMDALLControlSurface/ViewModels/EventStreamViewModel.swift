// Sources/HEIMDALLControlSurface/ViewModels/EventStreamViewModel.swift
// HCS-007: Observable state for event stream with filtering logic

import SwiftUI

/// View model for event stream with filtering support
@MainActor
@Observable
public final class EventStreamViewModel: @unchecked Sendable {
    /// All received events (limited to maxEvents)
    public private(set) var events: [WebSocketEvent] = []

    /// Available project codes for filtering (extracted from events)
    public private(set) var availableProjects: [String] = []

    /// Connection status
    public var isConnected: Bool = false

    /// Sound alert service
    private let soundService: any SoundAlertServiceProtocol

    /// Maximum events to retain
    private let maxEvents: Int

    public init(
        soundService: any SoundAlertServiceProtocol = SoundAlertService(),
        maxEvents: Int = 1000
    ) {
        self.soundService = soundService
        self.maxEvents = maxEvents
    }

    /// Add new event to stream
    public func addEvent(_ event: WebSocketEvent) {
        events.append(event)
        trimEventsIfNeeded()
        updateAvailableProjects(from: event)
        soundService.playSound(for: event.type)
    }

    /// Filter events based on current filter state
    public func filteredEvents(with filterState: EventFilterState) -> [WebSocketEvent] {
        events.filter { event in
            matchesFilters(event: event, filterState: filterState)
        }
    }

    /// Clear all events
    public func clearEvents() {
        events.removeAll()
        availableProjects.removeAll()
    }

    // MARK: - Private Helpers

    private func matchesFilters(event: WebSocketEvent, filterState: EventFilterState) -> Bool {
        // Filter by event type
        guard filterState.selectedEventTypes.contains(event.type) else {
            return false
        }

        // Filter by project (CRITICAL - required by acceptance criteria)
        if let selectedProject = filterState.selectedProjectCode {
            guard event.projectCode == selectedProject else {
                return false
            }
        }

        // Filter by severity
        guard filterState.selectedSeverities.contains(event.severity) else {
            return false
        }

        return true
    }

    private func trimEventsIfNeeded() {
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
    }

    private func updateAvailableProjects(from event: WebSocketEvent) {
        updateFromFactoryUpdate(event)
        updateFromEventProjectCode(event)
    }

    private func updateFromFactoryUpdate(_ event: WebSocketEvent) {
        guard event.type == .factoryUpdate else { return }
        guard let payload = try? event.factoryUpdatePayload() else { return }
        let newProjects = payload.pipelines.compactMap { extractProjectCode(from: $0.issueId) }
        let combined = Set(availableProjects).union(Set(newProjects))
        availableProjects = combined.sorted()
    }

    private func updateFromEventProjectCode(_ event: WebSocketEvent) {
        guard let projectCode = event.projectCode,
              !availableProjects.contains(projectCode) else { return }
        availableProjects.append(projectCode)
        availableProjects.sort()
    }

    private func extractProjectCode(from issueId: String) -> String? {
        guard let dashIndex = issueId.firstIndex(of: "-") else { return nil }
        return String(issueId[..<dashIndex])
    }
}
