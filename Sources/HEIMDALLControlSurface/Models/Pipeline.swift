// Sources/HEIMDALLControlSurface/Models/Pipeline.swift
// AASF-647: HEIMDALL API Client Models

import Foundation

/// Pipeline execution status
public enum PipelineStatus: String, Codable, Sendable {
    case running, blocked, idle, stalled
}

/// Factory-wide health status
public enum FactoryStatus: String, Codable, Sendable {
    case healthy, degraded, stalled
}

/// Single pipeline entry from /api/pipeline
public struct PipelineEntry: Codable, Sendable, Identifiable {
    public let issueId: String
    public let phase: String
    public let agent: String
    public let status: PipelineStatus
    public let startedAt: Date
    public let lastHeartbeat: Date

    enum CodingKeys: String, CodingKey {
        case issueId = "issue_id"
        case phase, agent, status
        case startedAt = "started_at"
        case lastHeartbeat = "last_heartbeat"
    }

    public var id: String { issueId }

    public init(
        issueId: String,
        phase: String,
        agent: String,
        status: PipelineStatus,
        startedAt: Date,
        lastHeartbeat: Date
    ) {
        self.issueId = issueId
        self.phase = phase
        self.agent = agent
        self.status = status
        self.startedAt = startedAt
        self.lastHeartbeat = lastHeartbeat
    }
}

/// Full pipeline response from /api/pipeline
public struct PipelineResponse: Codable, Sendable {
    public let pipelines: [PipelineEntry]
    public let factoryStatus: FactoryStatus
    public let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case pipelines
        case factoryStatus = "factory_status"
        case timestamp
    }

    public init(
        pipelines: [PipelineEntry],
        factoryStatus: FactoryStatus,
        timestamp: Date
    ) {
        self.pipelines = pipelines
        self.factoryStatus = factoryStatus
        self.timestamp = timestamp
    }
}
