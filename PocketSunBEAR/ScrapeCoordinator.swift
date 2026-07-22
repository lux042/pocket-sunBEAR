import Foundation
import SwiftData

@MainActor
@Observable
final class ScrapeCoordinator {
    var isRunning = false
    var status = "Ready"
    var completed = 0
    var total = 0
    private let loader = WebLoader()

    func importSearch(html: String, url: URL, source: ResearchSource, context: ModelContext) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }
        let links = source.resultLinks(in: html, baseURL: url)
        total = links.count
        completed = 0
        guard !links.isEmpty else { status = "No records found on this page."; return }
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { ["q", "term", "Query", "keyword"].contains($0.name) })?.value
        let name = "\(source.title) – \(query?.isEmpty == false ? query! : "Search")"
        let session = ResearchSession(name: name, sourceName: source.title, searchURL: url.absoluteString)
        context.insert(session)

        for link in links {
            status = "Reading \(completed + 1) of \(total)…"
            do {
                let (detailHTML, finalURL) = try await loader.html(at: link)
                var document = source.document(from: detailHTML, url: finalURL)
                document.pdfURLs = []
                let item = ResearchItem(document: document, session: session)
                context.insert(item)
                completed += 1
            } catch {
                status = "Skipped one record: \(error.localizedDescription)"
            }
        }
        try? context.save()
        status = "Saved \(completed) metadata records."
    }
}
