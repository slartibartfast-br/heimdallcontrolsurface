// Sources/HEIMDALLControlSurface/AppState.swift
// HCS-002: Observable state container for UI reactivity
// HCS-005: Extended with pending approvals queue
// HCS-006: Extended with escalation handling and notification support
// HCS-007: Extended with event stream storage and sound alerts

import SwiftUI

/// Model for tracking pending escalations
public struct EscalationEntry: Identifiable, Sendable {
    public let id: String
    public let issueId: String
    public let gate: String
    public let reason: String
    public let timestamp: Date

    public init(issueId: String, gate: String, reason: String, timestamp: Date = Date()) {
        self.id = "\(issueId)-\(timestamp.timeIntervalSince1970)"
        self.issueId = issueId
        self.gate = gate
        self.reason = reason
        self.timestamp = timestamp
    }
}

@MainActor
@Observable
final class AppState: @unchecked Sendable {
    // Dashboard window visibility
    var isDashboardOpen: Bool = false

    // Selected project (for future use)
    var selectedProjectId: String?

    // Connection status
    var isConnected: Bool = false

    // Last error message (nil if none)
    var lastError: String?

    // Pending escalations requiring user action (HCS-006)
    var escalations: [EscalationEntry] = []

    // Pending approvals queue (HCS-005)
    var pendingApprovals: [Approval] = []

    // Pending actions with undo window (HCS-005)
    var pendingActions: [ApprovalAction] = []

    // Event stream for real-time display (HCS-007)
    var events: [WebSocketEvent] = []
    private let maxEvents: Int = 500

    // Notification service (injected, HCS-006)
    private var notificationService: (any NotificationServiceProtocol)?
    private var apiClient: (any HeimdallAPIClientProtocol)?
    // Sound alert service (HCS-007)
    private var soundService: (any SoundAlertServiceProtocol)?

    // Toggle dashboard visibility
    func toggleDashboard() {
        isDashboardOpen.toggle()
    }

    // Clear error
    func clearError() {
        lastError = nil
    }

    /// Configure services (called from AppDelegate, HCS-006, HCS-007)
    func configure(
        notificationService: any NotificationServiceProtocol,
        apiClient: any HeimdallAPIClientProtocol,
        soundService: (any SoundAlertServiceProtocol)? = nil
    ) {
        self.notificationService = notificationService
        self.apiClient = apiClient
        self.soundService = soundService ?? SoundAlertService()
    }
}

// MARK: - Pending Approvals (HCS-005)

extension AppState {
    /// Refresh pending approvals from API
    func refreshPendingApprovals() async throws {
        guard let apiClient else { return }
        let response = try await apiClient.fetchPendingApprovals()
        pendingApprovals = response.approvals
    }

    /// Queue an approval action with undo window
    func queueApprovalAction(approval: Approval, actionType: ApprovalActionType) {
        // Remove from pending list immediately (optimistic UI)
        pendingApprovals.removeAll { $0.id == approval.id }

        // Create action with undo window
        let action = ApprovalAction(approval: approval, actionType: actionType)
        pendingActions.append(action)

        // Schedule execution after undo window
        scheduleActionExecution(action)
    }

    /// Cancel a pending action (undo)
    func cancelPendingAction(_ action: ApprovalAction) {
        action.cancel()
        pendingActions.removeAll { $0.id == action.id }
        // Restore to pending list
        pendingApprovals.append(action.approval)
    }

    /// Schedule action execution after undo window expires
    private func scheduleActionExecution(_ action: ApprovalAction) {
        Task {
            try? await Task.sleep(for: .seconds(ApprovalAction.undoWindowSeconds))
            await executeActionIfNotCancelled(action)
        }
    }

    /// Execute action if not cancelled
    private func executeActionIfNotCancelled(_ action: ApprovalAction) async {
        guard !action.isCancelled, let apiClient else {
            cleanupAction(action)
            return
        }

        do {
            try await action.execute(using: apiClient)
        } catch {
            lastError = "Action failed: \(error.localizedDescription)"
        }

        cleanupAction(action)
    }

    /// Remove action from pending list
    private func cleanupAction(_ action: ApprovalAction) {
        pendingActions.removeAll { $0.id == action.id }
    }
}

// MARK: - ConnectionEventHandler Conformance (HCS-006, HCS-007)

extension AppState: ConnectionEventHandler {
    func handleEvent(_ event: WebSocketEvent) {
        // HCS-007: Store event for EventStreamView
        storeEvent(event)
        // HCS-007: Play sound alert
        soundService?.playSound(for: event.type)
        // HCS-006: Handle specific event types
        switch event.type {
        case .verdict:
            handleVerdictEvent(event)
        case .escalation:
            handleEscalationEvent(event)
        default:
            break
        }
    }

    /// Store event in the events array, capped at maxEvents (HCS-007)
    private func storeEvent(_ event: WebSocketEvent) {
        events.append(event)
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
    }

    private func handleVerdictEvent(_ event: WebSocketEvent) {
        guard let payload = try? event.verdictPayload() else { return }
        if payload.verdict.outcome == .escalate {
            handleEscalation(verdict: payload.verdict)
        }
    }

    private func handleEscalationEvent(_ event: WebSocketEvent) {
        // For explicit escalation events, extract verdict and handle
        guard let payload = try? event.verdictPayload() else { return }
        handleEscalation(verdict: payload.verdict)
    }

    private func handleEscalation(verdict: VerdictEntry) {
        let entry = EscalationEntry(
            issueId: verdict.issueId,
            gate: verdict.gate,
            reason: verdict.reason,
            timestamp: verdict.timestamp
        )
        escalations.append(entry)
        Task {
            try? await notificationService?.showEscalationNotification(
                issueId: verdict.issueId,
                gate: verdict.gate,
                reason: verdict.reason
            )
        }
    }
}

// MARK: - NotificationResponseHandler Conformance (HCS-006)

extension AppState: NotificationResponseHandler {
    func handleApprove(issueId: String) async {
        do {
            _ = try await apiClient?.approve(id: issueId)
            escalations.removeAll { $0.issueId == issueId }
        } catch {
            lastError = "Approve failed: \(error.localizedDescription)"
        }
    }

    func handleReject(issueId: String) async {
        do {
            _ = try await apiClient?.reject(id: issueId, reason: nil)
            escalations.removeAll { $0.issueId == issueId }
        } catch {
            lastError = "Reject failed: \(error.localizedDescription)"
        }
    }

    func handleViewIssue(issueId: String) {
        selectedProjectId = issueId  // Used to navigate dashboard
        isDashboardOpen = true
        NotificationCenter.default.post(name: .openDashboard, object: nil)
    }
}
