import Foundation
import SwiftData

/// Einnahmezeiten als Bitmask gespeichert
struct IntakeTime: OptionSet, Codable, Hashable {
    let rawValue: Int

    static let morgens  = IntakeTime(rawValue: 1 << 0)
    static let mittags  = IntakeTime(rawValue: 1 << 1)
    static let abends   = IntakeTime(rawValue: 1 << 2)
    static let nachts   = IntakeTime(rawValue: 1 << 3)

    static let all: [IntakeTime] = [.morgens, .mittags, .abends, .nachts]

    var label: String {
        switch self {
        case .morgens:  return "Morgens"
        case .mittags:  return "Mittags"
        case .abends:   return "Abends"
        case .nachts:   return "Nachts"
        default:        return ""
        }
    }

    var icon: String {
        switch self {
        case .morgens:  return "sunrise.fill"
        case .mittags:  return "sun.max.fill"
        case .abends:   return "sunset.fill"
        case .nachts:   return "moon.fill"
        default:        return "clock"
        }
    }

    /// Anzahl der ausgewählten Einnahmezeiten
    var count: Int {
        IntakeTime.all.filter { self.contains($0) }.count
    }

    /// Alle ausgewählten Zeiten als lesbarer Text
    var displayText: String {
        let selected = IntakeTime.all.filter { self.contains($0) }
        if selected.isEmpty { return "Keine Angabe" }
        return selected.map { $0.label }.joined(separator: ", ")
    }
}

@Model
final class Medication {
    var name: String
    var packageSize: Int
    var receivedDate: Date
    /// Menge pro Einnahme (wenn Einnahmezeiten gesetzt) oder pro Tag (wenn keine Einnahmezeiten)
    var dailyDosage: Double
    var isOnDemand: Bool
    var manualConsumption: Int
    var intakeTimeRawValue: Int

    /// Einnahmezeiten als OptionSet
    var intakeTimes: IntakeTime {
        get { IntakeTime(rawValue: intakeTimeRawValue) }
        set { intakeTimeRawValue = newValue.rawValue }
    }

    init(
        name: String,
        packageSize: Int,
        receivedDate: Date,
        dailyDosage: Double = 1.0,
        isOnDemand: Bool = false,
        manualConsumption: Int = 0,
        intakeTimes: IntakeTime = []
    ) {
        self.name = name
        self.packageSize = packageSize
        self.receivedDate = receivedDate
        self.dailyDosage = dailyDosage
        self.isOnDemand = isOnDemand
        self.manualConsumption = manualConsumption
        self.intakeTimeRawValue = intakeTimes.rawValue
    }

    /// Anzahl der Einnahmen pro Tag
    var intakesPerDay: Int {
        let count = intakeTimes.count
        return count > 0 ? count : 1
    }

    /// Tatsächlicher Tagesverbrauch (Menge pro Einnahme × Einnahmen pro Tag)
    var dailyConsumption: Double {
        dailyDosage * Double(intakesPerDay)
    }

    /// Beschreibung der Dosierung
    var dosageDescription: String {
        if intakeTimes.count > 0 {
            return "\(formatDosage(dailyDosage))/Einnahme × \(intakesPerDay) = \(formatDosage(dailyConsumption))/Tag"
        }
        return "\(formatDosage(dailyDosage))/Tag"
    }

    /// Kurzbeschreibung der Dosierung
    var dosageShortDescription: String {
        if intakeTimes.count > 0 {
            return "\(formatDosage(dailyDosage))×\(intakesPerDay)/Tag"
        }
        return "\(formatDosage(dailyDosage))/Tag"
    }

    private func formatDosage(_ value: Double) -> String {
        if value == Double(Int(value)) {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }

    /// Anzahl der Tage seit Erhalt der Verpackung
    var daysSinceReceived: Int {
        Calendar.current.dateComponents([.day], from: receivedDate, to: Date()).day ?? 0
    }

    /// Verbrauchte Tabletten (Tagesverbrauch × Tage + manuell)
    var consumedTablets: Double {
        if isOnDemand {
            return Double(manualConsumption)
        }
        return Double(daysSinceReceived) * dailyConsumption + Double(manualConsumption)
    }

    /// Noch vorhandene Tabletten
    var remainingTablets: Double {
        max(0, Double(packageSize) - consumedTablets)
    }

    /// Anzahl verbleibender Tage
    var remainingDays: Int {
        if isOnDemand {
            return Int(remainingTablets)
        }
        guard dailyConsumption > 0 else { return Int.max }
        return Int(remainingTablets / dailyConsumption)
    }

    /// Datum bis zu dem die Tabletten reichen
    var depletionDate: Date {
        Calendar.current.date(byAdding: .day, value: remainingDays, to: Date()) ?? Date()
    }
}
