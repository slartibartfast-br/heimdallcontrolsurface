// Sources/HEIMDALLControlSurface/AppDelegate.swift
// HCS-002: Lifecycle
// HCS-008: HotkeyService initialization

import AppKit
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Notification delegate for handling user actions (HCS-006)
    private(set) var notificationDelegate: NotificationDelegate?
    /// Notification service (HCS-006)
    private(set) var notificationService: NotificationService?
    /// Hotkey service (HCS-008)
    private(set) var hotkeyService: HotkeyService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupNotifications()
        hotkeyService = HotkeyService()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyService?.unregisterAll()
    }

    /// Set up notification service and request permission (HCS-006)
    private func setupNotifications() {
        notificationService = NotificationService()
        notificationService?.registerCategories()

        notificationDelegate = NotificationDelegate()
        UNUserNotificationCenter.current().delegate = notificationDelegate

        Task {
            _ = try? await notificationService?.requestAuthorization()
        }
    }
}

extension Notification.Name {
    static let openDashboard = Notification.Name("openDashboard")
}
