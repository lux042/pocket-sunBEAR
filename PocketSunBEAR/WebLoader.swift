import Foundation
import WebKit

@MainActor
final class WebLoader: NSObject, WKNavigationDelegate {
    enum LoadError: Error { case noHTML }
    private var continuation: CheckedContinuation<(String, URL), Error>?
    private var webView: WKWebView?

    func html(at url: URL) async throws -> (String, URL) {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let view = WKWebView(frame: .zero, configuration: configuration)
        webView = view
        view.navigationDelegate = self
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            view.load(URLRequest(url: url))
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            webView.evaluateJavaScript("document.documentElement.outerHTML") { value, error in
                guard let continuation = self.continuation else { return }
                self.continuation = nil
                self.webView = nil
                if let error { continuation.resume(throwing: error) }
                else if let html = value as? String, let url = webView.url { continuation.resume(returning: (html, url)) }
                else { continuation.resume(throwing: LoadError.noHTML) }
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finish(error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { finish(error) }
    private func finish(_ error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
        webView = nil
    }
}
