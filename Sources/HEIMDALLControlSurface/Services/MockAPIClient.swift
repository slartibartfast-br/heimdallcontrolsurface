// Sources/HEIMDALLControlSurface/Services/MockAPIClient.swift
// AASF-647: Mock API client for testing and offline development

import Foundation

/// Mock API client for testing and offline development
public final class MockHeimdallAPIClient: HeimdallAPIClientProtocol, @unchecked Sendable {

    public var simulatedDelay: TimeInterval = 0.1
    public var shouldFail: Bool = false
    public var failureError: HeimdallAPIError = .networkError(
        NSError(domain: "Mock", code: -1)
    )

    public init() {}

    // MARK: - Protocol Implementation

    public func fetchPipeline() async throws -> PipelineResponse {
        try await simulateNetwork()
        return PipelineResponse(
            pipelines: [MockData.pipelineEntry],
            factoryStatus: .healthy,
            timestamp: Date()
        )
    }

    public func fetchVerdicts(limit: Int) async throws -> [VerdictEntry] {
        try await simulateNetwork()
        return [MockData.verdictEntry]
    }

    public func fetchHeartbeat() async throws -> HeartbeatResponse {
        try await simulateNetwork()
        return HeartbeatResponse(
            agents: [MockData.agentHeartbeat],
            uptimeSeconds: 3600
        )
    }

    public func fetchTelemetry() async throws -> KPIResponse {
        try await simulateNetwork()
        return KPIResponse(
            kpis: [MockData.kpiMetric],
            timestamp: Date().timeIntervalSince1970,
            uptimeSeconds: 3600
        )
    }

    public func fetchInfraHealth() async throws -> InfraResponse {
        try await simulateNetwork()
        return InfraResponse(
            services: [MockData.serviceHealth],
            timestamp: Date().timeIntervalSince1970
        )
    }

    public func fetchProjects() async throws -> SwitcherResponse {
        try await simulateNetwork()
        return SwitcherResponse(
            projects: [MockData.switcherProject],
            selectedProject: "AASF",
            timestamp: Date().timeIntervalSince1970
        )
    }

    public func fetchAgents() async throws -> AgentsResponse {
        try await simulateNetwork()
        return AgentsResponse(
            agents: [MockData.agentHeartbeat],
            count: 1,
            timestamp: Date().timeIntervalSince1970
        )
    }

    public func fetchDecisions(
        limit: Int,
        project: String?
    ) async throws -> DecisionsResponse {
        try await simulateNetwork()
        return DecisionsResponse(
            decisions: [MockData.decisionEntry],
            count: 1,
            project: project,
            timestamp: Date().timeIntervalSince1970
        )
    }

    public func approve(id: String) async throws -> ApprovalResult {
        try await simulateNetwork()
        return ApprovalResult(ok: true, message: "Approved", error: nil)
    }

    public func reject(id: String, reason: String?) async throws -> ApprovalResult {
        try await simulateNetwork()
        return ApprovalResult(ok: true, message: "Rejected", error: nil)
    }

    // MARK: - HCS-005: Hold Action

    public func hold(id: String) async throws -> ApprovalResult {
        try await simulateNetwork()
        return ApprovalResult(ok: true, message: "Held", error: nil)
    }

    // MARK: - HCS-005: Pending Approvals

    public func fetchPendingApprovals() async throws -> PendingApprovalsResponse {
        try await simulateNetwork()
        return PendingApprovalsResponse(
            approvals: [MockData.pendingApproval],
            count: 1,
            timestamp: Date().timeIntervalSince1970
        )
    }

    // MARK: - Private

    private func simulateNetwork() async throws {
        if simulatedDelay > 0 {
            try await Task.sleep(for: .seconds(simulatedDelay))
        }
        if shouldFail {
            throw failureError
        }
    }
}

// MARK: - Mock Data

public enum MockData {
    public static let pipelineEntry = PipelineEntry(
        issueId: "AASF-100",
        phase: "implement",
        agent: "odin",
        status: .running,
        startedAt: Date(),
        lastHeartbeat: Date()
    )

    public static let verdictEntry = VerdictEntry(
        timestamp: Date(),
        issueId: "AASF-100",
        gate: "plan",
        outcome: .pass,
        reason: "Plan approved by architect",
        agent: "superio"
    )

    public static let agentHeartbeat = AgentHeartbeat(
        name: "odin",
        lastSeen: Date(),
        status: .active,
        currentIssue: "AASF-100",
        executorType: .claudeCode,
        state: .executing,
        currentPhase: "implement",
        uptimeSeconds: 3600,
        throughput24h: 5,
        errorCount24h: 0
    )

    public static let kpiMetric = KPIMetric(
        id: "throughput",
        label: "Throughput",
        value: 5.0,
        formattedValue: "5/day",
        unit: "/day",
        trend: .up,
        sparkline: [3, 4, 5, 4, 5, 6, 5],
        format: .rate,
        thresholdWarning: 3.0,
        thresholdCritical: 1.0,
        isHero: true
    )

    public static let serviceHealth = ServiceHealth(
        name: "redis",
        status: .healthy,
        latencyMs: 2.5,
        lastCheck: Date(),
        message: nil
    )

    public static let switcherProject = SwitcherProject(
        id: "aasf-uuid",
        code: "AASF",
        name: "AASF Pipeline",
        status: .active,
        issueCounts: IssueCounts(open: 10, inProgress: 3, done: 50),
        healthScore: 95,
        healthSparkline: Array(repeating: 95, count: 24),
        lastActivity: Date().timeIntervalSince1970,
        pipelineRunning: true,
        activeIssue: "AASF-100"
    )

    public static let decisionEntry = DecisionEntry(
        id: "1234567890-0",
        issueRef: "AASF-100",
        agent: "superio",
        decision: "approve",
        rationale: "Plan meets all criteria",
        ts: ISO8601DateFormatter().string(from: Date())
    )

    // HCS-005: Mock pending approval
    public static let pendingApproval = Approval(
        id: "approval-1",
        issueId: "AASF-100",
        phase: "plan",
        reason: "Plan requires human review before proceeding to implement phase",
        agent: "odin",
        timestamp: Date()
    )
}
