import SwiftUI

struct ContentView: View {
    @Binding var document: MarkdownDocument
    @StateObject private var themeObserver = ThemeObserver()
    @State private var isSidebarVisible = true
    @State private var webViewCoordinator: MarkdownWebView.Coordinator?

    // Search state
    @State private var isSearchVisible = false
    @State private var searchQuery = ""
    @State private var searchCurrent = 0
    @State private var searchTotal = 0
    @FocusState private var isSearchFieldFocused: Bool

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
                    ZStack(alignment: .top) {
                        MarkdownWebView(
                            markdown: document.text,
                            isDarkMode: themeObserver.isDarkMode,
                            onCoordinatorReady: { coordinator in
                                webViewCoordinator = coordinator
                            }
                        )
                        .frame(minWidth: 400, minHeight: 400)
                        .onDrop(of: [.fileURL], delegate: FileDropDelegate(document: $document))

                        if isSearchVisible {
                            searchBar
                                .transition(.move(edge: .top).combined(with: .opacity))
                                .zIndex(1)
                        }
                    }
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
        .onReceive(NotificationCenter.default.publisher(for: .toggleSearch)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                if isSearchVisible {
                    dismissSearch()
                } else {
                    isSearchVisible = true
                    isSearchFieldFocused = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .findNext)) { _ in
            if isSearchVisible {
                findNext()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .findPrevious)) { _ in
            if isSearchVisible {
                findPrevious()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .printDocument)) { _ in
            webViewCoordinator?.printContent()
        }
        .onReceive(NotificationCenter.default.publisher(for: .zoomIn)) { _ in
            webViewCoordinator?.zoomIn()
        }
        .onReceive(NotificationCenter.default.publisher(for: .zoomOut)) { _ in
            webViewCoordinator?.zoomOut()
        }
        .onReceive(NotificationCenter.default.publisher(for: .zoomReset)) { _ in
            webViewCoordinator?.zoomReset()
        }
        .onReceive(NotificationCenter.default.publisher(for: .scrollToTop)) { _ in
            webViewCoordinator?.scrollToTop()
        }
        .onReceive(NotificationCenter.default.publisher(for: .scrollToBottom)) { _ in
            webViewCoordinator?.scrollToBottom()
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 13))

            TextField("Search...", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($isSearchFieldFocused)
                .onSubmit {
                    findNext()
                }
                .onChange(of: searchQuery) { newValue in
                    if newValue.isEmpty {
                        webViewCoordinator?.clearSearch()
                        searchCurrent = 0
                        searchTotal = 0
                    } else {
                        webViewCoordinator?.performSearch(newValue) { current, total in
                            DispatchQueue.main.async {
                                searchCurrent = current
                                searchTotal = total
                            }
                        }
                    }
                }

            if !searchQuery.isEmpty {
                Text("\(searchCurrent) of \(searchTotal)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }

            Button(action: findPrevious) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.borderless)
            .disabled(searchTotal == 0)
            .help("Previous match (Cmd+Shift+G)")

            Button(action: findNext) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.borderless)
            .disabled(searchTotal == 0)
            .help("Next match (Cmd+G)")

            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    dismissSearch()
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Close (Esc)")
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(.regularMaterial)
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 2)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Search Helpers

    private func findNext() {
        webViewCoordinator?.searchNext { current, total in
            DispatchQueue.main.async {
                searchCurrent = current
                searchTotal = total
            }
        }
    }

    private func findPrevious() {
        webViewCoordinator?.searchPrevious { current, total in
            DispatchQueue.main.async {
                searchCurrent = current
                searchTotal = total
            }
        }
    }

    private func dismissSearch() {
        isSearchVisible = false
        isSearchFieldFocused = false
        searchQuery = ""
        searchCurrent = 0
        searchTotal = 0
        webViewCoordinator?.clearSearch()
    }

    // MARK: - Sidebar

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
