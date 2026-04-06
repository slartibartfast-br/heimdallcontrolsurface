// Sources/HEIMDALLControlSurface/Models/Verdict.swift
// AASF-647: HEIMDALL API Client Models

import Foundation

/// Gate verdict outcome
public enum VerdictOutcome: String, Codable, Sendable {
    case pass, fail, escalate
}

/// Verdict entry from /api/verdicts
public struct VerdictEntry: Codable, Sendable, Identifiable {
    public let timestamp: Date
    public let issueId: String
    public let gate: String        // plan|implement|review|test|merge
    public let outcome: VerdictOutcome
    public let reason: String
    public let agent: String

    enum CodingKeys: String, CodingKey {
        case timestamp
        case issueId = "issue_id"
        case gate, outcome, reason, agent
    }

    // Synthesize stable ID from timestamp + issue
    public var id: String {
        "\(issueId)-\(timestamp.timeIntervalSince1970)"
    }

    public init(
        timestamp: Date,
        issueId: String,
        gate: String,
        outcome: VerdictOutcome,
        reason: String,
        agent: String
    ) {
        self.timestamp = timestamp
        self.issueId = issueId
        self.gate = gate
        self.outcome = outcome
        self.reason = reason
        self.agent = agent
    }
}

/// Verdicts response wrapper
public struct VerdictsResponse: Codable, Sendable {
    public let verdicts: [VerdictEntry]
    public let count: Int
    public let timestamp: Date

    public init(verdicts: [VerdictEntry], count: Int, timestamp: Date) {
        self.verdicts = verdicts
        self.count = count
        self.timestamp = timestamp
    }
}
