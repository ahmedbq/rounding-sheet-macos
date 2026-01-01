import SwiftUI
import AppKit

// MARK: - Model
struct Patient: Identifiable {
    let id = UUID()
    let baseName: String
    let unit: String
    let room: String
    let bed: String
    let los: Double
    let physician: String

    var isMarkedLOS: Bool {
        los >= 1 && los <= 3.3
    }

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
    case name, unit, room, bed, los, physician

    var title: String {
        switch self {
        case .name: return "Name"
        case .unit: return "Unit"
        case .room: return "Room"
        case .bed: return "Bed"
        case .los: return "LOS"
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

    @State private var inputText: String = """
    # Example (fictional)
    ZAFIECKI, JOHN M NURS N TR N02 D 79 years Male 17.7 Days Raval MD, Sumul
    GARTENSTEIN, IRVIN D NURS N TR N29 W 63 years Male 13.8 Days Mojarres MD, Richard
    """

    @State private var patients: [Patient] = []
    @State private var markingMode: MarkingMode = .stars
    @State private var sortKeys: [SortKey] = Self.defaultSortKeys

    static let defaultSortKeys: [SortKey] = [
        SortKey(column: .los, ascending: true),
        SortKey(column: .unit, ascending: true),
        SortKey(column: .room, ascending: true),
        SortKey(column: .bed, ascending: true)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            Text("Paste Patient List")
                .font(.headline)

            TextEditor(text: $inputText)
                .font(.system(.body, design: .monospaced))
                .frame(height: 180)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.gray.opacity(0.6)))
                .onChange(of: inputText) { _ in generate() }

            HStack {
                Button("Paste from Clipboard") {
                    if let s = NSPasteboard.general.string(forType: .string) {
                        inputText = s
                    }
                }

                Button("Copy Table") { copyTable() }
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

            List(Array(patients.enumerated()), id: \.element.id) { index, patient in
                dataRow(patient, index: index + 1)
                    .listRowBackground(rowBackground(for: patient))
            }
            .listStyle(.inset)
        }
        .padding()
        .onAppear { generate() }
    }

    // MARK: - Header / Rows

    func headerRow() -> some View {
        HStack {
            headerText("#", 40)
            header(.name, 220)
            header(.unit, 70)
            header(.room, 70)
            header(.bed, 50)
            header(.los, 60)
            header(.physician, nil)
        }
        .font(.system(.caption, design: .monospaced))
    }

    func header(_ column: SortColumn, _ width: CGFloat?) -> some View {
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

    func headerText(_ text: String, _ width: CGFloat) -> some View {
        Text(text).frame(width: width, alignment: .leading).fontWeight(.bold)
    }

    func dataRow(_ p: Patient, index: Int) -> some View {
        HStack {
            cell(String(index), 40)
            cell(displayName(p), 220)
            cell(p.unit, 70)
            cell(p.room, 70)
            cell(p.bed, 50)
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
        let parsed = inputText
            .split(separator: "\n")
            .map(String.init)
            .compactMap(parseLine)

        patients = parsed.sorted { a, b in
            for key in sortKeys {
                switch key.column {
                case .los:
                    if a.los != b.los { return key.ascending ? a.los < b.los : a.los > b.los }
                case .unit:
                    if a.unit != b.unit { return key.ascending ? a.unit < b.unit : a.unit > b.unit }
                case .room:
                    if a.roomNumber != b.roomNumber { return key.ascending ? a.roomNumber < b.roomNumber : a.roomNumber > b.roomNumber }
                case .bed:
                    if a.bed != b.bed { return key.ascending ? a.bed < b.bed : a.bed > b.bed }
                case .name:
                    if a.baseName != b.baseName { return key.ascending ? a.baseName < b.baseName : a.baseName > b.baseName }
                case .physician:
                    if a.physician != b.physician { return key.ascending ? a.physician < b.physician : a.physician > b.physician }
                }
            }
            return false
        }
    }

    // MARK: - Parsing (CORRECT Bed logic)

    func parseLine(_ line: String) -> Patient? {
        let t = line.trimmingCharacters(in: .whitespaces)
        if t.isEmpty || t.hasPrefix("#") { return nil }

        guard
            let losRange = t.range(of: #"(\d+\.?\d*)\s*Days"#, options: .regularExpression),
            let los = Double(t[losRange].components(separatedBy: " ").first ?? "")
        else { return nil }

        let tokens = t.split(separator: " ").map(String.init)

        guard let roomIndex = tokens.firstIndex(where: {
            $0.range(of: #"^N\d+$"#, options: .regularExpression) != nil
        }) else { return nil }

        let room = tokens[roomIndex]
        let bed = (roomIndex + 1 < tokens.count) ? tokens[roomIndex + 1] : ""

        let baseName =
            t.components(separatedBy: "NURS")
                .first?
                .trimmingCharacters(in: .whitespaces) ?? ""

        let physician =
            t.components(separatedBy: "Days")
                .last?
                .trimmingCharacters(in: .whitespaces) ?? ""

        return Patient(
            baseName: baseName,
            unit: "NURS",
            room: room,
            bed: bed,
            los: los,
            physician: physician
        )
    }

    // MARK: - Copy / Print

    func copyTable() {
        var text = "#\tName\tUnit\tRoom\tBed\tLOS\tConsulting Physician\n"
        for (idx, p) in patients.enumerated() {
            text += "\(idx + 1)\t\(displayName(p))\t\(p.unit)\t\(p.room)\t\(p.bed)\t\(p.los)\t\(p.physician)\n"
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func printTable() {
        let view = PrintableTableView(patients: patients,
                                     markingMode: markingMode,
                                     displayName: displayName)

        let printInfo = NSPrintInfo.shared
        printInfo.orientation = .landscape
        printInfo.horizontalPagination = .fit

        NSPrintOperation(view: view, printInfo: printInfo).run()
    }
}

// MARK: - Printable View
final class PrintableTableView: NSView {

    let patients: [Patient]
    let markingMode: MarkingMode
    let displayName: (Patient) -> String

    private let rowHeight: CGFloat = 20
    private let font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
    private let colWidths: [CGFloat] = [40, 220, 60, 60, 50, 50, 320]
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

        drawRow(["#", "Name", "Unit", "Room", "Bed", "LOS", "Consulting Physician"], bg: nil)

        for (idx, p) in patients.enumerated() {
            let bg = (markingMode == .highlight && p.isMarkedLOS)
                ? NSColor.systemGreen.withAlphaComponent(0.25)
                : nil

            drawRow(
                [String(idx + 1), displayName(p), p.unit, p.room, p.bed, String(p.los), p.physician],
                bg: bg
            )
        }
    }
}
