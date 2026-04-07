# PLAN: HCS-007 — Event Stream View

## Preflight Checklist

### 1. git status
```
On branch feat/HCS-007
nothing to commit, working tree clean
```

### 2. git branch
```
  feat/AASF-647
* feat/HCS-007
+ main
```

### 3. ls data/queue/
```
ls: /Users/maurizio/development/heimdall/hcs/.worktrees/aasf-673/data/queue/: No such file or directory
```
(No queue directory — this is a Swift project, no stale envelopes)

### 4. Mandatory Rules from CLAUDE.md
1. Functions < 50 lines
2. Read signatures before calling
3. String matching: \b word boundaries only
4. Max 5 files per refactor commit
5. One branch at a time
6. Squash merge to main
7. Every commit: (HCS-NNN)
8. swift test must pass before merge

---

## Scope

| # | File | Action | Purpose |
|---|------|--------|---------|
| 1 | `Sources/HEIMDALLControlSurface/Models/Event.swift` | MODIFY | Add EventSeverity enum and severity computed property to WebSocketEvent |
| 2 | `Sources/HEIMDALLControlSurface/Services/SoundAlertService.swift` | CREATE | Configurable sound alerts per event type using system sounds |
| 3 | `Sources/HEIMDALLControlSurface/Views/EventFilterBar.swift` | CREATE | Filter controls for event type, project, severity |
| 4 | `Sources/HEIMDALLControlSurface/Views/EventRow.swift` | CREATE | Formatted event row with timestamp, icon, details |
| 5 | `Sources/HEIMDALLControlSurface/Views/EventStreamView.swift` | CREATE | Scrolling list of live events with auto-scroll and pause-on-hover |
| 6 | `Sources/HEIMDALLControlSurface/ViewModels/EventStreamViewModel.swift` | CREATE | Observable state for event stream with filtering logic |
| 7 | `Sources/HEIMDALLControlSurface/AppState.swift` | MODIFY | Add events array and project list for filtering |
| 8 | `Tests/HEIMDALLControlSurfaceTests/EventStreamTests.swift` | CREATE | Unit tests for event filtering logic and sound configuration |

---

## Prior Attempt Analysis

**CRITICAL FAILURES FROM PRIOR ATTEMPTS:**
1. **Attempt 2 rejection:** "project filtering is explicitly required by acceptance criteria but completely absent"
2. **Attempt 3 rejection:** "Critical scope violation: project filtering completely absent"

**RESOLUTION:** This plan explicitly includes project filtering at multiple levels:
- `EventFilterState.selectedProjectCode` filter property (line-level)
- `EventStreamViewModel.filteredEvents` computed property with project matching
- `EventFilterBar` UI with project picker dropdown
- `AppState.projects` array populated from WebSocket events
- Test cases specifically verifying project filtering behavior

---

## Data Path Trace

### Event Ingestion Flow
```
ConnectionManager.consumeWebSocketEvents() (line 111-116)
    ↓
AppState.handleEvent(_:) (line 158-167)
    ↓
EventStreamViewModel.addEvent(_:) [NEW]
    ↓
SoundAlertService.playSound(for:) [NEW] — if sound enabled for event type
```

### Event Filtering Flow
```
EventStreamViewModel.events [array of WebSocketEvent]
    ↓
EventStreamViewModel.filteredEvents [computed property, NEW]
    applies: filterState.selectedEventTypes
    applies: filterState.selectedProjectCode (CRITICAL - must not omit)
    applies: filterState.selectedSeverities
    ↓
EventStreamView.body → List(filteredEvents)
```

### Auto-Scroll with Pause-on-Hover Flow
```
EventStreamView.body
    ↓
ScrollViewReader { proxy in List(...) }
    ↓
.onChange(of: viewModel.filteredEvents.count) → scrollTo(last.id)
    ↓
.onHover { hovering in isPaused = hovering } — pauses auto-scroll
```

### Sound Alert Flow
```
EventStreamViewModel.addEvent(_:)
    ↓
soundService.playSound(for: event.type)
    ↓
SoundAlertService.playSound(for:) → isSoundEnabled(for:) check
    ↓
NSSound(named: NSSound.Name(soundName))?.play()
```

### Project List Population Flow
```
WebSocketEvent.type == .factoryUpdate
    ↓
AppState.handleFactoryUpdate(_:) [NEW]
    ↓
Extract unique project codes from pipelines
    ↓
AppState.availableProjects [Set<String>]
```

---

## Function Size Plan

**Existing functions in files to modify:**

| File | Function | Current Lines | After Changes |
|------|----------|---------------|---------------|
| Event.swift | WebSocketEvent.init(from:) | 12 | 12 (unchanged) |
| AppState.swift | handleEvent(_:) | 9 | 12 (add factoryUpdate case) |
| AppState.swift | handleVerdictEvent(_:) | 5 | 5 (unchanged) |

**New functions (all < 50 lines):**

| File | Function | Projected Lines | Status |
|------|----------|-----------------|--------|
| Event.swift | WebSocketEvent.severity (computed) | 15 | OK |
| Event.swift | WebSocketEvent.projectCode (computed) | 12 | OK |
| SoundAlertService.swift | playSound(for:) | 8 | OK |
| SoundAlertService.swift | isSoundEnabled(for:) | 5 | OK |
| SoundAlertService.swift | setSoundEnabled(_:for:) | 4 | OK |
| SoundAlertService.swift | soundName(for:) | 8 | OK |
| SoundAlertService.swift | setSoundName(_:for:) | 4 | OK |
| EventFilterBar.swift | body | 35 | OK |
| EventRow.swift | body | 25 | OK |
| EventRow.swift | iconName(for:) | 12 | OK |
| EventRow.swift | iconColor(for:) | 12 | OK |
| EventStreamView.swift | body | 40 | OK |
| EventStreamViewModel.swift | addEvent(_:) | 8 | OK |
| EventStreamViewModel.swift | filteredEvents (computed) | 20 | OK |
| EventStreamViewModel.swift | clearEvents() | 3 | OK |
| AppState.swift | handleFactoryUpdate(_:) | 10 | OK |

No functions exceed 50 lines. No helper extraction required.

---

## Detailed Design

### 1. Event.swift — MODIFY (Add Severity)

**Location:** `Sources/HEIMDALLControlSurface/Models/Event.swift`

**Add after line 16 (after EventType enum):**

```swift
// MARK: - Event Severity

/// Event severity for filtering and display
public enum EventSeverity: String, Codable, Sendable, CaseIterable {
    case info
    case warning
    case error
    case critical
}
```

**Add extension after line 151 (after existing extensions):**

```swift
// MARK: - Severity and Project Extraction

extension WebSocketEvent {
    /// Inferred severity based on event type and payload
    public var severity: EventSeverity {
        switch type {
        case .heartbeat:
            return .info
        case .factoryUpdate, .pipelineUpdate, .agentStatus:
            return .info
        case .verdict:
            guard let payload = try? verdictPayload() else { return .info }
            switch payload.verdict.outcome {
            case .pass: return .info
            case .fail: return .warning
            case .escalate: return .critical
            }
        case .escalation:
            return .critical
        }
    }

    /// Extract project code from event payload (for filtering)
    public var projectCode: String? {
        switch type {
        case .verdict:
            guard let payload = try? verdictPayload() else { return nil }
            return extractProjectCode(from: payload.verdict.issueId)
        case .pipelineUpdate:
            guard let payload = try? decodePayload(as: PipelineUpdatePayload.self) else { return nil }
            return extractProjectCode(from: payload.pipeline.issueId)
        case .factoryUpdate:
            // Factory updates contain multiple pipelines; return nil (shows all)
            return nil
        default:
            return nil
        }
    }

    /// Extract project code prefix from issue ID (e.g., "AASF-123" → "AASF")
    private func extractProjectCode(from issueId: String) -> String? {
        guard let dashIndex = issueId.firstIndex(of: "-") else { return nil }
        return String(issueId[..<dashIndex])
    }
}
```

---

### 2. SoundAlertService.swift — CREATE

**Location:** `Sources/HEIMDALLControlSurface/Services/SoundAlertService.swift`

```swift
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
```

---

### 3. EventFilterBar.swift — CREATE

**Location:** `Sources/HEIMDALLControlSurface/Views/EventFilterBar.swift`

```swift
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
            // Event Type Filter
            Menu("Type") {
                ForEach(EventType.allCases, id: \.rawValue) { eventType in
                    Toggle(eventType.displayName, isOn: eventTypeBinding(for: eventType))
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            // Project Filter (CRITICAL - required by acceptance criteria)
            Picker("Project", selection: $filterState.selectedProjectCode) {
                Text("All Projects").tag(nil as String?)
                Divider()
                ForEach(availableProjects, id: \.self) { project in
                    Text(project).tag(project as String?)
                }
            }
            .pickerStyle(.menu)
            .fixedSize()

            // Severity Filter
            Menu("Severity") {
                ForEach(EventSeverity.allCases, id: \.rawValue) { severity in
                    Toggle(severity.displayName, isOn: severityBinding(for: severity))
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Spacer()

            // Clear filters button
            Button("Clear") {
                filterState = EventFilterState()
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
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
```

---

### 4. EventRow.swift — CREATE

**Location:** `Sources/HEIMDALLControlSurface/Views/EventRow.swift`

```swift
// Sources/HEIMDALLControlSurface/Views/EventRow.swift
// HCS-007: Formatted event row with timestamp, icon, details

import SwiftUI

/// Single event row in the stream list
struct EventRow: View {
    let event: WebSocketEvent

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    var body: some View {
        HStack(spacing: 8) {
            // Severity/Type icon
            Image(systemName: iconName(for: event))
                .foregroundStyle(iconColor(for: event))
                .frame(width: 20)

            // Timestamp
            Text(Self.timeFormatter.string(from: event.timestamp))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)

            // Event type badge
            Text(event.type.displayName)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(badgeColor(for: event.type).opacity(0.2))
                .foregroundStyle(badgeColor(for: event.type))
                .clipShape(Capsule())

            // Project code (if available)
            if let projectCode = event.projectCode {
                Text(projectCode)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Event details
            Text(eventSummary(for: event))
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func iconName(for event: WebSocketEvent) -> String {
        switch event.severity {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        case .critical: return "exclamationmark.octagon"
        }
    }

    private func iconColor(for event: WebSocketEvent) -> Color {
        switch event.severity {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .critical: return .red
        }
    }

    private func badgeColor(for eventType: EventType) -> Color {
        switch eventType {
        case .verdict: return .purple
        case .escalation: return .red
        case .pipelineUpdate: return .green
        case .factoryUpdate: return .blue
        case .agentStatus: return .cyan
        case .heartbeat: return .gray
        }
    }

    private func eventSummary(for event: WebSocketEvent) -> String {
        switch event.type {
        case .verdict:
            guard let payload = try? event.verdictPayload() else { return "Verdict" }
            return "\(payload.verdict.issueId): \(payload.verdict.outcome.rawValue) — \(payload.verdict.reason)"
        case .escalation:
            guard let payload = try? event.verdictPayload() else { return "Escalation" }
            return "\(payload.verdict.issueId): \(payload.verdict.reason)"
        case .pipelineUpdate:
            guard let payload = try? event.decodePayload(as: PipelineUpdatePayload.self) else { return "Pipeline" }
            return "\(payload.pipeline.issueId): \(payload.pipeline.phase) — \(payload.pipeline.status.rawValue)"
        case .factoryUpdate:
            guard let payload = try? event.factoryUpdatePayload() else { return "Factory" }
            return "Factory \(payload.factoryStatus.rawValue), \(payload.pipelines.count) pipelines"
        case .agentStatus:
            guard let payload = try? event.decodePayload(as: AgentStatusPayload.self) else { return "Agent" }
            return "Agent \(payload.agent.agentId): \(payload.agent.status)"
        case .heartbeat:
            guard let payload = try? event.heartbeatPayload() else { return "Heartbeat" }
            return "\(payload.agents.count) agents, uptime \(payload.uptimeSeconds)s"
        }
    }
}
```

---

### 5. EventStreamView.swift — CREATE

**Location:** `Sources/HEIMDALLControlSurface/Views/EventStreamView.swift`

```swift
// Sources/HEIMDALLControlSurface/Views/EventStreamView.swift
// HCS-007: Scrolling list of live events with auto-scroll and pause-on-hover

import SwiftUI

/// Main event stream view with filtering and auto-scroll
struct EventStreamView: View {
    @Bindable var viewModel: EventStreamViewModel
    @State private var isPaused: Bool = false
    @State private var filterState = EventFilterState()

    var body: some View {
        VStack(spacing: 0) {
            // Filter bar
            EventFilterBar(
                filterState: $filterState,
                availableProjects: viewModel.availableProjects
            )

            Divider()

            // Event list with auto-scroll
            ScrollViewReader { proxy in
                List(viewModel.filteredEvents(with: filterState)) { event in
                    EventRow(event: event)
                        .id(event.id)
                }
                .listStyle(.plain)
                .onChange(of: viewModel.events.count) { _, _ in
                    scrollToLatestIfNotPaused(proxy: proxy)
                }
                .onHover { hovering in
                    isPaused = hovering
                }
            }

            // Status bar
            statusBar
        }
    }

    private var statusBar: some View {
        HStack {
            // Connection indicator
            Circle()
                .fill(viewModel.isConnected ? .green : .red)
                .frame(width: 8, height: 8)

            Text(viewModel.isConnected ? "Connected" : "Disconnected")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            // Event count
            Text("\(viewModel.filteredEvents(with: filterState).count) events")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Pause indicator
            if isPaused {
                Text("(paused)")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            // Clear button
            Button("Clear") {
                viewModel.clearEvents()
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }

    private func scrollToLatestIfNotPaused(proxy: ScrollViewProxy) {
        guard !isPaused else { return }
        let filtered = viewModel.filteredEvents(with: filterState)
        guard let lastEvent = filtered.last else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(lastEvent.id, anchor: .bottom)
        }
    }
}
```

---

### 6. EventStreamViewModel.swift — CREATE

**Location:** `Sources/HEIMDALLControlSurface/ViewModels/EventStreamViewModel.swift`

Create directory first: `Sources/HEIMDALLControlSurface/ViewModels/`

```swift
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
            // Filter by event type
            guard filterState.selectedEventTypes.contains(event.type) else {
                return false
            }

            // Filter by project (CRITICAL — required by acceptance criteria)
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
    }

    /// Clear all events
    public func clearEvents() {
        events.removeAll()
        availableProjects.removeAll()
    }

    // MARK: - Private Helpers

    private func trimEventsIfNeeded() {
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
    }

    private func updateAvailableProjects(from event: WebSocketEvent) {
        // Extract project codes from factory updates
        if event.type == .factoryUpdate {
            guard let payload = try? event.factoryUpdatePayload() else { return }
            let newProjects = payload.pipelines.compactMap { pipeline -> String? in
                guard let dashIndex = pipeline.issueId.firstIndex(of: "-") else { return nil }
                return String(pipeline.issueId[..<dashIndex])
            }
            let uniqueNew = Set(newProjects)
            let existing = Set(availableProjects)
            let combined = existing.union(uniqueNew)
            availableProjects = combined.sorted()
        }

        // Also extract from individual events
        if let projectCode = event.projectCode,
           !availableProjects.contains(projectCode) {
            availableProjects.append(projectCode)
            availableProjects.sort()
        }
    }
}
```

---

### 7. AppState.swift — MODIFY

**Add property after line 47 (after pendingActions):**

```swift
    // Event stream view model (HCS-007)
    var eventStreamViewModel: EventStreamViewModel = EventStreamViewModel()
```

**Modify handleEvent(_:) at line 158:**

```swift
    func handleEvent(_ event: WebSocketEvent) {
        // Forward all events to stream view model (HCS-007)
        eventStreamViewModel.addEvent(event)

        switch event.type {
        case .verdict:
            handleVerdictEvent(event)
        case .escalation:
            handleEscalationEvent(event)
        default:
            break
        }
    }
```

---

### 8. EventStreamTests.swift — CREATE

**Location:** `Tests/HEIMDALLControlSurfaceTests/EventStreamTests.swift`

```swift
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
```

---

## Guard / Recovery Pairs

| Guard | Location | Recovery |
|-------|----------|----------|
| `filterState.selectedEventTypes.contains(event.type)` | EventStreamViewModel.filteredEvents() | Event excluded from filtered results |
| `filterState.selectedProjectCode` != nil | EventStreamViewModel.filteredEvents() | If nil, all projects shown; if set, only matching projects |
| `filterState.selectedSeverities.contains(event.severity)` | EventStreamViewModel.filteredEvents() | Event excluded from filtered results |
| `isSoundEnabled(for:)` returns false | SoundAlertService.playSound() | No sound played, method returns early |
| `soundName.isEmpty` | SoundAlertService.playSound() | No sound played (silent for heartbeat) |
| `events.count > maxEvents` | EventStreamViewModel.trimEventsIfNeeded() | Oldest events removed to maintain cap |
| `!isPaused` | EventStreamView.scrollToLatestIfNotPaused() | No auto-scroll while user hovers |
| `payload` decode fails | EventRow.eventSummary() | Fallback to simple type name string |

---

## Verification Plan

| Check | Command/Method | Expected |
|-------|----------------|----------|
| Build succeeds | `swift build` | Exit 0, no errors |
| Tests pass | `swift test` | All tests green |
| Severity inference | Run EventSeverityTests | Pass/fail/escalate mapped correctly |
| Project extraction | Run ProjectCodeExtractionTests | "AASF-123" → "AASF" |
| Type filtering | Run EventFilteringTests | Only selected types shown |
| **Project filtering** | Run EventFilteringTests.filtersEventsByProject | **Only AASF events when AASF selected** |
| Severity filtering | Run EventFilteringTests | Only selected severities shown |
| Combined filtering | Run EventFilteringTests.combinesMultipleFilters | All filters applied together |
| Sound defaults | Run SoundAlertTests | Escalation/verdict enabled by default |
| Sound config | Run SoundAlertTests | Enable/disable persists to UserDefaults |
| Event trimming | Run EventStreamViewModelTests | Max events enforced |

---

## Test Strategy

### Test Files
- `Tests/HEIMDALLControlSurfaceTests/EventStreamTests.swift` (CREATE)

### Test Suites and Cases

| Suite | Test | Verification |
|-------|------|--------------|
| EventSeverityTests | heartbeatSeverityIsInfo | Heartbeat → info |
| EventSeverityTests | verdictPassSeverityIsInfo | Pass → info |
| EventSeverityTests | verdictFailSeverityIsWarning | Fail → warning |
| EventSeverityTests | verdictEscalateSeverityIsCritical | Escalate → critical |
| EventSeverityTests | escalationSeverityIsCritical | Escalation → critical |
| ProjectCodeExtractionTests | extractsProjectCodeFromVerdictEvent | AASF-123 → AASF |
| ProjectCodeExtractionTests | extractsProjectCodeFromEscalationEvent | HCS-456 → HCS |
| ProjectCodeExtractionTests | heartbeatHasNoProjectCode | Returns nil |
| ProjectCodeExtractionTests | factoryUpdateHasNoProjectCode | Returns nil |
| EventFilteringTests | filtersEventsByType | Only selected types |
| EventFilteringTests | **filtersEventsByProject** | **Only AASF when AASF selected** |
| EventFilteringTests | filtersEventsBySeverity | Only selected severities |
| EventFilteringTests | combinesMultipleFilters | All filters applied |
| EventFilteringTests | nilProjectFilterShowsAllProjects | All projects when nil |
| SoundAlertTests | defaultSoundsConfigured | Glass, Sosumi configured |
| SoundAlertTests | escalationAndVerdictEnabledByDefault | Both enabled |
| SoundAlertTests | canDisableSoundForEventType | Persists to defaults |
| SoundAlertTests | canSetCustomSoundName | Persists to defaults |
| SoundAlertTests | viewModelPlaysSoundOnNewEvent | Sound triggered |
| SoundAlertTests | viewModelDoesNotPlayDisabledSound | No sound if disabled |
| EventStreamViewModelTests | addsEventsToStream | Events appended |
| EventStreamViewModelTests | clearsAllEvents | Empty after clear |
| EventStreamViewModelTests | trimEventsWhenExceedingMax | Capped at max |
| EventStreamViewModelTests | extractsAvailableProjectsFromEvents | Projects extracted |
| EventFilterStateTests | defaultStateIncludesAllEventTypes | All types selected |
| EventFilterStateTests | defaultStateIncludesAllSeverities | All severities selected |
| EventFilterStateTests | defaultProjectFilterIsNil | Nil = all projects |

### Verification Commands
```bash
swift build
swift test --filter EventSeverityTests
swift test --filter ProjectCodeExtractionTests
swift test --filter EventFilteringTests
swift test --filter SoundAlertTests
swift test --filter EventStreamViewModelTests
swift test --filter EventFilterStateTests
swift test  # All tests
```

---

## Execution Contract

```json
{
  "issue_ref": "HCS-007",
  "deliverables": [
    {
      "file": "Sources/HEIMDALLControlSurface/Models/Event.swift",
      "function": "EventSeverity enum, WebSocketEvent.severity, WebSocketEvent.projectCode",
      "change_description": "MODIFY to add EventSeverity enum with info/warning/error/critical cases, add computed severity property based on event type and payload, add computed projectCode property to extract project prefix from issue IDs",
      "verification": "swift build succeeds; EventSeverityTests and ProjectCodeExtractionTests pass"
    },
    {
      "file": "Sources/HEIMDALLControlSurface/Services/SoundAlertService.swift",
      "function": "",
      "change_description": "CREATE new file with SoundAlertServiceProtocol and SoundAlertService class providing per-event-type sound configuration using NSSound and UserDefaults persistence",
      "verification": "swift build succeeds; SoundAlertTests pass"
    },
    {
      "file": "Sources/HEIMDALLControlSurface/Views/EventFilterBar.swift",
      "function": "",
      "change_description": "CREATE new file with EventFilterState struct and EventFilterBar view providing filter controls for event type (multi-select menu), project (picker dropdown), and severity (multi-select menu)",
      "verification": "swift build succeeds; view renders filter controls"
    },
    {
      "file": "Sources/HEIMDALLControlSurface/Views/EventRow.swift",
      "function": "",
      "change_description": "CREATE new file with EventRow view displaying formatted event with severity icon, timestamp, type badge, project code, and summary text",
      "verification": "swift build succeeds; view renders event rows"
    },
    {
      "file": "Sources/HEIMDALLControlSurface/Views/EventStreamView.swift",
      "function": "",
      "change_description": "CREATE new file with EventStreamView providing scrolling list of filtered events with auto-scroll, pause-on-hover, connection status, and clear button",
      "verification": "swift build succeeds; view renders event stream with auto-scroll"
    },
    {
      "file": "Sources/HEIMDALLControlSurface/ViewModels/EventStreamViewModel.swift",
      "function": "",
      "change_description": "CREATE new file with EventStreamViewModel providing observable events array, filteredEvents(with:) method implementing type/project/severity filtering, addEvent() with sound playback, and project extraction",
      "verification": "swift build succeeds; EventFilteringTests and EventStreamViewModelTests pass"
    },
    {
      "file": "Sources/HEIMDALLControlSurface/AppState.swift",
      "function": "eventStreamViewModel property, handleEvent modification",
      "change_description": "MODIFY to add eventStreamViewModel property and forward all WebSocket events to it in handleEvent(_:)",
      "verification": "swift build succeeds; events flow to view model"
    },
    {
      "file": "Tests/HEIMDALLControlSurfaceTests/EventStreamTests.swift",
      "function": "",
      "change_description": "CREATE new test file with EventSeverityTests (5 tests), ProjectCodeExtractionTests (4 tests), EventFilteringTests (6 tests including project filtering), SoundAlertTests (6 tests), EventStreamViewModelTests (4 tests), EventFilterStateTests (3 tests)",
      "verification": "swift test passes all EventStreamTests"
    }
  ]
}
```
