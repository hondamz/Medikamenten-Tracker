import SwiftUI
import SwiftData

struct MedicationListView: View {
    @Query(sort: \Medication.name) private var medications: [Medication]
    @State private var refreshID = UUID()

    private var sortedMedications: [Medication] {
        medications.sorted { $0.remainingDays < $1.remainingDays }
    }

    var body: some View {
        Group {
            if medications.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "tray")
                        .font(.system(size: 50))
                        .foregroundColor(AppTheme.textSecondary)
                    Text("Keine Medikamente vorhanden")
                        .font(.headline)
                        .foregroundColor(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(sortedMedications) { medication in
                            MedicationStatusCard(medication: medication)
                        }
                    }
                    .padding()
                }
            }
        }
        .id(refreshID)
        .onAppear {
            refreshID = UUID()
        }
    }
}

struct MedicationStatusCard: View {
    let medication: Medication

    private var isLow: Bool {
        medication.remainingDays < 7
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
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

            HStack(spacing: 20) {
                // Restliche Tabletten
                HStack(spacing: 6) {
                    Image(systemName: "pills.fill")
                        .foregroundColor(AppTheme.accent)
                    Text("\(Int(medication.remainingTablets)) Tabletten übrig")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                // Datum bis zu dem sie reichen
                if !medication.isOnDemand {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .foregroundColor(isLow ? AppTheme.danger : AppTheme.accent)
                        Text("bis \(dateFormatter.string(from: medication.depletionDate))")
                            .font(.subheadline)
                            .foregroundColor(isLow ? AppTheme.danger : AppTheme.textSecondary)
                            .fontWeight(isLow ? .bold : .regular)
                    }
                }
            }

            // Fortschrittsbalken
            if !medication.isOnDemand {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppTheme.background)
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(progressColor)
                            .frame(width: geo.size.width * progressFraction, height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var progressFraction: CGFloat {
        guard medication.packageSize > 0 else { return 0 }
        return CGFloat(medication.remainingTablets / Double(medication.packageSize))
    }

    private var progressColor: Color {
        if medication.remainingDays < 7 {
            return AppTheme.danger
        } else if medication.remainingDays < 14 {
            return AppTheme.warning
        }
        return AppTheme.success
    }
}

#Preview {
    MedicationListView()
        .background(AppTheme.background)
        .modelContainer(for: Medication.self, inMemory: true)
}
