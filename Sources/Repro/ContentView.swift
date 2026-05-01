import SwiftUI
import WebKit

// MARK: - Owner of the WKWebView (held across SwiftUI rebuilds)

/// Holds a long-lived `WKWebView`. This mirrors a real-world pattern where a
/// browser-tab model owns its web view and SwiftUI just renders whichever
/// tab is active. The bug repros only when the WKWebView survives across
/// SwiftUI rebuilds, because that is when SwiftUI's hosting constraints
/// stack up around the same `WKWebView` instance.
@Observable
final class WebViewHolder {
    let webView: WKWebView

    init() {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.isElementFullscreenEnabled = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isInspectable = true
        // Passing a nil baseURL gives the page an opaque origin, which can
        // block media loads. Use an explicit https origin instead.
        webView.loadHTMLString(reproHTML, baseURL: URL(string: "https://example.com/"))
        self.webView = webView
    }
}

// MARK: - Repro page

private let reproHTML = """
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Element Fullscreen Repro</title>
<style>
  html, body { margin: 0; padding: 0; background: #222; color: #ddd; font-family: -apple-system, sans-serif; }
  .wrap { display: flex; flex-direction: column; align-items: center; padding: 24px; gap: 16px; }
  video { width: 720px; max-width: 100%; background: #000; }
  p { max-width: 720px; line-height: 1.5; }
</style>
</head>
<body>
  <div class="wrap">
    <video controls preload="metadata"
      src="https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_1MB.mp4">
    </video>
    <p>
      Press play, then right-click the video and choose <b>Enter Full Screen</b>.<br>
      In the broken mode, the video stays at its inline size in the top-left of
      the fullscreen window. In the workaround mode, it fills the screen.
    </p>
  </div>
</body>
</html>
"""

// MARK: - SwiftUI tree

struct ContentView: View {
    @Binding var hostingMode: HostingMode
    @State private var holder = WebViewHolder()

    var body: some View {
        // NavigationSplitView is part of the trigger: the extra _NSHostingView
        // layers it introduces around the WKWebView are what break under
        // WebKit's _saveConstraintsOf: single-level capture.
        NavigationSplitView {
            List {
                Text("Sidebar").font(.headline)
                Text(hostingMode.rawValue)
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 320)
        } detail: {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Picker("Hosting", selection: $hostingMode) {
                        ForEach(HostingMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 480)

                    Spacer()

                    Text("Right-click the video → \"Enter Full Screen\"")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
                .padding(8)

                Divider()

                Group {
                    switch hostingMode {
                    case .direct:
                        DirectHostedWebView(holder: holder)
                    case .container:
                        ContainerHostedWebView(holder: holder)
                    }
                }
                // Rebuild the representable when the mode flips so each
                // variant gets its own NSView. The underlying WKWebView is
                // the same instance across both, mirroring real-world
                // long-lived web view ownership.
                .id(hostingMode)
            }
        }
    }
}

// MARK: - Direct (bug repro)

/// Returns the long-lived `WKWebView` directly. SwiftUI installs AutoLayout
/// constraints from `_NSHostingView` ancestors. When `WKFullScreenWindowController`
/// reparents the `WKWebView` into its fullscreen window, those constraints are
/// not captured by `_saveConstraintsOf:` (which only inspects the immediate
/// superview), so the WKWebView's bounds collapse to zero in fullscreen.
struct DirectHostedWebView: NSViewRepresentable {
    let holder: WebViewHolder

    func makeNSView(context: Context) -> WKWebView {
        let webView = holder.webView
        webView.removeFromSuperview()
        return webView
    }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

// MARK: - Container (workaround)

/// Wraps the `WKWebView` in a plain container `NSView`. SwiftUI lays out the
/// container; the `WKWebView` itself is frame-based with autoresizing, so it
/// survives reparenting unchanged.
struct ContainerHostedWebView: NSViewRepresentable {
    let holder: WebViewHolder

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        let webView = holder.webView
        webView.translatesAutoresizingMaskIntoConstraints = true
        webView.autoresizingMask = [.width, .height]
        webView.frame = container.bounds
        // The same WKWebView may be re-mounted into a fresh container when
        // the segmented control flips; detach from the old superview first.
        webView.removeFromSuperview()
        container.addSubview(webView)
        return container
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
