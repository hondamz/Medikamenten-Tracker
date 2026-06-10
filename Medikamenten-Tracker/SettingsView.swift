import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Medication.name) private var medications: [Medication]
    @State private var showReport = false
    @State private var showExportSheet = false
    @State private var showImportPicker = false
    @State private var showImportAlert = false
    @State private var importResultMessage = ""
    @State private var showDeleteAllConfirmation = false
    @State private var backupDocument: BackupDocument?
    @State private var refreshID = UUID()
    @State private var showPathPicker = false

    @AppStorage("defaultReportPath") private var defaultReportPath: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Info (ganz oben)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Informationen")
                                .font(.headline)
                                .foregroundColor(AppTheme.textPrimary)

                            InfoRow(icon: "pills.fill", label: "Medikamente", value: "\(medications.count)")
                            InfoRow(
                                icon: "clock.fill",
                                label: "Regelmäßig",
                                value: "\(medications.filter { !$0.isOnDemand }.count)"
                            )
                            InfoRow(
                                icon: "hand.tap.fill",
                                label: "Bei Bedarf",
                                value: "\(medications.filter { $0.isOnDemand }.count)"
                            )
                        }
                        .padding()
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                        // Report Button
                        Button {
                            showReport = true
                        } label: {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                    .font(.title2)
                                    .foregroundColor(AppTheme.accentLight)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Medikamenten-Report")
                                        .font(.headline)
                                        .foregroundColor(AppTheme.textPrimary)
                                    Text("Übersicht aller Medikamente und Kalender")
                                        .font(.caption)
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            .padding()
                            .background(AppTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        // Bedarfsmedikamente - manuelle Einnahme
                        let onDemandMeds = medications.filter { $0.isOnDemand }
                        if !onDemandMeds.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Bedarfsmedikamente - Einnahme erfassen")
                                    .font(.headline)
                                    .foregroundColor(AppTheme.textPrimary)

                                ForEach(onDemandMeds) { med in
                                    OnDemandConsumptionRow(medication: med)
                                }
                            }
                            .padding()
                            .background(AppTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        // Default Speicherpfad
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(AppTheme.accent)
                                Text("Default Speicherpfad")
                                    .font(.headline)
                                    .foregroundColor(AppTheme.textPrimary)
                            }

                            Text("Wähle einen Standard-Ordner für Report-Exporte.")
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)

                            Button {
                                showPathPicker = true
                            } label: {
                                HStack {
                                    Image(systemName: "folder.badge.gearshape")
                                        .foregroundColor(AppTheme.accentLight)
                                    if defaultReportPath.isEmpty {
                                        Text("Ordner auswählen…")
                                            .foregroundColor(AppTheme.textSecondary)
                                    } else {
                                        Text(shortenedPath(defaultReportPath))
                                            .foregroundColor(AppTheme.textPrimary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(AppTheme.textSecondary)
                                        .font(.caption)
                                }
                                .padding()
                                .background(AppTheme.background)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }

                            if !defaultReportPath.isEmpty {
                                Button {
                                    defaultReportPath = ""
                                } label: {
                                    HStack {
                                        Image(systemName: "xmark.circle")
                                            .foregroundColor(AppTheme.textSecondary)
                                        Text("Pfad zurücksetzen")
                                            .font(.caption)
                                            .foregroundColor(AppTheme.textSecondary)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                        // Datensicherung
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                Image(systemName: "externaldrive.fill.badge.shield.checkmark")
                                    .foregroundColor(AppTheme.accent)
                                Text("Datensicherung")
                                    .font(.headline)
                                    .foregroundColor(AppTheme.textPrimary)
                            }

                            Text("Sichere deine Medikamenten-Daten als Datei, um sie nach einer Neuinstallation der App wiederherstellen zu können.")
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)

                            // Export Button
                            Button {
                                exportBackup()
                            } label: {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                        .foregroundColor(AppTheme.accentLight)
                                    Text("Backup exportieren")
                                        .foregroundColor(AppTheme.textPrimary)
                                    Spacer()
                                    Text("\(medications.count) Medikamente")
                                        .font(.caption)
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                                .padding()
                                .background(AppTheme.background)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .disabled(medications.isEmpty)
                            .opacity(medications.isEmpty ? 0.5 : 1)

                            // Import Button
                            Button {
                                showImportPicker = true
                            } label: {
                                HStack {
                                    Image(systemName: "square.and.arrow.down")
                                        .foregroundColor(AppTheme.accentLight)
                                    Text("Backup importieren")
                                        .foregroundColor(AppTheme.textPrimary)
                                    Spacer()
                                }
                                .padding()
                                .background(AppTheme.background)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                        .padding()
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                        // Alle Daten löschen
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                Image(systemName: "trash.fill")
                                    .foregroundColor(AppTheme.danger)
                                Text("Daten löschen")
                                    .font(.headline)
                                    .foregroundColor(AppTheme.textPrimary)
                            }

                            Text("Löscht alle gespeicherten Medikamenten-Daten. Erstelle vorher ein Backup, um die Daten später wiederherstellen zu können.")
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)

                            Button {
                                showDeleteAllConfirmation = true
                            } label: {
                                HStack {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(AppTheme.danger)
                                    Text("Alle Medikamente löschen")
                                        .foregroundColor(AppTheme.danger)
                                    Spacer()
                                }
                                .padding()
                                .background(AppTheme.danger.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .disabled(medications.isEmpty)
                            .opacity(medications.isEmpty ? 0.5 : 1)
                        }
                        .padding()
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                        // Lokale Speicherung Info
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                Image(systemName: "internaldrive.fill")
                                    .foregroundColor(AppTheme.accent)
                                Text("Lokale Speicherung")
                                    .font(.headline)
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                            Text("Deine Medikamente werden lokal auf diesem Gerät gespeichert. Erstelle regelmäßig ein Backup, um Datenverlust zu vermeiden.")
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .padding()
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding()
                }
            }
            .id(refreshID)
            .onAppear {
                refreshID = UUID()
            }
            .navigationTitle("Einstellungen")
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showReport) {
                ReportView()
            }
            .fileExporter(
                isPresented: $showExportSheet,
                document: backupDocument,
                contentType: .json,
                defaultFilename: "MedikamentenTracker-Backup"
            ) { result in
                switch result {
                case .success:
                    importResultMessage = "Backup wurde erfolgreich gespeichert."
                    showImportAlert = true
                case .failure(let error):
                    importResultMessage = "Fehler beim Speichern: \(error.localizedDescription)"
                    showImportAlert = true
                }
            }
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [.json]
            ) { result in
                importBackup(result: result)
            }
            .fileImporter(
                isPresented: $showPathPicker,
                allowedContentTypes: [.folder]
            ) { result in
                if case .success(let url) = result {
                    defaultReportPath = url.path
                }
            }
            .alert("Alle Medikamente löschen?", isPresented: $showDeleteAllConfirmation) {
                Button("Abbrechen", role: .cancel) { }
                Button("Zuerst Backup erstellen") {
                    exportBackup()
                }
                Button("Endgültig löschen", role: .destructive) {
                    deleteAllMedications()
                }
            } message: {
                Text("Alle \(medications.count) Medikamente werden unwiderruflich gelöscht. Möchtest du vorher ein Backup erstellen?")
            }
            .alert("Information", isPresented: $showImportAlert) {
                Button("OK") { }
            } message: {
                Text(importResultMessage)
            }
        }
    }

    private func shortenedPath(_ path: String) -> String {
        let components = path.split(separator: "/")
        if components.count > 3 {
            return "…/" + components.suffix(2).joined(separator: "/")
        }
        return path
    }

    private func exportBackup() {
        if let data = BackupManager.createBackup(from: Array(medications)) {
            backupDocument = BackupDocument(data: data)
            showExportSheet = true
        }
    }

    private func importBackup(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else {
                importResultMessage = "Kein Zugriff auf die ausgewählte Datei."
                showImportAlert = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try Data(contentsOf: url)
                let count = try BackupManager.restoreBackup(from: data, into: modelContext)
                importResultMessage = "\(count) Medikamente wurden erfolgreich importiert."
                showImportAlert = true
            } catch {
                importResultMessage = "Fehler beim Import: \(error.localizedDescription)"
                showImportAlert = true
            }
        case .failure(let error):
            importResultMessage = "Fehler: \(error.localizedDescription)"
            showImportAlert = true
        }
    }

    private func deleteAllMedications() {
        for medication in medications {
            modelContext.delete(medication)
        }
    }
}

struct OnDemandConsumptionRow: View {
    @Bindable var medication: Medication

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(medication.name)
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textPrimary)
                Text("Genommen: \(medication.manualConsumption) von \(medication.packageSize)")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()

            HStack(spacing: 12) {
                Button {
                    if medication.manualConsumption > 0 {
                        medication.manualConsumption -= 1
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(AppTheme.textSecondary)
                }

                Text("\(medication.manualConsumption)")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
                    .frame(minWidth: 30)

                Button {
                    if medication.manualConsumption < medication.packageSize {
                        medication.manualConsumption += 1
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(AppTheme.accentLight)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(AppTheme.accent)
                .frame(width: 24)
            Text(label)
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppTheme.textPrimary)
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: Medication.self, inMemory: true)
}
