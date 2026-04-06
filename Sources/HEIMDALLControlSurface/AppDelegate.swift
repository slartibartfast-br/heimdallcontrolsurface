// Sources/HEIMDALLControlSurface/AppDelegate.swift
// HCS-002: Lifecycle and global hotkey setup
// HCS-008: Delegate hotkey registration to HotkeyService

import AppKit
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Hotkey service for global keyboard shortcuts (HCS-008)
    private(set) var hotkeyService: HotkeyService?
    /// Notification delegate for handling user actions (HCS-006)
    private(set) var notificationDelegate: NotificationDelegate?
    /// Notification service (HCS-006)
    private(set) var notificationService: NotificationService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon for menu bar app
        NSApp.setActivationPolicy(.accessory)
        // Set up notifications (HCS-006)
        setupNotifications()
        // Note: Hotkey registration deferred to wireHotkeys() in HeimdallApp
        // because we need AppState reference for action handler
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyService?.unregisterHotkeys()
    }

    /// Set up notification service and request permission (HCS-006)
    private func setupNotifications() {
        notificationService = NotificationService()
        notificationService?.registerCategories()

        notificationDelegate = NotificationDelegate()
        UNUserNotificationCenter.current().delegate = notificationDelegate

        // Request permission (non-blocking)
        Task {
            _ = try? await notificationService?.requestAuthorization()
        }
    }

    /// Initialize hotkey service (called from HeimdallApp.wireHotkeys)
    func initializeHotkeyService() -> HotkeyService {
        let service = HotkeyService()
        self.hotkeyService = service
        return service
    }
}

extension Notification.Name {
    static let openDashboard = Notification.Name("openDashboard")
}
