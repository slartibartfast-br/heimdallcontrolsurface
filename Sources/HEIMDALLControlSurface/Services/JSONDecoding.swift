// Sources/HEIMDALLControlSurface/Services/JSONDecoding.swift
// AASF-647: Custom JSON decoders for HEIMDALL API

import Foundation

extension JSONDecoder {
    /// Decoder configured for HEIMDALL API responses
    public static func heimdallDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(decodeHeimdallDate)
        return decoder
    }
}

/// Custom date decoder handling ISO8601 and Unix timestamps
private func decodeHeimdallDate(decoder: Decoder) throws -> Date {
    let container = try decoder.singleValueContainer()

    // Try string first (ISO8601)
    if let dateString = try? container.decode(String.self) {
        return try parseISO8601Date(dateString, codingPath: decoder.codingPath)
    }

    // Try number (Unix timestamp)
    if let timestamp = try? container.decode(Double.self) {
        return Date(timeIntervalSince1970: timestamp)
    }

    throw DecodingError.dataCorrupted(
        .init(
            codingPath: decoder.codingPath,
            debugDescription: "Expected date string or timestamp"
        )
    )
}

/// Parse ISO8601 date string with optional fractional seconds
private func parseISO8601Date(
    _ dateString: String,
    codingPath: [CodingKey]
) throws -> Date {
    // ISO8601 with fractional seconds
    let formatterWithFractional = ISO8601DateFormatter()
    formatterWithFractional.formatOptions = [
        .withInternetDateTime,
        .withFractionalSeconds
    ]
    if let date = formatterWithFractional.date(from: dateString) {
        return date
    }

    // ISO8601 without fractional seconds
    let formatterBasic = ISO8601DateFormatter()
    formatterBasic.formatOptions = [.withInternetDateTime]
    if let date = formatterBasic.date(from: dateString) {
        return date
    }

    throw DecodingError.dataCorrupted(
        .init(
            codingPath: codingPath,
            debugDescription: "Invalid date string: \(dateString)"
        )
    )
}
