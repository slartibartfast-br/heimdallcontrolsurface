// Sources/HEIMDALLControlSurface/Models/ApprovalAction.swift
// HCS-005: Model for approval actions with 10-second undo window

import Foundation

/// Represents a pending approval action that can be undone within a time window
@MainActor
@Observable
public final class ApprovalAction: Identifiable, @unchecked Sendable {
    public let id: UUID
    public let approval: Approval
    public let actionType: ApprovalActionType
    public let startTime: Date
    public private(set) var isExecuted: Bool = false
    public private(set) var isCancelled: Bool = false

    /// Undo window duration in seconds
    public static let undoWindowSeconds: TimeInterval = 10.0

    /// Time remaining in the undo window
    public var timeRemaining: TimeInterval {
        max(0, Self.undoWindowSeconds - Date().timeIntervalSince(startTime))
    }

    /// Whether the undo window is still open
    public var canUndo: Bool {
        !isExecuted && !isCancelled && timeRemaining > 0
    }

    /// Fraction of time remaining (1.0 to 0.0)
    public var progressFraction: Double {
        timeRemaining / Self.undoWindowSeconds
    }

    public init(approval: Approval, actionType: ApprovalActionType) {
        self.id = UUID()
        self.approval = approval
        self.actionType = actionType
        self.startTime = Date()
    }

    /// Mark as cancelled (user pressed undo)
    public func cancel() {
        guard canUndo else { return }
        isCancelled = true
    }

    /// Mark as executed (timer expired, action committed)
    public func markExecuted() {
        guard !isCancelled else { return }
        isExecuted = true
    }
}

// MARK: - Action Execution

extension ApprovalAction {
    /// Execute the action via API client
    public func execute(using apiClient: any HeimdallAPIClientProtocol) async throws {
        guard !isCancelled else { return }

        switch actionType {
        case .approve:
            _ = try await apiClient.approve(id: approval.id)
        case .reject:
            _ = try await apiClient.reject(id: approval.id, reason: nil)
        case .hold:
            _ = try await apiClient.hold(id: approval.id)
        }

        await MainActor.run {
            markExecuted()
        }
    }
}

// MARK: - Display Helpers

extension ApprovalAction {
    /// Human-readable action description
    public var actionDescription: String {
        switch actionType {
        case .approve: return "Approving"
        case .reject: return "Rejecting"
        case .hold: return "Holding"
        }
    }

    /// Formatted time remaining
    public var formattedTimeRemaining: String {
        String(format: "%.0fs", timeRemaining)
    }
}
