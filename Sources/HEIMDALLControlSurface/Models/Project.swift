// Sources/HEIMDALLControlSurface/Models/Project.swift
// AASF-647: HEIMDALL API Client Models

import Foundation

/// Project status
public enum SwitcherStatus: String, Codable, Sendable {
    case active, standby, blocked, error
}

/// Issue counts for project dashboard
public struct IssueCounts: Codable, Sendable {
    public let open: Int
    public let inProgress: Int
    public let done: Int

    enum CodingKeys: String, CodingKey {
        case open
        case inProgress = "in_progress"
        case done
    }

    public init(open: Int, inProgress: Int, done: Int) {
        self.open = open
        self.inProgress = inProgress
        self.done = done
    }
}

/// Project entry for switcher panel
public struct SwitcherProject: Codable, Sendable, Identifiable {
    public let id: String
    public let code: String            // Project prefix (e.g., "AASF")
    public let name: String
    public let status: SwitcherStatus
    public let issueCounts: IssueCounts
    public let healthScore: Int        // 0-100
    public let healthSparkline: [Int]  // 24h hourly values
    public let lastActivity: Double    // Unix timestamp
    public let pipelineRunning: Bool
    public let activeIssue: String

    enum CodingKeys: String, CodingKey {
        case id, code, name, status
        case issueCounts = "issue_counts"
        case healthScore = "health_score"
        case healthSparkline = "health_sparkline"
        case lastActivity = "last_activity"
        case pipelineRunning = "pipeline_running"
        case activeIssue = "active_issue"
    }

    public init(
        id: String,
        code: String,
        name: String,
        status: SwitcherStatus,
        issueCounts: IssueCounts,
        healthScore: Int,
        healthSparkline: [Int],
        lastActivity: Double,
        pipelineRunning: Bool,
        activeIssue: String
    ) {
        self.id = id
        self.code = code
        self.name = name
        self.status = status
        self.issueCounts = issueCounts
        self.healthScore = healthScore
        self.healthSparkline = healthSparkline
        self.lastActivity = lastActivity
        self.pipelineRunning = pipelineRunning
        self.activeIssue = activeIssue
    }
}

/// Switcher response from /api/v1/projects
public struct SwitcherResponse: Codable, Sendable {
    public let projects: [SwitcherProject]
    public let selectedProject: String
    public let timestamp: Double

    enum CodingKeys: String, CodingKey {
        case projects
        case selectedProject = "selected_project"
        case timestamp
    }

    public init(
        projects: [SwitcherProject],
        selectedProject: String,
        timestamp: Double
    ) {
        self.projects = projects
        self.selectedProject = selectedProject
        self.timestamp = timestamp
    }
}

/// Issue entry with title
public struct ProjectIssue: Codable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let projectId: String?
    public let status: String?
    public let priority: String?
    public let retryCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, title
        case projectId = "project_id"
        case status, priority
        case retryCount = "retry_count"
    }

    public init(
        id: String,
        title: String,
        projectId: String? = nil,
        status: String? = nil,
        priority: String? = nil,
        retryCount: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.projectId = projectId
        self.status = status
        self.priority = priority
        self.retryCount = retryCount
    }
}
