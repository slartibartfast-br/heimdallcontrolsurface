# PLAN: HCS-004 — WebSocket Service

## Preflight Checklist

### git status
```
On branch feat/AASF-648
Untracked files:
  (use "git add <file>..." to include in what will be committed)
	Sources/HEIMDALLControlSurface/Models/Agent.swift
	Sources/HEIMDALLControlSurface/Models/Infrastructure.swift
	Sources/HEIMDALLControlSurface/Models/KPI.swift
	Sources/HEIMDALLControlSurface/Models/Pipeline.swift
	Sources/HEIMDALLControlSurface/Models/Project.swift
	Sources/HEIMDALLControlSurface/Models/Verdict.swift
	Sources/HEIMDALLControlSurface/Services/HeimdallAPIClient.swift
	Sources/HEIMDALLControlSurface/Services/JSONDecoding.swift
	Sources/HEIMDALLControlSurface/Services/MockAPIClient.swift

nothing added to commit but untracked files present (use "git add" to track)
```

### git branch
```
+ feat/AASF-646
* feat/AASF-648
+ main
```

### ls data/queue/
```
ls: /Users/maurizio/development/heimdall/hcs/.worktrees/aasf-648/data/queue/: No such file or directory
```
(No queue directory exists — this is a Swift project, no stale envelopes)

### Mandatory Rules from CLAUDE.md
1. Functions < 50 lines
2. Read signatures before calling
3. String matching: \b word boundaries only
4. Max 5 files per refactor commit
5. One branch at a time
6. Squash merge to main
7. Every commit: (HCS-NNN)
8. python -m pytest tests/ -q must pass before merge

---

## Scope

| Action | File | Purpose |
|--------|------|---------|
| CREATE | `Sources/.../Models/Event.swift` | WebSocket event models (factory_update, verdict, heartbeat) |
| CREATE | `Sources/.../Services/WebSocketService.swift` | URLSession WebSocket connection with exponential backoff |
| CREATE | `Sources/.../Services/SSEService.swift` | Server-Sent Events fallback service |
| CREATE | `Sources/.../Services/ConnectionManager.swift` | Orchestrates WebSocket → SSE → REST fallback |
| CREATE | `Sources/.../State/AppState.swift` | Observable state container for live updates |
| MODIFY | `Tests/.../ServiceTests.swift` | Add WebSocket, SSE, ConnectionManager tests |

---

## Design

### Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                      AppState                            │
│   @Published pipelines, verdicts, connectionStatus       │
└────────────────────────┬────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│                  ConnectionManager                       │
│   Orchestrates: WebSocket → SSE → REST polling          │
│   Tracks: ConnectionStatus, retry logic                 │
└───────┬──────────────────┬──────────────────┬───────────┘
        │                  │                  │
        ▼                  ▼                  ▼
┌───────────────┐  ┌───────────────┐  ┌────────────────────┐
│WebSocketService│ │  SSEService   │  │ HeimdallAPIClient  │
│ws://host/ws/  │  │ /api/events   │  │  REST polling      │
│   events      │  │   (SSE)       │  │  (existing)        │
└───────────────┘  └───────────────┘  └────────────────────┘
```

### 1. Event Models (`Event.swift`)

**Purpose:** Strongly-typed models for real-time WebSocket events.

```swift
// Event types matching HEIMDALL monitor backend
public enum EventType: String, Codable, Sendable {
    case factoryUpdate = "factory_update"
    case verdict = "verdict"
    case heartbeat = "heartbeat"
    case pipelineUpdate = "pipeline_update"
    case agentStatus = "agent_status"
}

// Wrapper for all events
public struct WebSocketEvent: Codable, Sendable, Identifiable {
    public let id: UUID
    public let type: EventType
    public let timestamp: Date
    public let payload: Data  // Raw JSON for type-specific decoding
}

// Type-specific payloads
public struct FactoryUpdatePayload: Codable, Sendable {
    public let factoryStatus: FactoryStatus
    public let pipelines: [PipelineEntry]
}

public struct VerdictPayload: Codable, Sendable {
    public let verdict: VerdictEntry
}

public struct HeartbeatPayload: Codable, Sendable {
    public let agents: [AgentHeartbeat]
    public let uptimeSeconds: Int
}
```

**Line estimate:** ~85 lines (models only, no logic)

### 2. WebSocketService (`WebSocketService.swift`)

**Purpose:** Manages URLSession WebSocket connection with reconnection logic.

**Key Components:**

```swift
/// Connection state for WebSocket
public enum WebSocketState: Sendable, Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting(attempt: Int)
}

/// Protocol for WebSocket service (enables mocking)
public protocol WebSocketServiceProtocol: Sendable {
    func connect() async throws
    func disconnect() async
    var events: AsyncStream<WebSocketEvent> { get }
    var state: WebSocketState { get async }
}

/// URLSession-based WebSocket service with exponential backoff
public actor WebSocketService: WebSocketServiceProtocol {
    private let url: URL
    private let session: URLSession
    private var webSocketTask: URLSessionWebSocketTask?
    private var reconnectAttempt: Int = 0
    private let maxReconnectDelay: TimeInterval = 30.0
    private let baseDelay: TimeInterval = 1.0

    // Exponential backoff: 1s → 2s → 4s → 8s → 16s → 30s (capped)
    private func reconnectDelay() -> TimeInterval

    public func connect() async throws
    public func disconnect() async
    private func receiveMessages() async
    private func scheduleReconnect() async
}
```

**Guard/Recovery Pairs:**
| Guard | Recovery |
|-------|----------|
| Connection fails | Schedule reconnect with exponential backoff |
| Message decode error | Log warning, continue receiving |
| Task cancelled | Clean disconnect, no reconnect |
| Max retries reached | Notify delegate/callback of failure |

**Line estimates per function:**
- `reconnectDelay()`: 8 lines
- `connect()`: 22 lines
- `disconnect()`: 12 lines
- `receiveMessages()`: 28 lines
- `scheduleReconnect()`: 18 lines

### 3. SSEService (`SSEService.swift`)

**Purpose:** Server-Sent Events fallback when WebSocket unavailable.

```swift
/// SSE connection state
public enum SSEState: Sendable, Equatable {
    case disconnected
    case connecting
    case connected
}

/// Protocol for SSE service (enables mocking)
public protocol SSEServiceProtocol: Sendable {
    func connect() async throws
    func disconnect() async
    var events: AsyncStream<WebSocketEvent> { get }
    var state: SSEState { get async }
}

/// URLSession-based SSE service
public actor SSEService: SSEServiceProtocol {
    private let url: URL
    private let session: URLSession
    private var dataTask: Task<Void, Never>?

    public func connect() async throws
    public func disconnect() async
    private func parseSSELine(_ line: String) -> WebSocketEvent?
    private func processStream(_ bytes: URLSession.AsyncBytes) async
}
```

**Line estimates per function:**
- `connect()`: 20 lines
- `disconnect()`: 10 lines
- `parseSSELine()`: 18 lines
- `processStream()`: 25 lines

### 4. ConnectionManager (`ConnectionManager.swift`)

**Purpose:** Orchestrates connection strategy with fallback chain.

```swift
/// Overall connection status exposed to UI
public enum ConnectionStatus: Sendable, Equatable {
    case disconnected
    case connecting(ConnectionMethod)
    case connected(ConnectionMethod)
    case reconnecting(ConnectionMethod, attempt: Int)
    case failed(String)  // Error description
}

/// Connection method in use
public enum ConnectionMethod: String, Sendable, CaseIterable {
    case webSocket
    case sse
    case restPolling
}

/// Manages connection fallback chain: WebSocket → SSE → REST
@MainActor
public final class ConnectionManager: ObservableObject {
    @Published public private(set) var status: ConnectionStatus = .disconnected

    private let webSocketService: any WebSocketServiceProtocol
    private let sseService: any SSEServiceProtocol
    private let apiClient: any HeimdallAPIClientProtocol
    private let pollingInterval: TimeInterval

    private var activeTask: Task<Void, Never>?
    private var webSocketRetries: Int = 0
    private var sseRetries: Int = 0
    private let maxRetries: Int = 3

    public init(
        webSocketService: any WebSocketServiceProtocol,
        sseService: any SSEServiceProtocol,
        apiClient: any HeimdallAPIClientProtocol,
        pollingInterval: TimeInterval = 5.0
    )

    public func start() async
    public func stop() async
    private func tryWebSocket() async -> Bool
    private func trySSE() async -> Bool
    private func startPolling() async
    private func handleEvent(_ event: WebSocketEvent)
}
```

**Fallback Strategy:**
1. Try WebSocket connection to `ws://host:7846/ws/events`
2. If WebSocket fails 3 times → fallback to SSE at `/api/events`
3. If SSE fails 3 times → fallback to REST polling
4. REST polling continues indefinitely (uses existing HeimdallAPIClient)

**Line estimates per function:**
- `start()`: 28 lines
- `stop()`: 12 lines
- `tryWebSocket()`: 22 lines
- `trySSE()`: 20 lines
- `startPolling()`: 24 lines
- `handleEvent()`: 15 lines

### 5. AppState (`AppState.swift`)

**Purpose:** Central observable state container for the entire app.

```swift
/// Central application state container
@MainActor
public final class AppState: ObservableObject {
    // Connection status
    @Published public var connectionStatus: ConnectionStatus = .disconnected

    // Live data from real-time events
    @Published public var pipelines: [PipelineEntry] = []
    @Published public var verdicts: [VerdictEntry] = []
    @Published public var agents: [AgentHeartbeat] = []
    @Published public var factoryStatus: FactoryStatus = .stalled

    // Services
    private let connectionManager: ConnectionManager

    public init(connectionManager: ConnectionManager)

    public func start() async
    public func stop() async

    // Called by ConnectionManager when events arrive
    internal func handleEvent(_ event: WebSocketEvent)
}
```

**Line estimates per function:**
- `init()`: 12 lines
- `start()`: 18 lines
- `stop()`: 10 lines
- `handleEvent()`: 28 lines

---

## Data Path Trace

### WebSocket Event Flow

1. **WebSocketService.receiveMessages()** (line ~60)
   - Calls `webSocketTask.receive()` in loop
   - Decodes `WebSocketEvent` from JSON `.string` message
   - Yields event to `AsyncStream<WebSocketEvent>`

2. **ConnectionManager.tryWebSocket()** (line ~45)
   - Awaits `for await event in webSocketService.events`
   - Calls `handleEvent(event)`

3. **ConnectionManager.handleEvent()** (line ~95)
   - Forwards event to `AppState` via callback or direct reference

4. **AppState.handleEvent()** (line ~55)
   - Pattern matches on `event.type`
   - Decodes type-specific payload from `event.payload`
   - Updates appropriate `@Published` property
   - SwiftUI views auto-refresh via Combine

### Fallback Chain Activation

1. **ConnectionManager.start()** (line ~25)
   - Calls `tryWebSocket()`
   - On success: remains in WebSocket mode
   - On failure: increments `webSocketRetries`

2. **ConnectionManager.tryWebSocket()** (line ~45)
   - Catches connection error after `maxRetries` (3)
   - Updates `status = .connecting(.sse)`
   - Calls `trySSE()`

3. **ConnectionManager.trySSE()** (line ~70)
   - Catches connection error after `maxRetries` (3)
   - Updates `status = .connecting(.restPolling)`
   - Calls `startPolling()`

4. **ConnectionManager.startPolling()** (line ~95)
   - Uses existing `HeimdallAPIClient.fetchPipeline()`
   - Polls every `pollingInterval` (5 seconds)
   - Wraps REST response in `WebSocketEvent` format
   - Continues indefinitely until `stop()` called

---

## Function Size Plan

All functions planned to be under 50 lines. Detailed breakdown:

| File | Function | Planned Lines | Notes |
|------|----------|---------------|-------|
| Event.swift | (models only) | N/A | No functions, just structs/enums |
| WebSocketService.swift | `init()` | 8 | Simple property initialization |
| WebSocketService.swift | `reconnectDelay()` | 8 | min(baseDelay * 2^attempt, maxDelay) |
| WebSocketService.swift | `connect()` | 22 | Create task, setup continuation |
| WebSocketService.swift | `disconnect()` | 12 | Cancel task, nil out references |
| WebSocketService.swift | `receiveMessages()` | 28 | Receive loop with decode |
| WebSocketService.swift | `scheduleReconnect()` | 18 | Delay + recursive connect |
| SSEService.swift | `init()` | 6 | Simple initialization |
| SSEService.swift | `connect()` | 20 | Setup bytes stream |
| SSEService.swift | `disconnect()` | 10 | Cancel task |
| SSEService.swift | `parseSSELine()` | 18 | Parse "data:" prefix, decode JSON |
| SSEService.swift | `processStream()` | 25 | Read lines, yield events |
| ConnectionManager.swift | `init()` | 10 | Store dependencies |
| ConnectionManager.swift | `start()` | 28 | Orchestrate fallback chain |
| ConnectionManager.swift | `stop()` | 12 | Cancel active task |
| ConnectionManager.swift | `tryWebSocket()` | 22 | Connect + handle events |
| ConnectionManager.swift | `trySSE()` | 20 | Connect + handle events |
| ConnectionManager.swift | `startPolling()` | 24 | Polling loop |
| ConnectionManager.swift | `handleEvent()` | 15 | Forward to AppState |
| AppState.swift | `init()` | 12 | Setup bindings |
| AppState.swift | `start()` | 18 | Start ConnectionManager |
| AppState.swift | `stop()` | 10 | Stop ConnectionManager |
| AppState.swift | `handleEvent()` | 28 | Switch on event type, update state |

**All functions ≤ 28 lines — well under 50-line limit.**

---

## Test Strategy

### File: `Tests/HEIMDALLControlSurfaceTests/ServiceTests.swift`

Replace placeholder test with comprehensive test suite:

**WebSocket Tests:**
```swift
@Suite("WebSocket Service Tests")
struct WebSocketServiceTests {
    @Test func connectsToValidURL() async throws
    @Test func yieldsEventsOnMessage() async throws
    @Test func exponentialBackoffCalculation() async throws
    @Test func maxReconnectDelayCapped() async throws
    @Test func disconnectCancelsTask() async throws
}
```

**SSE Tests:**
```swift
@Suite("SSE Service Tests")
struct SSEServiceTests {
    @Test func parsesDataLine() async throws
    @Test func ignoresCommentLines() async throws
    @Test func handlesMultilineData() async throws
}
```

**ConnectionManager Tests:**
```swift
@Suite("Connection Manager Tests")
struct ConnectionManagerTests {
    @Test func startsWithWebSocket() async throws
    @Test func fallsBackToSSEAfterRetries() async throws
    @Test func fallsBackToPollingAfterSSEFails() async throws
    @Test func reportsCorrectStatus() async throws
    @Test func stopCancelsActiveConnection() async throws
}
```

**AppState Tests:**
```swift
@Suite("AppState Tests")
struct AppStateTests {
    @Test func updatesOnFactoryEvent() async throws
    @Test func updatesOnVerdictEvent() async throws
    @Test func exposesConnectionStatus() async throws
}
```

### Mock Infrastructure

Create mocks for testing:

```swift
// In ServiceTests.swift
actor MockWebSocketService: WebSocketServiceProtocol {
    var shouldFail: Bool = false
    var eventsToYield: [WebSocketEvent] = []
    private(set) var state: WebSocketState = .disconnected

    var events: AsyncStream<WebSocketEvent> { ... }
    func connect() async throws { ... }
    func disconnect() async { ... }
}

actor MockSSEService: SSEServiceProtocol {
    var shouldFail: Bool = false
    var eventsToYield: [WebSocketEvent] = []
    private(set) var state: SSEState = .disconnected

    var events: AsyncStream<WebSocketEvent> { ... }
    func connect() async throws { ... }
    func disconnect() async { ... }
}
```

---

## Verification Plan

| Acceptance Criterion | Test Method | Verification |
|---------------------|-------------|--------------|
| WebSocket connects to ws://host:7846/ws/events | `@Test connectsToValidURL` | Mock verifies URL passed |
| Factory events update AppState | `@Test updatesOnFactoryEvent` | Check `@Published` property |
| Automatic reconnection with exponential backoff | `@Test exponentialBackoffCalculation` | Verify delays: 1s→2s→4s→...→30s |
| Graceful fallback to SSE | `@Test fallsBackToSSEAfterRetries` | Status changes after 3 WS failures |
| Graceful fallback to REST | `@Test fallsBackToPollingAfterSSEFails` | Status changes after 3 SSE failures |
| Connection status visible in AppState | `@Test exposesConnectionStatus` | Verify `connectionStatus` updates |
| No memory leaks | Manual | Verify weak refs, task cancellation |

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| URLSession WebSocket not available on older macOS | Target macOS 14+ (already in Package.swift) |
| Memory leaks from uncancelled tasks | Use structured concurrency, cancel in `disconnect()` |
| Race conditions in reconnect logic | Use actor isolation for WebSocketService/SSEService |
| Event payload schema mismatch | Use optional fields with defaults, log decode warnings |
| Connection manager state corruption | @MainActor isolation, single `activeTask` |

---

## Commit Plan

**Commit 1:** Event models (HCS-004)
- `Sources/HEIMDALLControlSurface/Models/Event.swift`

**Commit 2:** WebSocket service (HCS-004)
- `Sources/HEIMDALLControlSurface/Services/WebSocketService.swift`

**Commit 3:** SSE fallback (HCS-004)
- `Sources/HEIMDALLControlSurface/Services/SSEService.swift`

**Commit 4:** Connection manager + AppState (HCS-004)
- `Sources/HEIMDALLControlSurface/Services/ConnectionManager.swift`
- `Sources/HEIMDALLControlSurface/State/AppState.swift`

**Commit 5:** Tests (HCS-004)
- `Tests/HEIMDALLControlSurfaceTests/ServiceTests.swift`

Each commit ≤ 5 files per Rule 4.

---

## Execution Contract

```json
{
  "issue_ref": "HCS-004",
  "deliverables": [
    {
      "file": "Sources/HEIMDALLControlSurface/Models/Event.swift",
      "function": "",
      "change_description": "CREATE: WebSocket event models (EventType enum, WebSocketEvent struct, FactoryUpdatePayload, VerdictPayload, HeartbeatPayload)",
      "verification": "swift build compiles without errors"
    },
    {
      "file": "Sources/HEIMDALLControlSurface/Services/WebSocketService.swift",
      "function": "WebSocketService (actor)",
      "change_description": "CREATE: Actor-based WebSocket service with connect(), disconnect(), receiveMessages(), exponential backoff reconnection (1s→30s cap)",
      "verification": "@Test connectsToValidURL, @Test exponentialBackoffCalculation, @Test maxReconnectDelayCapped"
    },
    {
      "file": "Sources/HEIMDALLControlSurface/Services/SSEService.swift",
      "function": "SSEService (actor)",
      "change_description": "CREATE: Actor-based SSE fallback service with connect(), disconnect(), parseSSELine(), processStream()",
      "verification": "@Test parsesDataLine, @Test ignoresCommentLines"
    },
    {
      "file": "Sources/HEIMDALLControlSurface/Services/ConnectionManager.swift",
      "function": "ConnectionManager (@MainActor class)",
      "change_description": "CREATE: ObservableObject that orchestrates WebSocket → SSE → REST fallback with ConnectionStatus enum, maxRetries=3",
      "verification": "@Test fallsBackToSSEAfterRetries, @Test fallsBackToPollingAfterSSEFails, @Test reportsCorrectStatus"
    },
    {
      "file": "Sources/HEIMDALLControlSurface/State/AppState.swift",
      "function": "AppState (@MainActor class)",
      "change_description": "CREATE: Central ObservableObject with @Published properties for pipelines, verdicts, agents, factoryStatus, connectionStatus. handleEvent() dispatches by type.",
      "verification": "@Test updatesOnFactoryEvent, @Test updatesOnVerdictEvent, @Test exposesConnectionStatus"
    },
    {
      "file": "Tests/HEIMDALLControlSurfaceTests/ServiceTests.swift",
      "function": "",
      "change_description": "MODIFY: Replace placeholder with WebSocketServiceTests, SSEServiceTests, ConnectionManagerTests, AppStateTests suites. Add MockWebSocketService, MockSSEService.",
      "verification": "swift test passes all new tests"
    }
  ]
}
```
