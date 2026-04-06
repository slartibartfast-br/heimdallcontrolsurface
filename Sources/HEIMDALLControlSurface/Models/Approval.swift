// Sources/HEIMDALLControlSurface/Models/Approval.swift
// HCS-005: Model for pending approvals fetched from HEIMDALL API

import Foundation

/// Represents a pending approval requiring user action
public struct Approval: Codable, Sendable, Identifiable {
    public let id: String
    public let issueId: String
    public let phase: String
    public let reason: String
    public let agent: String
    public let timestamp: Date

    public init(
        id: String,
        issueId: String,
        phase: String,
        reason: String,
        agent: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.issueId = issueId
        self.phase = phase
        self.reason = reason
        self.agent = agent
        self.timestamp = timestamp
    }
}

/// API response for pending approvals
public struct PendingApprovalsResponse: Codable, Sendable {
    public let approvals: [Approval]
    public let count: Int
    public let timestamp: TimeInterval

    public init(approvals: [Approval], count: Int, timestamp: TimeInterval) {
        self.approvals = approvals
        self.count = count
        self.timestamp = timestamp
    }
}

/// Approval action types
public enum ApprovalActionType: String, Codable, Sendable {
    case approve
    case reject
    case hold
}
