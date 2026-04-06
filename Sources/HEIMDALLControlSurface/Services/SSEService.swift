// Sources/HEIMDALLControlSurface/Services/SSEService.swift
// HCS-004: Server-Sent Events fallback service

import Foundation

// MARK: - SSE State

/// SSE connection state
public enum SSEState: Sendable, Equatable {
    case disconnected
    case connecting
    case connected
}

// MARK: - Protocol

/// Protocol for SSE service (enables mocking)
public protocol SSEServiceProtocol: Sendable {
    func connect() async throws
    func disconnect() async
    var events: AsyncStream<WebSocketEvent> { get }
    var state: SSEState { get async }
}

// MARK: - SSE Errors

/// Errors that can occur during SSE operations
public enum SSEError: Error, Sendable {
    case invalidURL
    case connectionFailed
    case invalidResponse
}

// MARK: - SSE Service

/// URLSession-based SSE (Server-Sent Events) service
public actor SSEService: SSEServiceProtocol {
    private let url: URL
    private let session: URLSession
    private var streamTask: Task<Void, Never>?

    private var _state: SSEState = .disconnected
    public var state: SSEState { _state }

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
        guard _state == .disconnected else { return }
        _state = .connecting
        var request = URLRequest(url: url)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        let (bytes, response) = try await session.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            _state = .disconnected
            throw SSEError.invalidResponse
        }
        _state = .connected
        streamTask = Task { await processStream(bytes) }
    }

    public func disconnect() async {
        _state = .disconnected
        streamTask?.cancel()
        streamTask = nil
    }

    // MARK: - Private Methods

    private func processStream(_ bytes: URLSession.AsyncBytes) async {
        var buffer = ""
        do {
            for try await byte in bytes {
                guard !Task.isCancelled, _state == .connected else { break }
                let char = Character(UnicodeScalar(byte))
                if char == "\n" {
                    if let event = parseSSELine(buffer) {
                        eventContinuation?.yield(event)
                    }
                    buffer = ""
                } else {
                    buffer.append(char)
                }
            }
        } catch {
            // Connection closed or error occurred
        }
        if _state == .connected {
            _state = .disconnected
        }
    }

    private func parseSSELine(_ line: String) -> WebSocketEvent? {
        // SSE format: "data: {...json...}"
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        // Ignore empty lines and comments
        guard !trimmed.isEmpty, !trimmed.hasPrefix(":") else {
            return nil
        }
        // Parse "data:" prefix
        guard trimmed.hasPrefix("data:") else {
            return nil
        }
        let jsonStart = trimmed.index(trimmed.startIndex, offsetBy: 5)
        let jsonString = String(trimmed[jsonStart...]).trimmingCharacters(in: .whitespaces)
        guard let data = jsonString.data(using: .utf8) else {
            return nil
        }
        return decodeEvent(from: data)
    }

    private func decodeEvent(from data: Data) -> WebSocketEvent? {
        let decoder = JSONDecoder.heimdallDecoder()
        do {
            return try decoder.decode(WebSocketEvent.self, from: data)
        } catch {
            print("[SSE] Failed to decode event: \(error)")
            return nil
        }
    }
}
