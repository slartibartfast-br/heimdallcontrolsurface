// Sources/HEIMDALLControlSurface/Views/ApprovalQueueView.swift
// HCS-005: SwiftUI view listing pending approvals from HEIMDALL API

import SwiftUI

/// View displaying the queue of pending approvals
struct ApprovalQueueView: View {
    @Environment(AppState.self) private var appState
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            contentView
        }
        .frame(minWidth: 400, minHeight: 300)
        .task {
            await loadApprovals()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Label("Pending Approvals", systemImage: "checkmark.circle.badge.questionmark")
                .font(.headline)
            Spacer()
            refreshButton
        }
        .padding()
    }

    private var refreshButton: some View {
        Button(action: { Task { await loadApprovals() } }) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "arrow.clockwise")
            }
        }
        .buttonStyle(.borderless)
        .disabled(isLoading)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        if let error = errorMessage {
            errorView(message: error)
        } else if appState.pendingApprovals.isEmpty && !isLoading {
            emptyStateView
        } else {
            approvalListView
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Pending Approvals", systemImage: "checkmark.circle")
        } description: {
            Text("All caught up! No items require your approval.")
        }
    }

    private func errorView(message: String) -> some View {
        ContentUnavailableView {
            Label("Error", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Retry") {
                Task { await loadApprovals() }
            }
        }
    }

    private var approvalListView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(appState.pendingApprovals) { approval in
                    ApprovalRowView(approval: approval)
                }
                pendingActionsSection
            }
            .padding()
        }
    }

    @ViewBuilder
    private var pendingActionsSection: some View {
        if !appState.pendingActions.isEmpty {
            Divider()
                .padding(.vertical, 8)
            Text("Pending Actions")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ForEach(appState.pendingActions) { action in
                PendingActionRowView(action: action)
            }
        }
    }

    // MARK: - Data Loading

    private func loadApprovals() async {
        isLoading = true
        errorMessage = nil

        do {
            try await appState.refreshPendingApprovals()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Pending Action Row

/// Displays a pending action with undo countdown
struct PendingActionRowView: View {
    let action: ApprovalAction
    @Environment(AppState.self) private var appState
    @State private var timeRemaining: TimeInterval = 10.0

    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack {
            Label(action.actionDescription, systemImage: actionIcon)
                .foregroundStyle(actionColor)
            Text(action.approval.issueId)
                .font(.caption.monospaced())
            Spacer()
            Text(action.formattedTimeRemaining)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            Button("Undo") {
                appState.cancelPendingAction(action)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!action.canUndo)
        }
        .padding(8)
        .background(actionColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onReceive(timer) { _ in
            timeRemaining = action.timeRemaining
        }
    }

    private var actionIcon: String {
        switch action.actionType {
        case .approve: return "checkmark.circle"
        case .reject: return "xmark.circle"
        case .hold: return "pause.circle"
        }
    }

    private var actionColor: Color {
        switch action.actionType {
        case .approve: return .green
        case .reject: return .red
        case .hold: return .orange
        }
    }
}
