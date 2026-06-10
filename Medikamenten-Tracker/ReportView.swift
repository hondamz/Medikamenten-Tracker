import SwiftUI
import SwiftData
import UniformTypeIdentifiers

enum ReportFormat: String, CaseIterable, Identifiable {
    case text = "Textdatei (.txt)"
    case pdf = "PDF (.pdf)"
    case csv = "CSV (.csv)"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .text: return "doc.text"
        case .pdf:  return "doc.richtext"
        case .csv:  return "tablecells"
        }
    }
}

struct ReportView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Medication.name) private var medications: [Medication]
    @State private var showCalendar = false
    @State private var refreshID = UUID()

    // Export
    @State private var showFormatPicker = false
    @State private var selectedFormat: ReportFormat = .pdf
    @State private var showTextExport = false
    @State private var showCSVExport = false
    @State private var showPDFExport = false
    @State private var textDocument: TextReportDocument?
    @State private var csvDocument: CSVReportDocument?
    @State private var pdfDocument: PDFReportDocument?
    @State private var showExportAlert = false
    @State private var exportMessage = ""

    @AppStorage("defaultReportPath") private var defaultReportPath: String = ""

    private var sortedMedications: [Medication] {
        medications.sorted { $0.remainingDays < $1.remainingDays }
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.locale = Locale(identifier: "de_DE")
        return f
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    Picker("Ansicht", selection: $showCalendar) {
                        Text("Tabelle").tag(false)
                        Text("Kalender").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    if showCalendar {
                        CalendarView()
                    } else {
                        ScrollView {
                            VStack(spacing: 12) {
                                // Report Header
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Medikamenten-Report")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(AppTheme.textPrimary)
                                        Text("Stand: \(dateFormatter.string(from: Date()))")
                                            .font(.subheadline)
                                            .foregroundColor(AppTheme.textSecondary)
                                    }
                                    Spacer()

                                    // Export Button
                                    Button {
                                        showFormatPicker = true
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "square.and.arrow.up")
                                            Text("Export")
                                        }
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(AppTheme.accent)
                                        .foregroundColor(.white)
                                        .clipShape(Capsule())
                                    }
                                    .disabled(medications.isEmpty)
                                }
                                .padding()
                                .background(AppTheme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 14))

                                // Medikamente Report
                                ForEach(sortedMedications) { med in
                                    ReportMedicationRow(medication: med)
                                }

                                if medications.isEmpty {
                                    Text("Keine Medikamente erfasst")
                                        .font(.headline)
                                        .foregroundColor(AppTheme.textSecondary)
                                        .padding(.top, 40)
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .id(refreshID)
            .onAppear {
                refreshID = UUID()
            }
            .navigationTitle("Report")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                        .foregroundColor(AppTheme.accentLight)
                }
            }
            .confirmationDialog("Report exportieren als", isPresented: $showFormatPicker, titleVisibility: .visible) {
                Button("Textdatei (.txt)") { exportAs(.text) }
                Button("PDF (.pdf)") { exportAs(.pdf) }
                Button("CSV (.csv)") { exportAs(.csv) }
                Button("Abbrechen", role: .cancel) { }
            }
            .fileExporter(
                isPresented: $showTextExport,
                document: textDocument,
                contentType: .plainText,
                defaultFilename: "Medikamenten-Report"
            ) { handleExportResult($0) }
            .fileExporter(
                isPresented: $showCSVExport,
                document: csvDocument,
                contentType: .commaSeparatedText,
                defaultFilename: "Medikamenten-Report"
            ) { handleExportResult($0) }
            .fileExporter(
                isPresented: $showPDFExport,
                document: pdfDocument,
                contentType: .pdf,
                defaultFilename: "Medikamenten-Report"
            ) { handleExportResult($0) }
            .alert("Export", isPresented: $showExportAlert) {
                Button("OK") { }
            } message: {
                Text(exportMessage)
            }
        }
    }

    private func exportAs(_ format: ReportFormat) {
        let meds = Array(medications)
        switch format {
        case .text:
            textDocument = TextReportDocument(text: ReportExporter.generateTextReport(from: meds))
            showTextExport = true
        case .csv:
            csvDocument = CSVReportDocument(text: ReportExporter.generateCSVReport(from: meds))
            showCSVExport = true
        case .pdf:
            pdfDocument = PDFReportDocument(data: ReportExporter.generatePDFReport(from: meds))
            showPDFExport = true
        }
    }

    private func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            // Speichere den Pfad als Default
            defaultReportPath = url.deletingLastPathComponent().path
            exportMessage = "Report wurde erfolgreich gespeichert."
            showExportAlert = true
        case .failure(let error):
            exportMessage = "Fehler beim Export: \(error.localizedDescription)"
            showExportAlert = true
        }
    }
}

struct ReportMedicationRow: View {
    let medication: Medication

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.locale = Locale(identifier: "de_DE")
        return f
    }

    private var isLow: Bool {
        medication.remainingDays < 7
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(medication.name)
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                if medication.isOnDemand {
                    Text("Bei Bedarf")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppTheme.warning.opacity(0.2))
                        .foregroundColor(AppTheme.warning)
                        .clipShape(Capsule())
                }
            }

            // Einnahmezeiten
            if medication.intakeTimeRawValue > 0 {
                IntakeTimeBadges(intakeTimes: medication.intakeTimes)
            }

            Divider()
                .background(AppTheme.textSecondary.opacity(0.3))

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Verfügbar heute")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                    Text("\(Int(medication.remainingTablets)) Tabletten")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.textPrimary)
                }

                Spacer()

                if !medication.isOnDemand {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Reicht bis")
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                        Text(dateFormatter.string(from: medication.depletionDate))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(isLow ? AppTheme.danger : AppTheme.success)
                    }
                }
            }

            if !medication.isOnDemand {
                HStack {
                    Text("Noch \(medication.remainingDays) Tage")
                        .font(.caption)
                        .foregroundColor(isLow ? AppTheme.danger : AppTheme.textSecondary)
                    Spacer()
                    Text(medication.dosageDescription)
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    ReportView()
        .modelContainer(for: Medication.self, inMemory: true)
}
