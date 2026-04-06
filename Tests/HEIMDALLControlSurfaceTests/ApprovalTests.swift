// Tests/HEIMDALLControlSurfaceTests/ApprovalTests.swift
// HCS-005: Unit tests for ApprovalAction undo logic

import Foundation
import Testing

@testable import HEIMDALLControlSurface

// MARK: - Approval Model Tests

@Suite("Approval Model Tests")
struct ApprovalModelTests {
    @Test("Approval initializes with correct values")
    func testApprovalInit() {
        let approval = Approval(
            id: "test-1",
            issueId: "AASF-100",
            phase: "plan",
            reason: "Test reason",
            agent: "odin"
        )

        #expect(approval.id == "test-1")
        #expect(approval.issueId == "AASF-100")
        #expect(approval.phase == "plan")
        #expect(approval.reason == "Test reason")
        #expect(approval.agent == "odin")
    }

    @Test("Approval is Identifiable")
    func testApprovalIdentifiable() {
        let approval1 = Approval(
            id: "id-1",
            issueId: "AASF-100",
            phase: "plan",
            reason: "R1",
            agent: "odin"
        )
        let approval2 = Approval(
            id: "id-2",
            issueId: "AASF-100",
            phase: "plan",
            reason: "R2",
            agent: "odin"
        )

        #expect(approval1.id != approval2.id)
    }
}

// MARK: - ApprovalAction Tests

@Suite("ApprovalAction Tests")
@MainActor
struct ApprovalActionTests {
    private func makeApproval() -> Approval {
        Approval(
            id: "test-1",
            issueId: "AASF-100",
            phase: "plan",
            reason: "Test reason",
            agent: "odin"
        )
    }

    @Test("ApprovalAction initializes with correct state")
    func testActionInit() {
        let approval = makeApproval()
        let action = ApprovalAction(approval: approval, actionType: .approve)

        #expect(action.approval.id == approval.id)
        #expect(action.actionType == .approve)
        #expect(action.isExecuted == false)
        #expect(action.isCancelled == false)
    }

    @Test("New action has full undo window")
    func testNewActionUndoWindow() {
        let action = ApprovalAction(approval: makeApproval(), actionType: .approve)

        // Time remaining should be close to 10 seconds
        #expect(action.timeRemaining > 9.5)
        #expect(action.timeRemaining <= 10.0)
    }

    @Test("New action can be undone")
    func testNewActionCanUndo() {
        let action = ApprovalAction(approval: makeApproval(), actionType: .approve)

        #expect(action.canUndo == true)
    }

    @Test("Progress fraction is 1.0 for new action")
    func testProgressFractionNew() {
        let action = ApprovalAction(approval: makeApproval(), actionType: .approve)

        #expect(action.progressFraction > 0.95)
        #expect(action.progressFraction <= 1.0)
    }

    @Test("Cancel marks action as cancelled")
    func testCancelAction() {
        let action = ApprovalAction(approval: makeApproval(), actionType: .reject)

        action.cancel()

        #expect(action.isCancelled == true)
        #expect(action.canUndo == false)
    }

    @Test("Cancelled action cannot be executed")
    func testCancelledActionNotExecutable() {
        let action = ApprovalAction(approval: makeApproval(), actionType: .approve)

        action.cancel()
        action.markExecuted()

        #expect(action.isExecuted == false)
        #expect(action.isCancelled == true)
    }

    @Test("markExecuted sets executed flag")
    func testMarkExecuted() {
        let action = ApprovalAction(approval: makeApproval(), actionType: .approve)

        action.markExecuted()

        #expect(action.isExecuted == true)
        #expect(action.canUndo == false)
    }

    @Test("Executed action cannot be cancelled")
    func testExecutedActionCannotCancel() {
        let action = ApprovalAction(approval: makeApproval(), actionType: .approve)

        action.markExecuted()
        action.cancel()  // Should be ignored

        #expect(action.isExecuted == true)
        #expect(action.isCancelled == false)
    }
}

// MARK: - ApprovalAction Display Tests

@Suite("ApprovalAction Display Tests")
@MainActor
struct ApprovalActionDisplayTests {
    private func makeApproval() -> Approval {
        Approval(
            id: "test-1",
            issueId: "AASF-100",
            phase: "plan",
            reason: "Test",
            agent: "odin"
        )
    }

    @Test("Approve action description")
    func testApproveDescription() {
        let action = ApprovalAction(approval: makeApproval(), actionType: .approve)
        #expect(action.actionDescription == "Approving")
    }

    @Test("Reject action description")
    func testRejectDescription() {
        let action = ApprovalAction(approval: makeApproval(), actionType: .reject)
        #expect(action.actionDescription == "Rejecting")
    }

    @Test("Hold action description")
    func testHoldDescription() {
        let action = ApprovalAction(approval: makeApproval(), actionType: .hold)
        #expect(action.actionDescription == "Holding")
    }

    @Test("Formatted time remaining shows seconds")
    func testFormattedTimeRemaining() {
        let action = ApprovalAction(approval: makeApproval(), actionType: .approve)
        let formatted = action.formattedTimeRemaining

        // Should be "10s" or close to it
        #expect(formatted.hasSuffix("s"))
        #expect(formatted.count <= 4)  // "10s" or "9s"
    }
}

// MARK: - ApprovalActionType Tests

@Suite("ApprovalActionType Tests")
struct ApprovalActionTypeTests {
    @Test("All action types have raw values")
    func testActionTypeRawValues() {
        #expect(ApprovalActionType.approve.rawValue == "approve")
        #expect(ApprovalActionType.reject.rawValue == "reject")
        #expect(ApprovalActionType.hold.rawValue == "hold")
    }
}

// MARK: - PendingApprovalsResponse Tests

@Suite("PendingApprovalsResponse Tests")
struct PendingApprovalsResponseTests {
    @Test("Response initializes correctly")
    func testResponseInit() {
        let approval = Approval(
            id: "1",
            issueId: "AASF-100",
            phase: "plan",
            reason: "Test",
            agent: "odin"
        )
        let response = PendingApprovalsResponse(
            approvals: [approval],
            count: 1,
            timestamp: 1234567890.0
        )

        #expect(response.approvals.count == 1)
        #expect(response.count == 1)
        #expect(response.timestamp == 1234567890.0)
    }
}

// MARK: - Mock API Client Approval Tests

@Suite("MockAPIClient Approval Tests")
struct MockAPIClientApprovalTests {
    @Test("Mock approve returns success")
    func testMockApprove() async throws {
        let client = MockHeimdallAPIClient()
        client.simulatedDelay = 0

        let result = try await client.approve(id: "test-1")

        #expect(result.ok == true)
        #expect(result.message == "Approved")
    }

    @Test("Mock reject returns success")
    func testMockReject() async throws {
        let client = MockHeimdallAPIClient()
        client.simulatedDelay = 0

        let result = try await client.reject(id: "test-1", reason: "Not ready")

        #expect(result.ok == true)
        #expect(result.message == "Rejected")
    }

    @Test("Mock hold returns success")
    func testMockHold() async throws {
        let client = MockHeimdallAPIClient()
        client.simulatedDelay = 0

        let result = try await client.hold(id: "test-1")

        #expect(result.ok == true)
        #expect(result.message == "Held")
    }

    @Test("Mock fetchPendingApprovals returns data")
    func testMockFetchPendingApprovals() async throws {
        let client = MockHeimdallAPIClient()
        client.simulatedDelay = 0

        let response = try await client.fetchPendingApprovals()

        #expect(response.approvals.count == 1)
        #expect(response.approvals.first?.issueId == "AASF-100")
    }
}
