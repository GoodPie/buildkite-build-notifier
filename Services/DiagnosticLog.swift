//
//  DiagnosticLog.swift
//  BuildkiteNotifier
//

import Foundation
import Combine
import os

// MARK: - Logger

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.goodpie.BuildkiteNotifier"

    static let api = Logger(subsystem: subsystem, category: "api")
    static let monitor = Logger(subsystem: subsystem, category: "monitor")
    static let notifications = Logger(subsystem: subsystem, category: "notifications")
    static let app = Logger(subsystem: subsystem, category: "app")
}

// MARK: - Diagnostic Codes

enum DiagnosticCode: String {
    // API errors (BK- prefix)
    case apiUnauthorized = "BK-401"
    case apiNotFound = "BK-404"
    case apiNetwork = "BK-NET"
    case apiInvalidResponse = "BK-RSP"
    case apiDecoding = "BK-DEC"
    case apiRateLimited = "BK-429"
    case apiBuildNotFound = "BK-404B"

    // App-internal errors (BN- prefix)
    case notificationFailed = "BN-NTF"
    case notificationDenied = "BN-NTD"
    case invalidURL = "BN-URL"
    case duplicateBuild = "BN-DUP"
    case unknown = "BN-UNK"

    static func from(_ apiError: APIError) -> DiagnosticCode {
        switch apiError {
        case .unauthorized: return .apiUnauthorized
        case .organizationNotFound: return .apiNotFound
        case .buildNotFound: return .apiBuildNotFound
        case .networkError: return .apiNetwork
        case .invalidResponse: return .apiInvalidResponse
        case .decodingError: return .apiDecoding
        case .rateLimited: return .apiRateLimited
        }
    }
}

// MARK: - Diagnostic Entry

struct DiagnosticEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let code: DiagnosticCode
    let message: String
    let detail: String?
}

// MARK: - Diagnostic Log

@MainActor
class DiagnosticLog: ObservableObject {
    @Published private(set) var entries: [DiagnosticEntry] = []

    private let maxEntries = 50

    var recentEntries: [DiagnosticEntry] {
        Array(entries.suffix(10).reversed())
    }

    var errorCount: Int {
        entries.count
    }

    func log(code: DiagnosticCode, message: String, detail: String? = nil) {
        let entry = DiagnosticEntry(
            timestamp: Date(),
            code: code,
            message: message,
            detail: detail
        )
        entries.append(entry)

        // Ring buffer: trim from front if over limit
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    func clear() {
        entries.removeAll()
    }
}
