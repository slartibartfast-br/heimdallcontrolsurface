// Sources/HEIMDALLControlSurface/Views/EventRow.swift
// HCS-007: Event row component for stream list

import SwiftUI

struct EventRow: View {
    let event: WebSocketEvent

    var body: some View {
        HStack(spacing: 12) {
            iconView
            VStack(alignment: .leading, spacing: 2) {
                headerRow
                detailText
            }
            Spacer()
            timestampText
        }
        .padding(.vertical, 4)
    }

    private var iconView: some View {
        Image(systemName: Self.icon(for: event.type))
            .font(.title3)
            .foregroundStyle(Self.color(for: event.severity))
            .frame(width: 24)
    }

    private var headerRow: some View {
        Text(event.type.rawValue.replacingOccurrences(of: "_", with: " ").uppercased())
            .font(.caption.bold())
            .foregroundStyle(Self.color(for: event.severity))
    }

    private var detailText: some View {
        Text(eventDetail)
            .font(.subheadline)
            .foregroundStyle(.primary)
            .lineLimit(2)
    }

    private var timestampText: some View {
        Text(event.timestamp, style: .time)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var eventDetail: String {
        switch event.type {
        case .verdict:
            if let payload = try? event.verdictPayload() {
                return "\(payload.verdict.issueId): \(payload.verdict.outcome.rawValue)"
            }
        case .heartbeat:
            return "System heartbeat"
        case .escalation:
            return "Escalation required"
        default:
            break
        }
        return event.type.rawValue
    }
}

// MARK: - Helpers

extension EventRow {
    static func icon(for type: EventType) -> String {
        switch type {
        case .factoryUpdate: return "building.2"
        case .verdict: return "checkmark.seal"
        case .heartbeat: return "heart.fill"
        case .pipelineUpdate: return "arrow.triangle.branch"
        case .agentStatus: return "person.fill"
        case .escalation: return "exclamationmark.triangle.fill"
        }
    }

    static func color(for severity: EventSeverity) -> Color {
        switch severity {
        case .info: return .secondary
        case .warning: return .orange
        case .error: return .red
        case .critical: return .red
        }
    }
}

#Preview {
    List {
        EventRow(event: WebSocketEvent(
            type: .heartbeat,
            timestamp: Date(),
            payload: Data()
        ))
        EventRow(event: WebSocketEvent(
            type: .escalation,
            timestamp: Date(),
            payload: Data()
        ))
    }
}
