// Sources/HEIMDALLControlSurface/AppState.swift
// HCS-002: Observable state container for UI reactivity
// HCS-006: Extended with escalation handling and notification support

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

    // Notification service (injected, HCS-006)
    private var notificationService: (any NotificationServiceProtocol)?
    private var apiClient: (any HeimdallAPIClientProtocol)?

    // Toggle dashboard visibility
    func toggleDashboard() {
        isDashboardOpen.toggle()
    }

    // Clear error
    func clearError() {
        lastError = nil
    }

    /// Configure services (called from AppDelegate, HCS-006)
    func configure(
        notificationService: any NotificationServiceProtocol,
        apiClient: any HeimdallAPIClientProtocol
    ) {
        self.notificationService = notificationService
        self.apiClient = apiClient
    }
}

// MARK: - ConnectionEventHandler Conformance (HCS-006)

extension AppState: ConnectionEventHandler {
    func handleEvent(_ event: WebSocketEvent) {
        switch event.type {
        case .verdict:
            handleVerdictEvent(event)
        case .escalation:
            handleEscalationEvent(event)
        default:
            break
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
