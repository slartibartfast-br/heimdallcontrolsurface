// Sources/HEIMDALLControlSurface/Services/NotificationDelegate.swift
// HCS-006: UNUserNotificationCenter delegate for handling user actions

import Foundation
import UserNotifications

/// Protocol for notification response handling (enables testing)
public protocol NotificationResponseHandler: AnyObject {
    @MainActor func handleApprove(issueId: String) async
    @MainActor func handleReject(issueId: String) async
    @MainActor func handleViewIssue(issueId: String)
}

/// UNUserNotificationCenter delegate for inline action handling
public final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    @MainActor public weak var responseHandler: (any NotificationResponseHandler)?

    public override init() {
        super.init()
    }

    /// Handle user response to notification action
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping @Sendable () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let issueId = userInfo["issueId"] as? String ?? ""
        let actionId = response.actionIdentifier

        Task { @MainActor [weak self] in
            guard let self else {
                completionHandler()
                return
            }
            await self.routeAction(actionId, issueId: issueId)
            completionHandler()
        }
    }

    /// Route action to appropriate handler
    @MainActor
    private func routeAction(_ actionId: String, issueId: String) async {
        switch actionId {
        case NotificationActionID.approve.rawValue:
            await responseHandler?.handleApprove(issueId: issueId)
        case NotificationActionID.reject.rawValue:
            await responseHandler?.handleReject(issueId: issueId)
        case NotificationActionID.view.rawValue:
            responseHandler?.handleViewIssue(issueId: issueId)
        case UNNotificationDefaultActionIdentifier:
            // User clicked notification body — open dashboard
            responseHandler?.handleViewIssue(issueId: issueId)
        default:
            break
        }
    }

    /// Handle notification presentation while app is in foreground
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping @Sendable (UNNotificationPresentationOptions) -> Void
    ) {
        // Always show notifications even when app is active
        completionHandler([.banner, .sound])
    }
}
