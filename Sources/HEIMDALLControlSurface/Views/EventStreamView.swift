// Sources/HEIMDALLControlSurface/Views/EventStreamView.swift
// HCS-007: Real-time event stream view with filtering and auto-scroll
// Observes AppState.events which are populated by ConnectionManager via WebSocket

import SwiftUI

// MARK: - Event Stream View

struct EventStreamView: View {
    @Environment(AppState.self) private var appState

    // Filter state
    @State private var selectedTypes: Set<EventType> = Set(EventType.allCases)
    @State private var selectedProject: String? = nil
    @State private var selectedSeverity: EventSeverity? = nil
    @State private var isPaused: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            EventFilterBar(
                selectedTypes: $selectedTypes,
                selectedProject: $selectedProject,
                selectedSeverity: $selectedSeverity,
                availableProjects: availableProjects
            )
            Divider()
            eventListContent
        }
        .navigationTitle("Event Stream")
    }

    /// Unique project codes extracted from events
    private var availableProjects: [String] {
        let codes = appState.events.compactMap(\.projectCode)
        return Array(Set(codes)).sorted()
    }

    private var filteredEvents: [WebSocketEvent] {
        appState.events.filter { event in
            selectedTypes.contains(event.type) &&
            (selectedSeverity == nil || event.severity == selectedSeverity) &&
            matchesProjectFilter(event)
        }
    }

    private func matchesProjectFilter(_ event: WebSocketEvent) -> Bool {
        guard let selectedProject else { return true }
        return event.projectCode == selectedProject
    }

    private var eventListContent: some View {
        ScrollViewReader { proxy in
            List(filteredEvents) { event in
                EventRow(event: event)
            }
            .onHover { hovering in
                isPaused = hovering
            }
            .onChange(of: appState.events.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard !isPaused, let lastEvent = filteredEvents.last else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(lastEvent.id, anchor: .bottom)
        }
    }
}

#Preview {
    EventStreamView()
        .environment(AppState())
}
