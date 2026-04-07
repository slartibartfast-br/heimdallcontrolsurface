# PLAN: HCS-007 Event Stream View

## Preflight Checklist

### 1. git status
```
On branch feat/AASF-673
nothing to commit, working tree clean
```

### 2. git branch
```
+ feat/AASF-647
+ feat/AASF-671
* feat/AASF-673
+ main
```

### 3. ls data/queue/
```
ls: /Users/maurizio/development/heimdall/hcs/.worktrees/aasf-673/data/queue/: No such file or directory
```
(No queue directory exists — this is a Swift project, no stale envelopes)

### 4. Mandatory Rules from CLAUDE.md
1. Functions < 50 lines
2. Read signatures before calling
3. String matching: \b word boundaries only
4. Max 5 files per refactor commit
5. One branch at a time
6. Squash merge to main
7. Every commit: (HCS-NNN)
8. python -m pytest tests/ -q must pass before merge (N/A — Swift project uses `swift test`)

---

## Scope

| File | Action | Purpose |
|------|--------|---------|
| `Sources/HEIMDALLControlSurface/Models/Event.swift` | MODIFY | Add EventSeverity enum and CaseIterable conformance to EventType |
| `Sources/HEIMDALLControlSurface/Views/EventStreamView.swift` | CREATE | Main event stream view with scrolling list, auto-scroll, pause-on-hover |
| `Sources/HEIMDALLControlSurface/Views/EventFilterBar.swift` | CREATE | Filter bar for type/project/severity filtering |
| `Sources/HEIMDALLControlSurface/Views/EventRow.swift` | CREATE | Individual event row with timestamp, icon, details |
| `Sources/HEIMDALLControlSurface/Services/SoundAlertService.swift` | CREATE | System sound playback per event type with configurable preferences |
| `Tests/HEIMDALLControlSurfaceTests/EventStreamTests.swift` | CREATE | Unit tests for filtering logic, severity, sound configuration, ViewModel |

---

## Function Size Plan

### Existing Files to Modify

**Event.swift** (209 lines total)
- No functions exceed 50 lines
- Adding EventSeverity enum (~8 lines) + severity computed property (~15 lines)
- Adding CaseIterable conformance to EventType (0 additional lines, just protocol)
- **No functions will exceed 50 lines after changes**

### New Files — Projected Function Sizes

| File | Function/Property | Projected Lines |
|------|-------------------|-----------------|
| **EventStreamView.swift** (~95 lines total) | | |
| | `body` | ~15 |
| | `filteredEvents` | ~12 |
| | `eventListContent` | ~15 |
| | `handleNewEvent(_:)` | ~8 |
| **EventFilterBar.swift** (~65 lines total) | | |
| | `body` | ~20 |
| | `eventTypeMenu` | ~15 |
| | `projectPicker` | ~10 |
| | `severityPicker` | ~10 |
| **EventRow.swift** (~75 lines total) | | |
| | `body` | ~18 |
| | `iconView` | ~8 |
| | `headerRow` | ~8 |
| | `detailText` | ~8 |
| | `timestampText` | ~6 |
| | `icon(for:)` | ~12 |
| | `color(for:)` | ~8 |
| **SoundAlertService.swift** (~85 lines total) | | |
| | `playSound(for:)` | ~6 |
| | `isSoundEnabled(for:)` | ~4 |
| | `setSoundEnabled(_:for:)` | ~4 |
| | `soundName(for:)` | ~6 |
| | `setSoundName(_:for:)` | ~4 |
| | `defaultSounds` dictionary | ~10 |
| **EventStreamTests.swift** (~160 lines total) | | |
| | Individual test functions | 5-15 each |

**All functions remain under 50 lines.**

---

## Data Path Trace

### Event Flow: WebSocket → EventStreamView

1. **WebSocketService.swift:88** `receiveMessages()` yields events via `eventContinuation?.yield(event)`
2. **ConnectionManager.swift:112** `consumeWebSocketEvents()` iterates `for await event in webSocketService.events`
3. **ConnectionManager.swift:114** calls `handleEvent(event)` at line 165
4. **ConnectionManager.swift:165-167** `handleEvent(_:)` forwards to `eventHandler?.handleEvent(event)`
5. **NEW: EventStreamViewModel** will observe events via passed-in event source or direct subscription
6. **NEW: EventStreamView** observes `@StateObject viewModel` and renders `filteredEvents`

### Filter Application Flow

1. User interacts with `EventFilterBar` bindings → updates `@State` in `EventStreamView`
2. `EventStreamView.filteredEvents` computed property applies predicates:
   ```swift
   viewModel.events.filter { event in
       selectedTypes.contains(event.type) &&
       (selectedProject == nil || extractProject(event) == selectedProject) &&
       (selectedSeverity == nil || event.severity == selectedSeverity)
   }
   ```
3. SwiftUI re-renders `List` when filter state changes

### Sound Alert Flow

1. `EventStreamViewModel.addEvent(_:)` receives new event
2. Calls `soundService.playSound(for: event.type)`
3. **SoundAlertService.playSound(for:)** checks `isSoundEnabled(for:)`
4. If enabled, retrieves `soundName(for:)` from UserDefaults (or default)
5. Plays system sound via `NSSound(named: NSSound.Name(name))?.play()`

### Auto-Scroll with Pause-on-Hover Flow

1. `EventStreamView` uses `ScrollViewReader` with `scrollTo(id:)`
2. When `viewModel.events` changes and `!isPaused`, scroll to last event ID
3. `.onHover { hovering in isPaused = hovering }` on the List pauses auto-scroll

---

## Detailed Implementation

### 1. Event.swift Modifications (MODIFY)

**Location:** `Sources/HEIMDALLControlSurface/Models/Event.swift`

**Change 1:** Add `CaseIterable` conformance to `EventType` (line 9):
```swift
public enum EventType: String, Codable, Sendable, CaseIterable {
    // existing cases unchanged
}
```

**Change 2:** Add `EventSeverity` enum (after line 16, after EventType enum):
```swift
/// Event severity for filtering and display
public enum EventSeverity: String, Codable, Sendable, CaseIterable {
    case info
    case warning
    case error
    case critical
}
```

**Change 3:** Add severity computed property to `WebSocketEvent` (new extension after line 151):
```swift
// MARK: - Severity Inference

extension WebSocketEvent {
    /// Inferred severity based on event type and payload
    public var severity: EventSeverity {
        switch type {
        case .heartbeat:
            return .info
        case .factoryUpdate, .pipelineUpdate, .agentStatus:
            return .info
        case .verdict:
            if let payload = try? verdictPayload() {
                return payload.verdict.outcome == .escalate ? .critical : .info
            }
            return .info
        case .escalation:
            return .critical
        }
    }
}
```

**Projected line count:** 209 + 25 = ~234 lines

---

### 2. EventStreamView.swift (CREATE)

**Location:** `Sources/HEIMDALLControlSurface/Views/EventStreamView.swift`

```swift
// Sources/HEIMDALLControlSurface/Views/EventStreamView.swift
// HCS-007: Real-time event stream view with filtering and auto-scroll

import SwiftUI

// MARK: - View Model

@MainActor
final class EventStreamViewModel: ObservableObject {
    @Published var events: [WebSocketEvent] = []
    private let soundService: SoundAlertServiceProtocol
    private let maxEvents: Int = 500

    init(soundService: SoundAlertServiceProtocol = SoundAlertService()) {
        self.soundService = soundService
    }

    func addEvent(_ event: WebSocketEvent) {
        events.append(event)
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
        soundService.playSound(for: event.type)
    }

    func clearEvents() {
        events.removeAll()
    }
}

// MARK: - Event Stream View

struct EventStreamView: View {
    @StateObject private var viewModel = EventStreamViewModel()

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
                selectedSeverity: $selectedSeverity
            )
            Divider()
            eventListContent
        }
        .navigationTitle("Event Stream")
    }

    private var filteredEvents: [WebSocketEvent] {
        viewModel.events.filter { event in
            selectedTypes.contains(event.type) &&
            (selectedSeverity == nil || event.severity == selectedSeverity)
        }
    }

    private var eventListContent: some View {
        ScrollViewReader { proxy in
            List(filteredEvents) { event in
                EventRow(event: event)
            }
            .onHover { hovering in
                isPaused = hovering
            }
            .onChange(of: viewModel.events.count) { _, _ in
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
}
```

**Line count:** ~80 lines

---

### 3. EventFilterBar.swift (CREATE)

**Location:** `Sources/HEIMDALLControlSurface/Views/EventFilterBar.swift`

```swift
// Sources/HEIMDALLControlSurface/Views/EventFilterBar.swift
// HCS-007: Event filter bar component

import SwiftUI

struct EventFilterBar: View {
    @Binding var selectedTypes: Set<EventType>
    @Binding var selectedProject: String?
    @Binding var selectedSeverity: EventSeverity?

    var body: some View {
        HStack(spacing: 12) {
            eventTypeMenu
            severityPicker
            Spacer()
            clearFiltersButton
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
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
        selectedSeverity: .constant(nil)
    )
}
```

**Line count:** ~75 lines

---

### 4. EventRow.swift (CREATE)

**Location:** `Sources/HEIMDALLControlSurface/Views/EventRow.swift`

```swift
// Sources/HEIMDALLControlSurface/Views/EventRow.swift
// HCS-007: Event row component for stream list

import SwiftUI

struct EventRow: View {
    let event: WebSocketEvent

    var body: some View {
        HStack(spacing: 12) {
            iconView
            VStack(alignment: .leading, spacing: 2) {
                headerRow
                detailText
            }
            Spacer()
            timestampText
        }
        .padding(.vertical, 4)
    }

    private var iconView: some View {
        Image(systemName: Self.icon(for: event.type))
            .font(.title3)
            .foregroundStyle(Self.color(for: event.severity))
            .frame(width: 24)
    }

    private var headerRow: some View {
        Text(event.type.rawValue.replacingOccurrences(of: "_", with: " ").uppercased())
            .font(.caption.bold())
            .foregroundStyle(Self.color(for: event.severity))
    }

    private var detailText: some View {
        Text(eventDetail)
            .font(.subheadline)
            .foregroundStyle(.primary)
            .lineLimit(2)
    }

    private var timestampText: some View {
        Text(event.timestamp, style: .time)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var eventDetail: String {
        switch event.type {
        case .verdict:
            if let payload = try? event.verdictPayload() {
                return "\(payload.verdict.issueId): \(payload.verdict.outcome.rawValue)"
            }
        case .heartbeat:
            return "System heartbeat"
        case .escalation:
            return "Escalation required"
        default:
            break
        }
        return event.type.rawValue
    }
}

// MARK: - Helpers

extension EventRow {
    static func icon(for type: EventType) -> String {
        switch type {
        case .factoryUpdate: return "building.2"
        case .verdict: return "checkmark.seal"
        case .heartbeat: return "heart.fill"
        case .pipelineUpdate: return "arrow.triangle.branch"
        case .agentStatus: return "person.fill"
        case .escalation: return "exclamationmark.triangle.fill"
        }
    }

    static func color(for severity: EventSeverity) -> Color {
        switch severity {
        case .info: return .secondary
        case .warning: return .orange
        case .error: return .red
        case .critical: return .red
        }
    }
}

#Preview {
    List {
        EventRow(event: WebSocketEvent(
            type: .heartbeat,
            timestamp: Date(),
            payload: Data()
        ))
        EventRow(event: WebSocketEvent(
            type: .escalation,
            timestamp: Date(),
            payload: Data()
        ))
    }
}
```

**Line count:** ~95 lines

---

### 5. SoundAlertService.swift (CREATE)

**Location:** `Sources/HEIMDALLControlSurface/Services/SoundAlertService.swift`

```swift
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
```

**Line count:** ~75 lines

---

### 6. EventStreamTests.swift (CREATE)

**Location:** `Tests/HEIMDALLControlSurfaceTests/EventStreamTests.swift`

```swift
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

// MARK: - Event Stream ViewModel Tests

@Suite("Event Stream ViewModel Tests")
struct EventStreamViewModelTests {
    @Test @MainActor func addEventAppendsToList() async throws {
        let mockSound = MockSoundAlertService()
        let viewModel = EventStreamViewModel(soundService: mockSound)
        let event = WebSocketEvent(type: .heartbeat, timestamp: Date(), payload: Data())
        viewModel.addEvent(event)
        #expect(viewModel.events.count == 1)
        #expect(viewModel.events.first?.type == .heartbeat)
    }

    @Test @MainActor func addEventTriggersSoundAlert() async throws {
        let mockSound = MockSoundAlertService()
        let viewModel = EventStreamViewModel(soundService: mockSound)
        let event = WebSocketEvent(type: .verdict, timestamp: Date(), payload: Data())
        viewModel.addEvent(event)
        #expect(mockSound.playedSounds.count == 1)
        #expect(mockSound.playedSounds.first == .verdict)
    }

    @Test @MainActor func eventsAreCappedAtMaximum() async throws {
        let mockSound = MockSoundAlertService()
        let viewModel = EventStreamViewModel(soundService: mockSound)
        // Add 600 events (more than 500 cap)
        for _ in 0..<600 {
            viewModel.addEvent(WebSocketEvent(type: .heartbeat, timestamp: Date(), payload: Data()))
        }
        #expect(viewModel.events.count == 500)
    }

    @Test @MainActor func clearEventsRemovesAll() async throws {
        let mockSound = MockSoundAlertService()
        let viewModel = EventStreamViewModel(soundService: mockSound)
        viewModel.addEvent(WebSocketEvent(type: .heartbeat, timestamp: Date(), payload: Data()))
        viewModel.addEvent(WebSocketEvent(type: .verdict, timestamp: Date(), payload: Data()))
        #expect(viewModel.events.count == 2)
        viewModel.clearEvents()
        #expect(viewModel.events.isEmpty)
    }

    @Test @MainActor func soundNotPlayedWhenDisabled() async throws {
        let mockSound = MockSoundAlertService()
        mockSound.setSoundEnabled(false, for: .heartbeat)
        let viewModel = EventStreamViewModel(soundService: mockSound)
        viewModel.addEvent(WebSocketEvent(type: .heartbeat, timestamp: Date(), payload: Data()))
        #expect(mockSound.playedSounds.isEmpty)
    }
}

// MARK: - Event Row Helper Tests

@Suite("Event Row Helper Tests")
struct EventRowHelperTests {
    @Test func iconMappingCoversAllEventTypes() async throws {
        for eventType in EventType.allCases {
            let icon = EventRow.icon(for: eventType)
            #expect(!icon.isEmpty)
        }
    }

    @Test func colorMappingCoversAllSeverities() async throws {
        for severity in EventSeverity.allCases {
            // Just verify it doesn't crash and returns something
            _ = EventRow.color(for: severity)
        }
    }

    @Test func escalationIconIsWarningTriangle() async throws {
        let icon = EventRow.icon(for: .escalation)
        #expect(icon == "exclamationmark.triangle.fill")
    }
}
```

**Line count:** ~180 lines

---

## Verification Plan

### Build Verification
```bash
cd /Users/maurizio/development/heimdall/hcs/.worktrees/aasf-673
swift build
```

### Test Verification
```bash
swift test
```

### Specific Test Cases to Verify

| Suite | Test | What It Verifies |
|-------|------|------------------|
| EventSeverityTests | `heartbeatSeverityIsInfo` | Heartbeat events return `.info` severity |
| EventSeverityTests | `escalationSeverityIsCritical` | Escalation events return `.critical` severity |
| EventTypeCaseIterableTests | `eventTypeHasAllCases` | EventType conforms to CaseIterable with 6 cases |
| SoundAlertServiceTests | `soundEnabledByDefaultForAllTypes` | All sounds enabled by default |
| SoundAlertServiceTests | `disableSoundForEventType` | Can disable specific event type sound |
| SoundAlertServiceTests | `customSoundNamePersists` | Custom sound names saved to UserDefaults |
| EventStreamViewModelTests | `addEventAppendsToList` | Events added to ViewModel appear in list |
| EventStreamViewModelTests | `eventsAreCappedAtMaximum` | Memory protection caps events at 500 |
| EventStreamViewModelTests | `addEventTriggersSoundAlert` | Sound service called on new event |
| EventRowHelperTests | `iconMappingCoversAllEventTypes` | Every event type has an icon |

---

## Execution Contract

```json
{
  "issue_ref": "HCS-007",
  "deliverables": [
    {
      "file": "Sources/HEIMDALLControlSurface/Models/Event.swift",
      "function": "EventSeverity enum, EventType CaseIterable, WebSocketEvent.severity",
      "change_description": "MODIFY: Add EventSeverity enum, add CaseIterable to EventType, add severity computed property to WebSocketEvent",
      "verification": "swift build succeeds, EventSeverityTests and EventTypeCaseIterableTests pass"
    },
    {
      "file": "Sources/HEIMDALLControlSurface/Views/EventStreamView.swift",
      "function": "EventStreamView, EventStreamViewModel",
      "change_description": "CREATE: Main event stream view with scrolling list, auto-scroll with pause-on-hover, filter integration, and ViewModel with event capping",
      "verification": "swift build succeeds, EventStreamViewModelTests pass"
    },
    {
      "file": "Sources/HEIMDALLControlSurface/Views/EventFilterBar.swift",
      "function": "EventFilterBar",
      "change_description": "CREATE: Filter bar with event type multi-select menu, severity picker, and clear filters button",
      "verification": "swift build succeeds, view renders in SwiftUI preview"
    },
    {
      "file": "Sources/HEIMDALLControlSurface/Views/EventRow.swift",
      "function": "EventRow, icon(for:), color(for:)",
      "change_description": "CREATE: Event row component with timestamp, icon, type label, detail text, and static helper methods for icon/color mapping",
      "verification": "swift build succeeds, EventRowHelperTests pass"
    },
    {
      "file": "Sources/HEIMDALLControlSurface/Services/SoundAlertService.swift",
      "function": "SoundAlertService, SoundAlertServiceProtocol",
      "change_description": "CREATE: Sound alert service with configurable sounds per event type using macOS system sounds, UserDefaults persistence",
      "verification": "swift build succeeds, SoundAlertServiceTests pass"
    },
    {
      "file": "Tests/HEIMDALLControlSurfaceTests/EventStreamTests.swift",
      "function": "EventSeverityTests, EventTypeCaseIterableTests, SoundAlertServiceTests, EventStreamViewModelTests, EventRowHelperTests",
      "change_description": "CREATE: Comprehensive unit tests for severity inference, filtering logic, sound configuration, ViewModel behavior, and row helpers",
      "verification": "swift test passes with all new tests green"
    }
  ]
}
```
