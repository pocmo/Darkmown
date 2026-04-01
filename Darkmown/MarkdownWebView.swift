import SwiftUI
import WebKit

struct MarkdownWebView: NSViewRepresentable {
    let markdown: String
    let isDarkMode: Bool
    var fileURL: URL?
    var onCoordinatorReady: ((Coordinator) -> Void)?

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        context.coordinator.webView = webView
        context.coordinator.fileURL = fileURL
        context.coordinator.loadTemplate(in: webView, fileURL: fileURL)

        DispatchQueue.main.async {
            onCoordinatorReady?(context.coordinator)
        }

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.fileURL = fileURL
        context.coordinator.updateMarkdown(markdown, isDarkMode: isDarkMode)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, WKNavigationDelegate, ObservableObject {
        weak var webView: WKWebView?
        var fileURL: URL?
        private var isLoaded = false
        private var pendingMarkdown: String?
        private var pendingIsDark: Bool = false

        func loadTemplate(in webView: WKWebView, fileURL: URL?) {
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
            let processed = embedLocalImages(in: markdown)
            let escaped = processed
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")
            let js = "renderMarkdown(`\(escaped)`, \(isDarkMode));"
            webView?.evaluateJavaScript(js, completionHandler: nil)
        }

        /// Replaces relative image paths in markdown with base64 data URIs
        /// so that WKWebView can display them without file system access.
        private func embedLocalImages(in markdown: String) -> String {
            guard let fileDir = fileURL?.deletingLastPathComponent() else {
                print("[Darkmown] embedLocalImages: fileURL is nil, skipping")
                return markdown
            }
            print("[Darkmown] embedLocalImages: fileDir = \(fileDir.path)")

            let pattern = #"!\[([^\]]*)\]\(([^)]+)\)"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return markdown }

            let nsString = markdown as NSString
            let matches = regex.matches(in: markdown, range: NSRange(location: 0, length: nsString.length))

            var result = markdown
            // Process matches in reverse so replacements don't shift ranges
            for match in matches.reversed() {
                let pathRange = match.range(at: 2)
                let path = nsString.substring(with: pathRange)

                // Skip absolute URLs and data URIs
                if path.hasPrefix("http://") || path.hasPrefix("https://") || path.hasPrefix("data:") {
                    continue
                }

                let imageURL = fileDir.appendingPathComponent(path)
                print("[Darkmown] Trying to load image: \(imageURL.path)")
                guard let data = try? Data(contentsOf: imageURL) else {
                    print("[Darkmown] Failed to read image at: \(imageURL.path)")
                    continue
                }
                print("[Darkmown] Successfully loaded image: \(data.count) bytes")

                let ext = imageURL.pathExtension.lowercased()
                let mimeType: String
                switch ext {
                case "png": mimeType = "image/png"
                case "jpg", "jpeg": mimeType = "image/jpeg"
                case "gif": mimeType = "image/gif"
                case "svg": mimeType = "image/svg+xml"
                case "webp": mimeType = "image/webp"
                default: mimeType = "application/octet-stream"
                }

                let base64 = data.base64EncodedString()
                let dataURI = "data:\(mimeType);base64,\(base64)"

                let fullRange = match.range(at: 0)
                let altRange = match.range(at: 1)
                let altText = nsString.substring(with: altRange)
                let replacement = "![\(altText)](\(dataURI))"
                result = (result as NSString).replacingCharacters(in: fullRange, with: replacement)
            }

            return result
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
