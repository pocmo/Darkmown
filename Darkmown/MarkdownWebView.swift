import SwiftUI
import WebKit

struct MarkdownWebView: NSViewRepresentable {
    let markdown: String
    let isDarkMode: Bool
    var onCoordinatorReady: ((Coordinator) -> Void)?

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        context.coordinator.webView = webView
        context.coordinator.loadTemplate(in: webView)

        DispatchQueue.main.async {
            onCoordinatorReady?(context.coordinator)
        }

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.updateMarkdown(markdown, isDarkMode: isDarkMode)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
        private var isLoaded = false
        private var pendingMarkdown: String?
        private var pendingIsDark: Bool = false

        func loadTemplate(in webView: WKWebView) {
            webView.navigationDelegate = self
            guard let templateURL = Bundle.main.url(forResource: "markdown-template", withExtension: "html") else {
                return
            }
            webView.loadFileURL(templateURL, allowingReadAccessTo: templateURL.deletingLastPathComponent())
        }

        func updateMarkdown(_ markdown: String, isDarkMode: Bool) {
            if isLoaded {
                renderMarkdown(markdown, isDarkMode: isDarkMode)
            } else {
                pendingMarkdown = markdown
                pendingIsDark = isDarkMode
            }
        }

        private func renderMarkdown(_ markdown: String, isDarkMode: Bool) {
            let escaped = markdown
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")
            let js = "renderMarkdown(`\(escaped)`, \(isDarkMode));"
            webView?.evaluateJavaScript(js, completionHandler: nil)
        }

        /// Scrolls the WebView to a heading with the given id attribute.
        func scrollToHeading(id: String) {
            let escapedId = id
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
            let js = "scrollToHeading('\(escapedId)');"
            webView?.evaluateJavaScript(js, completionHandler: nil)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoaded = true
            if let markdown = pendingMarkdown {
                renderMarkdown(markdown, isDarkMode: pendingIsDark)
                pendingMarkdown = nil
            }
        }
    }
}
