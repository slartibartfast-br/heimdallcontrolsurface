// Sources/HEIMDALLControlSurface/Services/ConnectionManager.swift
// HCS-004: Connection orchestrator with WebSocket -> SSE -> REST fallback

import Foundation

// MARK: - Connection Status

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

// MARK: - Event Handler Protocol

/// Protocol for receiving events from ConnectionManager
public protocol ConnectionEventHandler: AnyObject, Sendable {
    @MainActor func handleEvent(_ event: WebSocketEvent)
}

// MARK: - Connection Manager

/// Manages connection fallback chain: WebSocket -> SSE -> REST polling
@MainActor
public final class ConnectionManager: ObservableObject, Sendable {
    @Published public private(set) var status: ConnectionStatus = .disconnected

    private let webSocketService: any WebSocketServiceProtocol
    private let sseService: any SSEServiceProtocol
    private let apiClient: any HeimdallAPIClientProtocol
    private let pollingInterval: TimeInterval

    private var activeTask: Task<Void, Never>?
    private var webSocketRetries: Int = 0
    private var sseRetries: Int = 0
    private let maxRetries: Int = 3

    public weak var eventHandler: (any ConnectionEventHandler)?

    public init(
        webSocketService: any WebSocketServiceProtocol,
        sseService: any SSEServiceProtocol,
        apiClient: any HeimdallAPIClientProtocol,
        pollingInterval: TimeInterval = 5.0
    ) {
        self.webSocketService = webSocketService
        self.sseService = sseService
        self.apiClient = apiClient
        self.pollingInterval = pollingInterval
    }

    // MARK: - Public Methods

    public func start() async {
        guard activeTask == nil else { return }
        webSocketRetries = 0
        sseRetries = 0
        activeTask = Task { await runConnectionLoop() }
    }

    public func stop() async {
        activeTask?.cancel()
        activeTask = nil
        await disconnectAll()
        status = .disconnected
    }

    // MARK: - Private Methods

    private func runConnectionLoop() async {
        // Try WebSocket first
        if await tryWebSocket() { return }
        // Fallback to SSE
        if await trySSE() { return }
        // Last resort: REST polling
        await startPolling()
    }

    private func disconnectAll() async {
        await webSocketService.disconnect()
        await sseService.disconnect()
    }

    private func tryWebSocket() async -> Bool {
        while webSocketRetries < maxRetries {
            status = .connecting(.webSocket)
            do {
                try await webSocketService.connect()
                status = .connected(.webSocket)
                await consumeWebSocketEvents()
                return true
            } catch {
                webSocketRetries += 1
                status = .reconnecting(.webSocket, attempt: webSocketRetries)
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
        return false
    }

    private func consumeWebSocketEvents() async {
        for await event in webSocketService.events {
            guard !Task.isCancelled else { break }
            handleEvent(event)
        }
    }

    private func trySSE() async -> Bool {
        while sseRetries < maxRetries {
            status = .connecting(.sse)
            do {
                try await sseService.connect()
                status = .connected(.sse)
                await consumeSSEEvents()
                return true
            } catch {
                sseRetries += 1
                status = .reconnecting(.sse, attempt: sseRetries)
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
        return false
    }

    private func consumeSSEEvents() async {
        for await event in sseService.events {
            guard !Task.isCancelled else { break }
            handleEvent(event)
        }
    }

    private func startPolling() async {
        status = .connected(.restPolling)
        while !Task.isCancelled {
            do {
                let response = try await apiClient.fetchPipeline()
                let event = createFactoryEvent(from: response)
                handleEvent(event)
            } catch {
                status = .failed("Polling error: \(error.localizedDescription)")
            }
            try? await Task.sleep(nanoseconds: UInt64(pollingInterval * 1_000_000_000))
        }
    }

    private func createFactoryEvent(from response: PipelineResponse) -> WebSocketEvent {
        let payload = FactoryUpdatePayload(
            factoryStatus: response.factoryStatus,
            pipelines: response.pipelines
        )
        let payloadData = (try? JSONEncoder().encode(payload)) ?? Data()
        return WebSocketEvent(type: .factoryUpdate, timestamp: response.timestamp, payload: payloadData)
    }

    private func handleEvent(_ event: WebSocketEvent) {
        eventHandler?.handleEvent(event)
    }
}
