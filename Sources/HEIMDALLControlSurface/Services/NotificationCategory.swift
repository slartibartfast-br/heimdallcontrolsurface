// Sources/HEIMDALLControlSurface/Services/NotificationCategory.swift
// HCS-006: Notification categories for escalation actions

import UserNotifications

/// Notification category identifiers
public enum NotificationCategoryID: String {
    case escalation = "ESCALATION"
    case verdict = "VERDICT"
    case error = "ERROR"
}

/// Notification action identifiers
public enum NotificationActionID: String {
    case approve = "APPROVE_ACTION"
    case reject = "REJECT_ACTION"
    case view = "VIEW_ACTION"
    case dismiss = "DISMISS_ACTION"
}

/// Creates and registers notification categories
public struct NotificationCategories {
    /// Create escalation category with approve/reject buttons
    public static func escalationCategory() -> UNNotificationCategory {
        let approveAction = UNNotificationAction(
            identifier: NotificationActionID.approve.rawValue,
            title: "Approve",
            options: [.foreground]
        )
        let rejectAction = UNNotificationAction(
            identifier: NotificationActionID.reject.rawValue,
            title: "Reject",
            options: [.destructive, .foreground]
        )
        return UNNotificationCategory(
            identifier: NotificationCategoryID.escalation.rawValue,
            actions: [approveAction, rejectAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
    }

    /// Create verdict category with view button
    public static func verdictCategory() -> UNNotificationCategory {
        let viewAction = UNNotificationAction(
            identifier: NotificationActionID.view.rawValue,
            title: "View Details",
            options: [.foreground]
        )
        return UNNotificationCategory(
            identifier: NotificationCategoryID.verdict.rawValue,
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )
    }

    /// Create error category (dismiss only)
    public static func errorCategory() -> UNNotificationCategory {
        return UNNotificationCategory(
            identifier: NotificationCategoryID.error.rawValue,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
    }

    /// All categories for registration
    public static func allCategories() -> Set<UNNotificationCategory> {
        [escalationCategory(), verdictCategory(), errorCategory()]
    }
}
