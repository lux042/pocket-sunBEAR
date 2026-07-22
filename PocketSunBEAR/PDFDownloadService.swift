import Foundation
import WebKit

struct PDFDownloadService {
    enum DownloadError: LocalizedError {
        case invalidResponse
        case notPDF

        var errorDescription: String? {
            switch self {
            case .invalidResponse: "The source returned an invalid response."
            case .notPDF: "The source returned a webpage instead of a PDF; login or publisher access may be required."
            }
        }
    }

    func download(_ urls: [URL], title: String, identifier: String, sessionName: String, referer: URL) async -> (paths: [String], errors: [String]) {
        guard !urls.isEmpty else { return ([], []) }
        let cookies = await websiteCookies()
        var paths: [String] = []
        var errors: [String] = []

        for (index, url) in urls.enumerated() {
            do {
                var request = URLRequest(url: url)
                request.setValue(referer.absoluteString, forHTTPHeaderField: "Referer")
                request.setValue("application/pdf,application/octet-stream;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
                let matching = cookies.filter { cookie in
                    url.host?.hasSuffix(cookie.domain.trimmingCharacters(in: CharacterSet(charactersIn: "."))) == true
                }
                HTTPCookie.requestHeaderFields(with: matching).forEach { request.setValue($1, forHTTPHeaderField: $0) }

                let (temporaryURL, response) = try await URLSession.shared.download(for: request)
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { throw DownloadError.invalidResponse }
                guard isPDF(at: temporaryURL) else { throw DownloadError.notPDF }

                let relativePath = try save(temporaryURL, title: title, identifier: identifier, sessionName: sessionName, index: index)
                paths.append(relativePath)
            } catch {
                errors.append("\(url.host ?? "Source"): \(error.localizedDescription)")
            }
        }
        return (paths, errors)
    }

    static func fileURL(for relativePath: String) -> URL? {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let url = documents.appendingPathComponent(relativePath)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private func save(_ temporaryURL: URL, title: String, identifier: String, sessionName: String, index: Int) throws -> String {
        let manager = FileManager.default
        let documents = manager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let root = documents.appendingPathComponent("Pocket sunBEAR PDFs", isDirectory: true)
        let sessionFolder = safeFilename(sessionName)
        let folder = root.appendingPathComponent(sessionFolder, isDirectory: true)
        try manager.createDirectory(at: folder, withIntermediateDirectories: true)
        let base = safeFilename(identifier.isEmpty ? title : identifier)
        let suffix = index == 0 ? "" : "-\(index + 1)"
        var destination = folder.appendingPathComponent("\(base)\(suffix).pdf")
        var duplicate = 2
        while manager.fileExists(atPath: destination.path) {
            destination = folder.appendingPathComponent("\(base)\(suffix)-\(duplicate).pdf")
            duplicate += 1
        }
        try manager.moveItem(at: temporaryURL, to: destination)
        return "Pocket sunBEAR PDFs/\(sessionFolder)/\(destination.lastPathComponent)"
    }

    private func isPDF(at url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        return (try? handle.read(upToCount: 5)) == Data("%PDF-".utf8)
    }

    private func safeFilename(_ value: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:?%*|\"<>\n\r\t")
        let cleaned = value.components(separatedBy: forbidden).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String((cleaned.isEmpty ? "document" : cleaned).prefix(100))
    }

    @MainActor private func websiteCookies() async -> [HTTPCookie] {
        await withCheckedContinuation { continuation in
            WKWebsiteDataStore.default().httpCookieStore.getAllCookies { continuation.resume(returning: $0) }
        }
    }
}
