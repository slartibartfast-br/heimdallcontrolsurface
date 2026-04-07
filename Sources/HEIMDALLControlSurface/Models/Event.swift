// Sources/HEIMDALLControlSurface/Models/Event.swift
// HCS-004: WebSocket event models for real-time updates

import Foundation

// MARK: - Event Types

/// Event types matching HEIMDALL monitor backend
public enum EventType: String, Codable, Sendable, CaseIterable {
    case factoryUpdate = "factory_update"
    case verdict = "verdict"
    case heartbeat = "heartbeat"
    case pipelineUpdate = "pipeline_update"
    case agentStatus = "agent_status"
    case escalation = "escalation"  // HCS-006: explicit escalation events
}

/// Event severity for filtering and display (HCS-007)
public enum EventSeverity: String, Codable, Sendable, CaseIterable {
    case info
    case warning
    case error
    case critical
}

// MARK: - WebSocket Event Wrapper

/// Wrapper for all WebSocket events with type-safe payload access
public struct WebSocketEvent: Codable, Sendable, Identifiable {
    public let id: UUID
    public let type: EventType
    public let timestamp: Date
    public let payload: Data  // Raw JSON for type-specific decoding

    enum CodingKeys: String, CodingKey {
        case id, type, timestamp, payload
    }

    public init(
        id: UUID = UUID(),
        type: EventType,
        timestamp: Date = Date(),
        payload: Data
    ) {
        self.id = id
        self.type = type
        self.timestamp = timestamp
        self.payload = payload
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.type = try container.decode(EventType.self, forKey: .type)
        self.timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date()
        // Store raw payload JSON as Data
        if let payloadData = try? container.decode(AnyCodable.self, forKey: .payload) {
            self.payload = (try? JSONEncoder().encode(payloadData)) ?? Data()
        } else {
            self.payload = Data()
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(timestamp, forKey: .timestamp)
        if let payloadValue = try? JSONDecoder().decode(AnyCodable.self, from: payload) {
            try container.encode(payloadValue, forKey: .payload)
        }
    }
}

// MARK: - Type-Specific Payloads

/// Payload for factory_update events
public struct FactoryUpdatePayload: Codable, Sendable {
    public let factoryStatus: FactoryStatus
    public let pipelines: [PipelineEntry]

    enum CodingKeys: String, CodingKey {
        case factoryStatus = "factory_status"
        case pipelines
    }

    public init(factoryStatus: FactoryStatus, pipelines: [PipelineEntry]) {
        self.factoryStatus = factoryStatus
        self.pipelines = pipelines
    }
}

/// Payload for verdict events
public struct VerdictPayload: Codable, Sendable {
    public let verdict: VerdictEntry

    public init(verdict: VerdictEntry) {
        self.verdict = verdict
    }
}

/// Payload for heartbeat events
public struct HeartbeatPayload: Codable, Sendable {
    public let agents: [AgentHeartbeat]
    public let uptimeSeconds: Int

    enum CodingKeys: String, CodingKey {
        case agents
        case uptimeSeconds = "uptime_seconds"
    }

    public init(agents: [AgentHeartbeat], uptimeSeconds: Int) {
        self.agents = agents
        self.uptimeSeconds = uptimeSeconds
    }
}

/// Payload for pipeline_update events
public struct PipelineUpdatePayload: Codable, Sendable {
    public let pipeline: PipelineEntry

    public init(pipeline: PipelineEntry) {
        self.pipeline = pipeline
    }
}

/// Payload for agent_status events
public struct AgentStatusPayload: Codable, Sendable {
    public let agent: AgentHeartbeat

    public init(agent: AgentHeartbeat) {
        self.agent = agent
    }
}

// MARK: - Payload Extraction

extension WebSocketEvent {
    /// Decode the payload as a specific type
    public func decodePayload<T: Decodable>(as type: T.Type) throws -> T {
        let decoder = JSONDecoder.heimdallDecoder()
        return try decoder.decode(T.self, from: payload)
    }

    /// Extract factory update payload
    public func factoryUpdatePayload() throws -> FactoryUpdatePayload {
        try decodePayload(as: FactoryUpdatePayload.self)
    }

    /// Extract verdict payload
    public func verdictPayload() throws -> VerdictPayload {
        try decodePayload(as: VerdictPayload.self)
    }

    /// Extract heartbeat payload
    public func heartbeatPayload() throws -> HeartbeatPayload {
        try decodePayload(as: HeartbeatPayload.self)
    }
}

// MARK: - Severity Inference (HCS-007)

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

// MARK: - Project Extraction (HCS-007)

extension WebSocketEvent {
    /// Extract project code from event payload (e.g., "AASF" from "AASF-123")
    public var projectCode: String? {
        extractIssueId().flatMap { Self.extractProjectCode(from: $0) }
    }

    /// Extract issue ID from various payload types
    private func extractIssueId() -> String? {
        switch type {
        case .verdict, .escalation:
            return (try? verdictPayload())?.verdict.issueId
        case .pipelineUpdate:
            return (try? decodePayload(as: PipelineUpdatePayload.self))?.pipeline.issueId
        case .factoryUpdate:
            return (try? factoryUpdatePayload())?.pipelines.first?.issueId
        case .agentStatus:
            return nil  // Agent status is not project-specific
        case .heartbeat:
            return nil  // Heartbeat is not project-specific
        }
    }

    /// Extract project code prefix from issue ID (e.g., "AASF-123" → "AASF")
    static func extractProjectCode(from issueId: String) -> String? {
        let parts = issueId.split(separator: "-")
        guard parts.count >= 2, let first = parts.first else { return nil }
        return String(first)
    }
}

// MARK: - AnyCodable Helper

/// Type-erased Codable wrapper for handling arbitrary JSON
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if container.decodeNil() {
            value = NSNull()
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported type"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let string as String:
            try container.encode(string)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        case is NSNull:
            try container.encodeNil()
        default:
            try container.encodeNil()
        }
    }
}
