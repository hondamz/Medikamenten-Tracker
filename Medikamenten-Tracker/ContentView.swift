import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            // Inhalt
            Group {
                switch selectedTab {
                case 0:
                    StatusView()
                case 1:
                    AddMedicationView()
                case 2:
                    SettingsView()
                default:
                    StatusView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 70)

            // Custom Tab Bar
            CustomTabBar(selectedTab: $selectedTab)
        }
        .background(AppTheme.background)
        .preferredColorScheme(.dark)
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: Int

    var body: some View {
        HStack {
            TabBarButton(
                icon: "list.bullet.rectangle",
                label: "Anzeigen",
                isSelected: selectedTab == 0
            ) {
                selectedTab = 0
            }

            Spacer()

            TabBarButton(
                icon: "plus.circle.fill",
                label: "Erfassen",
                isSelected: selectedTab == 1
            ) {
                selectedTab = 1
            }

            Spacer()

            TabBarButton(
                icon: "gearshape",
                label: "Einstellungen",
                isSelected: selectedTab == 2
            ) {
                selectedTab = 2
            }
        }
        .padding(.horizontal, 30)
        .padding(.top, 12)
        .padding(.bottom, 28)
        .background(
            AppTheme.tabBarBackground
                .clipShape(RoundedCorner(radius: 24, corners: [.topLeft, .topRight]))
                .shadow(color: .black.opacity(0.3), radius: 10, y: -5)
        )
    }
}

struct TabBarButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? AppTheme.accentLight : AppTheme.textSecondary)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(isSelected ? AppTheme.accentLight : AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        #if canImport(UIKit)
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
        #else
        return Path(roundedRect: rect, cornerRadius: radius)
        #endif
    }
}

#if !canImport(UIKit)
struct UIRectCorner: OptionSet {
    let rawValue: Int
    static let topLeft = UIRectCorner(rawValue: 1 << 0)
    static let topRight = UIRectCorner(rawValue: 1 << 1)
    static let bottomLeft = UIRectCorner(rawValue: 1 << 2)
    static let bottomRight = UIRectCorner(rawValue: 1 << 3)
}
#endif

#Preview {
    ContentView()
        .modelContainer(for: Medication.self, inMemory: true)
}
