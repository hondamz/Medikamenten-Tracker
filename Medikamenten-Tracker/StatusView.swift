import SwiftUI
import SwiftData

struct StatusView: View {
    @State private var showCalendar = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Segmented Control
                    Picker("Ansicht", selection: $showCalendar) {
                        Text("Liste").tag(false)
                        Text("Kalender").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    if showCalendar {
                        CalendarView()
                    } else {
                        MedicationListView()
                    }
                }
            }
            .navigationTitle("Medikamenten-Status")
            .preferredColorScheme(.dark)
        }
    }
}

#Preview {
    StatusView()
        .modelContainer(for: Medication.self, inMemory: true)
}
