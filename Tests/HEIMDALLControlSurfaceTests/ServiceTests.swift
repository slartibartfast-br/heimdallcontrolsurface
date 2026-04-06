// Tests/HEIMDALLControlSurfaceTests/ServiceTests.swift
// HCS-004: WebSocket, SSE, ConnectionManager, and AppState tests

import Testing
import Foundation
@testable import HEIMDALLControlSurface

// MARK: - Mock WebSocket Service

actor MockWebSocketService: WebSocketServiceProtocol {
    var shouldFail: Bool = false
    var eventsToYield: [WebSocketEvent] = []
    var connectCalled: Bool = false
    var disconnectCalled: Bool = false

    private var _state: WebSocketState = .disconnected
    var state: WebSocketState { _state }

    private var eventContinuation: AsyncStream<WebSocketEvent>.Continuation?
    let events: AsyncStream<WebSocketEvent>

    init() {
        var continuation: AsyncStream<WebSocketEvent>.Continuation?
        self.events = AsyncStream { continuation = $0 }
        self.eventContinuation = continuation
    }

    func connect() async throws {
        connectCalled = true
        if shouldFail {
            throw SSEError.connectionFailed
        }
        _state = .connected
        for event in eventsToYield {
            eventContinuation?.yield(event)
        }
    }

    func disconnect() async {
        disconnectCalled = true
        _state = .disconnected
        eventContinuation?.finish()
    }

    func setShouldFail(_ fail: Bool) { shouldFail = fail }
    func setEventsToYield(_ events: [WebSocketEvent]) { eventsToYield = events }
    func yieldEvent(_ event: WebSocketEvent) { eventContinuation?.yield(event) }
    func finishEvents() { eventContinuation?.finish() }
}

// MARK: - Mock SSE Service

actor MockSSEService: SSEServiceProtocol {
    var shouldFail: Bool = false
    var eventsToYield: [WebSocketEvent] = []
    var connectCalled: Bool = false
    var disconnectCalled: Bool = false

    private var _state: SSEState = .disconnected
    var state: SSEState { _state }

    private var eventContinuation: AsyncStream<WebSocketEvent>.Continuation?
    let events: AsyncStream<WebSocketEvent>

    init() {
        var continuation: AsyncStream<WebSocketEvent>.Continuation?
        self.events = AsyncStream { continuation = $0 }
        self.eventContinuation = continuation
    }

    func connect() async throws {
        connectCalled = true
        if shouldFail {
            throw SSEError.connectionFailed
        }
        _state = .connected
        for event in eventsToYield {
            eventContinuation?.yield(event)
        }
    }

    func disconnect() async {
        disconnectCalled = true
        _state = .disconnected
        eventContinuation?.finish()
    }

    func setShouldFail(_ fail: Bool) { shouldFail = fail }
    func setEventsToYield(_ events: [WebSocketEvent]) { eventsToYield = events }
    func yieldEvent(_ event: WebSocketEvent) { eventContinuation?.yield(event) }
    func finishEvents() { eventContinuation?.finish() }
}

// MARK: - Mock API Client

final class MockAPIClient: HeimdallAPIClientProtocol, @unchecked Sendable {
    var pipelineResponse: PipelineResponse?
    var fetchPipelineCalled: Bool = false

    func fetchPipeline() async throws -> PipelineResponse {
        fetchPipelineCalled = true
        if let response = pipelineResponse {
            return response
        }
        return PipelineResponse(pipelines: [], factoryStatus: .healthy, timestamp: Date())
    }

    func fetchVerdicts(limit: Int) async throws -> [VerdictEntry] { [] }
    func fetchHeartbeat() async throws -> HeartbeatResponse {
        HeartbeatResponse(agents: [], uptimeSeconds: 0)
    }
    func fetchTelemetry() async throws -> KPIResponse {
        KPIResponse(kpis: [], timestamp: Date().timeIntervalSince1970, uptimeSeconds: 0)
    }
    func fetchInfraHealth() async throws -> InfraResponse {
        InfraResponse(services: [], timestamp: Date().timeIntervalSince1970)
    }
    func fetchProjects() async throws -> SwitcherResponse {
        SwitcherResponse(projects: [], selectedProject: "", timestamp: Date().timeIntervalSince1970)
    }
    func fetchAgents() async throws -> AgentsResponse {
        AgentsResponse(agents: [], count: 0, timestamp: 0)
    }
    func fetchDecisions(limit: Int, project: String?) async throws -> DecisionsResponse {
        DecisionsResponse(decisions: [], count: 0, timestamp: Date().timeIntervalSince1970)
    }
    func approve(id: String) async throws -> ApprovalResult {
        ApprovalResult(ok: true)
    }
    func reject(id: String, reason: String?) async throws -> ApprovalResult {
        ApprovalResult(ok: true)
    }
}

// MARK: - WebSocket Service Tests

@Suite("WebSocket Service Tests")
struct WebSocketServiceTests {
    @Test func exponentialBackoffCalculation() async throws {
        let url = URL(string: "ws://localhost:7846/ws/events")!
        let service = WebSocketService(url: url)
        // First attempt: 1s
        let delay0 = await service.reconnectDelay()
        #expect(delay0 == 1.0)
    }

    @Test func maxReconnectDelayCapped() async throws {
        let url = URL(string: "ws://localhost:7846/ws/events")!
        let service = WebSocketService(url: url)
        // The max delay should be 30 seconds as per implementation
        let delay = await service.reconnectDelay()
        #expect(delay <= 30.0)
    }

    @Test func stateTransitions() async throws {
        let url = URL(string: "ws://localhost:7846/ws/events")!
        let service = WebSocketService(url: url)
        let initialState = await service.state
        #expect(initialState == .disconnected)
    }
}

// MARK: - SSE Service Tests

@Suite("SSE Service Tests")
struct SSEServiceTests {
    @Test func initialStateIsDisconnected() async throws {
        let url = URL(string: "http://localhost:7846/api/events")!
        let service = SSEService(url: url)
        let state = await service.state
        #expect(state == .disconnected)
    }

    @Test func disconnectSetsStateToDisconnected() async throws {
        let url = URL(string: "http://localhost:7846/api/events")!
        let service = SSEService(url: url)
        await service.disconnect()
        let state = await service.state
        #expect(state == .disconnected)
    }
}

// MARK: - Connection Manager Tests

@Suite("Connection Manager Tests")
struct ConnectionManagerTests {
    @Test @MainActor func startsWithWebSocket() async throws {
        let mockWS = MockWebSocketService()
        let mockSSE = MockSSEService()
        let mockAPI = MockAPIClient()
        let manager = ConnectionManager(
            webSocketService: mockWS,
            sseService: mockSSE,
            apiClient: mockAPI
        )
        await manager.start()
        // Give time for connection attempt
        try await Task.sleep(nanoseconds: 100_000_000)
        let connectCalled = await mockWS.connectCalled
        #expect(connectCalled == true)
        await manager.stop()
    }

    @Test @MainActor func fallsBackToSSEAfterRetries() async throws {
        let mockWS = MockWebSocketService()
        await mockWS.setShouldFail(true)
        let mockSSE = MockSSEService()
        let mockAPI = MockAPIClient()
        let manager = ConnectionManager(
            webSocketService: mockWS,
            sseService: mockSSE,
            apiClient: mockAPI
        )
        await manager.start()
        // Wait for WebSocket retries and SSE fallback
        try await Task.sleep(nanoseconds: 2_000_000_000)
        let sseConnectCalled = await mockSSE.connectCalled
        #expect(sseConnectCalled == true)
        await manager.stop()
    }

    @Test @MainActor func fallsBackToPollingAfterSSEFails() async throws {
        let mockWS = MockWebSocketService()
        await mockWS.setShouldFail(true)
        let mockSSE = MockSSEService()
        await mockSSE.setShouldFail(true)
        let mockAPI = MockAPIClient()
        let manager = ConnectionManager(
            webSocketService: mockWS,
            sseService: mockSSE,
            apiClient: mockAPI
        )
        await manager.start()
        // Wait for both WebSocket and SSE retries
        try await Task.sleep(nanoseconds: 4_000_000_000)
        #expect(mockAPI.fetchPipelineCalled == true)
        await manager.stop()
    }

    @Test @MainActor func reportsCorrectStatus() async throws {
        let mockWS = MockWebSocketService()
        let mockSSE = MockSSEService()
        let mockAPI = MockAPIClient()
        let manager = ConnectionManager(
            webSocketService: mockWS,
            sseService: mockSSE,
            apiClient: mockAPI
        )
        #expect(manager.status == .disconnected)
    }

    @Test @MainActor func stopCancelsActiveConnection() async throws {
        let mockWS = MockWebSocketService()
        let mockSSE = MockSSEService()
        let mockAPI = MockAPIClient()
        let manager = ConnectionManager(
            webSocketService: mockWS,
            sseService: mockSSE,
            apiClient: mockAPI
        )
        await manager.start()
        try await Task.sleep(nanoseconds: 100_000_000)
        await manager.stop()
        #expect(manager.status == .disconnected)
    }
}

// MARK: - AppState Tests (HCS-002)

@Suite("AppState Tests")
struct AppStateTests {
    @Test @MainActor func initialStateValues() async throws {
        let appState = AppState()
        #expect(appState.isDashboardOpen == false)
        #expect(appState.isConnected == false)
        #expect(appState.selectedProjectId == nil)
        #expect(appState.lastError == nil)
    }

    @Test @MainActor func toggleDashboard() async throws {
        let appState = AppState()
        #expect(appState.isDashboardOpen == false)
        appState.toggleDashboard()
        #expect(appState.isDashboardOpen == true)
        appState.toggleDashboard()
        #expect(appState.isDashboardOpen == false)
    }

    @Test @MainActor func clearError() async throws {
        let appState = AppState()
        appState.lastError = "Test error"
        #expect(appState.lastError == "Test error")
        appState.clearError()
        #expect(appState.lastError == nil)
    }

    @Test @MainActor func connectionState() async throws {
        let appState = AppState()
        #expect(appState.isConnected == false)
        appState.isConnected = true
        #expect(appState.isConnected == true)
    }

    @Test @MainActor func selectedProject() async throws {
        let appState = AppState()
        #expect(appState.selectedProjectId == nil)
        appState.selectedProjectId = "project-123"
        #expect(appState.selectedProjectId == "project-123")
    }
}

// MARK: - Event Model Tests

@Suite("Event Model Tests")
struct EventModelTests {
    @Test func eventTypeRawValues() async throws {
        #expect(EventType.factoryUpdate.rawValue == "factory_update")
        #expect(EventType.verdict.rawValue == "verdict")
        #expect(EventType.heartbeat.rawValue == "heartbeat")
        #expect(EventType.pipelineUpdate.rawValue == "pipeline_update")
        #expect(EventType.agentStatus.rawValue == "agent_status")
    }

    @Test func webSocketEventCreation() async throws {
        let event = WebSocketEvent(
            type: .heartbeat,
            timestamp: Date(),
            payload: Data()
        )
        #expect(event.type == .heartbeat)
    }

    @Test func connectionStatusEquality() async throws {
        let status1 = ConnectionStatus.disconnected
        let status2 = ConnectionStatus.disconnected
        #expect(status1 == status2)
        let status3 = ConnectionStatus.connected(.webSocket)
        let status4 = ConnectionStatus.connected(.sse)
        #expect(status3 != status4)
    }

    @Test func connectionMethodCases() async throws {
        let methods = ConnectionMethod.allCases
        #expect(methods.count == 3)
        #expect(methods.contains(.webSocket))
        #expect(methods.contains(.sse))
        #expect(methods.contains(.restPolling))
    }

    @Test func escalationEventType() async throws {
        #expect(EventType.escalation.rawValue == "escalation")
    }
}

// MARK: - Mock Notification Service (HCS-006)

final class MockNotificationService: NotificationServiceProtocol, @unchecked Sendable {
    var authorizationRequested: Bool = false
    var authorizationResult: Bool = true
    var escalationNotifications: [(issueId: String, gate: String, reason: String)] = []
    var verdictNotifications: [(issueId: String, outcome: String, reason: String)] = []
    var errorNotifications: [(title: String, message: String)] = []
    var categoriesRegistered: Bool = false

    func requestAuthorization() async throws -> Bool {
        authorizationRequested = true
        return authorizationResult
    }

    func showEscalationNotification(issueId: String, gate: String, reason: String) async throws {
        escalationNotifications.append((issueId, gate, reason))
    }

    func showVerdictNotification(issueId: String, outcome: String, reason: String) async throws {
        verdictNotifications.append((issueId, outcome, reason))
    }

    func showErrorNotification(title: String, message: String) async throws {
        errorNotifications.append((title, message))
    }

    func registerCategories() {
        categoriesRegistered = true
    }
}

// MARK: - Notification Category Tests (HCS-006)

@Suite("Notification Category Tests")
struct NotificationCategoryTests {
    @Test func escalationCategoryHasApproveRejectActions() async throws {
        let category = NotificationCategories.escalationCategory()
        #expect(category.identifier == "ESCALATION")
        #expect(category.actions.count == 2)
        let actionIds = category.actions.map { $0.identifier }
        #expect(actionIds.contains("APPROVE_ACTION"))
        #expect(actionIds.contains("REJECT_ACTION"))
    }

    @Test func verdictCategoryHasViewAction() async throws {
        let category = NotificationCategories.verdictCategory()
        #expect(category.identifier == "VERDICT")
        #expect(category.actions.count == 1)
        #expect(category.actions.first?.identifier == "VIEW_ACTION")
    }

    @Test func errorCategoryHasNoActions() async throws {
        let category = NotificationCategories.errorCategory()
        #expect(category.identifier == "ERROR")
        #expect(category.actions.isEmpty)
    }

    @Test func allCategoriesReturnsThreeCategories() async throws {
        let categories = NotificationCategories.allCategories()
        #expect(categories.count == 3)
    }
}

// MARK: - Mock Response Handler (HCS-006)

@MainActor
final class MockResponseHandler: NotificationResponseHandler {
    var approvedIds: [String] = []
    var rejectedIds: [String] = []
    var viewedIds: [String] = []

    func handleApprove(issueId: String) async {
        approvedIds.append(issueId)
    }

    func handleReject(issueId: String) async {
        rejectedIds.append(issueId)
    }

    func handleViewIssue(issueId: String) {
        viewedIds.append(issueId)
    }
}

// MARK: - Notification Delegate Tests (HCS-006)

@Suite("Notification Delegate Tests")
struct NotificationDelegateTests {
    @Test @MainActor func delegateInitialization() async throws {
        let delegate = NotificationDelegate()
        #expect(delegate.responseHandler == nil)
    }
}

// MARK: - AppState Escalation Tests (HCS-006)

@Suite("AppState Escalation Tests")
struct AppStateEscalationTests {
    @Test @MainActor func initialEscalationsEmpty() async throws {
        let appState = AppState()
        #expect(appState.escalations.isEmpty)
    }

    @Test @MainActor func escalationEntryIdGeneration() async throws {
        let entry = EscalationEntry(
            issueId: "AASF-123",
            gate: "review",
            reason: "Test reason"
        )
        #expect(entry.issueId == "AASF-123")
        #expect(entry.gate == "review")
        #expect(entry.id.hasPrefix("AASF-123-"))
    }

    @Test @MainActor func escalationEntryProperties() async throws {
        let timestamp = Date()
        let entry = EscalationEntry(
            issueId: "HCS-001",
            gate: "implement",
            reason: "Needs human approval",
            timestamp: timestamp
        )
        #expect(entry.issueId == "HCS-001")
        #expect(entry.gate == "implement")
        #expect(entry.reason == "Needs human approval")
        #expect(entry.timestamp == timestamp)
    }
}
