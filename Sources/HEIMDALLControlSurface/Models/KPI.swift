// Sources/HEIMDALLControlSurface/Models/KPI.swift
// AASF-647: HEIMDALL API Client Models

import Foundation

/// KPI trend direction
public enum KPITrend: String, Codable, Sendable {
    case up, down, flat
}

/// KPI display format
public enum KPIFormat: String, Codable, Sendable {
    case number, percentage, duration, rate
}

/// Individual KPI metric
public struct KPIMetric: Codable, Sendable, Identifiable {
    public let id: String
    public let label: String
    public let value: Double
    public let formattedValue: String
    public let unit: String
    public let trend: KPITrend
    public let sparkline: [Double]
    public let format: KPIFormat
    public let thresholdWarning: Double?
    public let thresholdCritical: Double?
    public let isHero: Bool?

    enum CodingKeys: String, CodingKey {
        case id, label, value
        case formattedValue = "formatted_value"
        case unit, trend, sparkline, format
        case thresholdWarning = "threshold_warning"
        case thresholdCritical = "threshold_critical"
        case isHero = "is_hero"
    }

    public init(
        id: String,
        label: String,
        value: Double,
        formattedValue: String,
        unit: String,
        trend: KPITrend,
        sparkline: [Double],
        format: KPIFormat,
        thresholdWarning: Double? = nil,
        thresholdCritical: Double? = nil,
        isHero: Bool? = nil
    ) {
        self.id = id
        self.label = label
        self.value = value
        self.formattedValue = formattedValue
        self.unit = unit
        self.trend = trend
        self.sparkline = sparkline
        self.format = format
        self.thresholdWarning = thresholdWarning
        self.thresholdCritical = thresholdCritical
        self.isHero = isHero
    }
}

/// Full KPI response from /api/v1/telemetry
public struct KPIResponse: Codable, Sendable {
    public let kpis: [KPIMetric]
    public let timestamp: Double
    public let uptimeSeconds: Int

    enum CodingKeys: String, CodingKey {
        case kpis, timestamp
        case uptimeSeconds = "uptime_seconds"
    }

    public init(kpis: [KPIMetric], timestamp: Double, uptimeSeconds: Int) {
        self.kpis = kpis
        self.timestamp = timestamp
        self.uptimeSeconds = uptimeSeconds
    }
}
