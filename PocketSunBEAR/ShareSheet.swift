import SwiftUI

struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]

    init(_ items: [Any]) { self.items = items }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
