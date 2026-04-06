// Sources/HEIMDALLControlSurface/Services/HeimdallAPIClient.swift
// AASF-647: URLSession-based HTTP client for HEIMDALL monitor API

import Foundation

/// Errors that can occur during API operations
public enum HeimdallAPIError: Error, Sendable {
    case invalidURL
    case networkError(Error)
    case httpError(statusCode: Int, data: Data?)
    case decodingError(Error)
    case serverError(message: String)
}

/// Approval action result
public struct ApprovalResult: Codable, Sendable {
    public let ok: Bool
    public let message: String?
    public let error: String?

    public init(ok: Bool, message: String? = nil, error: String? = nil) {
        self.ok = ok
        self.message = message
        self.error = error
    }
}

/// Protocol for HEIMDALL API client (enables mocking)
public protocol HeimdallAPIClientProtocol: Sendable {
    func fetchPipeline() async throws -> PipelineResponse
    func fetchVerdicts(limit: Int) async throws -> [VerdictEntry]
    func fetchHeartbeat() async throws -> HeartbeatResponse
    func fetchTelemetry() async throws -> KPIResponse
    func fetchInfraHealth() async throws -> InfraResponse
    func fetchProjects() async throws -> SwitcherResponse
    func fetchAgents() async throws -> AgentsResponse
    func fetchDecisions(limit: Int, project: String?) async throws -> DecisionsResponse
    func approve(id: String) async throws -> ApprovalResult
    func reject(id: String, reason: String?) async throws -> ApprovalResult
}

/// URLSession-based HTTP client for HEIMDALL monitor API
public final class HeimdallAPIClient: HeimdallAPIClientProtocol, @unchecked Sendable {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = JSONDecoder.heimdallDecoder()
    }

    // MARK: - Pipeline

    public func fetchPipeline() async throws -> PipelineResponse {
        try await get("/api/pipeline")
    }

    // MARK: - Verdicts

    public func fetchVerdicts(limit: Int = 50) async throws -> [VerdictEntry] {
        let response: VerdictsResponse = try await get("/api/verdicts?limit=\(limit)")
        return response.verdicts
    }

    // MARK: - Heartbeat

    public func fetchHeartbeat() async throws -> HeartbeatResponse {
        try await get("/api/heartbeat")
    }

    // MARK: - Telemetry

    public func fetchTelemetry() async throws -> KPIResponse {
        try await get("/api/v1/telemetry")
    }

    // MARK: - Infrastructure

    public func fetchInfraHealth() async throws -> InfraResponse {
        try await get("/api/v1/infra")
    }

    // MARK: - Projects

    public func fetchProjects() async throws -> SwitcherResponse {
        try await get("/api/v1/projects")
    }

    // MARK: - Agents

    public func fetchAgents() async throws -> AgentsResponse {
        try await get("/api/v1/agents")
    }

    // MARK: - Decisions

    public func fetchDecisions(
        limit: Int = 20,
        project: String? = nil
    ) async throws -> DecisionsResponse {
        var path = "/api/v1/decisions?limit=\(limit)"
        if let project {
            path += "&project=\(project)"
        }
        return try await get(path)
    }

    // MARK: - Approval Actions

    public func approve(id: String) async throws -> ApprovalResult {
        try await post("/api/v1/approve/\(id)", body: nil as String?)
    }

    public func reject(id: String, reason: String? = nil) async throws -> ApprovalResult {
        struct RejectBody: Encodable { let reason: String }
        let body = reason.map { RejectBody(reason: $0) }
        return try await post("/api/v1/reject/\(id)", body: body)
    }

    // MARK: - Private Helpers

    private func get<T: Decodable>(_ path: String) async throws -> T {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw HeimdallAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await perform(request)
    }

    private func post<T: Decodable, B: Encodable>(
        _ path: String,
        body: B?
    ) async throws -> T {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw HeimdallAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        return try await perform(request)
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await executeRequest(request)
        try validateHTTPResponse(response, data: data)
        return try decodeResponse(data)
    }

    private func executeRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw HeimdallAPIError.networkError(error)
        }
    }

    private func validateHTTPResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HeimdallAPIError.networkError(
                NSError(domain: "HeimdallAPI", code: -1)
            )
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw HeimdallAPIError.httpError(
                statusCode: httpResponse.statusCode,
                data: data
            )
        }
    }

    private func decodeResponse<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw HeimdallAPIError.decodingError(error)
        }
    }
}
