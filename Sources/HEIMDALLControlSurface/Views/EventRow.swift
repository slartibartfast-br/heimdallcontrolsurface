// Sources/HEIMDALLControlSurface/Views/EventRow.swift
// HCS-007: Formatted event row with timestamp, icon, details

import SwiftUI

/// Single event row in the stream list
struct EventRow: View {
    let event: WebSocketEvent

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    var body: some View {
        HStack(spacing: 8) {
            severityIcon
            timestampText
            eventTypeBadge
            projectCodeText
            eventSummaryText
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var severityIcon: some View {
        Image(systemName: iconName(for: event))
            .foregroundStyle(iconColor(for: event))
            .frame(width: 20)
    }

    private var timestampText: some View {
        Text(Self.timeFormatter.string(from: event.timestamp))
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.secondary)
    }

    private var eventTypeBadge: some View {
        Text(event.type.displayName)
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeColor(for: event.type).opacity(0.2))
            .foregroundStyle(badgeColor(for: event.type))
            .clipShape(Capsule())
    }

    @ViewBuilder
    private var projectCodeText: some View {
        if let projectCode = event.projectCode {
            Text(projectCode)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var eventSummaryText: some View {
        Text(eventSummary(for: event))
            .lineLimit(1)
            .truncationMode(.tail)
    }

    private func iconName(for event: WebSocketEvent) -> String {
        switch event.severity {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        case .critical: return "exclamationmark.octagon"
        }
    }

    private func iconColor(for event: WebSocketEvent) -> Color {
        switch event.severity {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .critical: return .red
        }
    }

    private func badgeColor(for eventType: EventType) -> Color {
        switch eventType {
        case .verdict: return .purple
        case .escalation: return .red
        case .pipelineUpdate: return .green
        case .factoryUpdate: return .blue
        case .agentStatus: return .cyan
        case .heartbeat: return .gray
        }
    }

    private func eventSummary(for event: WebSocketEvent) -> String {
        switch event.type {
        case .verdict:
            return verdictSummary(event)
        case .escalation:
            return escalationSummary(event)
        case .pipelineUpdate:
            return pipelineSummary(event)
        case .factoryUpdate:
            return factorySummary(event)
        case .agentStatus:
            return agentSummary(event)
        case .heartbeat:
            return heartbeatSummary(event)
        }
    }

    private func verdictSummary(_ event: WebSocketEvent) -> String {
        guard let payload = try? event.verdictPayload() else { return "Verdict" }
        return "\(payload.verdict.issueId): \(payload.verdict.outcome.rawValue) - \(payload.verdict.reason)"
    }

    private func escalationSummary(_ event: WebSocketEvent) -> String {
        guard let payload = try? event.verdictPayload() else { return "Escalation" }
        return "\(payload.verdict.issueId): \(payload.verdict.reason)"
    }

    private func pipelineSummary(_ event: WebSocketEvent) -> String {
        guard let payload = try? event.decodePayload(as: PipelineUpdatePayload.self) else { return "Pipeline" }
        return "\(payload.pipeline.issueId): \(payload.pipeline.phase) - \(payload.pipeline.status.rawValue)"
    }

    private func factorySummary(_ event: WebSocketEvent) -> String {
        guard let payload = try? event.factoryUpdatePayload() else { return "Factory" }
        return "Factory \(payload.factoryStatus.rawValue), \(payload.pipelines.count) pipelines"
    }

    private func agentSummary(_ event: WebSocketEvent) -> String {
        guard let payload = try? event.decodePayload(as: AgentStatusPayload.self) else { return "Agent" }
        return "Agent \(payload.agent.name): \(payload.agent.status.rawValue)"
    }

    private func heartbeatSummary(_ event: WebSocketEvent) -> String {
        guard let payload = try? event.heartbeatPayload() else { return "Heartbeat" }
        return "\(payload.agents.count) agents, uptime \(payload.uptimeSeconds)s"
    }
}
