# wkwebview-element-fullscreen-repro

Minimal reproduction for a `WKWebView` HTML5 element fullscreen issue on macOS
when the web view is hosted via SwiftUI's `NSViewRepresentable` and AutoLayout.

Reported as: [WebKit Bugzilla #313802](https://bugs.webkit.org/show_bug.cgi?id=313802) / Apple Feedback FB22665668.

## Symptom

With `WKPreferences.isElementFullscreenEnabled = true`:

- Right-clicking a `<video>` element and choosing **Enter Full Screen** moves
  the WebKit fullscreen window into place, but the `<video>` stays at its
  in-page inline size and is anchored to the top-left of the fullscreen
  window. The rest of the screen is black.
- If the video is paused before entering fullscreen, no video frame is drawn
  at all; only the audio plays and the WebKit native controls appear.

This does not happen in Safari.

Recordings of both modes (right-click → Enter Full Screen):

- Broken (Direct hosting): [`media/broken.mov`](media/broken.mov)
- Workaround (Container NSView): [`media/workaround.mov`](media/workaround.mov)

The system console emits:

> Attempting to update all DD element frames, but the bounds or contentsRect
> are invalid. Bounds: X: 0.00 Y: 0.00, W: 0.00 H: 0.00, contentsRect: ... ,
> skipping

## Cause (working theory)

`WKFullScreenWindowController` (see
`Source/WebKit/UIProcess/mac/WKFullScreenWindowController.mm`) reparents the
`WKWebView` from its host view hierarchy into a private fullscreen
`NSWindow` for the duration of fullscreen.

It tries to be friendly to AutoLayout-hosted clients via `_saveConstraintsOf:`
(L944) and `_replaceView:with:` (L932), but `_saveConstraintsOf:` only
captures the constraints stored on `webView.superview`. SwiftUI's
`NSViewRepresentable` installs hosting constraints higher in the ancestor
chain (via `_NSHostingView`), so those constraints are not captured and not
restored. When the `WKWebView` is removed and re-added, AppKit collapses its
bounds to zero, and the page's UA stylesheet
(`Source/WebCore/css/fullscreen.css`):

```css
*|*:not(:root):fullscreen {
  position: fixed !important;
  inset: 0 !important;
  width: 100% !important;
  height: 100% !important;
  ...
}
```

evaluates `100%` against a zero-sized viewport and yields a zero-sized box.
The video element therefore retains its prior inline size in the top-left of
the otherwise-empty fullscreen window.

## Workaround

Wrap the `WKWebView` in a plain container `NSView`, set
`translatesAutoresizingMaskIntoConstraints = true` and
`autoresizingMask = [.width, .height]` on the `WKWebView`, and let SwiftUI
size the container instead. This isolates the `WKWebView` from AutoLayout, so
it survives reparenting unchanged.

```swift
final class Container: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        let webView = makeWebView()
        webView.translatesAutoresizingMaskIntoConstraints = true
        webView.autoresizingMask = [.width, .height]
        webView.frame = container.bounds
        container.addSubview(webView)
        return container
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
```

## Repro steps

1. `swift run` (or open `Package.swift` in Xcode and Run)
2. Press the play button on the video (a 10s Big Buck Bunny clip)
3. Right-click the video and choose **Enter Full Screen**
4. In the **Direct (broken)** mode the video appears at its original 720px
   size in the top-left of the fullscreen window. In the
   **Container NSView (workaround)** mode it fills the screen.
5. Try the same after pausing the video. In broken mode no frame is drawn.

The segmented control at the top switches between the two hosting strategies.
Each switch rebuilds the `NSViewRepresentable` so a fresh `WKWebView` is
created.

## Environment

- macOS 26.x (also reported on 15.2)
- Xcode 26.x
- WebKit revision pinned for analysis: `4b9916df` (2026-04-30 main HEAD)

## Related

- Apple Developer Forums:
  <https://developer.apple.com/forums/thread/768688>
- Apple Developer Forums (different but adjacent fullscreen bug, fixed in
  iOS 18.3 / macOS 15.3 as FB15553776):
  <https://developer.apple.com/forums/thread/766736>

## License

MIT, see `LICENSE`.
