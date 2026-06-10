import SwiftUI
import SwiftData

struct AddMedicationView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Medication.name) private var medications: [Medication]

    @State private var showingAddSheet = false
    @State private var editingMedication: Medication?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                if medications.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "pills")
                            .font(.system(size: 60))
                            .foregroundColor(AppTheme.textSecondary)
                        Text("Noch keine Medikamente erfasst")
                            .font(.headline)
                            .foregroundColor(AppTheme.textSecondary)
                        Text("Tippe auf '+' um ein Medikament hinzuzufügen")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textSecondary.opacity(0.7))
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(medications) { medication in
                                MedicationEditCard(medication: medication) {
                                    editingMedication = medication
                                } onDelete: {
                                    modelContext.delete(medication)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Medikamente erfassen")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(AppTheme.accentLight)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                MedicationFormSheet(medication: nil) { name, packageSize, receivedDate, dailyDosage, isOnDemand, intakeTimes in
                    let med = Medication(
                        name: name,
                        packageSize: packageSize,
                        receivedDate: receivedDate,
                        dailyDosage: dailyDosage,
                        isOnDemand: isOnDemand,
                        intakeTimes: intakeTimes
                    )
                    modelContext.insert(med)
                }
            }
            .sheet(item: $editingMedication) { medication in
                MedicationFormSheet(medication: medication) { name, packageSize, receivedDate, dailyDosage, isOnDemand, intakeTimes in
                    medication.name = name
                    medication.packageSize = packageSize
                    medication.receivedDate = receivedDate
                    medication.dailyDosage = dailyDosage
                    medication.isOnDemand = isOnDemand
                    medication.intakeTimes = intakeTimes
                }
            }
        }
    }
}

struct MedicationEditCard: View {
    let medication: Medication
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirmation = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(medication.name)
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)

                HStack(spacing: 16) {
                    Label("\(medication.packageSize) Stk.", systemImage: "pills")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)

                    Label(
                        medication.isOnDemand ? "Bei Bedarf" : medication.dosageShortDescription,
                        systemImage: medication.isOnDemand ? "hand.tap" : "clock"
                    )
                    .font(.caption)
                    .foregroundColor(medication.isOnDemand ? AppTheme.warning : AppTheme.textSecondary)
                }

                // Einnahmezeiten anzeigen
                if medication.intakeTimeRawValue > 0 {
                    IntakeTimeBadges(intakeTimes: medication.intakeTimes)
                }
            }

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "pencil.circle.fill")
                    .font(.title2)
                    .foregroundColor(AppTheme.accent)
            }

            Button {
                showDeleteConfirmation = true
            } label: {
                Image(systemName: "trash.circle.fill")
                    .font(.title2)
                    .foregroundColor(AppTheme.danger.opacity(0.7))
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .alert("Medikament löschen?", isPresented: $showDeleteConfirmation) {
            Button("Abbrechen", role: .cancel) { }
            Button("Löschen", role: .destructive, action: onDelete)
        } message: {
            Text("Möchtest du \"\(medication.name)\" wirklich löschen?")
        }
    }
}

/// Anzeige der Einnahmezeiten als kleine Badges
struct IntakeTimeBadges: View {
    let intakeTimes: IntakeTime

    var body: some View {
        HStack(spacing: 6) {
            ForEach(IntakeTime.all, id: \.rawValue) { time in
                if intakeTimes.contains(time) {
                    HStack(spacing: 3) {
                        Image(systemName: time.icon)
                            .font(.system(size: 9))
                        Text(time.label)
                            .font(.system(size: 9))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppTheme.accent.opacity(0.2))
                    .foregroundColor(AppTheme.accentLight)
                    .clipShape(Capsule())
                }
            }
        }
    }
}

struct MedicationFormSheet: View {
    @Environment(\.dismiss) private var dismiss

    let medication: Medication?
    let onSave: (String, Int, Date, Double, Bool, IntakeTime) -> Void

    @State private var name: String = ""
    @State private var packageSize: String = ""
    @State private var receivedDate: Date = Date()
    @State private var dailyDosage: String = "1"
    @State private var isOnDemand: Bool = false
    @State private var selectedIntakeTimes: IntakeTime = []

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
        && (Int(packageSize) ?? 0) > 0
        && (Double(dailyDosage.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0
    }

    /// Vorschau des Tagesverbrauchs basierend auf Einnahmezeiten
    private var dosagePreviewText: String {
        let perIntake = Double(dailyDosage.replacingOccurrences(of: ",", with: ".")) ?? 0
        let total = perIntake * Double(selectedIntakeTimes.count)
        if total == Double(Int(total)) {
            return "\(Int(total))/Tag"
        }
        return String(format: "%.1f/Tag", total)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Name
                        FormField(label: "Medikamenten-Name") {
                            TextField("z.B. Ibuprofen", text: $name)
                                .padding()
                                .background(AppTheme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .foregroundColor(AppTheme.textPrimary)
                        }

                        // Packungsgröße
                        FormField(label: "Tabletten in der Verpackung") {
                            TextField("z.B. 30", text: $packageSize)
                                #if canImport(UIKit)
                                .keyboardType(.numberPad)
                                #endif
                                .padding()
                                .background(AppTheme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .foregroundColor(AppTheme.textPrimary)
                        }

                        // Erhaltungsdatum
                        FormField(label: "Verpackung erhalten am") {
                            DatePicker("", selection: $receivedDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .padding()
                                .background(AppTheme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .tint(AppTheme.accentLight)
                        }

                        // Einnahmezeiten (Mehrfachauswahl)
                        FormField(label: "Einnahmezeit") {
                            VStack(spacing: 8) {
                                ForEach(IntakeTime.all, id: \.rawValue) { time in
                                    IntakeTimeToggleRow(
                                        time: time,
                                        isSelected: selectedIntakeTimes.contains(time)
                                    ) {
                                        if selectedIntakeTimes.contains(time) {
                                            selectedIntakeTimes.remove(time)
                                        } else {
                                            selectedIntakeTimes.insert(time)
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(AppTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        // Bei Bedarf Schalter
                        FormField(label: "Einnahme bei Bedarf") {
                            Toggle("", isOn: $isOnDemand)
                                .labelsHidden()
                                .tint(AppTheme.accent)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(AppTheme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        // Dosis (nur wenn regulär)
                        if !isOnDemand {
                            let dosageLabel = selectedIntakeTimes.count > 0
                                ? "Tabletten pro Einnahme (\(selectedIntakeTimes.count)× täglich = \(dosagePreviewText))"
                                : "Tabletten pro Tag"

                            FormField(label: dosageLabel) {
                                TextField("z.B. 1", text: $dailyDosage)
                                    #if canImport(UIKit)
                                    .keyboardType(.decimalPad)
                                    #endif
                                    .padding()
                                    .background(AppTheme.cardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(medication == nil ? "Neues Medikament" : "Bearbeiten")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundColor(AppTheme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        let dosage = Double(dailyDosage.replacingOccurrences(of: ",", with: ".")) ?? 1.0
                        onSave(
                            name.trimmingCharacters(in: .whitespaces),
                            Int(packageSize) ?? 0,
                            receivedDate,
                            dosage,
                            isOnDemand,
                            selectedIntakeTimes
                        )
                        dismiss()
                    }
                    .disabled(!isValid)
                    .foregroundColor(isValid ? AppTheme.accentLight : AppTheme.textSecondary)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let med = medication {
                    name = med.name
                    packageSize = "\(med.packageSize)"
                    receivedDate = med.receivedDate
                    dailyDosage = "\(med.dailyDosage)"
                    isOnDemand = med.isOnDemand
                    selectedIntakeTimes = med.intakeTimes
                }
            }
        }
    }
}

/// Einzelne Zeile für Einnahmezeit-Auswahl
struct IntakeTimeToggleRow: View {
    let time: IntakeTime
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack {
                Image(systemName: time.icon)
                    .foregroundColor(isSelected ? AppTheme.accentLight : AppTheme.textSecondary)
                    .frame(width: 24)
                Text(time.label)
                    .foregroundColor(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? AppTheme.accentLight : AppTheme.textSecondary.opacity(0.5))
                    .font(.title3)
            }
        }
    }
}

struct FormField<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppTheme.textSecondary)
            content
        }
    }
}

#Preview {
    AddMedicationView()
        .modelContainer(for: Medication.self, inMemory: true)
}
