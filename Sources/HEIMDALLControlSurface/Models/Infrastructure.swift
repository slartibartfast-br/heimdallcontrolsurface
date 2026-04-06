// Sources/HEIMDALLControlSurface/Models/Infrastructure.swift
// AASF-647: HEIMDALL API Client Models

import Foundation

/// Service health status
public enum ServiceHealthStatus: String, Codable, Sendable {
    case healthy, degraded, unhealthy, unknown
}

/// Individual service health entry
public struct ServiceHealth: Codable, Sendable, Identifiable {
    public let name: String
    public let status: ServiceHealthStatus
    public let latencyMs: Double?
    public let lastCheck: Date?
    public let message: String?

    public var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name, status
        case latencyMs = "latency_ms"
        case lastCheck = "last_check"
        case message
    }

    public init(
        name: String,
        status: ServiceHealthStatus,
        latencyMs: Double? = nil,
        lastCheck: Date? = nil,
        message: String? = nil
    ) {
        self.name = name
        self.status = status
        self.latencyMs = latencyMs
        self.lastCheck = lastCheck
        self.message = message
    }
}

/// Infrastructure health response
public struct InfraResponse: Codable, Sendable {
    public let services: [ServiceHealth]
    public let timestamp: Double

    public init(services: [ServiceHealth], timestamp: Double) {
        self.services = services
        self.timestamp = timestamp
    }
}

/// Decision ledger entry
public struct DecisionEntry: Codable, Sendable, Identifiable {
    public let id: String
    public let issueRef: String
    public let agent: String
    public let decision: String
    public let rationale: String
    public let ts: String

    enum CodingKeys: String, CodingKey {
        case id
        case issueRef = "issue_ref"
        case agent, decision, rationale, ts
    }

    public init(
        id: String,
        issueRef: String,
        agent: String,
        decision: String,
        rationale: String,
        ts: String
    ) {
        self.id = id
        self.issueRef = issueRef
        self.agent = agent
        self.decision = decision
        self.rationale = rationale
        self.ts = ts
    }
}

/// Decisions response
public struct DecisionsResponse: Codable, Sendable {
    public let decisions: [DecisionEntry]
    public let count: Int
    public let project: String?
    public let timestamp: Double

    public init(
        decisions: [DecisionEntry],
        count: Int,
        project: String? = nil,
        timestamp: Double
    ) {
        self.decisions = decisions
        self.count = count
        self.project = project
        self.timestamp = timestamp
    }
}
