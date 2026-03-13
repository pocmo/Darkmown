import SwiftUI
import Combine

final class ThemeObserver: ObservableObject {
    @Published var isDarkMode: Bool

    private var observer: NSKeyValueObservation?

    init() {
        let appearance = NSApp.effectiveAppearance
        isDarkMode = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        observer = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] app, _ in
            DispatchQueue.main.async {
                let dark = app.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                self?.isDarkMode = dark
            }
        }
    }

    deinit {
        observer?.invalidate()
    }
}
