# WebKit Bugzilla draft

Filing template for <https://bugs.webkit.org/>. Replace `<REPO_URL>` with the
public GitHub URL once the repo is pushed (e.g.
`https://github.com/mnkd/wkwebview-element-fullscreen-repro`).

---

## Product / Component

- Product: **WebKit**
- Component: **Fullscreen** (or **WebKit2** if Fullscreen is not available)
- Version: **Safari Technology Preview** (or specific macOS version)
- Hardware / OS: **All / macOS 14+**
- Severity: **Normal**

## Summary

WKWebView element fullscreen collapses to zero-size viewport when the web view
is hosted via SwiftUI `NSViewRepresentable` (or any AutoLayout setup that
constrains the WKWebView from above its immediate superview)

## Description

When `WKPreferences.isElementFullscreenEnabled = true` and a `WKWebView` is
returned directly from `NSViewRepresentable.makeNSView(context:)` in a
SwiftUI app, entering element fullscreen on a `<video>` (or any element)
collapses the page viewport to `0×0`. The fullscreen `NSWindow` shown by
`WKFullScreenWindowController` is correctly sized to the screen, but the
hosted `WKWebView` itself ends up with `bounds = (0, 0, 0, 0)` after the
reparenting in
`-[WKFullScreenWindowController _continueEnteringFullscreenAfterPostingNotification:]`.

Because the page viewport is `0×0`, the user-agent stylesheet rule for
`:fullscreen` (`Source/WebCore/css/fullscreen.css`):

```css
*|*:not(:root):fullscreen {
  position: fixed !important;
  inset: 0 !important;
  width: 100% !important;
  height: 100% !important;
  ...
}
```

evaluates `100%` against the zero viewport and produces a zero-sized fullscreen
element. The `<video>` retains its previous inline render box, which leaves it
anchored to the top-left of the otherwise empty fullscreen window. If the
video was paused before fullscreen entry, no frame is drawn at all and only
the audio track plays.

The system console emits messages of the form:

> Attempting to update all DD element frames, but the bounds or contentsRect
> are invalid. Bounds: X: 0.00 Y: 0.00, W: 0.00 H: 0.00, contentsRect: ...

The same content works correctly in Safari, and works correctly in WKWebView
when the WKWebView is **not** directly governed by AutoLayout from an
ancestor (see Workaround below).

## Steps to reproduce

1. Clone <REPO_URL>
2. `swift run` (or open `Package.swift` in Xcode and Run)
3. Wait for the Big Buck Bunny clip to load
4. Right-click the video → **Enter Full Screen**
5. Observe: the video stays at its inline (720px) size in the top-left of an
   otherwise black fullscreen window
6. Toggle the segmented control to **Container NSView (workaround)** at the
   top of the window and repeat step 4 → the video now fills the screen as
   expected

## Expected behavior

The `<video>` element fills the fullscreen window, identical to Safari and to
the workaround mode.

## Actual behavior

The `WKWebView` viewport is `0×0` while in element fullscreen, so UA-stylesheet
sizing yields a `0×0` `:fullscreen` element. The `<video>` element draws at
its previous inline size from the top-left corner of the fullscreen window.

## Analysis

`Source/WebKit/UIProcess/mac/WKFullScreenWindowController.mm` (revision
`4b9916df`, 2026-04-30 main HEAD):

- `_continueEnteringFullscreenAfterPostingNotification:` (L368) reparents the
  `WKWebView` from its host hierarchy into the fullscreen window's
  `_clipView` and resizes it via
  `[webView setFrame:NSInsetRect(contentView.bounds, ...)]` (L427).
- Before reparenting, `_saveConstraintsOf:` (L944) is called on
  `webView.superview`, but only captures constraints stored in
  `superview.constraints`, filtering out
  `NSAutoresizingMaskLayoutConstraint`.
- `_replaceView:with:` (L932) installs a placeholder using `frame` and
  `autoresizingMask` only. If the original WKWebView was governed by
  AutoLayout from a higher ancestor (which is what SwiftUI's `_NSHostingView`
  does), the relevant constraints are not captured by `_saveConstraintsOf:`
  and the placeholder does not satisfy them either.

The result is that AppKit collapses the WKWebView's bounds when it is removed
from its original position in the hierarchy.

## Workaround

Wrap the `WKWebView` in a plain container `NSView`, set
`translatesAutoresizingMaskIntoConstraints = true` and
`autoresizingMask = [.width, .height]` on the `WKWebView`, and have SwiftUI
size the container instead of the `WKWebView` directly. The `WKWebView` then
uses frame-based layout and survives the reparenting unchanged.

The repro project demonstrates both the broken and working configurations
side by side.

## Suggested fix (in priority order)

1. **Internal wrapper view inside `WKWebView`.** Have the public `WKWebView`
   `NSView` keep a single inner content view that owns the rendering surface,
   and reparent the inner view into the fullscreen window instead of the
   public `WKWebView`. The public view stays in the host's AutoLayout
   hierarchy, so client constraints are never disturbed. This is what the
   workaround does manually.
2. **Walk the ancestor chain in `_saveConstraintsOf:`.** Capture every active
   `NSLayoutConstraint` whose `firstItem` or `secondItem` reaches the
   `WKWebView` (or any of its descendants) from any ancestor up to the host
   window's content view, and reactivate them on exit. Higher-fidelity than
   today's single-level capture.
3. **Document the requirement.** Update the doc comments on
   `WKWebView.fullscreenState` and `WKPreferences.elementFullscreenEnabled` to
   say that the WKWebView must not be the direct AutoLayout-managed view and
   must be hostable in a way that tolerates reparenting (i.e. inside a
   container with autoresizing). Lowest cost; useful even alongside a
   later code fix.

## Related

- Apple Developer Forums, "WkWebView breaks with isElementEnabled":
  <https://developer.apple.com/forums/thread/768688>
  (Same symptom, OP found the autoresizing-wrapper workaround. Marked
  "Solved" by the OP's workaround, not by an Apple-side fix.)
- Apple Developer Forums, "WKWebView: Fullscreen API very unreliable":
  <https://developer.apple.com/forums/thread/766736>
  (Different but adjacent fullscreen bug, fixed in iOS 18.3 / macOS 15.3 as
  FB15553776.)

## Attachments

- Repro repository: <REPO_URL>
- Screenshots / video of broken vs. working behavior (TBD)
