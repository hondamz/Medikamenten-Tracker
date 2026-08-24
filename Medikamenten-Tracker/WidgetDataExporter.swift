import Foundation
import SwiftData
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Exportiert den aktuellen Stand aller Medikamente in den App-Group-Container
/// und löst eine Widget-Aktualisierung aus.
/// Nur in der Haupt-App vorhanden (verwendet `Medication` aus SwiftData).
enum WidgetDataExporter {

    @MainActor
    static func export(from context: ModelContext) {
        let descriptor = FetchDescriptor<Medication>()
        guard let medications = try? context.fetch(descriptor) else { return }

        let snapshots = medications.map { med in
            MedicationSnapshot(
                id: UUID(),
                name: med.name,
                packageSize: med.packageSize,
                receivedDate: med.receivedDate,
                dailyDosage: med.dailyDosage,
                isOnDemand: med.isOnDemand,
                manualConsumption: med.manualConsumption,
                intakeTimeRawValue: med.intakeTimeRawValue
            )
        }

        let snapshot = WidgetSnapshot(updatedAt: Date(), medications: snapshots)
        SharedStorage.write(snapshot)

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
