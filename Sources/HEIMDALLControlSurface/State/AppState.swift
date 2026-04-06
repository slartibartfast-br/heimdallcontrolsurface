// Sources/HEIMDALLControlSurface/State/AppState.swift
// HCS-004: Central application state container with real-time updates

import Foundation

// MARK: - App State

/// Central application state container
@MainActor
public final class AppState: ObservableObject, ConnectionEventHandler {
    // Connection status
    @Published public var connectionStatus: ConnectionStatus = .disconnected

    // Live data from real-time events
    @Published public var pipelines: [PipelineEntry] = []
    @Published public var verdicts: [VerdictEntry] = []
    @Published public var agents: [AgentHeartbeat] = []
    @Published public var factoryStatus: FactoryStatus = .stalled

    // Last update timestamp
    @Published public var lastUpdate: Date?

    // Services
    private let connectionManager: ConnectionManager
    private var statusObservation: Task<Void, Never>?

    public init(connectionManager: ConnectionManager) {
        self.connectionManager = connectionManager
        connectionManager.eventHandler = self
    }

    // MARK: - Public Methods

    public func start() async {
        startStatusObservation()
        await connectionManager.start()
    }

    public func stop() async {
        statusObservation?.cancel()
        statusObservation = nil
        await connectionManager.stop()
    }

    // MARK: - ConnectionEventHandler

    public func handleEvent(_ event: WebSocketEvent) {
        lastUpdate = event.timestamp
        switch event.type {
        case .factoryUpdate:
            handleFactoryUpdate(event)
        case .verdict:
            handleVerdict(event)
        case .heartbeat:
            handleHeartbeat(event)
        case .pipelineUpdate:
            handlePipelineUpdate(event)
        case .agentStatus:
            handleAgentStatus(event)
        }
    }

    // MARK: - Private Methods

    private func startStatusObservation() {
        statusObservation = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                self.connectionStatus = self.connectionManager.status
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }

    private func handleFactoryUpdate(_ event: WebSocketEvent) {
        guard let payload = try? event.factoryUpdatePayload() else { return }
        factoryStatus = payload.factoryStatus
        pipelines = payload.pipelines
    }

    private func handleVerdict(_ event: WebSocketEvent) {
        guard let payload = try? event.verdictPayload() else { return }
        // Prepend new verdict, keep last 50
        verdicts.insert(payload.verdict, at: 0)
        if verdicts.count > 50 {
            verdicts = Array(verdicts.prefix(50))
        }
    }

    private func handleHeartbeat(_ event: WebSocketEvent) {
        guard let payload = try? event.heartbeatPayload() else { return }
        agents = payload.agents
    }

    private func handlePipelineUpdate(_ event: WebSocketEvent) {
        guard let payload = try? event.decodePayload(as: PipelineUpdatePayload.self) else { return }
        updatePipeline(payload.pipeline)
    }

    private func handleAgentStatus(_ event: WebSocketEvent) {
        guard let payload = try? event.decodePayload(as: AgentStatusPayload.self) else { return }
        updateAgent(payload.agent)
    }

    private func updatePipeline(_ pipeline: PipelineEntry) {
        if let index = pipelines.firstIndex(where: { $0.issueId == pipeline.issueId }) {
            pipelines[index] = pipeline
        } else {
            pipelines.append(pipeline)
        }
    }

    private func updateAgent(_ agent: AgentHeartbeat) {
        if let index = agents.firstIndex(where: { $0.name == agent.name }) {
            agents[index] = agent
        } else {
            agents.append(agent)
        }
    }
}
