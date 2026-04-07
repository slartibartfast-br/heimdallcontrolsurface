// Sources/HEIMDALLControlSurface/Views/EventFilterBar.swift
// HCS-007: Filter controls for event type, project, severity

import SwiftUI

/// Filter state for event stream
public struct EventFilterState: Equatable, Sendable {
    public var selectedEventTypes: Set<EventType> = Set(EventType.allCases)
    public var selectedProjectCode: String? = nil  // nil = all projects
    public var selectedSeverities: Set<EventSeverity> = Set(EventSeverity.allCases)

    public init() {}
}

/// Make EventType conform to CaseIterable for filter UI
extension EventType: CaseIterable {
    public static var allCases: [EventType] {
        [.factoryUpdate, .verdict, .heartbeat, .pipelineUpdate, .agentStatus, .escalation]
    }
}

/// Filter bar view for event stream
struct EventFilterBar: View {
    @Binding var filterState: EventFilterState
    let availableProjects: [String]

    var body: some View {
        HStack(spacing: 12) {
            eventTypeMenu
            projectPicker
            severityMenu
            Spacer()
            clearButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var eventTypeMenu: some View {
        Menu("Type") {
            ForEach(EventType.allCases, id: \.rawValue) { eventType in
                Toggle(eventType.displayName, isOn: eventTypeBinding(for: eventType))
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var projectPicker: some View {
        Picker("Project", selection: $filterState.selectedProjectCode) {
            Text("All Projects").tag(nil as String?)
            Divider()
            ForEach(availableProjects, id: \.self) { project in
                Text(project).tag(project as String?)
            }
        }
        .pickerStyle(.menu)
        .fixedSize()
    }

    private var severityMenu: some View {
        Menu("Severity") {
            ForEach(EventSeverity.allCases, id: \.rawValue) { severity in
                Toggle(severity.displayName, isOn: severityBinding(for: severity))
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var clearButton: some View {
        Button("Clear") {
            filterState = EventFilterState()
        }
        .buttonStyle(.borderless)
    }

    private func eventTypeBinding(for eventType: EventType) -> Binding<Bool> {
        Binding(
            get: { filterState.selectedEventTypes.contains(eventType) },
            set: { isSelected in
                if isSelected {
                    filterState.selectedEventTypes.insert(eventType)
                } else {
                    filterState.selectedEventTypes.remove(eventType)
                }
            }
        )
    }

    private func severityBinding(for severity: EventSeverity) -> Binding<Bool> {
        Binding(
            get: { filterState.selectedSeverities.contains(severity) },
            set: { isSelected in
                if isSelected {
                    filterState.selectedSeverities.insert(severity)
                } else {
                    filterState.selectedSeverities.remove(severity)
                }
            }
        )
    }
}

// MARK: - Display Names

extension EventType {
    var displayName: String {
        switch self {
        case .factoryUpdate: return "Factory Update"
        case .verdict: return "Verdict"
        case .heartbeat: return "Heartbeat"
        case .pipelineUpdate: return "Pipeline Update"
        case .agentStatus: return "Agent Status"
        case .escalation: return "Escalation"
        }
    }
}

extension EventSeverity {
    var displayName: String {
        rawValue.capitalized
    }
}
