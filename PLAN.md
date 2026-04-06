# PLAN: HCS-003 — HEIMDALL API Client

## Preflight Checklist

### 1. git status
```
On branch feat/AASF-647
nothing to commit, working tree clean
```

### 2. git branch
```
* feat/AASF-647
+ main
```

### 3. ls data/queue/
```
ls: /Users/maurizio/development/heimdall/hcs/.worktrees/aasf-647/data/queue/: No such file or directory
```
(No queue directory exists — this is a Swift project, no stale envelopes)

### 4. Mandatory Rules from CLAUDE.md

1. Functions < 50 lines
2. Read signatures before calling
3. String matching: \b word boundaries only
4. Max 5 files per refactor commit
5. One branch at a time
6. Squash merge to main
7. Every commit: (HCS-NNN)
8. python -m pytest tests/ -q must pass before merge (Note: Swift project uses `swift test`)

---

## Summary

HCS-003 requires implementing a REST client for the HEIMDALL monitor API with Codable models and unit tests.

**IMPLEMENTATION STATUS:**

| File | Path | Status | Lines |
|------|------|--------|-------|
| HeimdallAPIClient.swift | Services/HeimdallAPIClient.swift | COMPLETE | 186 |
| MockAPIClient.swift | Services/MockAPIClient.swift | COMPLETE | 189 |
| JSONDecoding.swift | Services/JSONDecoding.swift | COMPLETE | 66 |
| Pipeline.swift | Models/Pipeline.swift | COMPLETE | 73 |
| Verdict.swift | Models/Verdict.swift | COMPLETE | 60 |
| Agent.swift | Models/Agent.swift | COMPLETE | 107 |
| KPI.swift | Models/KPI.swift | COMPLETE | 83 |
| Project.swift | Models/Project.swift | COMPLETE | 133 |
| Infrastructure.swift | Models/Infrastructure.swift | COMPLETE | 105 |

**GAP IDENTIFIED:** `ModelTests.swift` contains only a placeholder test (11 lines).

Acceptance criteria require:
- Unit tests achieve >80% coverage on models and client
- Unit tests for Codable round-trip serialization

---

## Scope

| Action | File | Purpose |
|--------|------|---------|
| MODIFY | `Tests/HEIMDALLControlSurfaceTests/ModelTests.swift` | Add Codable round-trip tests for all API models |

---

## Data Path Trace

### Encoding/Decoding Flow
1. `JSONEncoder().encode(model)` → Data (line N/A, Foundation)
2. `JSONDecoder.heimdallDecoder().decode(T.self, from: data)` → Model (JSONDecoding.swift:8-12)
3. Verify original == decoded (via Equatable conformance)

### Models to Test (with source locations)

| Model | File | Lines |
|-------|------|-------|
| PipelineEntry | Models/Pipeline.swift | 17-49 |
| PipelineResponse | Models/Pipeline.swift | 52-72 |
| VerdictEntry | Models/Verdict.swift | 12-46 |
| VerdictsResponse | Models/Verdict.swift | 49-59 |
| AgentHeartbeat | Models/Agent.swift | 27-77 |
| HeartbeatResponse | Models/Agent.swift | 80-93 |
| AgentsResponse | Models/Agent.swift | 96-106 |
| KPIMetric | Models/KPI.swift | 17-64 |
| KPIResponse | Models/KPI.swift | 67-82 |
| ServiceHealth | Models/Infrastructure.swift | 12-41 |
| InfraResponse | Models/Infrastructure.swift | 44-52 |
| DecisionEntry | Models/Infrastructure.swift | 55-84 |
| DecisionsResponse | Models/Infrastructure.swift | 87-104 |
| IssueCounts | Models/Project.swift | 12-28 |
| SwitcherProject | Models/Project.swift | 31-76 |
| SwitcherResponse | Models/Project.swift | 79-99 |
| ProjectIssue | Models/Project.swift | 102-132 |
| ApprovalResult | Services/HeimdallAPIClient.swift | 16-26 |

### Enums to Test

| Enum | File | Values |
|------|------|--------|
| PipelineStatus | Models/Pipeline.swift:7-9 | running, blocked, idle, stalled |
| FactoryStatus | Models/Pipeline.swift:12-14 | healthy, degraded, stalled |
| VerdictOutcome | Models/Verdict.swift:7-9 | pass, fail, escalate |
| AgentStatus | Models/Agent.swift:7-9 | active, idle, dead |
| AgentState | Models/Agent.swift:12-17 | IDLE, EXECUTING, ERROR, COOLDOWN |
| ExecutorType | Models/Agent.swift:20-24 | claude-code, cascade, agent-sdk |
| KPITrend | Models/KPI.swift:7-9 | up, down, flat |
| KPIFormat | Models/KPI.swift:12-14 | number, percentage, duration, rate |
| ServiceHealthStatus | Models/Infrastructure.swift:7-9 | healthy, degraded, unhealthy, unknown |
| SwitcherStatus | Models/Project.swift:7-9 | active, standby, blocked, error |

---

## Detailed Changes

### File: Tests/HEIMDALLControlSurfaceTests/ModelTests.swift

**Current State:** 11 lines with placeholder test only

```swift
import Testing
@testable import HEIMDALLControlSurface

@Suite("Model Tests")
struct ModelTests {
    @Test func placeholder() async throws {
        // Placeholder test - to be implemented with models
        #expect(true)
    }
}
```

**Proposed State:** Complete Codable round-trip test suite (~180 lines)

```swift
import Testing
import Foundation
@testable import HEIMDALLControlSurface

@Suite("Model Tests")
struct ModelTests {

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
        #expect(decoded.status == original.status)
    }

    @Test func pipelineResponseRoundTrip() async throws {
        let entry = PipelineEntry(...)
        let original = PipelineResponse(
            pipelines: [entry],
            factoryStatus: .healthy,
            timestamp: Date(timeIntervalSince1970: 1712400000)
        )
        let decoded = try roundTrip(original)
        #expect(decoded.pipelines.count == 1)
        #expect(decoded.factoryStatus == .healthy)
    }

    // ... similar tests for all 18 models ...

    // MARK: - Enum Tests

    @Test func pipelineStatusRoundTrip() async throws {
        for status in [PipelineStatus.running, .blocked, .idle, .stalled] {
            let decoded = try roundTrip(status)
            #expect(decoded == status)
        }
    }

    // ... similar tests for all 10 enums ...

    // MARK: - JSON Decoding Edge Cases

    @Test func dateDecodingISO8601() async throws {
        let json = """
        {"timestamp": "2024-04-06T12:00:00Z", ...}
        """
        // Test ISO8601 parsing in heimdallDecoder
    }

    @Test func dateDecodingUnixTimestamp() async throws {
        let json = """
        {"timestamp": 1712404800, ...}
        """
        // Test Unix timestamp parsing
    }

    // MARK: - Helper

    private func roundTrip<T: Codable>(_ value: T) throws -> T {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder.heimdallDecoder()
        let data = try encoder.encode(value)
        return try decoder.decode(T.self, from: data)
    }
}
```

---

## Function Size Plan

**ModelTests.swift** - Test file:

| Function/Test | Lines | Notes |
|---------------|-------|-------|
| `roundTrip<T>()` | 6 | Generic encode/decode helper |
| Each `@Test` function | 5-10 | Create instance, roundTrip, verify fields |
| Total file | ~180 | 30+ tests, all under 50 lines each |

**No function will exceed 50 lines.**

---

## Equatable Conformance Analysis

Swift auto-synthesizes `Equatable` for structs where all stored properties are `Equatable`. Verification:

| Model | Properties | All Equatable? |
|-------|------------|----------------|
| PipelineEntry | String, String, String, PipelineStatus, Date, Date | ✅ Yes |
| PipelineResponse | [PipelineEntry], FactoryStatus, Date | ✅ Yes |
| VerdictEntry | Date, String×4, VerdictOutcome | ✅ Yes |
| VerdictsResponse | [VerdictEntry], Int, Date | ✅ Yes |
| AgentHeartbeat | String, Date, AgentStatus, String?, ExecutorType?, AgentState?, String?, Int?×3 | ✅ Yes |
| HeartbeatResponse | [AgentHeartbeat], Int | ✅ Yes |
| AgentsResponse | [AgentHeartbeat], Int, Double | ✅ Yes |
| KPIMetric | String×4, Double×2, [Double], KPIFormat, Double?×2, Bool? | ✅ Yes |
| KPIResponse | [KPIMetric], Double, Int | ✅ Yes |
| ServiceHealth | String, ServiceHealthStatus, Double?, Date?, String? | ✅ Yes |
| InfraResponse | [ServiceHealth], Double | ✅ Yes |
| DecisionEntry | String×6 | ✅ Yes |
| DecisionsResponse | [DecisionEntry], Int, String?, Double | ✅ Yes |
| IssueCounts | Int×3 | ✅ Yes |
| SwitcherProject | String×4, SwitcherStatus, IssueCounts, Int, [Int], Double, Bool, String | ✅ Yes |
| SwitcherResponse | [SwitcherProject], String, Double | ✅ Yes |
| ProjectIssue | String×2, String?×3, Int? | ✅ Yes |
| ApprovalResult | Bool, String?×2 | ✅ Yes |

**Conclusion:** No explicit `Equatable` conformance needed — Swift synthesizes automatically.

---

## Test Verification Plan

### Test File: Tests/HEIMDALLControlSurfaceTests/ModelTests.swift

| Test Case | Model Tested | Verification |
|-----------|--------------|--------------|
| `pipelineEntryRoundTrip` | PipelineEntry | All 6 fields match after encode/decode |
| `pipelineResponseRoundTrip` | PipelineResponse | pipelines array, factoryStatus, timestamp match |
| `verdictEntryRoundTrip` | VerdictEntry | All fields including outcome enum match |
| `verdictsResponseRoundTrip` | VerdictsResponse | verdicts array and count match |
| `agentHeartbeatRoundTrip` | AgentHeartbeat | All fields including optionals match |
| `heartbeatResponseRoundTrip` | HeartbeatResponse | agents array and uptimeSeconds match |
| `agentsResponseRoundTrip` | AgentsResponse | All fields match |
| `kpiMetricRoundTrip` | KPIMetric | Sparkline array, optional thresholds match |
| `kpiResponseRoundTrip` | KPIResponse | kpis array with all metrics match |
| `serviceHealthRoundTrip` | ServiceHealth | Optional latencyMs and lastCheck handled |
| `infraResponseRoundTrip` | InfraResponse | services array matches |
| `decisionEntryRoundTrip` | DecisionEntry | All string fields match |
| `decisionsResponseRoundTrip` | DecisionsResponse | Optional project field handled |
| `issueCountsRoundTrip` | IssueCounts | Snake_case key mapping works |
| `switcherProjectRoundTrip` | SwitcherProject | Nested IssueCounts decodes correctly |
| `switcherResponseRoundTrip` | SwitcherResponse | projects array matches |
| `projectIssueRoundTrip` | ProjectIssue | Optional fields handled correctly |
| `approvalResultRoundTrip` | ApprovalResult | Optional message/error handled |
| `pipelineStatusRoundTrip` | PipelineStatus | All 4 enum cases round-trip |
| `factoryStatusRoundTrip` | FactoryStatus | All 3 enum cases round-trip |
| `verdictOutcomeRoundTrip` | VerdictOutcome | All 3 enum cases round-trip |
| `agentStatusRoundTrip` | AgentStatus | All 3 enum cases round-trip |
| `agentStateRoundTrip` | AgentState | All 4 enum cases (raw values IDLE, etc.) |
| `executorTypeRoundTrip` | ExecutorType | All 3 enum cases (raw values claude-code, etc.) |
| `kpiTrendRoundTrip` | KPITrend | All 3 enum cases round-trip |
| `kpiFormatRoundTrip` | KPIFormat | All 4 enum cases round-trip |
| `serviceHealthStatusRoundTrip` | ServiceHealthStatus | All 4 enum cases round-trip |
| `switcherStatusRoundTrip` | SwitcherStatus | All 4 enum cases round-trip |
| `dateDecodingISO8601` | JSONDecoder | ISO8601 string parsed correctly |
| `dateDecodingUnixTimestamp` | JSONDecoder | Unix timestamp parsed correctly |
| `dateDecodingWithFractionalSeconds` | JSONDecoder | ISO8601 with .SSSS parsed |

### Run Command
```bash
cd /Users/maurizio/development/heimdall/hcs/.worktrees/aasf-647
swift test --filter ModelTests
```

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Date encoding mismatch | Use `.iso8601` encoding, heimdallDecoder handles both formats |
| Optional field nil after decode | Test both nil and non-nil cases |
| Enum raw value case sensitivity | Tests verify exact raw value strings |

---

## Execution Contract

```json
{
  "issue_ref": "HCS-003",
  "deliverables": [
    {
      "file": "Tests/HEIMDALLControlSurfaceTests/ModelTests.swift",
      "function": "",
      "change_description": "MODIFY: Replace placeholder test with comprehensive Codable round-trip tests for all API models: PipelineEntry, PipelineResponse, VerdictEntry, VerdictsResponse, AgentHeartbeat, HeartbeatResponse, AgentsResponse, KPIMetric, KPIResponse, ServiceHealth, InfraResponse, DecisionEntry, DecisionsResponse, IssueCounts, SwitcherProject, SwitcherResponse, ProjectIssue, ApprovalResult. Plus enum round-trip tests for all 10 enums (PipelineStatus, FactoryStatus, VerdictOutcome, AgentStatus, AgentState, ExecutorType, KPITrend, KPIFormat, ServiceHealthStatus, SwitcherStatus) and date decoding edge case tests for ISO8601 and Unix timestamps.",
      "verification": "swift test --filter ModelTests passes with all tests green"
    }
  ]
}
```
