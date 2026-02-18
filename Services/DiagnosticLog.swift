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

enum DiagnosticCode: String, Codable {
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

    // Info-level events
    case monitoringStarted = "BN-MON"
    case monitoringStopped = "BN-STP"

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

// MARK: - Diagnostic Level

enum DiagnosticLevel: String, Codable, Comparable {
    case info
    case warning
    case error

    private var sortOrder: Int {
        switch self {
        case .info: return 0
        case .warning: return 1
        case .error: return 2
        }
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

// MARK: - Diagnostic Entry

struct DiagnosticEntry: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let code: DiagnosticCode
    let message: String
    let detail: String?
    let level: DiagnosticLevel

    init(id: UUID = UUID(), timestamp: Date = Date(), code: DiagnosticCode, message: String, detail: String? = nil, level: DiagnosticLevel = .error) {
        self.id = id
        self.timestamp = timestamp
        self.code = code
        self.message = message
        self.detail = detail
        self.level = level
    }
}

// MARK: - Diagnostic Log

@MainActor
class DiagnosticLog: ObservableObject {
    @Published private(set) var entries: [DiagnosticEntry] = []

    private let maxEntries = 50

    private static var logFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("com.goodpie.BuildkiteNotifier")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("diagnostic_log.json")
    }

    init() {
        loadFromDisk()
    }

    var recentEntries: [DiagnosticEntry] {
        Array(entries.suffix(10).reversed())
    }

    var recentErrors: [DiagnosticEntry] {
        Array(entries.filter { $0.level == .error }.suffix(10).reversed())
    }

    var errorCount: Int {
        entries.filter { $0.level == .error }.count
    }

    func log(code: DiagnosticCode, message: String, detail: String? = nil, level: DiagnosticLevel = .error) {
        let entry = DiagnosticEntry(
            code: code,
            message: message,
            detail: detail,
            level: level
        )
        entries.append(entry)

        // Ring buffer: trim from front if over limit
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }

        saveToDisk()
    }

    func clear() {
        entries.removeAll()
        saveToDisk()
    }

    // MARK: - Persistence

    private func loadFromDisk() {
        do {
            let data = try Data(contentsOf: Self.logFileURL)
            entries = try JSONDecoder().decode([DiagnosticEntry].self, from: data)
        } catch {
            // Silently ignore — fresh start or corrupted file
        }
    }

    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: Self.logFileURL, options: .atomic)
        } catch {
            // Graceful degradation — log still works in-memory
            Logger.app.warning("Failed to persist diagnostic log: \(error.localizedDescription)")
        }
    }
}
