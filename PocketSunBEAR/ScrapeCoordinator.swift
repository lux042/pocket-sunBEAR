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
    private let pdfDownloader = PDFDownloadService()

    func importSearch(html: String, url: URL, source: ResearchSource, pageLimit: Int, downloadPDFs: Bool, context: ModelContext) async {
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
                if source == .pubmed,
                   let pmcURL = PubMedHTMLParser.pmcArticleURL(in: detailHTML, baseURL: finalURL),
                   let (pmcHTML, pmcFinalURL) = try? await loader.html(at: pmcURL) {
                    document.pdfURLs.append(contentsOf: PubMedHTMLParser.pdfURLs(in: pmcHTML, baseURL: pmcFinalURL))
                    document.pdfURLs = Array(Set(document.pdfURLs)).sorted { $0.absoluteString < $1.absoluteString }
                }
                let item = ResearchItem(document: document, session: session)
                context.insert(item)
                if downloadPDFs, !document.pdfURLs.isEmpty {
                    status = "Downloading PDF for \(completed + 1) of \(total)…"
                    let result = await pdfDownloader.download(document.pdfURLs, title: item.title, identifier: item.identifier, sessionName: session.name, source: item.contentType, referer: finalURL)
                    item.localPDFPaths = result.paths
                    item.pdfDownloadError = result.errors.joined(separator: "\n")
                    if !result.paths.isEmpty {
                        item.pdfVerificationStatus = "Verified with PDFKit"
                    }
                }
                completed += 1
            } catch {
                status = "Skipped one record: \(error.localizedDescription)"
            }
        }
        try? context.save()
        let pdfCount = session.items.reduce(0) { $0 + $1.localPDFPaths.count }
        status = downloadPDFs
            ? "Saved \(completed) records and \(pdfCount) PDF\(pdfCount == 1 ? "" : "s")."
            : "Saved \(completed) metadata records."
    }
}
