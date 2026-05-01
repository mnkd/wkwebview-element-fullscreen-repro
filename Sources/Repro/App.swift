import SwiftUI

@main
struct ReproApp: App {
    @State private var hostingMode: HostingMode = .direct

    var body: some Scene {
        WindowGroup("WKWebView Element Fullscreen Repro") {
            ContentView(hostingMode: $hostingMode)
                .frame(minWidth: 900, minHeight: 600)
        }
    }
}

/// Selects how the WKWebView is handed to SwiftUI.
enum HostingMode: String, CaseIterable, Identifiable {
    /// Returns `WKWebView` directly from `NSViewRepresentable.makeNSView`.
    /// SwiftUI installs AutoLayout constraints on the WKWebView, which
    /// breaks element fullscreen (this is the bug being reported).
    case direct = "Direct (broken)"

    /// Wraps the `WKWebView` in a container `NSView` and uses
    /// `translatesAutoresizingMaskIntoConstraints = true` +
    /// `autoresizingMask = [.width, .height]`. This is the workaround.
    case container = "Container NSView (workaround)"

    var id: String { rawValue }
}
