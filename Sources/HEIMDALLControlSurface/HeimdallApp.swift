// Sources/HEIMDALLControlSurface/HeimdallApp.swift
// HCS-002: Main app entry point
// HCS-006: Wire notification services to AppState

import SwiftUI

@main
struct HEIMDALLControlSurfaceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()

    init() {
        // Wiring deferred to onAppear since appDelegate isn't ready at init
    }

    var body: some Scene {
        // Menu bar icon and dropdown (always present, handles hotkey)
        MenuBarExtra("HEIMDALL", systemImage: "circle.hexagongrid.fill") {
            MenuBarView()
                .environment(appState)
                .onAppear { wireNotifications() }
        }
        .menuBarExtraStyle(.window)

        // Dashboard window (opens via menu action or global hotkey)
        Window("HEIMDALL Dashboard", id: "dashboard") {
            DashboardView()
                .environment(appState)
        }
        .defaultSize(width: 800, height: 600)
    }

    /// Wire notification delegate and service to AppState (HCS-006)
    private func wireNotifications() {
        guard let notificationDelegate = appDelegate.notificationDelegate,
              let notificationService = appDelegate.notificationService else {
            return
        }
        // Connect response handler
        notificationDelegate.responseHandler = appState
        // Configure AppState with services (default HEIMDALL monitor URL)
        let baseURL = URL(string: "http://localhost:7846")!
        let apiClient = HeimdallAPIClient(baseURL: baseURL)
        appState.configure(notificationService: notificationService, apiClient: apiClient)
    }
}
