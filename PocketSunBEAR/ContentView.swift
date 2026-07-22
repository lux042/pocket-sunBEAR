import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ResearchSession.createdAt, order: .reverse) private var sessions: [ResearchSession]
    @State private var selectedSource = ResearchSource.cia
    @State private var showingBrowser = false
    @State private var pendingImport: (html: String, url: URL)?
    @State private var scraper = ScrapeCoordinator()

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
                        Text("Search on the source website, then tap Import. Pocket sunBEAR saves metadata only—no PDFs.")
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

            NavigationStack {
                List {
                    ForEach(sessions) { SessionLink(session: $0) }
                    .onDelete { offsets in offsets.map { sessions[$0] }.forEach(context.delete) }
                }
                .overlay { if sessions.isEmpty { ContentUnavailableView("Library is empty", systemImage: "books.vertical") } }
                .navigationTitle("Library")
            }
            .tabItem { Label("Library", systemImage: "books.vertical") }
        }
        .sheet(isPresented: $showingBrowser) {
            BrowserView(source: selectedSource) { html, url in pendingImport = (html, url) }
        }
        .onChange(of: pendingImport?.url) { _, _ in
            guard let pendingImport else { return }
            self.pendingImport = nil
            Task { await scraper.importSearch(html: pendingImport.html, url: pendingImport.url, source: selectedSource, context: context) }
        }
    }
}

private struct SessionLink: View {
    let session: ResearchSession
    var body: some View {
        NavigationLink {
            SessionView(session: session)
        } label: {
            VStack(alignment: .leading) {
                Text(session.name).lineLimit(1)
                Text("\(session.items.count) records · \(session.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct SessionView: View {
    let session: ResearchSession
    @State private var shareItems: [Any] = []
    @State private var showingShare = false

    var body: some View {
        List(session.items.sorted { $0.title < $1.title }) { item in
            NavigationLink {
                ItemView(item: item)
            } label: {
                VStack(alignment: .leading) {
                    Text(item.title)
                    Text(item.collection).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(session.name)
        .toolbar {
            Menu {
                Button("EndNote file") { share(kind: "EndNote") }
                Button("TSV file") { share(kind: "TSV") }
            } label: { Label("Export", systemImage: "square.and.arrow.up") }
        }
        .sheet(isPresented: $showingShare) { ShareSheet(items: shareItems) }
    }

    private func share(kind: String) {
        do {
            let url = kind == "EndNote"
                ? try ExportService.temporaryFile(name: session.name, extension: "enw", contents: ExportService.endNote(session.items))
                : try ExportService.temporaryFile(name: session.name, extension: "tsv", contents: ExportService.tsv(session.items))
            shareItems = [url]
            showingShare = true
        } catch {}
    }
}

private struct ItemView: View {
    let item: ResearchItem
    var body: some View {
        Form {
            Section { LabeledContent("Identifier", value: item.identifier); LabeledContent("Type", value: item.documentType); LabeledContent("Collection", value: item.collection); LabeledContent("Date", value: item.publicationDate) }
            if !item.abstractText.isEmpty { Section("Abstract / description") { Text(item.abstractText) } }
            if let url = URL(string: item.recordURL) { Section { Link("Open source record", destination: url) } }
        }
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
