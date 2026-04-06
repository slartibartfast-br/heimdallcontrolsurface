// Sources/HEIMDALLControlSurface/Views/ApprovalRowView.swift
// HCS-005: Individual approval row with approve/reject/hold action buttons

import SwiftUI

/// Row view displaying a single pending approval with action buttons
struct ApprovalRowView: View {
    let approval: Approval
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerRow
            reasonText
            actionButtons
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack {
            issueLabel
            Spacer()
            phaseLabel
            agentLabel
        }
    }

    private var issueLabel: some View {
        Text(approval.issueId)
            .font(.headline.monospaced())
    }

    private var phaseLabel: some View {
        Text(approval.phase.capitalized)
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(phaseColor.opacity(0.2))
            .foregroundStyle(phaseColor)
            .clipShape(Capsule())
    }

    private var phaseColor: Color {
        switch approval.phase.lowercased() {
        case "plan": return .blue
        case "implement": return .purple
        case "review": return .orange
        default: return .gray
        }
    }

    private var agentLabel: some View {
        Label(approval.agent, systemImage: "person.circle")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    // MARK: - Reason

    private var reasonText: some View {
        Text(approval.reason)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(2)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Spacer()
            holdButton
            rejectButton
            approveButton
        }
    }

    private var approveButton: some View {
        Button {
            appState.queueApprovalAction(approval: approval, actionType: .approve)
        } label: {
            Label("Approve", systemImage: "checkmark.circle.fill")
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)
        .controlSize(.small)
    }

    private var rejectButton: some View {
        Button {
            appState.queueApprovalAction(approval: approval, actionType: .reject)
        } label: {
            Label("Reject", systemImage: "xmark.circle.fill")
        }
        .buttonStyle(.bordered)
        .tint(.red)
        .controlSize(.small)
    }

    private var holdButton: some View {
        Button {
            appState.queueApprovalAction(approval: approval, actionType: .hold)
        } label: {
            Label("Hold", systemImage: "pause.circle.fill")
        }
        .buttonStyle(.bordered)
        .tint(.orange)
        .controlSize(.small)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ApprovalRowView(
        approval: Approval(
            id: "1",
            issueId: "AASF-100",
            phase: "plan",
            reason: "Plan requires architect review before proceeding",
            agent: "odin"
        )
    )
    .environment(AppState())
    .frame(width: 400)
    .padding()
}
#endif
