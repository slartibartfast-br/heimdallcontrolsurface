// Sources/HEIMDALLControlSurface/Views/DashboardView.swift
// HCS-002: Dashboard window content

import SwiftUI

struct DashboardView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationSplitView {
            sidebarContent
        } detail: {
            detailContent
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    private var sidebarContent: some View {
        List {
            Section("Projects") {
                Text("No projects loaded")
                    .foregroundStyle(.secondary)
            }
            Section("Agents") {
                Text("No agents connected")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("HEIMDALL")
    }

    private var detailContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "circle.hexagongrid.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue.opacity(0.5))
            Text("HEIMDALL Control Surface")
                .font(.largeTitle)
            Text("Select a project or agent to view details")
                .foregroundStyle(.secondary)
            if let error = appState.lastError {
                errorBanner(error)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
            Text(message)
            Spacer()
            Button("Dismiss") {
                appState.clearError()
            }
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
        .padding()
    }
}

#Preview {
    DashboardView()
        .environment(AppState())
}
