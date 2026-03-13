import SwiftUI

struct ContentView: View {
    @Binding var document: MarkdownDocument
    @StateObject private var themeObserver = ThemeObserver()

    var body: some View {
        MarkdownWebView(markdown: document.text, isDarkMode: themeObserver.isDarkMode)
            .frame(minWidth: 600, minHeight: 400)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        NSDocumentController.shared.openDocument(nil)
                    }) {
                        Label("Open", systemImage: "doc")
                    }
                    .help("Open a Markdown file")
                }
            }
            .onDrop(of: [.fileURL], delegate: FileDropDelegate(document: $document))
    }
}
