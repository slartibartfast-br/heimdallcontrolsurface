// Sources/HEIMDALLControlSurface/Views/EventFilterBar.swift
// HCS-007: Event filter bar component

import SwiftUI

struct EventFilterBar: View {
    @Binding var selectedTypes: Set<EventType>
    @Binding var selectedProject: String?
    @Binding var selectedSeverity: EventSeverity?
    let availableProjects: [String]

    var body: some View {
        HStack(spacing: 12) {
            eventTypeMenu
            projectPicker
            severityPicker
            Spacer()
            clearFiltersButton
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var projectPicker: some View {
        Picker("Project", selection: $selectedProject) {
            Text("All Projects").tag(nil as String?)
            ForEach(availableProjects, id: \.self) { project in
                Text(project).tag(project as String?)
            }
        }
        .pickerStyle(.menu)
    }

    private var eventTypeMenu: some View {
        Menu {
            ForEach(EventType.allCases, id: \.self) { type in
                Button {
                    toggleType(type)
                } label: {
                    HStack {
                        Text(type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                        if selectedTypes.contains(type) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Label("Types (\(selectedTypes.count))", systemImage: "line.3.horizontal.decrease.circle")
        }
    }

    private var severityPicker: some View {
        Picker("Severity", selection: $selectedSeverity) {
            Text("All Severities").tag(nil as EventSeverity?)
            ForEach(EventSeverity.allCases, id: \.self) { severity in
                Text(severity.rawValue.capitalized).tag(severity as EventSeverity?)
            }
        }
        .pickerStyle(.menu)
    }

    private var clearFiltersButton: some View {
        Button("Clear") {
            selectedTypes = Set(EventType.allCases)
            selectedProject = nil
            selectedSeverity = nil
        }
        .disabled(isFiltersDefault)
    }

    private var isFiltersDefault: Bool {
        selectedTypes.count == EventType.allCases.count &&
        selectedProject == nil &&
        selectedSeverity == nil
    }

    private func toggleType(_ type: EventType) {
        if selectedTypes.contains(type) {
            selectedTypes.remove(type)
        } else {
            selectedTypes.insert(type)
        }
    }
}

#Preview {
    EventFilterBar(
        selectedTypes: .constant(Set(EventType.allCases)),
        selectedProject: .constant(nil),
        selectedSeverity: .constant(nil),
        availableProjects: ["AASF", "HCS", "DEMO"]
    )
}
