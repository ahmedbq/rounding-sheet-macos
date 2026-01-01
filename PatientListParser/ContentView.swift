import SwiftUI
import AppKit

// MARK: - Model
struct Patient: Identifiable {
    let id = UUID()
    let baseName: String
    let room: String
    let bed: String
    let los: Double
    let physiciansAndNotes: String

    var isMarkedLOS: Bool {
        los >= 1 && los <= 3.3
    }

    var roomNumber: Int {
        let digits = room.drop { !$0.isNumber }
        return Int(digits) ?? 0
    }
    
    var roomPrefixAndNumber: (String, Int) {
        let prefix = room.prefix { $0.isLetter }
        let number = Int(room.drop { !$0.isNumber }) ?? 0
        return (String(prefix), number)
    }
}

// MARK: - Marking Mode
enum MarkingMode: String, CaseIterable, Identifiable {
    case stars = "Stars (***)"
    case highlight = "Row Highlight"
    case none = "None"
    var id: String { rawValue }
}

// MARK: - Sorting
enum SortColumn: CaseIterable {
    case name, room, bed, los, physicians

    var title: String {
        switch self {
        case .name: return "Name"
        case .room: return "Room"
        case .bed: return "Bed"
        case .los: return "LOS"
        case .physicians: return "Physicians + Notes"
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
    # Example input (dummy data)
    DOE, JANE A NURS N TR N03 D 72 years Female 123456789  0.8 Days Smith MD, John Alpha Note Here
    SMITH, ROBERT B NURS S TR S15 W 65 years Male 987654321  1.6 Days Adams DO, Mary Beta Program Note
    BROWN, LINDA C 230 D 79 years Female 555444333 12.9 Days Shah MD, Shilpan H Raval MD, Sumul MTO Mult TR No Brain/SCN
    """
    @State private var patients: [Patient] = []
    @State private var markingMode: MarkingMode = .stars
    @State private var prioritizeLowLOS: Bool = true

    static let defaultSortKeys: [SortKey] = [
        SortKey(column: .room, ascending: true),
        SortKey(column: .bed, ascending: true)
    ]

    @State private var sortKeys: [SortKey] = defaultSortKeys

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            TextEditor(text: $inputText)
                .font(.system(.body, design: .monospaced))
                .frame(height: 180)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.gray.opacity(0.6)))
                .onChange(of: inputText) { _ in generate() }

            HStack {
                Button("Paste") {
                    let pb = NSPasteboard.general

                    if let str = pb.string(forType: .string) {
                        inputText = str
                        return
                    }

                    if let rtfData = pb.data(forType: .rtf),
                       let attr = try? NSAttributedString(
                           data: rtfData,
                           options: [.documentType: NSAttributedString.DocumentType.rtf],
                           documentAttributes: nil
                       ) {
                        inputText = attr.string
                        return
                    }

                    if let htmlData = pb.data(forType: .html),
                       let attr = try? NSAttributedString(
                           data: htmlData,
                           options: [.documentType: NSAttributedString.DocumentType.html],
                           documentAttributes: nil
                       ) {
                        inputText = attr.string
                    }
                }
                
                Toggle("Prioritize LOS < 1.0", isOn: $prioritizeLowLOS)
                    .toggleStyle(.checkbox)
                    .onChange(of: prioritizeLowLOS) { _ in generate() }


                Button("Copy Table") { copyTable() }
                Button("Print") { printTable() }

                Button("Reset Sort") {
                    sortKeys = Self.defaultSortKeys
                    generate()
                }
                .keyboardShortcut("r", modifiers: [.command])

                Spacer()

                Picker("Marking", selection: $markingMode) {
                    ForEach(MarkingMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 320)
                .onChange(of: markingMode) { _ in generate() }
            }

            Divider()
            headerRow()

            List(Array(patients.enumerated()), id: \.element.id) { index, p in
                dataRow(p, index: index + 1)
                    .listRowBackground(
                        markingMode == .highlight && p.isMarkedLOS
                        ? Color.green.opacity(0.25)
                        : .clear
                    )
            }
            .listStyle(.inset)
        }
        .padding()
        .onAppear {
            generate()
        }
    }

    // MARK: - Header / Rows

    func headerRow() -> some View {
        HStack {
            fixedHeader("#", 40)
            sortableHeader(.name, 220)
            sortableHeader(.room, 60)
            sortableHeader(.bed, 50)
            sortableHeader(.los, 50)
            sortableHeader(.physicians, nil)
        }
        .font(.system(.caption, design: .monospaced))
    }

    func fixedHeader(_ text: String, _ width: CGFloat) -> some View {
        Text(text)
            .frame(width: width, alignment: .leading)
            .fontWeight(.bold)
    }

    func sortableHeader(_ column: SortColumn, _ width: CGFloat?) -> some View {
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
                        .background(Color.gray.opacity(0.2))
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

    func dataRow(_ p: Patient, index: Int) -> some View {
        HStack {
            cell(String(index), 40)
            cell(displayName(p), 220)
            cell(p.room, 60)
            cell(p.bed, 50)
            cell(String(p.los), 50)
            cell(p.physiciansAndNotes, nil)
        }
        .font(.system(.body, design: .monospaced))
    }

    func cell(_ text: String, _ width: CGFloat?) -> some View {
        Text(text).frame(width: width, alignment: .leading)
    }

    func displayName(_ p: Patient) -> String {
        markingMode == .stars && p.isMarkedLOS ? "*** \(p.baseName)" : p.baseName
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

        func sorted(_ list: [Patient]) -> [Patient] {
            list.sorted { a, b in
                for key in sortKeys {
                    switch key.column {
                    case .los:
                        if a.los != b.los {
                            return key.ascending ? a.los < b.los : a.los > b.los
                        }
                    case .room:
                        let (ap, an) = a.roomPrefixAndNumber
                        let (bp, bn) = b.roomPrefixAndNumber
                        if ap != bp { return key.ascending ? ap < bp : ap > bp }
                        if an != bn { return key.ascending ? an < bn : an > bn }
                    case .bed:
                        if a.bed != b.bed {
                            return key.ascending ? a.bed < b.bed : a.bed > b.bed
                        }
                    case .name:
                        if a.baseName != b.baseName {
                            return key.ascending ? a.baseName < b.baseName : a.baseName > b.baseName
                        }
                    case .physicians:
                        if a.physiciansAndNotes != b.physiciansAndNotes {
                            return key.ascending
                                ? a.physiciansAndNotes < b.physiciansAndNotes
                                : a.physiciansAndNotes > b.physiciansAndNotes
                        }
                    }
                }
                return false
            }
        }

        if prioritizeLowLOS {
            let low = parsed.filter { $0.los < 1.0 }
            let rest = parsed.filter { $0.los >= 1.0 }
            patients = sorted(low) + sorted(rest)
        } else {
            patients = sorted(parsed)
        }
    }


    // MARK: - Parsing (OLD + NEW formats)

    func parseLine(_ line: String) -> Patient? {
        let t = line.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return nil }

        guard
            let losRange = t.range(of: #"(\d+\.?\d*)\s*Days"#, options: .regularExpression),
            let los = Double(t[losRange].components(separatedBy: " ").first ?? "")
        else { return nil }

        let tokens = t.split(separator: " ").map(String.init)

        // Room: N03 / W18 OR numeric 230
        guard let roomIdx = tokens.firstIndex(where: {
            $0.range(of: #"^[A-Z]\d+$"#, options: .regularExpression) != nil ||
            $0.range(of: #"^\d{3}$"#, options: .regularExpression) != nil
        }) else { return nil }

        let room = tokens[roomIdx]
        let bed = roomIdx + 1 < tokens.count ? tokens[roomIdx + 1] : ""

        // Name:
        // - Old format: stop at NURS
        // - New format: everything before room
        let rawName = tokens[..<roomIdx].joined(separator: " ")
        let baseName = rawName.components(separatedBy: "NURS").first?
            .trimmingCharacters(in: .whitespaces) ?? rawName

        // Everything after Days = Physicians + Notes
        let physiciansAndNotes =
            t.components(separatedBy: "Days")
                .last?
                .trimmingCharacters(in: .whitespaces) ?? ""

        return Patient(
            baseName: baseName,
            room: room,
            bed: bed,
            los: los,
            physiciansAndNotes: physiciansAndNotes
        )
    }

    // MARK: - Copy / Print

    func copyTable() {
        var out = "#\tName\tRoom\tBed\tLOS\tPhysicians + Notes\n"
        for (i, p) in patients.enumerated() {
            out += "\(i+1)\t\(displayName(p))\t\(p.room)\t\(p.bed)\t\(p.los)\t\(p.physiciansAndNotes)\n"
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(out, forType: .string)
    }

    func printTable() {
        let view = PrintableTableView(
            patients: patients,
            markingMode: markingMode
        )

        let printInfo = NSPrintInfo.shared
        printInfo.orientation = .landscape
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic

        NSPrintOperation(view: view, printInfo: printInfo).run()
    }
    
    final class PrintableTableView: NSView {

        let patients: [Patient]
        let markingMode: MarkingMode

        private let rowHeight: CGFloat = 20
        private let font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)

        // Column widths must match your table
        private let colWidths: [CGFloat] = [
            40,   // #
            220,  // Name
            60,   // Room
            50,   // Bed
            50,   // LOS
            360   // Physicians + Notes
        ]

        init(patients: [Patient], markingMode: MarkingMode) {
            self.patients = patients
            self.markingMode = markingMode

            let width = colWidths.reduce(0, +) + 20
            let height = CGFloat(patients.count + 2) * rowHeight
            super.init(frame: NSRect(x: 0, y: 0, width: width, height: height))
        }

        required init?(coder: NSCoder) { nil }

        override func draw(_ dirtyRect: NSRect) {
            guard let ctx = NSGraphicsContext.current?.cgContext else { return }

            let attrs: [NSAttributedString.Key: Any] = [.font: font]
            var y = bounds.height - rowHeight

            func drawRow(_ values: [String], highlight: Bool) {
                if highlight {
                    ctx.setFillColor(NSColor.systemGreen.withAlphaComponent(0.25).cgColor)
                    ctx.fill(CGRect(x: 0, y: y, width: bounds.width, height: rowHeight))
                }

                var x: CGFloat = 10
                for (i, v) in values.enumerated() {
                    (v as NSString).draw(at: CGPoint(x: x, y: y + 4), withAttributes: attrs)
                    x += colWidths[i]
                }
                y -= rowHeight
            }

            // Header
            drawRow(
                ["#", "Name", "Room", "Bed", "LOS", "Physicians + Notes"],
                highlight: false
            )

            // Rows
            for (idx, p) in patients.enumerated() {
                drawRow(
                    [
                        "\(idx + 1)",
                        p.baseName,
                        p.room,
                        p.bed,
                        "\(p.los)",
                        p.physiciansAndNotes
                    ],
                    highlight: markingMode == .highlight && p.isMarkedLOS
                )
            }
        }
    }

}
