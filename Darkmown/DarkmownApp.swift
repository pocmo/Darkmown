import SwiftUI
import UniformTypeIdentifiers

@main
struct DarkmownApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: MarkdownDocument()) { file in
            ContentView(document: file.$document)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open...") {
                    NSDocumentController.shared.openDocument(nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            CommandGroup(after: .sidebar) {
                Button("Toggle Table of Contents") {
                    NotificationCenter.default.post(name: .toggleSidebar, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }

            // Find menu
            CommandGroup(after: .textEditing) {
                Divider()

                Button("Find...") {
                    NotificationCenter.default.post(name: .toggleSearch, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)

                Button("Find Next") {
                    NotificationCenter.default.post(name: .findNext, object: nil)
                }
                .keyboardShortcut("g", modifiers: .command)

                Button("Find Previous") {
                    NotificationCenter.default.post(name: .findPrevious, object: nil)
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
            }

            // Print
            CommandGroup(replacing: .printItem) {
                Button("Print...") {
                    NotificationCenter.default.post(name: .printDocument, object: nil)
                }
                .keyboardShortcut("p", modifiers: .command)
            }

            // View menu - Zoom and Scroll
            CommandGroup(after: .toolbar) {
                Divider()

                Button("Zoom In") {
                    NotificationCenter.default.post(name: .zoomIn, object: nil)
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("Zoom Out") {
                    NotificationCenter.default.post(name: .zoomOut, object: nil)
                }
                .keyboardShortcut("-", modifiers: .command)

                Button("Actual Size") {
                    NotificationCenter.default.post(name: .zoomReset, object: nil)
                }
                .keyboardShortcut("0", modifiers: .command)

                Divider()

                Button("Scroll to Top") {
                    NotificationCenter.default.post(name: .scrollToTop, object: nil)
                }
                .keyboardShortcut(.upArrow, modifiers: .command)

                Button("Scroll to Bottom") {
                    NotificationCenter.default.post(name: .scrollToBottom, object: nil)
                }
                .keyboardShortcut(.downArrow, modifiers: .command)
            }
        }
        .defaultSize(width: 1000, height: 700)
    }
}

extension Notification.Name {
    static let toggleSidebar = Notification.Name("toggleSidebar")
    static let toggleSearch = Notification.Name("toggleSearch")
    static let findNext = Notification.Name("findNext")
    static let findPrevious = Notification.Name("findPrevious")
    static let printDocument = Notification.Name("printDocument")
    static let zoomIn = Notification.Name("zoomIn")
    static let zoomOut = Notification.Name("zoomOut")
    static let zoomReset = Notification.Name("zoomReset")
    static let scrollToTop = Notification.Name("scrollToTop")
    static let scrollToBottom = Notification.Name("scrollToBottom")
}
