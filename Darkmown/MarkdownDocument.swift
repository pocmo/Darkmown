import SwiftUI
import UniformTypeIdentifiers

struct MarkdownDocument: FileDocument {
    var text: String

    static var readableContentTypes: [UTType] {
        [
            UTType(filenameExtension: "md", conformingTo: .plainText) ?? .plainText,
            UTType(filenameExtension: "markdown", conformingTo: .plainText) ?? .plainText
        ]
    }

    init(text: String = "# Welcome to Darkmown\n\nStart writing your markdown here.") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = string
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = Data(text.utf8)
        return .init(regularFileWithContents: data)
    }
}
