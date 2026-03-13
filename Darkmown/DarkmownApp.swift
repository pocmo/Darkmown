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
        }
        .defaultSize(width: 1000, height: 700)
    }
}

extension Notification.Name {
    static let toggleSidebar = Notification.Name("toggleSidebar")
}
