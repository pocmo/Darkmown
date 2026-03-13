import SwiftUI

struct HeadingItem: Identifiable, Equatable {
    let id: String
    let text: String
    let level: Int
}

struct TableOfContents: View {
    let headings: [HeadingItem]
    var onSelectHeading: (HeadingItem) -> Void

    var body: some View {
        List(headings) { heading in
            Button(action: {
                onSelectHeading(heading)
            }) {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(headingColor(for: heading.level))
                        .frame(width: 3, height: 14)

                    Text(heading.text)
                        .font(headingFont(for: heading.level))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
                .padding(.leading, CGFloat((heading.level - 1)) * 12)
            }
            .buttonStyle(.plain)
        }
        .listStyle(.sidebar)
    }

    private func headingFont(for level: Int) -> Font {
        switch level {
        case 1:
            return .system(size: 13, weight: .bold)
        case 2:
            return .system(size: 12, weight: .semibold)
        case 3:
            return .system(size: 12, weight: .medium)
        default:
            return .system(size: 11, weight: .regular)
        }
    }

    private func headingColor(for level: Int) -> Color {
        switch level {
        case 1: return .blue
        case 2: return .purple
        case 3: return .orange
        default: return .gray
        }
    }
}

// MARK: - Heading Parser

enum HeadingParser {
    /// Parses markdown text and returns an array of HeadingItem for H1-H6.
    static func parse(markdown: String) -> [HeadingItem] {
        var headings: [HeadingItem] = []
        var counter: [Int: Int] = [:]

        let lines = markdown.components(separatedBy: .newlines)
        var inCodeBlock = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Track fenced code blocks to avoid parsing headings inside them
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                inCodeBlock.toggle()
                continue
            }

            guard !inCodeBlock else { continue }

            // Match ATX-style headings: # through ######
            guard trimmed.hasPrefix("#") else { continue }

            var level = 0
            for char in trimmed {
                if char == "#" {
                    level += 1
                } else {
                    break
                }
            }

            guard level >= 1, level <= 6 else { continue }

            let textStart = trimmed.index(trimmed.startIndex, offsetBy: level)
            var text = String(trimmed[textStart...]).trimmingCharacters(in: .whitespaces)

            // Remove trailing # characters (optional closing sequence)
            if let range = text.range(of: #"\s+#+\s*$"#, options: .regularExpression) {
                text = String(text[text.startIndex..<range.lowerBound])
            }

            guard !text.isEmpty else { continue }

            // Generate a slug-style id matching the HTML renderer
            let count = (counter[text.hashValue] ?? 0)
            counter[text.hashValue] = count + 1
            let slug = slugify(text)
            let id = count == 0 ? slug : "\(slug)-\(count)"

            headings.append(HeadingItem(id: id, text: text, level: level))
        }

        return headings
    }

    /// Converts heading text to a URL-friendly slug, matching the JS slugify logic.
    private static func slugify(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: #"[^\w\s-]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
