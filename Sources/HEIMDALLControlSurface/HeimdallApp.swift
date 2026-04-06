// Sources/HEIMDALLControlSurface/HeimdallApp.swift
// HCS-002: Main app entry point

import SwiftUI

@main
struct HEIMDALLControlSurfaceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()

    var body: some Scene {
        // Menu bar icon and dropdown (always present, handles hotkey)
        MenuBarExtra("HEIMDALL", systemImage: "circle.hexagongrid.fill") {
            MenuBarView()
                .environment(appState)
        }
        .menuBarExtraStyle(.window)

        // Dashboard window (opens via menu action or global hotkey)
        Window("HEIMDALL Dashboard", id: "dashboard") {
            DashboardView()
                .environment(appState)
        }
        .defaultSize(width: 800, height: 600)
    }
}
