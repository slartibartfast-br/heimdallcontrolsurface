// Sources/HEIMDALLControlSurface/Services/NotificationService.swift
// HCS-006: macOS notification service for escalation alerts

import Foundation
import UserNotifications

/// Protocol for notification service (enables mocking)
public protocol NotificationServiceProtocol: Sendable {
    func requestAuthorization() async throws -> Bool
    func showEscalationNotification(issueId: String, gate: String, reason: String) async throws
    func showVerdictNotification(issueId: String, outcome: String, reason: String) async throws
    func showErrorNotification(title: String, message: String) async throws
    func registerCategories()
}

/// UNUserNotificationCenter-based notification service
public final class NotificationService: NotificationServiceProtocol, @unchecked Sendable {
    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    /// Register notification categories on init
    public func registerCategories() {
        center.setNotificationCategories(NotificationCategories.allCategories())
    }

    /// Request notification authorization
    public func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Show escalation notification with approve/reject actions
    public func showEscalationNotification(
        issueId: String,
        gate: String,
        reason: String
    ) async throws {
        let content = createEscalationContent(issueId: issueId, gate: gate, reason: reason)
        let request = UNNotificationRequest(
            identifier: "escalation-\(issueId)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil  // Immediate
        )
        try await center.add(request)
    }

    /// Show verdict notification with view action
    public func showVerdictNotification(
        issueId: String,
        outcome: String,
        reason: String
    ) async throws {
        let content = createVerdictContent(issueId: issueId, outcome: outcome, reason: reason)
        let request = UNNotificationRequest(
            identifier: "verdict-\(issueId)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        try await center.add(request)
    }

    /// Show error notification
    public func showErrorNotification(title: String, message: String) async throws {
        let content = createErrorContent(title: title, message: message)
        let request = UNNotificationRequest(
            identifier: "error-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        try await center.add(request)
    }

    // MARK: - Private Helpers

    private func createEscalationContent(issueId: String, gate: String, reason: String) -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Escalation Required"
        content.subtitle = "\(issueId) — \(gate) gate"
        content.body = reason
        content.sound = .default
        content.categoryIdentifier = NotificationCategoryID.escalation.rawValue
        content.userInfo = ["issueId": issueId, "gate": gate]
        return content
    }

    private func createVerdictContent(issueId: String, outcome: String, reason: String) -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Verdict: \(outcome.capitalized)"
        content.subtitle = issueId
        content.body = reason
        content.sound = .default
        content.categoryIdentifier = NotificationCategoryID.verdict.rawValue
        content.userInfo = ["issueId": issueId]
        return content
    }

    private func createErrorContent(title: String, message: String) -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .defaultCritical
        content.categoryIdentifier = NotificationCategoryID.error.rawValue
        return content
    }
}
