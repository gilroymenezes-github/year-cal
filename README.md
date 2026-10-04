# year-cal

A dates-only calendar for macOS: a menu bar panel plus desktop / Notification Center widgets.
No events, no accounts — just the calendar.

## What you get

**Menu bar panel** — click the calendar icon in the menu bar. A tall panel opens pinned to the
top-right of the screen showing December of the previous year, the full year, and January of the
next (2 months per row). `‹ ›` changes year, **Today** jumps back. Click anywhere else or press
Esc to close. Opens at login (checkbox in the panel to turn off).

**Widgets** (right-click desktop → Edit Widgets… → search "Year Calendar"):

| Widget | Sizes | Layout |
|---|---|---|
| Year Calendar | Large, Extra-large portrait (macOS 27+) | 3 × 4 year; portrait is 2 × 7, Dec → Jan |
| Year Calendar · Jan–Jun / Jul–Dec | Large | 2 × 3 each; stack both for a 2 × 6 year |
| Three Months | Medium | Sliding window, `‹ ›` moves one month |

Year widgets have `‹ year ›` (tap the year to return to today). Each widget has a **Background**
option (right-click → Edit Widget): Clear, Smoke or Solid.

> **Note:** if *System Settings → Appearance → Icon & widget style* is Dark, Clear or Tinted,
> macOS draws its own glass behind every widget and the Background option has no effect. Set it
> to Default to use the widget's own background.

## Install

### Option A — download the app (no Xcode needed)

1. Download `YearCal-1.0.zip` from the [latest release](https://github.com/gilroymenezes-github/year-cal/releases/latest) and unzip it.
2. Move `YearCal.app` to `~/Applications` (or `/Applications`).
3. The app is ad-hoc signed, not notarized, so clear the download quarantine flag, then open it:

```sh
xattr -dr com.apple.quarantine ~/Applications/YearCal.app
open ~/Applications/YearCal.app
```

Then add the widgets from *Edit Widgets…*. If they don't appear, log out and back in.

### Option B — build from source

Requirements: macOS 14 or later (extra-large portrait needs macOS 27), Xcode 16 or later.

```sh
git clone https://github.com/gilroymenezes-github/year-cal.git ~/Projects/year-cal
open ~/Projects/year-cal/YearCal.xcodeproj
```

In Xcode choose **Product → Build** (⌘B). A post-build step copies the app to
`~/Applications/YearCal.app`, registers the widgets and launches it — no Run needed. Rebuild the
same way after pulling changes.

The project is signed "to run locally" (ad-hoc), so no Apple developer account is needed. If
widgets don't show up in the gallery, select your Apple ID team under the target's
**Signing & Capabilities** and build again.

### Troubleshooting

- **Widgets show grey placeholder bars:** another copy of YearCal is registered (e.g. a stray
  Xcode build). Building again cleans these up; then remove and re-add the widget.
- **Check the install:** `install.log` in the project folder shows what the post-build step did.

## Project layout

```
Shared/YearView.swift            Month grid + mini month views (used by app and widgets)
YearCal/YearCalApp.swift         Menu bar app and pinned panel
YearCalWidget/YearCalWidget.swift Widgets, timeline provider, ‹ › intents, background styles
```

## License

MIT — see [LICENSE](LICENSE).
