# Dynamic review, second pass: pristine image + the two known QML modules

Image: `filelight-noble-fixed` (container/Dockerfile.fixed) = pristine noble +
`qml-module-qtquick-shapes` + `qml-module-org-kde-kcoreaddons` + `x11-apps` (xwd for
screenshots). Packages added relative to the pristine+tooling image are in
`fix-added-pkgs.txt`: the two QML modules, libqt5quickshapes5 (their dependency),
and x11-apps with its man-db/groff pull-ins. Nothing else Qt/KF related.

Purpose: in the first pass the scan page (`MapPage.qml`) failed to instantiate, so
anything it or its children (`CenterShape.qml`, `SegmentShape.qml`) load lazily was
never exercised. This pass lets the page load and the scan complete.

## Run

`docker run --rm -v "$PWD/analysis/dynamic-fixed:/out" filelight-noble-fixed bash /out/run-trace-fixed.sh`

- Xvfb 1280x800, `filelight /scan` where /scan holds ~1,668 files / 15.4 MiB.
- Logging: `QML_IMPORT_TRACE=1 QT_DEBUG_PLUGINS=1 QT_LOGGING_RULES='kf.*=true;qt.qml.*=true'`.
- Second run under `strace -f -e trace=openat,stat,newfstatat,access,readlink`.
- Both runs exit 0 (`exitcodes.txt`). No SIGABRT (the offscreen platform was not used
  because it has no OpenGL and aborts; see first-pass notes).

## Result

**Scan page loads, scan completes, radial map renders.** `screenshot-after-scan.png`
shows the map with the breadcrumb list ("c/ 10.4 MiB", "a/ 5.0 MiB"), centre label
"15.4 MiB", and status bar "1,668 files".

Distinct warnings in the Qt/KF log after the fix (`xvfb-errors.txt`, deduplicated):

| Message | Resource | Package (noble) | Verdict |
|---|---|---|---|
| `kf.iconthemes: Icon theme "breeze" not found.` / `Couldn't find current icon theme, falling back to default.` | icon theme | `breeze-icon-theme` | real, cosmetic: toolbar buttons render as text only (visible in screenshot) |
| `kf.crash: Could not find drkonqi in search paths` | crash handler | `drkonqi` | optional, only affects crash reporting dialog |
| `kf.i18n: Loading the "qt_" catalog failed for locale QLocale(C, ...)` | Qt translations for locale C | n/a | noise, locale is C in the container |

**No "module ... is not installed", no "Component is not ready", no plugin load
failure** anywhere in the log. Compared with the first pass, the strace shows the
newly loaded QML modules are exactly QtQuick.Shapes, org.kde.kcoreaddons, and the
Kirigami / qqc2desktopstyle / quickcharts / Qt.labs.platform files that the now-working
page pulls in, plus Qt imageformats and xcb GL integration plugins. All of them resolved
to installed packages (`strace-loaded-qml-plugins.txt`).

## Coverage gaps of this pass

- The xdotool keystrokes (Ctrl+, / F1 / Ctrl+O / Ctrl+Q) did not reach the window: there
  is no window manager in Xvfb and the window never had keyboard focus, so all three
  screenshots were identical and only one is kept. The Settings pages, the handbook
  action and the Open Folder dialog were therefore NOT exercised dynamically. Static
  review covers them: `SettingsPage*.qml` import only QtQuick, Layouts, Controls,
  Window, Kirigami and org.kde.filelight, all of which are already in the closure; the
  open-folder dialog is QFileDialog from linked Qt Widgets; the handbook action goes
  through KHelpClient (see static review for khelpcenter).
- Delete-from-context-menu (KIO::del) and remote URL scanning were not exercised.
