import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ResearchSession.createdAt, order: .reverse) private var sessions: [ResearchSession]
    @State private var selectedSource = ResearchSource.cia
    @State private var showingBrowser = false
    @State private var pendingImport: (html: String, url: URL)?
    @State private var scraper = ScrapeCoordinator()
    @State private var requestedPageCount = 1
    @State private var shouldDownloadPDFs = true

    var body: some View {
        TabView {
            NavigationStack {
                Form {
                    Section("New metadata scrape") {
                        Picker("Source", selection: $selectedSource) {
                            ForEach(ResearchSource.allCases) { Text($0.title).tag($0) }
                        }
                        Button { showingBrowser = true } label: {
                            Label("Open \(selectedSource.title)", systemImage: "safari")
                        }
                        Stepper("Search pages: \(requestedPageCount)", value: $requestedPageCount, in: 1...ScrapeCoordinator.maximumSearchPages)
                        Toggle("Download available PDFs", isOn: $shouldDownloadPDFs)
                        Text("Open-access PDFs download automatically. Login or publisher-only files remain available through the source record.")
                            .font(.caption).foregroundStyle(.secondary)
                        Text("Search the source, then tap Import. Pocket sunBEAR saves metadata and, when enabled, downloads accessible PDFs.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    if scraper.isRunning || scraper.completed > 0 {
                        Section("Import") {
                            if scraper.isRunning { ProgressView(value: Double(scraper.completed), total: Double(max(scraper.total, 1))) }
                            Text(scraper.status).font(.footnote)
                        }
                    }
                    Section("Recent sessions") {
                        if sessions.isEmpty { ContentUnavailableView("No research yet", systemImage: "books.vertical") }
                        ForEach(sessions.prefix(5)) { SessionLink(session: $0) }
                    }
                }
                .navigationTitle("Pocket sunBEAR")
            }
            .tabItem { Label("Research", systemImage: "magnifyingglass") }

            NavigationStack { LibraryView() }
                .tabItem { Label("Library", systemImage: "books.vertical") }

            NavigationStack { DownloadsView() }
                .tabItem { Label("Downloads", systemImage: "arrow.down.doc.fill") }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingBrowser) {
            BrowserView(source: selectedSource) { html, url in pendingImport = (html, url) }
                .preferredColorScheme(.dark)
        }
        .onChange(of: pendingImport?.url) { _, _ in
            guard let pendingImport else { return }
            self.pendingImport = nil
            Task { await scraper.importSearch(html: pendingImport.html, url: pendingImport.url, source: selectedSource, pageLimit: requestedPageCount, downloadPDFs: shouldDownloadPDFs, context: context) }
        }
    }
}

private struct DownloadedPDF: Identifiable {
    let path: String
    let title: String
    let source: String
    var id: String { path }
    var url: URL? { PDFDownloadService.fileURL(for: path) }
}

private struct DownloadsView: View {
    @Query private var items: [ResearchItem]
    @State private var search = ""
    @State private var sharePayload: SharePayload?

    private var downloads: [DownloadedPDF] {
        items.flatMap { item in
            item.localPDFPaths.map { DownloadedPDF(path: $0, title: item.title, source: item.contentType) }
        }
        .filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.path.localizedCaseInsensitiveContains(search) || $0.source.localizedCaseInsensitiveContains(search) }
        .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        List {
            Section {
                Label("Also available in Files → On My iPhone → Pocket sunBEAR → Pocket sunBEAR PDFs", systemImage: "folder")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(downloads) { download in
                Button { share(download) } label: {
                    HStack {
                        Image(systemName: "doc.richtext.fill").foregroundStyle(.red)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(download.title).foregroundStyle(.primary).lineLimit(2)
                            Text("\(download.source) · \((download.path as NSString).lastPathComponent)")
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
            }
        }
        .overlay { if downloads.isEmpty { ContentUnavailableView(search.isEmpty ? "No PDFs downloaded" : "No matching PDFs", systemImage: "arrow.down.doc") } }
        .navigationTitle("Downloads")
        .searchable(text: $search, prompt: "Title, source, or filename")
        .toolbar {
            if !downloads.isEmpty {
                Button { sharePayload = SharePayload(downloads.compactMap(\.url)) } label: {
                    Label("Share All", systemImage: "square.and.arrow.up")
                }
            }
        }
        .sheet(item: $sharePayload) { ShareSheet(items: $0.items) }
    }

    private func share(_ download: DownloadedPDF) {
        guard let url = download.url else { return }
        sharePayload = SharePayload([url])
    }
}

private enum LibrarySort: String, CaseIterable, Identifiable {
    case newest, oldest, name, records
    var id: Self { self }
    var title: String { rawValue.capitalized }
}

private struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ResearchSession.createdAt, order: .reverse) private var sessions: [ResearchSession]
    @Query(sort: \LibraryCollection.name) private var collections: [LibraryCollection]
    @State private var search = ""
    @State private var sort = LibrarySort.newest
    @State private var showingNewCollection = false
    @State private var newCollectionName = ""
    @State private var renamingSession: ResearchSession?
    @State private var renameText = ""

    private var displayedSessions: [ResearchSession] {
        let filtered = search.isEmpty ? sessions : sessions.filter { session in
            session.name.localizedCaseInsensitiveContains(search) ||
            session.sourceName.localizedCaseInsensitiveContains(search) ||
            session.items.contains { $0.title.localizedCaseInsensitiveContains(search) || $0.collection.localizedCaseInsensitiveContains(search) || $0.identifier.localizedCaseInsensitiveContains(search) }
        }
        switch sort {
        case .newest: return filtered.sorted { $0.createdAt > $1.createdAt }
        case .oldest: return filtered.sorted { $0.createdAt < $1.createdAt }
        case .name: return filtered.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .records: return filtered.sorted { $0.items.count > $1.items.count }
        }
    }

    var body: some View {
        List {
            ForEach(collections) { collection in
                DisclosureGroup {
                    let members = displayedSessions.filter { $0.libraryCollection?.persistentModelID == collection.persistentModelID }
                    if members.isEmpty { Text("No matching sessions").font(.caption).foregroundStyle(.secondary) }
                    ForEach(members) { session in
                        SessionLink(session: session)
                            .swipeActions {
                                Button(role: .destructive) { context.delete(session) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                } label: {
                    Label("\(collection.name) (\(collection.sessions.count))", systemImage: "folder.fill")
                }
                .contextMenu {
                    Button("Delete Collection", role: .destructive) { context.delete(collection) }
                }
            }
            let unfiled = displayedSessions.filter { $0.libraryCollection == nil }
            if !unfiled.isEmpty {
                Section("Unfiled") {
                    ForEach(unfiled) { session in
                        SessionLink(session: session)
                            .swipeActions {
                                Button(role: .destructive) { context.delete(session) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .overlay { if sessions.isEmpty { ContentUnavailableView("Library is empty", systemImage: "books.vertical") } }
        .navigationTitle("Library")
        .searchable(text: $search, prompt: "Sessions, titles, identifiers")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Picker("Sort", selection: $sort) { ForEach(LibrarySort.allCases) { Text($0.title).tag($0) } }
                } label: { Label("Sort", systemImage: "arrow.up.arrow.down") }
                Button { showingNewCollection = true } label: { Label("New Collection", systemImage: "folder.badge.plus") }
            }
        }
        .alert("New collection", isPresented: $showingNewCollection) {
            TextField("Collection name", text: $newCollectionName)
            Button("Cancel", role: .cancel) { newCollectionName = "" }
            Button("Create") { createCollection() }.disabled(newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .alert("Rename session", isPresented: Binding(get: { renamingSession != nil }, set: { if !$0 { renamingSession = nil } })) {
            TextField("Session name", text: $renameText)
            Button("Cancel", role: .cancel) { renamingSession = nil }
            Button("Rename") { renamingSession?.name = renameText.trimmingCharacters(in: .whitespacesAndNewlines); renamingSession = nil }
        }
    }

    private func createCollection() {
        context.insert(LibraryCollection(name: newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines)))
        newCollectionName = ""
    }
}

private struct SessionLink: View {
    let session: ResearchSession
    private var pdfCount: Int { session.items.reduce(0) { $0 + $1.localPDFPaths.count } }
    var body: some View {
        NavigationLink { SessionView(session: session) } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(session.name).lineLimit(2)
                Text("\(session.sourceName) · \(session.items.count) records · \(session.pagesScraped) page\(session.pagesScraped == 1 ? "" : "s")")
                    .font(.caption).foregroundStyle(.secondary)
                if pdfCount > 0 {
                    Label("\(pdfCount) PDF\(pdfCount == 1 ? "" : "s")", systemImage: "arrow.down.doc.fill")
                        .font(.caption2).foregroundStyle(.green)
                }
                Text(session.createdAt, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }
}

private struct SessionView: View {
    let session: ResearchSession
    @Query(sort: \LibraryCollection.name) private var collections: [LibraryCollection]
    @State private var recordSearch = ""
    @State private var sharePayload: SharePayload?
    @State private var exportError: String?
    @State private var showingRename = false
    @State private var renameText = ""

    private var items: [ResearchItem] {
        session.items.filter { recordSearch.isEmpty || $0.title.localizedCaseInsensitiveContains(recordSearch) || $0.identifier.localizedCaseInsensitiveContains(recordSearch) || $0.collection.localizedCaseInsensitiveContains(recordSearch) || $0.abstractText.localizedCaseInsensitiveContains(recordSearch) }.sorted { $0.title < $1.title }
    }

    var body: some View {
        List(items) { item in
            NavigationLink { ItemView(item: item) } label: {
                VStack(alignment: .leading) { Text(item.title); Text(item.collection).font(.caption).foregroundStyle(.secondary) }
            }
        }
        .overlay { if items.isEmpty { ContentUnavailableView("No matching records", systemImage: "doc.text.magnifyingglass") } }
        .navigationTitle(session.name)
        .searchable(text: $recordSearch, prompt: "Title, identifier, or text")
        .toolbar {
            Menu {
                Button("Rename Session") { renameText = session.name; showingRename = true }
                Menu("Move to Collection") {
                    Button("Unfiled") { session.libraryCollection = nil }
                    ForEach(collections) { collection in Button(collection.name) { session.libraryCollection = collection } }
                }
                Divider()
                Button("Share EndNote File") { share(kind: "EndNote") }
                Button("Share TSV File") { share(kind: "TSV") }
            } label: { Label("Session Actions", systemImage: "ellipsis.circle") }
        }
        .alert("Rename session", isPresented: $showingRename) {
            TextField("Session name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Rename") { session.name = renameText.trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        .sheet(item: $sharePayload) { ShareSheet(items: $0.items) }
        .alert("Could not create export", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("OK") { exportError = nil }
        } message: { Text(exportError ?? "Unknown export error") }
    }

    private func share(kind: String) {
        do {
            let url = kind == "EndNote" ? try ExportService.temporaryFile(name: session.name, extension: "enw", contents: ExportService.endNote(session.items)) : try ExportService.temporaryFile(name: session.name, extension: "tsv", contents: ExportService.tsv(session.items))
            sharePayload = SharePayload([url])
        } catch { exportError = error.localizedDescription }
    }
}

private struct ItemView: View {
    let item: ResearchItem
    @State private var sharePayload: SharePayload?

    private var pdfFiles: [URL] { item.localPDFPaths.compactMap(PDFDownloadService.fileURL(for:)) }
    var body: some View {
        Form {
            Section { LabeledContent("Identifier", value: item.identifier); LabeledContent("Type", value: item.documentType); LabeledContent("Collection", value: item.collection); LabeledContent("Date", value: item.publicationDate) }
            if !pdfFiles.isEmpty {
                Section("PDFs") {
                    ForEach(pdfFiles, id: \.path) { file in
                        Button { sharePayload = SharePayload([file]) } label: {
                            Label(file.lastPathComponent, systemImage: "doc.richtext")
                        }
                    }
                    if pdfFiles.count > 1 {
                        Button("Share All PDFs") { sharePayload = SharePayload(pdfFiles) }
                    }
                }
            } else if !item.pdfDownloadError.isEmpty {
                Section("PDF") {
                    Label("Automatic download unavailable", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text(item.pdfDownloadError).font(.caption).foregroundStyle(.secondary)
                }
            }
            if !item.abstractText.isEmpty { Section("Abstract / description") { Text(item.abstractText).textSelection(.enabled) } }
            if let url = URL(string: item.recordURL) { Section { Link(pdfFiles.isEmpty ? "Open source record to check access" : "Open source record", destination: url) } }
        }
        .navigationTitle(item.title).navigationBarTitleDisplayMode(.inline)
        .sheet(item: $sharePayload) { ShareSheet(items: $0.items) }
    }
}
