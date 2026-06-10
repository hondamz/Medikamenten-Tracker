import SwiftUI
import SwiftData

struct CalendarView: View {
    @Query(sort: \Medication.name) private var medications: [Medication]
    @State private var displayedMonth: Date = Date()
    @State private var refreshID = UUID()

    private var calendar: Calendar { Calendar.current }

    private var monthFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        f.locale = Locale(identifier: "de_DE")
        return f
    }

    private var daysInMonth: [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth) else { return [] }
        let components = calendar.dateComponents([.year, .month], from: displayedMonth)
        return range.compactMap { day in
            var dc = components
            dc.day = day
            return calendar.date(from: dc)
        }
    }

    private var firstWeekday: Int {
        guard let firstDay = daysInMonth.first else { return 0 }
        let weekday = calendar.component(.weekday, from: firstDay)
        // Montag = 1 in der Darstellung
        return (weekday + 5) % 7
    }

    var body: some View {
        VStack(spacing: 16) {
            // Monat Navigation
            HStack {
                Button {
                    displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(AppTheme.accentLight)
                        .font(.title3)
                }

                Spacer()

                Text(monthFormatter.string(from: displayedMonth))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                Button {
                    displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                } label: {
                    Image(systemName: "chevron.right")
                        .foregroundColor(AppTheme.accentLight)
                        .font(.title3)
                }
            }
            .padding(.horizontal)

            // Wochentage Header
            HStack(spacing: 0) {
                ForEach(["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"], id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 8)

            // Kalender Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 8) {
                // Leere Felder vor dem 1.
                ForEach(0..<firstWeekday, id: \.self) { _ in
                    Color.clear.frame(height: 44)
                }

                // Tage
                ForEach(daysInMonth, id: \.self) { date in
                    CalendarDayCell(
                        date: date,
                        depletionStatus: statusForDate(date),
                        isToday: calendar.isDateInToday(date)
                    )
                }
            }
            .padding(.horizontal, 8)

            // Legende
            HStack(spacing: 20) {
                LegendItem(color: AppTheme.calendarDotRed, label: "0 Tage")
                LegendItem(color: AppTheme.calendarDotOrange, label: "≤ 7 Tage")
                LegendItem(color: AppTheme.calendarDotGreen, label: "> 7 Tage")
            }
            .padding(.top, 8)

            // Medikamente die an einem Tag aufgebraucht sind
            if !depletionEventsThisMonth.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Aufgebraucht in diesem Monat:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.textSecondary)
                        .padding(.horizontal)

                    ForEach(depletionEventsThisMonth, id: \.medication.id) { event in
                        HStack {
                            Circle()
                                .fill(AppTheme.danger)
                                .frame(width: 8, height: 8)
                            Text(event.medication.name)
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            Text(dayFormatter.string(from: event.date))
                                .font(.subheadline)
                                .foregroundColor(AppTheme.danger)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)
            }

            Spacer()
        }
        .id(refreshID)
        .onAppear {
            refreshID = UUID()
        }
    }

    private var dayFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "dd. MMMM"
        f.locale = Locale(identifier: "de_DE")
        return f
    }

    struct DepletionEvent {
        let medication: Medication
        let date: Date
    }

    private var depletionEventsThisMonth: [DepletionEvent] {
        let monthComponents = calendar.dateComponents([.year, .month], from: displayedMonth)
        return medications
            .filter { !$0.isOnDemand }
            .compactMap { med in
                let depComp = calendar.dateComponents([.year, .month], from: med.depletionDate)
                if depComp.year == monthComponents.year && depComp.month == monthComponents.month {
                    return DepletionEvent(medication: med, date: med.depletionDate)
                }
                return nil
            }
            .sorted { $0.date < $1.date }
    }

    /// Status für einen bestimmten Tag: wie viele Tage noch Medikamente reichen
    private func statusForDate(_ date: Date) -> DayStatus {
        let regularMeds = medications.filter { !$0.isOnDemand }
        guard !regularMeds.isEmpty else { return .none }

        // Prüfe ob an diesem Tag ein Medikament aufgebraucht wird
        let hasDepleted = regularMeds.contains { med in
            calendar.isDate(med.depletionDate, inSameDayAs: date)
        }

        if hasDepleted {
            return .depleted
        }

        // Prüfe den minimalen Restbestand aller Medikamente für diesen Tag
        let today = calendar.startOfDay(for: Date())
        let targetDay = calendar.startOfDay(for: date)
        let daysFromNow = calendar.dateComponents([.day], from: today, to: targetDay).day ?? 0

        guard daysFromNow >= 0 else { return .none }

        let minRemaining = regularMeds.map { $0.remainingDays - daysFromNow }.min() ?? Int.max

        if minRemaining <= 0 {
            return .critical
        } else if minRemaining <= 7 {
            return .warning
        } else {
            return .good
        }
    }
}

enum DayStatus {
    case none, good, warning, critical, depleted
}

struct CalendarDayCell: View {
    let date: Date
    let depletionStatus: DayStatus
    let isToday: Bool

    var body: some View {
        VStack(spacing: 3) {
            // Status-Punkt
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
                .opacity(depletionStatus == .none ? 0 : 1)

            Text("\(Calendar.current.component(.day, from: date))")
                .font(.system(size: 14, weight: isToday ? .bold : .regular))
                .foregroundColor(isToday ? AppTheme.accentLight : AppTheme.textPrimary)
        }
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isToday ? AppTheme.accent.opacity(0.2) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(depletionStatus == .depleted ? AppTheme.danger : Color.clear, lineWidth: 1.5)
        )
    }

    private var dotColor: Color {
        switch depletionStatus {
        case .none: return .clear
        case .good: return AppTheme.calendarDotGreen
        case .warning: return AppTheme.calendarDotOrange
        case .critical, .depleted: return AppTheme.calendarDotRed
        }
    }
}

struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption2)
                .foregroundColor(AppTheme.textSecondary)
        }
    }
}

#Preview {
    CalendarView()
        .background(AppTheme.background)
        .modelContainer(for: Medication.self, inMemory: true)
}
