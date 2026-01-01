import SwiftUI
import AppKit

// MARK: - Model
struct Patient: Identifiable {
    let id = UUID()
    let baseName: String
    let room: String
    let bed: String
    let los: Double
    let consultingPhysician: String

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

// MARK: - Sorting
enum SortColumn: CaseIterable {
    case name, room, bed, los, consulting

    var title: String {
        switch self {
        case .name: return "Name"
        case .room: return "Room"
        case .bed: return "Bed"
        case .los: return "LOS"
        case .consulting: return "Consulting Physician"
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

    @State private var inputText: String = ""
    @State private var patients: [Patient] = []
    @State private var markingMode: MarkingMode = .stars

    // Default sort: LOS → Room → Bed
    static let defaultSortKeys: [SortKey] = [
        SortKey(column: .los, ascending: true),
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
                    if let s = NSPasteboard.general.string(forType: .string) {
                        inputText = s
                    }
                }

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
    }

    // MARK: - Header / Rows

    func headerRow() -> some View {
        HStack {
            fixedHeader("#", 40)
            sortableHeader(.name, 220)
            sortableHeader(.room, 60)
            sortableHeader(.bed, 50)
            sortableHeader(.los, 50)
            sortableHeader(.consulting, nil)
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
            cell(p.consultingPhysician, nil)
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

        patients = parsed.sorted { a, b in
            for key in sortKeys {
                switch key.column {
                case .los:
                    if a.los != b.los { return key.ascending ? a.los < b.los : a.los > b.los }
                case .room:
                    if a.roomNumber != b.roomNumber { return key.ascending ? a.roomNumber < b.roomNumber : a.roomNumber > b.roomNumber }
                case .bed:
                    if a.bed != b.bed { return key.ascending ? a.bed < b.bed : a.bed > b.bed }
                case .name:
                    if a.baseName != b.baseName { return key.ascending ? a.baseName < b.baseName : a.baseName > b.baseName }
                case .consulting:
                    if a.consultingPhysician != b.consultingPhysician {
                        return key.ascending
                            ? a.consultingPhysician < b.consultingPhysician
                            : a.consultingPhysician > b.consultingPhysician
                    }
                }
            }
            return false
        }
    }

    // MARK: - Parsing (simple, reliable)

    func parseLine(_ line: String) -> Patient? {
        let t = line.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return nil }

        guard
            let losRange = t.range(of: #"(\d+\.?\d*)\s*Days"#, options: .regularExpression),
            let los = Double(t[losRange].components(separatedBy: " ").first ?? "")
        else { return nil }

        let tokens = t.split(separator: " ").map(String.init)

        guard let roomIdx = tokens.firstIndex(where: {
            $0.range(of: #"^[A-Z]\d+$"#, options: .regularExpression) != nil
        }) else { return nil }

        let room = tokens[roomIdx]
        let bed = roomIdx + 1 < tokens.count ? tokens[roomIdx + 1] : ""

        let baseName =
            t.components(separatedBy: "NURS")
                .first?
                .trimmingCharacters(in: .whitespaces) ?? ""

        let consulting =
            t.components(separatedBy: "Days")
                .last?
                .trimmingCharacters(in: .whitespaces) ?? ""

        return Patient(
            baseName: baseName,
            room: room,
            bed: bed,
            los: los,
            consultingPhysician: consulting
        )
    }

    // MARK: - Copy / Print

    func copyTable() {
        var out = "#\tName\tRoom\tBed\tLOS\tConsulting Physician\n"
        for (i, p) in patients.enumerated() {
            out += "\(i+1)\t\(displayName(p))\t\(p.room)\t\(p.bed)\t\(p.los)\t\(p.consultingPhysician)\n"
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(out, forType: .string)
    }

    func printTable() {
        let tv = NSTextView(frame: NSRect(x: 0, y: 0, width: 900, height: 1200))
        tv.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        tv.isEditable = false

        var text = "#\tName\tRoom\tBed\tLOS\tConsulting Physician\n"
        for (i, p) in patients.enumerated() {
            text += "\(i+1)\t\(displayName(p))\t\(p.room)\t\(p.bed)\t\(p.los)\t\(p.consultingPhysician)\n"
        }
        tv.string = text

        let info = NSPrintInfo.shared
        info.orientation = .landscape
        info.horizontalPagination = .fit

        NSPrintOperation(view: tv, printInfo: info).run()
    }
}
