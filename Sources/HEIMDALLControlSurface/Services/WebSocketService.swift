// Sources/HEIMDALLControlSurface/Services/WebSocketService.swift
// HCS-004: URLSession WebSocket service with exponential backoff reconnection

import Foundation

// MARK: - Connection State

/// Connection state for WebSocket
public enum WebSocketState: Sendable, Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting(attempt: Int)
}

// MARK: - Protocol

/// Protocol for WebSocket service (enables mocking)
public protocol WebSocketServiceProtocol: Sendable {
    func connect() async throws
    func disconnect() async
    var events: AsyncStream<WebSocketEvent> { get }
    var state: WebSocketState { get async }
}

// MARK: - WebSocket Service

/// URLSession-based WebSocket service with exponential backoff
public actor WebSocketService: WebSocketServiceProtocol {
    private let url: URL
    private let session: URLSession
    private var webSocketTask: URLSessionWebSocketTask?
    private var reconnectAttempt: Int = 0
    private let maxReconnectDelay: TimeInterval = 30.0
    private let baseDelay: TimeInterval = 1.0
    private let maxRetries: Int = 10

    private var _state: WebSocketState = .disconnected
    public var state: WebSocketState { _state }

    private var eventContinuation: AsyncStream<WebSocketEvent>.Continuation?
    public let events: AsyncStream<WebSocketEvent>

    public init(url: URL, session: URLSession = .shared) {
        self.url = url
        self.session = session
        var continuation: AsyncStream<WebSocketEvent>.Continuation?
        self.events = AsyncStream { continuation = $0 }
        self.eventContinuation = continuation
    }

    // MARK: - Public Methods

    public func connect() async throws {
        guard _state == .disconnected || isReconnecting() else { return }
        _state = .connecting
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        _state = .connected
        reconnectAttempt = 0
        await receiveMessages()
    }

    public func disconnect() async {
        _state = .disconnected
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        reconnectAttempt = 0
    }

    // MARK: - Private Methods

    private func isReconnecting() -> Bool {
        if case .reconnecting = _state { return true }
        return false
    }

    /// Calculate exponential backoff delay: 1s -> 2s -> 4s -> ... -> 30s (capped)
    func reconnectDelay() -> TimeInterval {
        let delay = baseDelay * pow(2.0, Double(reconnectAttempt))
        return min(delay, maxReconnectDelay)
    }

    private func receiveMessages() async {
        guard let task = webSocketTask else { return }
        while _state == .connected {
            do {
                let message = try await task.receive()
                if let event = parseMessage(message) {
                    eventContinuation?.yield(event)
                }
            } catch {
                await handleReceiveError(error)
                return
            }
        }
    }

    private func parseMessage(_ message: URLSessionWebSocketTask.Message) -> WebSocketEvent? {
        switch message {
        case .string(let text):
            guard let data = text.data(using: .utf8) else { return nil }
            return decodeEvent(from: data)
        case .data(let data):
            return decodeEvent(from: data)
        @unknown default:
            return nil
        }
    }

    private func decodeEvent(from data: Data) -> WebSocketEvent? {
        let decoder = JSONDecoder.heimdallDecoder()
        do {
            return try decoder.decode(WebSocketEvent.self, from: data)
        } catch {
            // Log warning but continue receiving
            print("[WebSocket] Failed to decode event: \(error)")
            return nil
        }
    }

    private func handleReceiveError(_ error: Error) async {
        guard _state == .connected else { return }
        _state = .disconnected
        await scheduleReconnect()
    }

    private func scheduleReconnect() async {
        guard reconnectAttempt < maxRetries else {
            _state = .disconnected
            eventContinuation?.finish()
            return
        }
        reconnectAttempt += 1
        _state = .reconnecting(attempt: reconnectAttempt)
        let delay = reconnectDelay()
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        guard _state != .disconnected else { return }
        do {
            try await connect()
        } catch {
            await scheduleReconnect()
        }
    }
}
