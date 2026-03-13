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

    class Coordinator: NSObject, WKNavigationDelegate, ObservableObject {
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

        // MARK: - Search

        func performSearch(_ query: String, completion: ((Int, Int) -> Void)? = nil) {
            let escaped = query
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
            let js = "performSearch('\(escaped)');"
            webView?.evaluateJavaScript(js) { result, _ in
                self.parseSearchResult(result, completion: completion)
            }
        }

        func searchNext(completion: ((Int, Int) -> Void)? = nil) {
            webView?.evaluateJavaScript("searchNext();") { result, _ in
                self.parseSearchResult(result, completion: completion)
            }
        }

        func searchPrevious(completion: ((Int, Int) -> Void)? = nil) {
            webView?.evaluateJavaScript("searchPrevious();") { result, _ in
                self.parseSearchResult(result, completion: completion)
            }
        }

        func clearSearch() {
            webView?.evaluateJavaScript("clearSearch();", completionHandler: nil)
        }

        private func parseSearchResult(_ result: Any?, completion: ((Int, Int) -> Void)?) {
            guard let jsonString = result as? String,
                  let data = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let total = json["total"] as? Int,
                  let current = json["current"] as? Int else {
                completion?(0, 0)
                return
            }
            completion?(current, total)
        }

        // MARK: - Zoom

        func zoomIn() {
            webView?.evaluateJavaScript("zoomIn();", completionHandler: nil)
        }

        func zoomOut() {
            webView?.evaluateJavaScript("zoomOut();", completionHandler: nil)
        }

        func zoomReset() {
            webView?.evaluateJavaScript("zoomReset();", completionHandler: nil)
        }

        // MARK: - Scroll

        func scrollToTop() {
            webView?.evaluateJavaScript("scrollToTop();", completionHandler: nil)
        }

        func scrollToBottom() {
            webView?.evaluateJavaScript("scrollToBottom();", completionHandler: nil)
        }

        // MARK: - Print

        func printContent() {
            guard let webView = webView else { return }
            let printInfo = NSPrintInfo.shared
            printInfo.horizontalPagination = .fit
            printInfo.verticalPagination = .automatic
            printInfo.isHorizontallyCentered = true
            printInfo.isVerticallyCentered = false
            printInfo.topMargin = 36
            printInfo.bottomMargin = 36
            printInfo.leftMargin = 36
            printInfo.rightMargin = 36

            let printOperation = webView.printOperation(with: printInfo)
            printOperation.showsPrintPanel = true
            printOperation.showsProgressPanel = true
            printOperation.run()
        }

        // MARK: - Export HTML

        func getRenderedHTML(completion: @escaping (String?) -> Void) {
            webView?.evaluateJavaScript("document.documentElement.outerHTML;") { result, _ in
                completion(result as? String)
            }
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
