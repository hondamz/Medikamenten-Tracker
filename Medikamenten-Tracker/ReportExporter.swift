import Foundation
import SwiftUI
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
#endif

/// Erzeugt Report-Dateien in verschiedenen Formaten
enum ReportExporter {

    private static var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.locale = Locale(identifier: "de_DE")
        return f
    }

    // MARK: - Text Report

    static func generateTextReport(from medications: [Medication]) -> String {
        let sorted = medications.sorted { $0.remainingDays < $1.remainingDays }
        let date = dateFormatter.string(from: Date())

        var lines: [String] = []
        lines.append("═══════════════════════════════════════════")
        lines.append("  MEDIKAMENTEN-REPORT")
        lines.append("  Stand: \(date)")
        lines.append("═══════════════════════════════════════════")
        lines.append("")

        for med in sorted {
            lines.append("───────────────────────────────────────────")
            lines.append("  \(med.name)")
            lines.append("───────────────────────────────────────────")

            if med.isOnDemand {
                lines.append("  Typ:              Bei Bedarf")
            } else {
                lines.append("  Typ:              Regelmäßig")
                if med.intakeTimes.count > 0 {
                    lines.append("  Pro Einnahme:     \(String(format: "%.1f", med.dailyDosage)) Tabletten")
                    lines.append("  Einnahmen/Tag:    \(med.intakesPerDay)× (\(med.intakeTimes.displayText))")
                    lines.append("  Tagesverbrauch:   \(String(format: "%.1f", med.dailyConsumption)) Tabletten/Tag")
                } else {
                    lines.append("  Dosis:            \(String(format: "%.1f", med.dailyConsumption)) Tabletten/Tag")
                }
            }

            if med.intakeTimeRawValue > 0 {
                lines.append("  Einnahmezeit:     \(med.intakeTimes.displayText)")
            }

            lines.append("  Packungsgröße:    \(med.packageSize) Tabletten")
            lines.append("  Erhalten am:      \(dateFormatter.string(from: med.receivedDate))")
            lines.append("  Noch verfügbar:   \(Int(med.remainingTablets)) Tabletten")

            if !med.isOnDemand {
                lines.append("  Reicht bis:       \(dateFormatter.string(from: med.depletionDate))")
                lines.append("  Verbleibend:      \(med.remainingDays) Tage")
            }

            lines.append("")
        }

        lines.append("═══════════════════════════════════════════")
        lines.append("  Gesamt: \(medications.count) Medikamente")
        lines.append("  Regelmäßig: \(medications.filter { !$0.isOnDemand }.count)")
        lines.append("  Bei Bedarf: \(medications.filter { $0.isOnDemand }.count)")
        lines.append("═══════════════════════════════════════════")

        return lines.joined(separator: "\n")
    }

    // MARK: - CSV Report

    static func generateCSVReport(from medications: [Medication]) -> String {
        let sorted = medications.sorted { $0.remainingDays < $1.remainingDays }

        var lines: [String] = []
        lines.append("Name;Typ;Packungsgröße;Erhalten am;Pro Einnahme;Einnahmen/Tag;Tagesverbrauch;Einnahmezeit;Verfügbar;Reicht bis;Verbleibende Tage")

        for med in sorted {
            let typ = med.isOnDemand ? "Bei Bedarf" : "Regelmäßig"
            let proEinnahme = med.isOnDemand ? "-" : String(format: "%.1f", med.dailyDosage)
            let einnahmenTag = med.isOnDemand ? "-" : "\(med.intakesPerDay)"
            let tagesverbrauch = med.isOnDemand ? "-" : String(format: "%.1f", med.dailyConsumption)
            let einnahme = med.intakeTimeRawValue > 0 ? med.intakeTimes.displayText : "-"
            let reichtBis = med.isOnDemand ? "-" : dateFormatter.string(from: med.depletionDate)
            let tage = med.isOnDemand ? "-" : "\(med.remainingDays)"

            lines.append("\(med.name);\(typ);\(med.packageSize);\(dateFormatter.string(from: med.receivedDate));\(proEinnahme);\(einnahmenTag);\(tagesverbrauch);\(einnahme);\(Int(med.remainingTablets));\(reichtBis);\(tage)")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - PDF Report

    static func generatePDFReport(from medications: [Medication]) -> Data {
        let sorted = medications.sorted { $0.remainingDays < $1.remainingDays }
        let date = dateFormatter.string(from: Date())

        let pageWidth: CGFloat = 595.0  // A4
        let pageHeight: CGFloat = 842.0
        let margin: CGFloat = 50.0
        let contentWidth = pageWidth - 2 * margin

        let pdfData = NSMutableData()

        #if canImport(UIKit)
        UIGraphicsBeginPDFContextToData(pdfData, CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight), nil)

        var yPos: CGFloat = margin
        var currentPage = 0

        func startNewPage() {
            UIGraphicsBeginPDFPage()
            yPos = margin
            currentPage += 1
        }

        func checkPageBreak(needed: CGFloat) {
            if yPos + needed > pageHeight - margin {
                startNewPage()
            }
        }

        func drawText(_ text: String, at point: CGPoint, font: UIFont, color: UIColor = .black) {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color
            ]
            (text as NSString).draw(at: point, withAttributes: attrs)
        }

        func drawLine(from: CGPoint, to: CGPoint, color: UIColor = .gray) {
            guard let context = UIGraphicsGetCurrentContext() else { return }
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(0.5)
            context.move(to: from)
            context.addLine(to: to)
            context.strokePath()
        }

        // Erste Seite
        startNewPage()

        // Titel
        let titleFont = UIFont.boldSystemFont(ofSize: 20)
        let headerFont = UIFont.boldSystemFont(ofSize: 14)
        let bodyFont = UIFont.systemFont(ofSize: 11)
        let smallFont = UIFont.systemFont(ofSize: 9)

        drawText("Medikamenten-Report", at: CGPoint(x: margin, y: yPos), font: titleFont)
        yPos += 28
        drawText("Stand: \(date)", at: CGPoint(x: margin, y: yPos), font: bodyFont, color: .gray)
        yPos += 30

        drawLine(from: CGPoint(x: margin, y: yPos), to: CGPoint(x: pageWidth - margin, y: yPos))
        yPos += 20

        for med in sorted {
            checkPageBreak(needed: 140)

            // Name
            drawText(med.name, at: CGPoint(x: margin, y: yPos), font: headerFont)
            if med.isOnDemand {
                drawText("Bei Bedarf", at: CGPoint(x: margin + contentWidth - 60, y: yPos + 2), font: smallFont, color: .orange)
            }
            yPos += 22

            // Details
            let labelX = margin + 10
            let valueX = margin + 150

            if !med.isOnDemand {
                if med.intakeTimes.count > 0 {
                    drawText("Pro Einnahme:", at: CGPoint(x: labelX, y: yPos), font: bodyFont, color: .darkGray)
                    drawText("\(String(format: "%.1f", med.dailyDosage)) Tabletten", at: CGPoint(x: valueX, y: yPos), font: bodyFont)
                    yPos += 16

                    drawText("Einnahmen/Tag:", at: CGPoint(x: labelX, y: yPos), font: bodyFont, color: .darkGray)
                    drawText("\(med.intakesPerDay)× (\(med.intakeTimes.displayText))", at: CGPoint(x: valueX, y: yPos), font: bodyFont)
                    yPos += 16

                    drawText("Tagesverbrauch:", at: CGPoint(x: labelX, y: yPos), font: bodyFont, color: .darkGray)
                    drawText("\(String(format: "%.1f", med.dailyConsumption)) Tabletten/Tag", at: CGPoint(x: valueX, y: yPos), font: bodyFont)
                    yPos += 16
                } else {
                    drawText("Dosis:", at: CGPoint(x: labelX, y: yPos), font: bodyFont, color: .darkGray)
                    drawText("\(String(format: "%.1f", med.dailyConsumption)) Tabletten/Tag", at: CGPoint(x: valueX, y: yPos), font: bodyFont)
                    yPos += 16
                }
            }

            if med.intakeTimeRawValue > 0 && med.isOnDemand {
                drawText("Einnahmezeit:", at: CGPoint(x: labelX, y: yPos), font: bodyFont, color: .darkGray)
                drawText(med.intakeTimes.displayText, at: CGPoint(x: valueX, y: yPos), font: bodyFont)
                yPos += 16
            }

            drawText("Noch verfügbar:", at: CGPoint(x: labelX, y: yPos), font: bodyFont, color: .darkGray)
            drawText("\(Int(med.remainingTablets)) von \(med.packageSize) Tabletten", at: CGPoint(x: valueX, y: yPos), font: bodyFont)
            yPos += 16

            if !med.isOnDemand {
                drawText("Reicht bis:", at: CGPoint(x: labelX, y: yPos), font: bodyFont, color: .darkGray)
                let dateColor: UIColor = med.remainingDays < 7 ? .red : .darkGray
                drawText("\(dateFormatter.string(from: med.depletionDate)) (\(med.remainingDays) Tage)", at: CGPoint(x: valueX, y: yPos), font: bodyFont, color: dateColor)
                yPos += 16
            }

            yPos += 10
            drawLine(from: CGPoint(x: margin, y: yPos), to: CGPoint(x: pageWidth - margin, y: yPos), color: .lightGray)
            yPos += 15
        }

        // Zusammenfassung
        checkPageBreak(needed: 60)
        yPos += 10
        drawText("Zusammenfassung", at: CGPoint(x: margin, y: yPos), font: headerFont)
        yPos += 20
        drawText("Gesamt: \(medications.count) Medikamente  |  Regelmäßig: \(medications.filter { !$0.isOnDemand }.count)  |  Bei Bedarf: \(medications.filter { $0.isOnDemand }.count)",
                 at: CGPoint(x: margin + 10, y: yPos), font: bodyFont, color: .darkGray)

        UIGraphicsEndPDFContext()
        #endif

        return pdfData as Data
    }
}

// MARK: - Export Document Types

struct TextReportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    var text: String

    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws {
        text = String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8) ?? ""
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: text.data(using: .utf8) ?? Data())
    }
}

struct CSVReportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    var text: String

    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws {
        text = String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8) ?? ""
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: text.data(using: .utf8) ?? Data())
    }
}

struct PDFReportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }
    var data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
