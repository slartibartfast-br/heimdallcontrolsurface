// Tests/HEIMDALLControlSurfaceTests/ModelTests.swift
// HCS-003: Codable round-trip tests for all API models

import Testing
import Foundation
@testable import HEIMDALLControlSurface

@Suite("Model Tests")
struct ModelTests {

    // MARK: - Helper

    /// Generic encode/decode round-trip test helper
    private func roundTrip<T: Codable>(_ value: T) throws -> T {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder.heimdallDecoder()
        let data = try encoder.encode(value)
        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Pipeline Models

    @Test func pipelineEntryRoundTrip() async throws {
        let original = PipelineEntry(
            issueId: "AASF-100",
            phase: "implement",
            agent: "odin",
            status: .running,
            startedAt: Date(timeIntervalSince1970: 1712400000),
            lastHeartbeat: Date(timeIntervalSince1970: 1712400060)
        )
        let decoded = try roundTrip(original)
        #expect(decoded.issueId == original.issueId)
        #expect(decoded.phase == original.phase)
        #expect(decoded.agent == original.agent)
        #expect(decoded.status == original.status)
    }

    @Test func pipelineResponseRoundTrip() async throws {
        let entry = PipelineEntry(
            issueId: "AASF-101",
            phase: "plan",
            agent: "thor",
            status: .blocked,
            startedAt: Date(timeIntervalSince1970: 1712400000),
            lastHeartbeat: Date(timeIntervalSince1970: 1712400060)
        )
        let original = PipelineResponse(
            pipelines: [entry],
            factoryStatus: .healthy,
            timestamp: Date(timeIntervalSince1970: 1712400000)
        )
        let decoded = try roundTrip(original)
        #expect(decoded.pipelines.count == 1)
        #expect(decoded.factoryStatus == .healthy)
        #expect(decoded.pipelines[0].issueId == "AASF-101")
    }

    // MARK: - Verdict Models

    @Test func verdictEntryRoundTrip() async throws {
        let original = VerdictEntry(
            timestamp: Date(timeIntervalSince1970: 1712400000),
            issueId: "AASF-200",
            gate: "implement",
            outcome: .pass,
            reason: "All tests passed",
            agent: "odin"
        )
        let decoded = try roundTrip(original)
        #expect(decoded.issueId == original.issueId)
        #expect(decoded.gate == original.gate)
        #expect(decoded.outcome == original.outcome)
        #expect(decoded.reason == original.reason)
    }

    @Test func verdictsResponseRoundTrip() async throws {
        let verdict = VerdictEntry(
            timestamp: Date(timeIntervalSince1970: 1712400000),
            issueId: "AASF-201",
            gate: "review",
            outcome: .fail,
            reason: "Missing tests",
            agent: "heimdall"
        )
        let original = VerdictsResponse(
            verdicts: [verdict],
            count: 1,
            timestamp: Date(timeIntervalSince1970: 1712400000)
        )
        let decoded = try roundTrip(original)
        #expect(decoded.verdicts.count == 1)
        #expect(decoded.count == 1)
        #expect(decoded.verdicts[0].outcome == .fail)
    }

    // MARK: - Agent Models

    @Test func agentHeartbeatRoundTrip() async throws {
        let original = AgentHeartbeat(
            name: "odin",
            lastSeen: Date(timeIntervalSince1970: 1712400000),
            status: .active,
            currentIssue: "AASF-300",
            executorType: .claudeCode,
            state: .executing,
            currentPhase: "implement",
            uptimeSeconds: 3600,
            throughput24h: 10,
            errorCount24h: 2
        )
        let decoded = try roundTrip(original)
        #expect(decoded.name == original.name)
        #expect(decoded.status == original.status)
        #expect(decoded.currentIssue == original.currentIssue)
        #expect(decoded.executorType == original.executorType)
        #expect(decoded.state == original.state)
    }

    @Test func agentHeartbeatWithNilsRoundTrip() async throws {
        let original = AgentHeartbeat(
            name: "idle-agent",
            lastSeen: Date(timeIntervalSince1970: 1712400000),
            status: .idle,
            currentIssue: nil,
            executorType: nil,
            state: nil,
            currentPhase: nil,
            uptimeSeconds: nil,
            throughput24h: nil,
            errorCount24h: nil
        )
        let decoded = try roundTrip(original)
        #expect(decoded.name == original.name)
        #expect(decoded.currentIssue == nil)
        #expect(decoded.executorType == nil)
        #expect(decoded.state == nil)
    }

    @Test func heartbeatResponseRoundTrip() async throws {
        let agent = AgentHeartbeat(
            name: "thor",
            lastSeen: Date(timeIntervalSince1970: 1712400000),
            status: .dead
        )
        let original = HeartbeatResponse(agents: [agent], uptimeSeconds: 7200)
        let decoded = try roundTrip(original)
        #expect(decoded.agents.count == 1)
        #expect(decoded.uptimeSeconds == 7200)
        #expect(decoded.agents[0].status == .dead)
    }

    @Test func agentsResponseRoundTrip() async throws {
        let agent = AgentHeartbeat(
            name: "loki",
            lastSeen: Date(timeIntervalSince1970: 1712400000),
            status: .active
        )
        let original = AgentsResponse(agents: [agent], count: 1, timestamp: 1712400000.0)
        let decoded = try roundTrip(original)
        #expect(decoded.agents.count == 1)
        #expect(decoded.count == 1)
        #expect(decoded.timestamp == 1712400000.0)
    }

    // MARK: - KPI Models

    @Test func kpiMetricRoundTrip() async throws {
        let original = KPIMetric(
            id: "throughput",
            label: "Throughput",
            value: 42.5,
            formattedValue: "42.5/h",
            unit: "issues/hour",
            trend: .up,
            sparkline: [10.0, 20.0, 30.0, 40.0],
            format: .rate,
            thresholdWarning: 20.0,
            thresholdCritical: 10.0,
            isHero: true
        )
        let decoded = try roundTrip(original)
        #expect(decoded.id == original.id)
        #expect(decoded.value == original.value)
        #expect(decoded.trend == original.trend)
        #expect(decoded.sparkline == original.sparkline)
        #expect(decoded.thresholdWarning == original.thresholdWarning)
        #expect(decoded.isHero == true)
    }

    @Test func kpiMetricWithNilsRoundTrip() async throws {
        let original = KPIMetric(
            id: "simple",
            label: "Simple",
            value: 100.0,
            formattedValue: "100",
            unit: "",
            trend: .flat,
            sparkline: [],
            format: .number,
            thresholdWarning: nil,
            thresholdCritical: nil,
            isHero: nil
        )
        let decoded = try roundTrip(original)
        #expect(decoded.thresholdWarning == nil)
        #expect(decoded.thresholdCritical == nil)
        #expect(decoded.isHero == nil)
    }

    @Test func kpiResponseRoundTrip() async throws {
        let kpi = KPIMetric(
            id: "cycle_time",
            label: "Cycle Time",
            value: 45.0,
            formattedValue: "45m",
            unit: "minutes",
            trend: .down,
            sparkline: [60.0, 55.0, 50.0, 45.0],
            format: .duration
        )
        let original = KPIResponse(kpis: [kpi], timestamp: 1712400000.0, uptimeSeconds: 86400)
        let decoded = try roundTrip(original)
        #expect(decoded.kpis.count == 1)
        #expect(decoded.timestamp == 1712400000.0)
        #expect(decoded.uptimeSeconds == 86400)
    }

    // MARK: - Infrastructure Models

    @Test func serviceHealthRoundTrip() async throws {
        let original = ServiceHealth(
            name: "postgres",
            status: .healthy,
            latencyMs: 5.5,
            lastCheck: Date(timeIntervalSince1970: 1712400000),
            message: "All connections OK"
        )
        let decoded = try roundTrip(original)
        #expect(decoded.name == original.name)
        #expect(decoded.status == original.status)
        #expect(decoded.latencyMs == original.latencyMs)
        #expect(decoded.message == original.message)
    }

    @Test func serviceHealthWithNilsRoundTrip() async throws {
        let original = ServiceHealth(
            name: "redis",
            status: .unknown,
            latencyMs: nil,
            lastCheck: nil,
            message: nil
        )
        let decoded = try roundTrip(original)
        #expect(decoded.name == "redis")
        #expect(decoded.status == .unknown)
        #expect(decoded.latencyMs == nil)
        #expect(decoded.lastCheck == nil)
    }

    @Test func infraResponseRoundTrip() async throws {
        let service = ServiceHealth(name: "api", status: .degraded)
        let original = InfraResponse(services: [service], timestamp: 1712400000.0)
        let decoded = try roundTrip(original)
        #expect(decoded.services.count == 1)
        #expect(decoded.timestamp == 1712400000.0)
        #expect(decoded.services[0].status == .degraded)
    }

    @Test func decisionEntryRoundTrip() async throws {
        let original = DecisionEntry(
            id: "dec-001",
            issueRef: "AASF-400",
            agent: "odin",
            decision: "approve",
            rationale: "Tests pass, code reviewed",
            ts: "2024-04-06T12:00:00Z"
        )
        let decoded = try roundTrip(original)
        #expect(decoded.id == original.id)
        #expect(decoded.issueRef == original.issueRef)
        #expect(decoded.agent == original.agent)
        #expect(decoded.decision == original.decision)
        #expect(decoded.rationale == original.rationale)
    }

    @Test func decisionsResponseRoundTrip() async throws {
        let decision = DecisionEntry(
            id: "dec-002",
            issueRef: "AASF-401",
            agent: "heimdall",
            decision: "reject",
            rationale: "Missing coverage",
            ts: "2024-04-06T13:00:00Z"
        )
        let original = DecisionsResponse(
            decisions: [decision],
            count: 1,
            project: "heimdall",
            timestamp: 1712400000.0
        )
        let decoded = try roundTrip(original)
        #expect(decoded.decisions.count == 1)
        #expect(decoded.count == 1)
        #expect(decoded.project == "heimdall")
    }

    @Test func decisionsResponseWithNilProjectRoundTrip() async throws {
        let original = DecisionsResponse(
            decisions: [],
            count: 0,
            project: nil,
            timestamp: 1712400000.0
        )
        let decoded = try roundTrip(original)
        #expect(decoded.project == nil)
        #expect(decoded.count == 0)
    }

    // MARK: - Project Models

    @Test func issueCountsRoundTrip() async throws {
        let original = IssueCounts(open: 5, inProgress: 3, done: 10)
        let decoded = try roundTrip(original)
        #expect(decoded.open == 5)
        #expect(decoded.inProgress == 3)
        #expect(decoded.done == 10)
    }

    @Test func switcherProjectRoundTrip() async throws {
        let counts = IssueCounts(open: 2, inProgress: 1, done: 5)
        let original = SwitcherProject(
            id: "proj-001",
            code: "AASF",
            name: "Agent Factory",
            status: .active,
            issueCounts: counts,
            healthScore: 85,
            healthSparkline: [80, 82, 85, 87, 85],
            lastActivity: 1712400000.0,
            pipelineRunning: true,
            activeIssue: "AASF-500"
        )
        let decoded = try roundTrip(original)
        #expect(decoded.id == original.id)
        #expect(decoded.code == "AASF")
        #expect(decoded.status == .active)
        #expect(decoded.issueCounts.open == 2)
        #expect(decoded.healthScore == 85)
        #expect(decoded.pipelineRunning == true)
    }

    @Test func switcherResponseRoundTrip() async throws {
        let project = SwitcherProject(
            id: "proj-002",
            code: "HCS",
            name: "Control Surface",
            status: .standby,
            issueCounts: IssueCounts(open: 1, inProgress: 0, done: 3),
            healthScore: 90,
            healthSparkline: [88, 89, 90],
            lastActivity: 1712400000.0,
            pipelineRunning: false,
            activeIssue: ""
        )
        let original = SwitcherResponse(
            projects: [project],
            selectedProject: "HCS",
            timestamp: 1712400000.0
        )
        let decoded = try roundTrip(original)
        #expect(decoded.projects.count == 1)
        #expect(decoded.selectedProject == "HCS")
        #expect(decoded.projects[0].status == .standby)
    }

    @Test func projectIssueRoundTrip() async throws {
        let original = ProjectIssue(
            id: "AASF-600",
            title: "Implement feature X",
            projectId: "proj-001",
            status: "in_progress",
            priority: "high",
            retryCount: 2
        )
        let decoded = try roundTrip(original)
        #expect(decoded.id == original.id)
        #expect(decoded.title == original.title)
        #expect(decoded.projectId == original.projectId)
        #expect(decoded.status == original.status)
        #expect(decoded.retryCount == 2)
    }

    @Test func projectIssueWithNilsRoundTrip() async throws {
        let original = ProjectIssue(
            id: "AASF-601",
            title: "Simple task",
            projectId: nil,
            status: nil,
            priority: nil,
            retryCount: nil
        )
        let decoded = try roundTrip(original)
        #expect(decoded.id == "AASF-601")
        #expect(decoded.projectId == nil)
        #expect(decoded.retryCount == nil)
    }

    // MARK: - Approval Result

    @Test func approvalResultRoundTrip() async throws {
        let original = ApprovalResult(ok: true, message: "Approved", error: nil)
        let decoded = try roundTrip(original)
        #expect(decoded.ok == true)
        #expect(decoded.message == "Approved")
        #expect(decoded.error == nil)
    }

    @Test func approvalResultWithErrorRoundTrip() async throws {
        let original = ApprovalResult(ok: false, message: nil, error: "Not authorized")
        let decoded = try roundTrip(original)
        #expect(decoded.ok == false)
        #expect(decoded.message == nil)
        #expect(decoded.error == "Not authorized")
    }

    // MARK: - Enum Round-Trip Tests

    @Test func pipelineStatusRoundTrip() async throws {
        for status in [PipelineStatus.running, .blocked, .idle, .stalled] {
            let decoded = try roundTrip(status)
            #expect(decoded == status)
        }
    }

    @Test func factoryStatusRoundTrip() async throws {
        for status in [FactoryStatus.healthy, .degraded, .stalled] {
            let decoded = try roundTrip(status)
            #expect(decoded == status)
        }
    }

    @Test func verdictOutcomeRoundTrip() async throws {
        for outcome in [VerdictOutcome.pass, .fail, .escalate] {
            let decoded = try roundTrip(outcome)
            #expect(decoded == outcome)
        }
    }

    @Test func agentStatusRoundTrip() async throws {
        for status in [AgentStatus.active, .idle, .dead] {
            let decoded = try roundTrip(status)
            #expect(decoded == status)
        }
    }

    @Test func agentStateRoundTrip() async throws {
        for state in [AgentState.idle, .executing, .error, .cooldown] {
            let decoded = try roundTrip(state)
            #expect(decoded == state)
        }
    }

    @Test func executorTypeRoundTrip() async throws {
        for execType in [ExecutorType.claudeCode, .cascade, .agentSdk] {
            let decoded = try roundTrip(execType)
            #expect(decoded == execType)
        }
    }

    @Test func kpiTrendRoundTrip() async throws {
        for trend in [KPITrend.up, .down, .flat] {
            let decoded = try roundTrip(trend)
            #expect(decoded == trend)
        }
    }

    @Test func kpiFormatRoundTrip() async throws {
        for format in [KPIFormat.number, .percentage, .duration, .rate] {
            let decoded = try roundTrip(format)
            #expect(decoded == format)
        }
    }

    @Test func serviceHealthStatusRoundTrip() async throws {
        for status in [ServiceHealthStatus.healthy, .degraded, .unhealthy, .unknown] {
            let decoded = try roundTrip(status)
            #expect(decoded == status)
        }
    }

    @Test func switcherStatusRoundTrip() async throws {
        for status in [SwitcherStatus.active, .standby, .blocked, .error] {
            let decoded = try roundTrip(status)
            #expect(decoded == status)
        }
    }

    // MARK: - Date Decoding Edge Cases

    @Test func dateDecodingISO8601() async throws {
        let json = """
        {"timestamp":"2024-04-06T12:00:00Z","issue_id":"TEST-1","gate":"test","outcome":"pass","reason":"test","agent":"test"}
        """
        let decoder = JSONDecoder.heimdallDecoder()
        let decoded = try decoder.decode(VerdictEntry.self, from: Data(json.utf8))
        #expect(decoded.issueId == "TEST-1")
        // Date decoded correctly (no exception thrown)
    }

    @Test func dateDecodingUnixTimestamp() async throws {
        let json = """
        {"timestamp":1712404800,"issue_id":"TEST-2","gate":"test","outcome":"fail","reason":"test","agent":"test"}
        """
        let decoder = JSONDecoder.heimdallDecoder()
        let decoded = try decoder.decode(VerdictEntry.self, from: Data(json.utf8))
        #expect(decoded.issueId == "TEST-2")
        // Unix timestamp decoded as Date
        #expect(decoded.timestamp == Date(timeIntervalSince1970: 1712404800))
    }

    @Test func dateDecodingWithFractionalSeconds() async throws {
        let json = """
        {"timestamp":"2024-04-06T12:00:00.123Z","issue_id":"TEST-3","gate":"test","outcome":"escalate","reason":"test","agent":"test"}
        """
        let decoder = JSONDecoder.heimdallDecoder()
        let decoded = try decoder.decode(VerdictEntry.self, from: Data(json.utf8))
        #expect(decoded.issueId == "TEST-3")
        // Fractional seconds parsed correctly
    }
}
