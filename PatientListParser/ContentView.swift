import SwiftUI
import AppKit

// MARK: - Model
struct Patient: Identifiable {
    let id = UUID()
    let patientNumber: String
    let baseName: String
    let unit: String
    let room: String
    let los: Double
    let physician: String

    /// Marked patients: LOS between 1 and 3.3
    var isMarkedLOS: Bool {
        los >= 1 && los <= 3.3
    }

    /// Extract numeric part of room like "N29" -> 29
    var roomNumber: Int {
        let digits = room.drop { !$0.isNumber }
        return Int(digits) ?? 0
    }
}

// MARK: - Marking Mode
enum MarkingMode: String, CaseIterable, Identifiable {
    case stars = "Stars (***)"
    case highlight = "Row Highlight"
    case none = "None"

    var id: String { rawValue }
}

// MARK: - Sort Column
enum SortColumn: CaseIterable {
    case los, unit, room, patientNumber, name, physician

    var title: String {
        switch self {
        case .los: return "LOS"
        case .unit: return "Unit"
        case .room: return "Room"
        case .patientNumber: return "Patient #"
        case .name: return "Name"
        case .physician: return "Consulting Physician"
        }
    }
}

struct SortKey: Identifiable {
    let id = UUID()
    let column: SortColumn
    var ascending: Bool
}

// MARK: - Content View
struct ContentView: View {

    // Example dummy input shown at launch (ALL FICTIONAL)
    @State private var inputText: String = """
    # EXAMPLE DATA — replace with real patient list
    #
    # Input schema (what this app extracts from each line):
    # - Patient Number: 9-digit number (example: 875005902)
    # - Name: everything before "NURS" (example: ZENNER, ALEX)
    # - Unit: currently set to "NURS"
    # - Room: pattern like N## (example: N29)
    # - LOS: number before "Days" (example: 1.7 Days)
    # - Consulting Physician: everything after "Days"
    #
    # Paste lines like these:

    ZENNER, ALEX NURS N TR N29 D 72 years Other 875005902  0.4 Days Orion Vale MD, Kato Lin MD
    MORRIX, JULES NURS N TR N12 D 81 years Other 875005905  1.7 Days Tessa Bloom MD
    KAVEN, RHEA NURS N TR N03 D 69 years Other 875005923  3.1 Days Nolan Pike MD
    HALDEN, IVO NURS N TR N18 D 58 years Other 875005944  5.4 Days Mira Solis MD
    """

    @State private var patients: [Patient] = []
    @State private var markingMode: MarkingMode = .stars

    // Default sort: LOS ↑, Unit ↑, Room ↑
    @State private var sortKeys: [SortKey] = ContentView.defaultSortKeys

    static let defaultSortKeys: [SortKey] = [
        SortKey(column: .los, ascending: true),
        SortKey(column: .unit, ascending: true),
        SortKey(column: .room, ascending: true)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            Text("Paste Patient List")
                .font(.headline)

            TextEditor(text: $inputText)
                .font(.system(.body, design: .monospaced))
                .frame(height: 180)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.6)))
                .onChange(of: inputText) { _ in generate() }

            HStack {
                Button("Paste from Clipboard") {
                    if let text = NSPasteboard.general.string(forType: .string) {
                        inputText = text
                    }
                }

                Button("Copy Table") { copyTable() }
                Button("Export CSV") { exportCSV() }
                Button("Print Table") { printTable() }

                Button("Reset Sort") {
                    sortKeys = Self.defaultSortKeys
                    generate()
                }
                .keyboardShortcut("r", modifiers: [.command])

                Spacer()

                Picker("Marking", selection: $markingMode) {
                    ForEach(MarkingMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 320)
                .onChange(of: markingMode) { _ in generate() }
            }

            Divider()

            headerRow()

            List(patients) { patient in
                dataRow(patient)
                    .listRowBackground(rowBackground(for: patient))
            }
            .listStyle(.inset)
        }
        .padding()
        .onAppear { generate() }
    }

    // MARK: - Header + Rows
    func headerRow() -> some View {
        HStack {
            header(.patientNumber, width: 100)
            header(.name, width: 240)
            header(.unit, width: 70)
            header(.room, width: 70)
            header(.los, width: 60)
            header(.physician, width: nil)
        }
        .font(.system(.caption, design: .monospaced))
    }

    func header(_ column: SortColumn, width: CGFloat?) -> some View {
        Button {
            toggleSort(column)
            generate()
        } label: {
            HStack(spacing: 4) {
                Text(column.title)

                if let idx = sortKeys.firstIndex(where: { $0.column == column }) {
                    Text("\(idx + 1)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(3)

                    Image(systemName: sortKeys[idx].ascending
                          ? "arrowtriangle.up.fill"
                          : "arrowtriangle.down.fill")
                        .font(.system(size: 8))
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: width, alignment: .leading)
        .fontWeight(.bold)
    }

    func dataRow(_ p: Patient) -> some View {
        HStack {
            cell(p.patientNumber, 100)
            cell(displayName(p), 240)
            cell(p.unit, 70)
            cell(p.room, 70)
            cell(String(p.los), 60)
            cell(p.physician, nil)
        }
        .font(.system(.body, design: .monospaced))
    }

    func cell(_ text: String, _ width: CGFloat?) -> some View {
        Text(text).frame(width: width, alignment: .leading)
    }

    // MARK: - Display
    func displayName(_ p: Patient) -> String {
        markingMode == .stars && p.isMarkedLOS ? "*** \(p.baseName)" : p.baseName
    }

    func rowBackground(for p: Patient) -> Color {
        markingMode == .highlight && p.isMarkedLOS
            ? Color.green.opacity(0.25)
            : .clear
    }

    // MARK: - Sorting
    func toggleSort(_ column: SortColumn) {
        if let idx = sortKeys.firstIndex(where: { $0.column == column }) {
            sortKeys[idx].ascending.toggle()
        } else {
            sortKeys.insert(SortKey(column: column, ascending: true), at: 0)
        }
    }

    // MARK: - Generate
    func generate() {
        let lines = inputText.split(separator: "\n").map(String.init)
        let parsed = lines.compactMap(parseLine)

        patients = parsed.sorted { a, b in
            for key in sortKeys {
                switch key.column {
                case .los:
                    if a.los != b.los { return key.ascending ? a.los < b.los : a.los > b.los }
                case .unit:
                    if a.unit != b.unit { return key.ascending ? a.unit < b.unit : a.unit > b.unit }
                case .room:
                    if a.roomNumber != b.roomNumber { return key.ascending ? a.roomNumber < b.roomNumber : a.roomNumber > b.roomNumber }
                case .patientNumber:
                    if a.patientNumber != b.patientNumber { return key.ascending ? a.patientNumber < b.patientNumber : a.patientNumber > b.patientNumber }
                case .name:
                    if a.baseName != b.baseName { return key.ascending ? a.baseName < b.baseName : a.baseName > b.baseName }
                case .physician:
                    if a.physician != b.physician { return key.ascending ? a.physician < b.physician : a.physician > b.physician }
                }
            }
            return false
        }
    }

    // MARK: - Parsing
    func parseLine(_ line: String) -> Patient? {
        let t = line.trimmingCharacters(in: .whitespaces)
        if t.isEmpty || t.hasPrefix("#") { return nil }

        guard
            let losRange = t.range(of: #"(\d+\.?\d*)\s*Days"#, options: .regularExpression),
            let los = Double(t[losRange].components(separatedBy: " ").first ?? "")
        else { return nil }

        let patientNumber = t.range(of: #"\b\d{9}\b"#, options: .regularExpression).map { String(t[$0]) } ?? ""
        let baseName = t.components(separatedBy: "NURS").first?.trimmingCharacters(in: .whitespaces) ?? ""
        let room = t.range(of: #"N\d+"#, options: .regularExpression).map { String(t[$0]) } ?? ""
        let physician = t.components(separatedBy: "Days").last?.trimmingCharacters(in: .whitespaces) ?? ""

        return Patient(
            patientNumber: patientNumber,
            baseName: baseName,
            unit: "NURS",
            room: room,
            los: los,
            physician: physician
        )
    }

    // MARK: - Copy / Export / Print
    func copyTable() {
        var text = "Patient #\tName\tUnit\tRoom\tLOS\tConsulting Physician\n"
        for p in patients {
            text += "\(p.patientNumber)\t\(displayName(p))\t\(p.unit)\t\(p.room)\t\(p.los)\t\(p.physician)\n"
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func exportCSV() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "rounding_sheet.csv"
        panel.begin { r in
            guard r == .OK, let url = panel.url else { return }
            var csv = "Patient#,Name,Unit,Room,LOS,Consulting Physician\n"
            for p in patients {
                csv += "\(p.patientNumber),\"\(displayName(p))\",\(p.unit),\(p.room),\(p.los),\"\(p.physician)\"\n"
            }
            try? csv.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    func printTable() {
        let view = PrintableTableView(patients: patients, markingMode: markingMode, displayName: displayName)
        let printInfo = NSPrintInfo.shared
        printInfo.orientation = .landscape
        printInfo.horizontalPagination = .fit
        NSPrintOperation(view: view, printInfo: printInfo).run()
    }
}

// MARK: - Printable Table View
final class PrintableTableView: NSView {

    let patients: [Patient]
    let markingMode: MarkingMode
    let displayName: (Patient) -> String

    private let rowHeight: CGFloat = 20
    private let font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
    private let colWidths: [CGFloat] = [110, 260, 60, 60, 50, 320]
    private let leftPadding: CGFloat = 10

    init(patients: [Patient], markingMode: MarkingMode, displayName: @escaping (Patient) -> String) {
        self.patients = patients
        self.markingMode = markingMode
        self.displayName = displayName

        let width = colWidths.reduce(leftPadding, +) + 10
        let height = CGFloat(patients.count + 2) * rowHeight
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: height))
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let attrs: [NSAttributedString.Key: Any] = [.font: font]

        var y = bounds.height - rowHeight

        func drawRow(_ values: [String], bg: NSColor?) {
            if let bg = bg {
                ctx.setFillColor(bg.cgColor)
                ctx.fill(CGRect(x: 0, y: y, width: bounds.width, height: rowHeight))
            }

            var x = leftPadding
            for (i, v) in values.enumerated() {
                (v as NSString).draw(at: CGPoint(x: x, y: y + 4), withAttributes: attrs)
                x += colWidths[min(i, colWidths.count - 1)]
            }
            y -= rowHeight
        }

        drawRow(["Patient #", "Name", "Unit", "Room", "LOS", "Consulting Physician"], bg: nil)

        for p in patients {
            let bg = (markingMode == .highlight && p.isMarkedLOS)
                ? NSColor.systemGreen.withAlphaComponent(0.25)
                : nil

            drawRow(
                [p.patientNumber, displayName(p), p.unit, p.room, String(p.los), p.physician],
                bg: bg
            )
        }
    }
}
