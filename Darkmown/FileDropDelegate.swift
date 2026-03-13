import SwiftUI
import UniformTypeIdentifiers

struct FileDropDelegate: DropDelegate {
    @Binding var document: MarkdownDocument

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.fileURL])
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let itemProvider = info.itemProviders(for: [.fileURL]).first else {
            return false
        }

        itemProvider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, _ in
            guard let urlData = data as? Data,
                  let urlString = String(data: urlData, encoding: .utf8),
                  let url = URL(string: urlString)
            else { return }

            let ext = url.pathExtension.lowercased()
            guard ext == "md" || ext == "markdown" else { return }

            if let content = try? String(contentsOf: url, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.document.text = content
                }
            }
        }
        return true
    }
}
