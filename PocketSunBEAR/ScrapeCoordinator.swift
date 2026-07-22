import Foundation
import SwiftData

@MainActor
@Observable
final class ScrapeCoordinator {
    static let maximumSearchPages = 10
    var isRunning = false
    var status = "Ready"
    var completed = 0
    var total = 0
    private let loader = WebLoader()

    func importSearch(html: String, url: URL, source: ResearchSource, pageLimit: Int, context: ModelContext) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }
        let limit = min(max(pageLimit, 1), Self.maximumSearchPages)
        var pageHTML = html
        var pageURL = url
        var visitedPages = Set<URL>()
        var links: [URL] = []
        var seenLinks = Set<URL>()

        while visitedPages.count < limit, visitedPages.insert(pageURL).inserted {
            status = "Reading search page \(visitedPages.count) of \(limit)…"
            for link in source.resultLinks(in: pageHTML, baseURL: pageURL) where seenLinks.insert(link).inserted {
                links.append(link)
            }
            guard visitedPages.count < limit,
                  let nextURL = source.nextPage(in: pageHTML, baseURL: pageURL),
                  !visitedPages.contains(nextURL) else { break }
            do {
                let (nextHTML, finalURL) = try await loader.html(at: nextURL)
                pageHTML = nextHTML
                pageURL = finalURL
            } catch {
                status = "Stopped after page \(visitedPages.count): \(error.localizedDescription)"
                break
            }
        }

        total = links.count
        completed = 0
        guard !links.isEmpty else { status = "No records found on this page."; return }
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { ["q", "term", "Query", "keyword"].contains($0.name) })?.value
        let name = "\(source.title) – \(query?.isEmpty == false ? query! : "Search")"
        let session = ResearchSession(name: name, sourceName: source.title, searchURL: url.absoluteString, pagesScraped: visitedPages.count)
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
