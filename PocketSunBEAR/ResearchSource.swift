import Foundation

enum ResearchSource: String, CaseIterable, Identifiable, Codable {
    case cia, jstor, eric, pubmed, nara
    var id: Self { self }

    var title: String {
        switch self {
        case .cia: "CIA FOIA"
        case .jstor: "JSTOR"
        case .eric: "ERIC"
        case .pubmed: "PubMed"
        case .nara: "National Archives"
        }
    }

    var homeURL: URL {
        switch self {
        case .cia: URL(string: "https://www.cia.gov/readingroom/advanced-search-view")!
        case .jstor: URL(string: "https://www.jstor.org/")!
        case .eric: URL(string: "https://eric.ed.gov/")!
        case .pubmed: URL(string: "https://pubmed.ncbi.nlm.nih.gov/")!
        case .nara: URL(string: "https://catalog.archives.gov/")!
        }
    }

    func resultLinks(in html: String, baseURL: URL) -> [URL] {
        switch self {
        case .cia: CIAHTMLParser.resultLinks(in: html, baseURL: baseURL)
        case .jstor: JSTORHTMLParser.resultLinks(in: html, baseURL: baseURL)
        case .eric: ERICHTMLParser.resultLinks(in: html, baseURL: baseURL)
        case .pubmed: PubMedHTMLParser.resultLinks(in: html, baseURL: baseURL)
        case .nara: NARAHTMLParser.resultLinks(in: html, baseURL: baseURL)
        }
    }

    func document(from html: String, url: URL) -> ScrapedDocument {
        switch self {
        case .cia: CIAHTMLParser.document(from: html, url: url)
        case .jstor: JSTORHTMLParser.document(from: html, url: url)
        case .eric: ERICHTMLParser.document(from: html, url: url)
        case .pubmed: PubMedHTMLParser.document(from: html, url: url)
        case .nara: NARAHTMLParser.document(from: html, url: url)
        }
    }
}
