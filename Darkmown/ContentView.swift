import SwiftUI

struct ContentView: View {
    @Binding var document: MarkdownDocument
    @StateObject private var themeObserver = ThemeObserver()
    @State private var isSidebarVisible = true
    @State private var webViewCoordinator: MarkdownWebView.Coordinator?

    private var isDocumentEmpty: Bool {
        let text = document.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty
            || text == "# Welcome to Darkmown\n\nStart writing your markdown here."
                .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var headings: [HeadingItem] {
        HeadingParser.parse(markdown: document.text)
    }

    var body: some View {
        Group {
            if isDocumentEmpty {
                WelcomeView()
                    .frame(minWidth: 600, minHeight: 400)
                    .onDrop(of: [.fileURL], delegate: FileDropDelegate(document: $document))
            } else {
                NavigationSplitView(columnVisibility: sidebarVisibility) {
                    sidebarContent
                } detail: {
                    MarkdownWebView(
                        markdown: document.text,
                        isDarkMode: themeObserver.isDarkMode,
                        onCoordinatorReady: { coordinator in
                            webViewCoordinator = coordinator
                        }
                    )
                    .frame(minWidth: 400, minHeight: 400)
                    .onDrop(of: [.fileURL], delegate: FileDropDelegate(document: $document))
                }
                .navigationSplitViewStyle(.balanced)
            }
        }
        .frame(minWidth: 700, idealWidth: 1000, minHeight: 500, idealHeight: 700)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    NSDocumentController.shared.openDocument(nil)
                }) {
                    Label("Open", systemImage: "doc")
                }
                .help("Open a Markdown file")
            }

            if !isDocumentEmpty {
                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isSidebarVisible.toggle()
                        }
                    }) {
                        Label("Toggle Sidebar", systemImage: "sidebar.left")
                    }
                    .help("Toggle Table of Contents (Cmd+Shift+S)")
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                isSidebarVisible.toggle()
            }
        }
    }

    private var sidebarVisibility: Binding<NavigationSplitViewVisibility> {
        Binding<NavigationSplitViewVisibility>(
            get: { isSidebarVisible ? .all : .detailOnly },
            set: { newValue in
                isSidebarVisible = (newValue != .detailOnly)
            }
        )
    }

    @ViewBuilder
    private var sidebarContent: some View {
        if headings.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "list.bullet")
                    .font(.title2)
                    .foregroundColor(.secondary)
                Text("No headings found")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Contents")
        } else {
            TableOfContents(headings: headings) { heading in
                webViewCoordinator?.scrollToHeading(id: heading.id)
            }
            .navigationTitle("Contents")
        }
    }
}
