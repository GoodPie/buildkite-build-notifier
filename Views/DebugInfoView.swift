//
//  DebugInfoView.swift
//  BuildkiteNotifier
//

import SwiftUI

struct DebugInfoView: View {
    @ObservedObject var buildMonitor: BuildMonitor
    @ObservedObject var diagnosticLog: DiagnosticLog
    @Environment(\.dismiss) var dismiss

    init(buildMonitor: BuildMonitor) {
        self.buildMonitor = buildMonitor
        self.diagnosticLog = buildMonitor.diagnosticLog
    }

    @State private var copied = false
    @State private var reportText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Debug Info")
                    .font(.headline)
                Spacer()
                Button("Clear Log") {
                    diagnosticLog.clear()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(16)

            Divider()

            // Recent errors quick-glance
            if !diagnosticLog.recentEntries.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("RECENT EVENTS")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .padding(.bottom, 2)

                    ForEach(diagnosticLog.recentEntries) { entry in
                        HStack(alignment: .top, spacing: 6) {
                            Text(formatTime(entry.timestamp))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospacedDigit()

                            Text(entry.code.rawValue)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(colorForLevel(entry.level))

                            Text(entry.message)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider()
            }

            // Full diagnostic report
            ScrollView {
                Text(reportText)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }

            Divider()

            // Footer buttons
            HStack {
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(copied ? "Copied!" : "Copy to Clipboard") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(reportText, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copied = false
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
        }
        .frame(width: 500, height: 480)
        .onAppear { regenerateReport() }
        .onChange(of: diagnosticLog.recentEntries.count) { regenerateReport() }
        .onChange(of: buildMonitor.lastUpdateTime) { regenerateReport() }
    }

    private func regenerateReport() {
        reportText = DiagnosticReport.generate(buildMonitor: buildMonitor, diagnosticLog: diagnosticLog)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private func formatTime(_ date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }

    private func colorForLevel(_ level: DiagnosticLevel) -> Color {
        switch level {
        case .error: return .red
        case .warning: return .orange
        case .info: return .secondary
        }
    }
}
