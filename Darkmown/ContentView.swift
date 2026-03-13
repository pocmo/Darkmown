import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum AppearanceMode: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }
}

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

    // Status bar state
    @State private var isStatusBarVisible = true

    // Appearance mode
    @State private var appearanceMode: AppearanceMode = .auto

    // Computed stats
    private var wordCount: Int {
        let words = document.text.split { $0.isWhitespace || $0.isNewline }
        return words.count
    }

    private var characterCount: Int {
        document.text.count
    }

    private var readingTime: String {
        let minutes = max(1, Int(ceil(Double(wordCount) / 200.0)))
        return minutes == 1 ? "1 min read" : "\(minutes) min read"
    }

    private var effectiveIsDarkMode: Bool {
        switch appearanceMode {
        case .auto: return themeObserver.isDarkMode
        case .light: return false
        case .dark: return true
        }
    }

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
                VStack(spacing: 0) {
                    NavigationSplitView(columnVisibility: sidebarVisibility) {
                        sidebarContent
                    } detail: {
                        ZStack(alignment: .top) {
                            MarkdownWebView(
                                markdown: document.text,
                                isDarkMode: effectiveIsDarkMode,
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

                    if isStatusBarVisible {
                        statusBar
                    }
                }
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

                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isStatusBarVisible.toggle()
                        }
                    }) {
                        Label("Toggle Status Bar", systemImage: "chart.bar.doc.horizontal")
                    }
                    .help("Toggle word count status bar")
                }

                ToolbarItem(placement: .automatic) {
                    Menu {
                        ForEach(AppearanceMode.allCases) { mode in
                            Button(action: {
                                appearanceMode = mode
                            }) {
                                if appearanceMode == mode {
                                    Label(mode.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(mode.rawValue)
                                }
                            }
                        }
                    } label: {
                        Label("Appearance", systemImage: appearanceIcon)
                    }
                    .help("Switch appearance mode")
                }

                ToolbarItem(placement: .automatic) {
                    Button(action: exportHTML) {
                        Label("Export HTML", systemImage: "square.and.arrow.up")
                    }
                    .help("Export as HTML (Cmd+Shift+E)")
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
        .onReceive(NotificationCenter.default.publisher(for: .refreshDocument)) { _ in
            refreshDocument()
        }
        .onReceive(NotificationCenter.default.publisher(for: .exportHTML)) { _ in
            exportHTML()
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

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 16) {
            Label("\(wordCount) words", systemImage: "text.word.spacing")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Divider()
                .frame(height: 12)

            Label("\(characterCount) characters", systemImage: "character.cursor.ibeam")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Divider()
                .frame(height: 12)

            Label(readingTime, systemImage: "clock")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Spacer()

            Text(appearanceMode.rawValue)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.1))
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .top) {
            Divider()
        }
    }

    // MARK: - Appearance

    private var appearanceIcon: String {
        switch appearanceMode {
        case .auto: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    // MARK: - Refresh

    private func refreshDocument() {
        // Force a re-render by toggling the markdown through the coordinator
        let currentText = document.text
        webViewCoordinator?.updateMarkdown(currentText, isDarkMode: effectiveIsDarkMode)
    }

    // MARK: - Export HTML

    private func exportHTML() {
        webViewCoordinator?.getRenderedHTML { html in
            guard let html = html else { return }

            DispatchQueue.main.async {
                let panel = NSSavePanel()
                panel.title = "Export HTML"
                panel.nameFieldStringValue = "document.html"
                panel.allowedContentTypes = [.html]
                panel.canCreateDirectories = true

                panel.begin { response in
                    guard response == .OK, let url = panel.url else { return }
                    do {
                        try html.write(to: url, atomically: true, encoding: .utf8)
                    } catch {
                        let alert = NSAlert(error: error)
                        alert.runModal()
                    }
                }
            }
        }
    }
}
