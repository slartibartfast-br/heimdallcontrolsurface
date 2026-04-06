// Sources/HEIMDALLControlSurface/Views/MenuBarView.swift
// HCS-002: Menu bar dropdown content

import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 12) {
            headerSection
            Divider()
            statusSection
            Divider()
            actionsSection
        }
        .padding()
        .frame(width: 280)
        .onReceive(NotificationCenter.default.publisher(for: .openDashboard)) { _ in
            openWindow(id: "dashboard")
        }
    }

    private var headerSection: some View {
        HStack {
            Image(systemName: "circle.hexagongrid.fill")
                .foregroundStyle(.blue)
            Text("HEIMDALL")
                .font(.headline)
            Spacer()
            connectionIndicator
        }
    }

    private var connectionIndicator: some View {
        Circle()
            .fill(appState.isConnected ? Color.green : Color.red)
            .frame(width: 8, height: 8)
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Status: Placeholder")
                .font(.subheadline)
            Text("No active pipelines")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionsSection: some View {
        VStack(spacing: 8) {
            Button("Open Dashboard") {
                openWindow(id: "dashboard")
            }
            .buttonStyle(.borderedProminent)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.bordered)
        }
    }
}

#Preview {
    MenuBarView()
        .environment(AppState())
}
