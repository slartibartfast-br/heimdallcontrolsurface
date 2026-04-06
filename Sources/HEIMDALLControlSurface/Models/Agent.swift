// Sources/HEIMDALLControlSurface/Models/Agent.swift
// AASF-647: HEIMDALL API Client Models

import Foundation

/// Agent online status
public enum AgentStatus: String, Codable, Sendable {
    case active, idle, dead
}

/// Agent execution state
public enum AgentState: String, Codable, Sendable {
    case idle = "IDLE"
    case executing = "EXECUTING"
    case error = "ERROR"
    case cooldown = "COOLDOWN"
}

/// Executor type
public enum ExecutorType: String, Codable, Sendable {
    case claudeCode = "claude-code"
    case cascade
    case agentSdk = "agent-sdk"
}

/// Agent heartbeat entry from /api/heartbeat
public struct AgentHeartbeat: Codable, Sendable, Identifiable {
    public let name: String
    public let lastSeen: Date
    public let status: AgentStatus
    public let currentIssue: String?
    public let executorType: ExecutorType?
    public let state: AgentState?
    public let currentPhase: String?
    public let uptimeSeconds: Int?
    public let throughput24h: Int?
    public let errorCount24h: Int?

    public var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name
        case lastSeen = "last_seen"
        case status
        case currentIssue = "current_issue"
        case executorType = "executor_type"
        case state
        case currentPhase = "current_phase"
        case uptimeSeconds = "uptime_seconds"
        case throughput24h = "throughput_24h"
        case errorCount24h = "error_count_24h"
    }

    public init(
        name: String,
        lastSeen: Date,
        status: AgentStatus,
        currentIssue: String? = nil,
        executorType: ExecutorType? = nil,
        state: AgentState? = nil,
        currentPhase: String? = nil,
        uptimeSeconds: Int? = nil,
        throughput24h: Int? = nil,
        errorCount24h: Int? = nil
    ) {
        self.name = name
        self.lastSeen = lastSeen
        self.status = status
        self.currentIssue = currentIssue
        self.executorType = executorType
        self.state = state
        self.currentPhase = currentPhase
        self.uptimeSeconds = uptimeSeconds
        self.throughput24h = throughput24h
        self.errorCount24h = errorCount24h
    }
}

/// Full heartbeat response
public struct HeartbeatResponse: Codable, Sendable {
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

/// Agents list response from /api/v1/agents
public struct AgentsResponse: Codable, Sendable {
    public let agents: [AgentHeartbeat]
    public let count: Int
    public let timestamp: Double

    public init(agents: [AgentHeartbeat], count: Int, timestamp: Double) {
        self.agents = agents
        self.count = count
        self.timestamp = timestamp
    }
}
