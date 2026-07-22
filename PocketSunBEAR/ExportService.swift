import Foundation

enum ExportService {
    static func tsv(_ items: [ResearchItem]) -> String {
        let header = "Title\tDocument Type\tCollection\tIdentifier\tPublication Date\tContent Type\tRecord URL\tAbstract"
        let rows = items.map { item in
            [item.title, item.documentType, item.collection, item.identifier, item.publicationDate, item.contentType, item.recordURL, item.abstractText]
                .map(clean).joined(separator: "\t")
        }
        return ([header] + rows).joined(separator: "\n") + "\n"
    }

    static func endNote(_ items: [ResearchItem]) -> String {
        items.map { item in
            let type = endNoteType(item)
            var fields = ["%0 \(type)", "%T \(clean(item.title))"]
            append("%J", item.collection, to: &fields)
            append("%8", item.publicationDate, to: &fields)
            append("%U", item.recordURL, to: &fields)
            append("%X", item.abstractText, to: &fields)
            append("%Z", identifierNote(item), to: &fields)
            return fields.joined(separator: "\n")
        }.joined(separator: "\n\n") + "\n"
    }

    static func temporaryFile(name: String, extension ext: String, contents: String) throws -> URL {
        let safe = name.replacingOccurrences(of: #"[^A-Za-z0-9._ -]"#, with: "-", options: .regularExpression)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safe).\(ext)")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func endNoteType(_ item: ResearchItem) -> String {
        if item.contentType == "CIA" || item.recordURL.contains("cia.gov") { return "CIA" }
        let type = item.documentType.lowercased()
        if type.contains("book") { return "Book" }
        if type.contains("report") { return "Report" }
        if item.contentType == "National Archives" { return "Generic" }
        return "Journal Article"
    }

    private static func identifierNote(_ item: ResearchItem) -> String {
        let label: String
        switch item.contentType {
        case "JSTOR": label = "JSTOR Stable ID"
        case "ERIC": label = "ERIC Number"
        case "PubMed": label = "PMID"
        case "National Archives": label = "National Archives Identifier (NAID)"
        default: label = "Document Number"
        }
        return item.identifier.isEmpty ? "" : "\(label): \(item.identifier)"
    }

    private static func append(_ tag: String, _ value: String, to fields: inout [String]) {
        let value = clean(value)
        if !value.isEmpty { fields.append("\(tag) \(value)") }
    }

    private static func clean(_ value: String) -> String {
        value.replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: #"[\r\n]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
