import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Codable Backup-Struktur

struct MedicationBackup: Codable {
    let name: String
    let packageSize: Int
    let receivedDate: Date
    let dailyDosage: Double
    let isOnDemand: Bool
    let manualConsumption: Int
    let intakeTimeRawValue: Int
}

struct AppBackup: Codable {
    let version: Int
    let exportDate: Date
    let medications: [MedicationBackup]
}

// MARK: - Backup Manager

enum BackupManager {

    /// Erstellt ein JSON-Backup aller Medikamente
    static func createBackup(from medications: [Medication]) -> Data? {
        let backupMeds = medications.map { med in
            MedicationBackup(
                name: med.name,
                packageSize: med.packageSize,
                receivedDate: med.receivedDate,
                dailyDosage: med.dailyDosage,
                isOnDemand: med.isOnDemand,
                manualConsumption: med.manualConsumption,
                intakeTimeRawValue: med.intakeTimeRawValue
            )
        }

        let backup = AppBackup(
            version: 2,
            exportDate: Date(),
            medications: backupMeds
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        return try? encoder.encode(backup)
    }

    /// Stellt Medikamente aus einem JSON-Backup wieder her
    static func restoreBackup(from data: Data, into context: ModelContext) throws -> Int {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let backup = try decoder.decode(AppBackup.self, from: data)

        var importedCount = 0
        for backupMed in backup.medications {
            let medication = Medication(
                name: backupMed.name,
                packageSize: backupMed.packageSize,
                receivedDate: backupMed.receivedDate,
                dailyDosage: backupMed.dailyDosage,
                isOnDemand: backupMed.isOnDemand,
                manualConsumption: backupMed.manualConsumption,
                intakeTimes: IntakeTime(rawValue: backupMed.intakeTimeRawValue)
            )
            context.insert(medication)
            importedCount += 1
        }

        return importedCount
    }
}

// MARK: - Document für Export

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
