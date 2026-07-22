import Foundation
import Testing
@testable import PocketSunBEAR

struct PocketSunBEARTests {
    @Test func nationalArchivesLinks() throws {
        let base = try #require(URL(string: "https://catalog.archives.gov/search?page=1&q=history"))
        #expect(NARAHTMLParser.resultLinks(in: #"<a href="/id/123">Record</a>"#, baseURL: base).first?.absoluteString == "https://catalog.archives.gov/id/123")
    }
}
