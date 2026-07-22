import SwiftUI
import WebKit

struct BrowserView: View {
    let source: ResearchSource
    let onImport: (String, URL) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var webView = WKWebView()
    @State private var currentURL: URL?
    @State private var isReading = false

    var body: some View {
        NavigationStack {
            WebView(webView: webView, source: source, currentURL: $currentURL)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(source.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Import") { importPage() }
                            .disabled(currentURL == nil || isReading)
                    }
                }
        }
    }

    private func importPage() {
        guard let url = currentURL else { return }
        isReading = true
        webView.evaluateJavaScript("document.documentElement.outerHTML") { value, _ in
            isReading = false
            guard let html = value as? String else { return }
            onImport(html, url)
            dismiss()
        }
    }
}

private struct WebView: UIViewRepresentable {
    let webView: WKWebView
    let source: ResearchSource
    @Binding var currentURL: URL?

    func makeCoordinator() -> Coordinator { Coordinator(currentURL: $currentURL) }
    func makeUIView(context: Context) -> WKWebView {
        webView.overrideUserInterfaceStyle = .dark
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: source.homeURL))
        return webView
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var currentURL: URL?
        init(currentURL: Binding<URL?>) { _currentURL = currentURL }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { currentURL = webView.url }
    }
}
