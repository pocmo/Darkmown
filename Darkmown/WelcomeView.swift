import SwiftUI

struct WelcomeView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "doc.richtext")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 8) {
                Text("Darkmown")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text("A beautiful Markdown viewer")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 12) {
                Button(action: {
                    NSDocumentController.shared.openDocument(nil)
                }) {
                    Label("Open File", systemImage: "folder")
                        .font(.system(size: 15, weight: .medium))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.accentColor)

                Text("or drag and drop a Markdown file")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundGradient)
    }

    private var backgroundGradient: some View {
        Group {
            if colorScheme == .dark {
                LinearGradient(
                    colors: [
                        Color(nsColor: NSColor.windowBackgroundColor),
                        Color(nsColor: NSColor.windowBackgroundColor).opacity(0.95)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                LinearGradient(
                    colors: [
                        Color(nsColor: NSColor.windowBackgroundColor),
                        Color.gray.opacity(0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }
}
