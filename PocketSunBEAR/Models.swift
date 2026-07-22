import Foundation
import SwiftData

@Model
final class LibraryCollection {
    var name: String
    var createdAt: Date
    @Relationship(deleteRule: .nullify, inverse: \ResearchSession.libraryCollection) var sessions: [ResearchSession]

    init(name: String, createdAt: Date = .now, sessions: [ResearchSession] = []) {
        self.name = name
        self.createdAt = createdAt
        self.sessions = sessions
    }
}

@Model
final class ResearchSession {
    var name: String
    var sourceName: String
    var searchURL: String
    var createdAt: Date
    var pagesScraped: Int = 1
    var libraryCollection: LibraryCollection?
    @Relationship(deleteRule: .cascade, inverse: \ResearchItem.session) var items: [ResearchItem]

    init(name: String, sourceName: String, searchURL: String, createdAt: Date = .now, pagesScraped: Int = 1, items: [ResearchItem] = [], libraryCollection: LibraryCollection? = nil) {
        self.name = name
        self.sourceName = sourceName
        self.searchURL = searchURL
        self.createdAt = createdAt
        self.pagesScraped = pagesScraped
        self.items = items
        self.libraryCollection = libraryCollection
    }
}

@Model
final class ResearchItem {
    var title: String
    var documentType: String
    var collection: String
    var identifier: String
    var publicationDate: String
    var contentType: String
    var recordURL: String
    var abstractText: String
    var pageCount: Int
    var localPDFPaths: [String] = []
    var pdfDownloadError: String = ""
    var pdfVerificationStatus: String = ""
    var session: ResearchSession?

    init(document: ScrapedDocument, session: ResearchSession? = nil) {
        let fields = document.fields
        title = document.title
        documentType = fields["Document Type"] ?? ""
        collection = fields["Collection"] ?? ""
        identifier = fields["Document Number (FOIA) /ESDN (CREST)"] ?? ""
        publicationDate = fields["Publication Date"] ?? ""
        contentType = fields["Content Type"] ?? ""
        recordURL = document.recordURL.absoluteString
        abstractText = document.body
        pageCount = Int(fields["Document Page Count"] ?? "") ?? 0
        self.session = session
    }
}
