# Feedback Assistant draft

Short, concrete version for Feedback Assistant.

Repro repository: <https://github.com/mnkd/wkwebview-element-fullscreen-repro>
WebKit Bugzilla report: <https://bugs.webkit.org/show_bug.cgi?id=313802>

---

## Title

WKWebView element fullscreen collapses to 0×0 viewport when hosted via SwiftUI
NSViewRepresentable

## Area

Safari and WebKit › WebKit

## Reproducibility

Always

## Description

When `WKPreferences.isElementFullscreenEnabled = true` is enabled and a
`WKWebView` is returned directly from
`NSViewRepresentable.makeNSView(context:)` in a SwiftUI macOS app, entering
HTML5 element fullscreen on a `<video>` element collapses the page viewport
to `0×0`. The fullscreen `NSWindow` is correctly sized to the screen, but
the `WKWebView` itself ends up with `bounds = (0, 0, 0, 0)` after
`WKFullScreenWindowController` reparents it into the fullscreen window.

Because the page viewport is `0×0`, the user-agent stylesheet rule for
`:fullscreen` (which uses `width: 100% !important; height: 100% !important`)
yields a zero-sized `:fullscreen` box, and the `<video>` element retains its
previous inline render size in the top-left of an otherwise black fullscreen
window. If the video was paused before entering fullscreen, no frame is drawn
at all and only the audio plays.

This does not reproduce in Safari, and does not reproduce in WKWebView when
the WKWebView is wrapped in a container `NSView` with
`translatesAutoresizingMaskIntoConstraints = true` and
`autoresizingMask = [.width, .height]`.

## Steps to reproduce

1. Clone the minimal repro at https://github.com/mnkd/wkwebview-element-fullscreen-repro
2. `swift run`
3. Wait for the Big Buck Bunny clip to load
4. Right-click the video → "Enter Full Screen"
5. Observe the video at 720px in the top-left of the fullscreen window
6. Switch the segmented control at the top to "Container NSView (workaround)"
7. Repeat step 4 → the video now fills the screen as expected

## Expected

The `<video>` element fills the fullscreen window, identical to Safari and
to the workaround mode.

## Actual

The page viewport is `0×0`, the `<video>` is anchored to the top-left at its
inline size, and the rest of the fullscreen window is black.

## Notes

- WebKit Bugzilla report with full analysis and suggested fixes:
  <https://bugs.webkit.org/show_bug.cgi?id=313802>
- Console emits "Attempting to update all DD element frames, but the bounds
  or contentsRect are invalid. Bounds: X: 0.00 Y: 0.00, W: 0.00 H: 0.00 ..."
- The same symptom is reported by another developer at
  <https://developer.apple.com/forums/thread/768688>; that thread's "Solved"
  status is via the OP's autoresizing-wrapper workaround, not an Apple-side
  fix.

## System

- macOS 26.x
- Xcode 26.x
- Repro project source: https://github.com/mnkd/wkwebview-element-fullscreen-repro
