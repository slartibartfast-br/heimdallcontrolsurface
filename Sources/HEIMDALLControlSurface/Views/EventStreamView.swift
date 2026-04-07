// Sources/HEIMDALLControlSurface/Views/EventStreamView.swift
// HCS-007: Scrolling list of live events with auto-scroll and pause-on-hover

import SwiftUI

/// Main event stream view with filtering and auto-scroll
struct EventStreamView: View {
    @Bindable var viewModel: EventStreamViewModel
    @State private var isPaused: Bool = false
    @State private var filterState = EventFilterState()

    var body: some View {
        VStack(spacing: 0) {
            EventFilterBar(
                filterState: $filterState,
                availableProjects: viewModel.availableProjects
            )
            Divider()
            eventList
            statusBar
        }
    }

    private var eventList: some View {
        ScrollViewReader { proxy in
            List(viewModel.filteredEvents(with: filterState)) { event in
                EventRow(event: event)
                    .id(event.id)
            }
            .listStyle(.plain)
            .onChange(of: viewModel.events.count) { _, _ in
                scrollToLatestIfNotPaused(proxy: proxy)
            }
            .onHover { hovering in
                isPaused = hovering
            }
        }
    }

    private var statusBar: some View {
        HStack {
            connectionIndicator
            Spacer()
            eventCountText
            pauseIndicator
            clearButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }

    private var connectionIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(viewModel.isConnected ? .green : .red)
                .frame(width: 8, height: 8)
            Text(viewModel.isConnected ? "Connected" : "Disconnected")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var eventCountText: some View {
        Text("\(viewModel.filteredEvents(with: filterState).count) events")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var pauseIndicator: some View {
        if isPaused {
            Text("(paused)")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    private var clearButton: some View {
        Button("Clear") {
            viewModel.clearEvents()
        }
        .buttonStyle(.borderless)
        .font(.caption)
    }

    private func scrollToLatestIfNotPaused(proxy: ScrollViewProxy) {
        guard !isPaused else { return }
        let filtered = viewModel.filteredEvents(with: filterState)
        guard let lastEvent = filtered.last else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(lastEvent.id, anchor: .bottom)
        }
    }
}
