import Foundation

/// Gemeinsam zwischen Haupt-App und Widget-Extension genutzt.
/// Muss in beiden Targets eingebunden sein ("Target Membership" in Xcode).
enum AppGroup {
    static let identifier = "group.al.Medikamenten-Tracker"
    static let snapshotFileName = "widget_snapshot.json"

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    static var snapshotURL: URL? {
        containerURL?.appendingPathComponent(snapshotFileName)
    }
}

/// Reine Codable-Repräsentation eines Medikaments für die Weitergabe an das Widget.
/// Enthält dieselbe Berechnungslogik wie `Medication`, damit das Widget jederzeit
/// mit dem aktuellen Datum die Restmenge / Reichweite berechnen kann ohne dass die
/// Haupt-App den Snapshot ständig aktualisieren muss.
struct MedicationSnapshot: Codable, Identifiable, Hashable {
    var id: UUID
    let name: String
    let packageSize: Int
    let receivedDate: Date
    let dailyDosage: Double
    let isOnDemand: Bool
    let manualConsumption: Int
    let intakeTimeRawValue: Int

    var intakesPerDay: Int {
        let count = (0..<4).reduce(0) { $0 + ((intakeTimeRawValue >> $1) & 1) }
        return count > 0 ? count : 1
    }

    var dailyConsumption: Double {
        dailyDosage * Double(intakesPerDay)
    }

    func daysSinceReceived(at referenceDate: Date) -> Int {
        Calendar.current.dateComponents([.day], from: receivedDate, to: referenceDate).day ?? 0
    }

    func consumedTablets(at referenceDate: Date) -> Double {
        if isOnDemand { return Double(manualConsumption) }
        return Double(daysSinceReceived(at: referenceDate)) * dailyConsumption + Double(manualConsumption)
    }

    func remainingTablets(at referenceDate: Date) -> Double {
        max(0, Double(packageSize) - consumedTablets(at: referenceDate))
    }

    func remainingDays(from referenceDate: Date) -> Int {
        if isOnDemand { return Int(remainingTablets(at: referenceDate)) }
        guard dailyConsumption > 0 else { return Int.max }
        return Int(remainingTablets(at: referenceDate) / dailyConsumption)
    }

    func depletionDate(from referenceDate: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: remainingDays(from: referenceDate), to: referenceDate) ?? referenceDate
    }
}

struct WidgetSnapshot: Codable {
    let updatedAt: Date
    let medications: [MedicationSnapshot]
}

/// Liest und schreibt den Snapshot in den geteilten App-Group-Container.
enum SharedStorage {

    static func write(_ snapshot: WidgetSnapshot) {
        guard let url = AppGroup.snapshotURL else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(snapshot)
            try data.write(to: url, options: .atomic)
        } catch {
            // Fehler beim Schreiben ignorieren – das Widget zeigt dann den letzten Stand
        }
    }

    static func read() -> WidgetSnapshot? {
        guard let url = AppGroup.snapshotURL,
              let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }
}
