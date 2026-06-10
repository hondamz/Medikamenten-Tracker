# Medikamenten-Tracker

Eine iOS-App (SwiftUI / SwiftData) zur Verwaltung von Medikamenten. Sie zeigt für jedes Medikament an, wie viele Tabletten aktuell noch vorhanden sind und bis zu welchem Datum der Vorrat reicht. Das Design ist modern in dunklem Marineblau gehalten und für die Bedienung am iPhone optimiert.

## Funktionsumfang

### Navigation
Eine fest am unteren Rand verankerte Tab-Bar mit drei Hauptbereichen:
- **Anzeigen** – Status und Kalenderansicht
- **Erfassen** – Neue Medikamente anlegen
- **Einstellungen** – App-Konfiguration, Report und Import/Export

### Medikament erfassen
- Name des Medikaments
- Packungsgröße (Anzahl Tabletten in der Packung)
- Datum, an dem die volle Packung erhalten wurde
- Menge **pro Einnahme** (nicht pro Tag)
- Einnahmezeitpunkte als Mehrfachauswahl: **Morgens, Mittags, Abends, Nachts**
- Schalter „Einnahme bei Bedarf" für optionale Medikamente, die nicht regelmäßig genommen werden

### Status-Anzeige
Zwei umschaltbare Darstellungen:

**1. Listenansicht**
- Pro Medikament: Name, verbleibende Tabletten, Datum bis zu dem der Vorrat reicht
- Sortiert nach Restdauer aufsteigend (kürzeste Reichweite oben)
- Datum wird **rot** dargestellt, wenn der Vorrat weniger als 7 Tage reicht

**2. Kalenderansicht (Monatskalender)**
- Markierung nur am **letzten Tag** vor dem Aufbrauchen eines Medikaments
- Farbcode pro Tag:
  - 🔴 **Rot** – 0 Tage verbleibend (Medikament aufgebraucht)
  - 🟠 **Orange** – ≤ 7 Tage verbleibend
  - 🟢 **Grün** – > 7 Tage verbleibend

### Berechnung der Restmenge
Bei jedem Bildschirmaufruf wird neu berechnet:
- ausgehend vom Erfassungsdatum
- multipliziert mit der Menge pro Einnahme und der Anzahl der ausgewählten Einnahmezeitpunkte pro Tag
- abzüglich manuell erfasster Zusatzentnahmen

### Report
- Aktuelle Übersicht über alle Medikamente mit Restmenge und Reichweite
- Kalender-Report wann jedes Medikament aufgebraucht ist
- Export der Übersicht als **Textdatei** oder **CSV** an einen vom Benutzer wählbaren Speicherort
- Der zuletzt verwendete Speicherpfad wird beim nächsten Export vorgeschlagen

### Einstellungen
- Medikamenten-Übersicht ist immer ganz oben sichtbar
- Konfigurierbarer **Default-Speicherpfad** für Reports und Exports
- **Import/Export** aller Medikamentendaten und Einstellungen als JSON-Datei
- Falls beim Export kein Default-Pfad konfiguriert ist, wird er per Abfrage gesetzt

### Datenpersistenz
- Permanente Speicherung über **SwiftData**
- iCloud-Synchronisation, damit die Daten von allen Geräten desselben Apple-ID-Accounts erreichbar sind
- Beim Löschen der App wird abgefragt, ob die Medikamentendaten und Einstellungen erhalten bleiben sollen, damit sie nach einer Neuinstallation wieder genutzt werden können

## Technik

- **Sprache:** Swift
- **UI:** SwiftUI
- **Persistenz:** SwiftData mit iCloud-Sync
- **Plattform:** iOS (iPhone)
- **Design:** Dunkles Marineblau (siehe `Theme.swift`)

## Projektstruktur

| Datei | Aufgabe |
|---|---|
| `Medikamenten_TrackerApp.swift` | App-Einstiegspunkt, SwiftData-Container |
| `ContentView.swift` | Haupt-Layout mit Custom Tab Bar |
| `Medication.swift` | Datenmodell inkl. Berechnung Restmenge / Reichweite |
| `AddMedicationView.swift` | Erfassung neuer Medikamente |
| `MedicationListView.swift` | Listenansicht der Medikamente |
| `CalendarView.swift` | Kalenderansicht mit Farbpunkten |
| `StatusView.swift` | Container für Listen- und Kalenderansicht |
| `ReportView.swift` | Report-Anzeige |
| `ReportExporter.swift` | Export als Text/CSV |
| `BackupManager.swift` | Import/Export als JSON |
| `SettingsView.swift` | Einstellungen inkl. Default-Speicherpfad |
| `Theme.swift` | Farb- und Style-Definitionen |

## Versionshistorie

### V1.1
- Restmengen werden bei jedem Bildschirmaufruf zum aktuellen Datum neu berechnet
- Abfrage beim App-Löschen, ob Daten erhalten bleiben sollen
- Medikamenten-Übersicht in den Einstellungen immer ganz oben
- Einnahmezeitpunkte (Morgens/Mittags/Abends/Nachts) mit Mehrfachauswahl bei der Erfassung
- Berechnung erfolgt pro Einnahme × Anzahl der Einnahmen pro Tag
- Kalenderansicht: nur noch letzter Tag vor Aufbrauchen wird markiert, Farbschema 🔴 / 🟠 / 🟢
- Report-Export als Text oder CSV mit gemerktem Speicherpfad
- Konfigurierbarer Default-Speicherpfad in den Einstellungen
- Import/Export aller Daten als JSON

### V1.0
- Erfassung, Anzeige und Verwaltung von Medikamenten
- Listenansicht sortiert nach verbleibender Reichweite
- Monatskalender mit Farbpunkten
- iCloud-Persistenz
