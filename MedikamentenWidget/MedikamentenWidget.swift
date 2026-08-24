 import WidgetKit
import SwiftUI

// MARK: - Theme (in Widget-Extension kopiert, da Haupt-App-Theme nicht ohne weiteres
// in der Extension verfügbar ist)

private enum WidgetTheme {
    static let background = Color(red: 0.06, green: 0.09, blue: 0.16)
    static let cardBackground = Color(red: 0.10, green: 0.14, blue: 0.24)
    static let accentLight = Color(red: 0.45, green: 0.65, blue: 1.0)
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 0.60, green: 0.65, blue: 0.75)
    static let warning = Color.orange
    static let danger = Color.red
    static let success = Color(red: 0.30, green: 0.80, blue: 0.50)
}

// MARK: - Datenladen

private func loadMedications() -> [MedicationSnapshot] {
    SharedStorage.read()?.medications ?? []
}

/// Liefert die Medikamente die innerhalb von `days` Tagen ab `referenceDate` aufgebraucht sind.
/// Optionale Medikamente (`isOnDemand`) werden ignoriert, da sie kein definiertes Aufbrauchdatum haben.
private func upcomingDepletions(from referenceDate: Date, withinDays days: Int) -> [MedicationSnapshot] {
    loadMedications()
        .filter { !$0.isOnDemand }
        .filter { $0.remainingDays(from: referenceDate) <= days }
        .sorted { $0.remainingDays(from: referenceDate) < $1.remainingDays(from: referenceDate) }
}

private func firstDepletion(from referenceDate: Date) -> MedicationSnapshot? {
    loadMedications()
        .filter { !$0.isOnDemand }
        .min { $0.remainingDays(from: referenceDate) < $1.remainingDays(from: referenceDate) }
}

// MARK: - TimelineProvider: Liste der nächsten Engpässe

struct UpcomingDepletionsEntry: TimelineEntry {
    let date: Date
    let items: [MedicationSnapshot]
}

struct UpcomingDepletionsProvider: TimelineProvider {

    func placeholder(in context: Context) -> UpcomingDepletionsEntry {
        UpcomingDepletionsEntry(date: Date(), items: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (UpcomingDepletionsEntry) -> Void) {
        let now = Date()
        completion(UpcomingDepletionsEntry(date: now, items: upcomingDepletions(from: now, withinDays: 28)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UpcomingDepletionsEntry>) -> Void) {
        let now = Date()
        let entry = UpcomingDepletionsEntry(date: now, items: upcomingDepletions(from: now, withinDays: 28))
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

// MARK: - TimelineProvider: Erster Engpass

struct FirstDepletionEntry: TimelineEntry {
    let date: Date
    let medication: MedicationSnapshot?
    let remainingDays: Int?
}

struct FirstDepletionProvider: TimelineProvider {

    func placeholder(in context: Context) -> FirstDepletionEntry {
        FirstDepletionEntry(date: Date(), medication: nil, remainingDays: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (FirstDepletionEntry) -> Void) {
        completion(makeEntry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FirstDepletionEntry>) -> Void) {
        let now = Date()
        let entry = makeEntry(for: now)
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func makeEntry(for date: Date) -> FirstDepletionEntry {
        if let first = firstDepletion(from: date) {
            return FirstDepletionEntry(date: date, medication: first, remainingDays: first.remainingDays(from: date))
        }
        return FirstDepletionEntry(date: date, medication: nil, remainingDays: nil)
    }
}

// MARK: - Helpers

private func depletionColor(forDays days: Int) -> Color {
    if days <= 0 { return WidgetTheme.danger }
    if days <= 7 { return WidgetTheme.warning }
    if days <= 14 { return Color.yellow }
    return WidgetTheme.success
}

private let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "de_DE")
    f.dateFormat = "dd.MM."
    return f
}()

// MARK: - Views: Liste der nächsten Engpässe

struct UpcomingDepletionsView: View {
    let entry: UpcomingDepletionsEntry
    @Environment(\.widgetFamily) private var family

    private var rowLimit: Int {
        switch family {
        case .systemLarge: return 8
        default: return 4
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "pills.fill")
                    .foregroundColor(WidgetTheme.accentLight)
                Text("Nächste 4 Wochen")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(WidgetTheme.textSecondary)
                Spacer()
            }

            if entry.items.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(WidgetTheme.success)
                        Text("Alle Medikamente reichen länger als 4 Wochen")
                            .font(.caption2)
                            .multilineTextAlignment(.center)
                            .foregroundColor(WidgetTheme.textSecondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ForEach(entry.items.prefix(rowLimit)) { med in
                    let days = med.remainingDays(from: entry.date)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(depletionColor(forDays: days))
                            .frame(width: 8, height: 8)
                        Text(med.name)
                            .font(.caption)
                            .foregroundColor(WidgetTheme.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(dateFormatter.string(from: med.depletionDate(from: entry.date)))
                            .font(.caption2)
                            .foregroundColor(depletionColor(forDays: days))
                            .fontWeight(.medium)
                    }
                }
                if entry.items.count > rowLimit {
                    Text("+ \(entry.items.count - rowLimit) weitere")
                        .font(.caption2)
                        .foregroundColor(WidgetTheme.textSecondary)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .containerBackground(for: .widget) {
            WidgetTheme.background
        }
    }
}

// MARK: - View: Erster Engpass

struct FirstDepletionView: View {
    let entry: FirstDepletionEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(WidgetTheme.accentLight)
                Text("Nächster Engpass")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(WidgetTheme.textSecondary)
                Spacer()
            }

            if let med = entry.medication, let days = entry.remainingDays {
                Spacer(minLength: 2)
                Text("\(days)")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(depletionColor(forDays: days))
                Text(days == 1 ? "Tag verbleibend" : "Tage verbleibend")
                    .font(.caption2)
                    .foregroundColor(WidgetTheme.textSecondary)
                Text(med.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(WidgetTheme.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            } else {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(WidgetTheme.success)
                        Text("Keine Medikamente erfasst")
                            .font(.caption2)
                            .multilineTextAlignment(.center)
                            .foregroundColor(WidgetTheme.textSecondary)
                    }
                    Spacer()
                }
                Spacer()
            }
        }
        .padding(12)
        .containerBackground(for: .widget) {
            WidgetTheme.background
        }
    }
}

// MARK: - Widget Definitionen

struct UpcomingDepletionsWidget: Widget {
    let kind: String = "UpcomingDepletionsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UpcomingDepletionsProvider()) { entry in
            UpcomingDepletionsView(entry: entry)
        }
        .configurationDisplayName("Nächste Engpässe")
        .description("Medikamente die in den kommenden 4 Wochen aufgebraucht sind.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct FirstDepletionWidget: Widget {
    let kind: String = "FirstDepletionWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FirstDepletionProvider()) { entry in
            FirstDepletionView(entry: entry)
        }
        .configurationDisplayName("Erster Engpass")
        .description("Tage bis das nächste Medikament aufgebraucht ist.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Widget Bundle (Einstiegspunkt)

@main
struct MedikamentenWidgetBundle: WidgetBundle {
    var body: some Widget {
        FirstDepletionWidget()
        UpcomingDepletionsWidget()
    }
}
