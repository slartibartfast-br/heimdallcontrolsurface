// Sources/HEIMDALLControlSurface/AppState.swift
// HCS-002: Observable state container for UI reactivity

import SwiftUI

@Observable
final class AppState {
    // Dashboard window visibility
    var isDashboardOpen: Bool = false

    // Selected project (for future use)
    var selectedProjectId: String?

    // Connection status
    var isConnected: Bool = false

    // Last error message (nil if none)
    var lastError: String?

    // Toggle dashboard visibility
    func toggleDashboard() {
        isDashboardOpen.toggle()
    }

    // Clear error
    func clearError() {
        lastError = nil
    }
}
