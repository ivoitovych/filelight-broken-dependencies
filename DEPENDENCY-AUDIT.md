# filelight 4:23.08.5-0ubuntu3 (noble): full runtime dependency audit

Goal: determine the *complete* set of runtime dependencies the noble deb fails to
declare, not just the two found on one machine. Two independent methods were used
and cross-checked, both against a pristine environment rather than the original host.

## Method

| Track | What | Where |
|---|---|---|
| Static | Every QML `import`, every C++ runtime-by-name API (icons, KIO, QQC2 style, KFormat, KColorScheme, help, translations), CMake runtime hints, mapped to the noble package that ships the looked-up file and checked against the dependency closure | `analysis/static/` |
| Dynamic, pass 1 | Pristine `ubuntu:24.04` + `apt install filelight` (Recommends on). Run under `QML_IMPORT_TRACE`, `QT_DEBUG_PLUGINS`, `kf.*` logging, and `strace`, offscreen and under Xvfb | `analysis/dynamic/` |
| Dynamic, pass 2 | Same image + only the two known modules, so the scan page actually loads; scan to completion, screenshot | `analysis/dynamic-fixed/` |
| Third signal | As-built Depends of Debian's package of the identical upstream version, Debian's current auto-generated (dh_qmldeps) list, upstream CMake hints | `analysis/static/*asbuilt*`, `reference/` |

Baseline: the pristine container's installed set is exactly filelight's dependency
closure (467 packages, `analysis/dynamic/pkgs-after-filelight.txt`). Any runtime
lookup that fails there is a packaging gap by construction. Diagnostic tooling added
20 X11/strace packages and no Qt, KF5, QML or icon packages
(`analysis/dynamic/tooling-added-pkgs.txt`).

## Result: classified list

### Bin 1: hard failure, must be `Depends` (SRU scope)

| Resource | Evidence | Package (noble) |
|---|---|---|
| QML `QtQuick.Shapes 1.15` (MapPage, CenterShape, SegmentShape) | static import list; runtime `module "QtQuick.Shapes" is not installed` → `Component is not ready`, scan page never appears | `qml-module-qtquick-shapes` 5.15.13+dfsg-1ubuntu0.1 |
| QML `org.kde.kcoreaddons 1.0` (MapPage, CenterShape, SegmentShape; `KCoreAddons.Format.formatByteSize`) | static import list; runtime `module "org.kde.kcoreaddons" is not installed`; Debian declared it since 4:22.12.2-1 | `qml-module-org-kde-kcoreaddons` 5.115.0-0ubuntu5 |

With exactly these two added, the scan page loads, a 1,668-file scan completes and
the radial map renders (`analysis/dynamic-fixed/screenshot-after-scan.png`). No other
`is not installed`, `Component is not ready`, plugin-load or KF5 lookup failure
occurs in any run. Every other QML module filelight imports (QtQuick, Controls,
Layouts, Window, Qt.labs.platform, Kirigami, QuickCharts, the org.kde.desktop style),
the `kio_file` worker, and the xcb platform plugin are in the closure via Depends only.

### Bin 2: degraded, `Recommends` at most (not for the SRU)

| Resource | Evidence | Package | Note |
|---|---|---|---|
| Icon theme providing freedesktop names (`go-previous`, `configure`, `folder`, ...) | `kf.iconthemes: Icon theme "breeze" not found` / `falling back to default`; toolbar renders text-only in the screenshot | `breeze-icon-theme` | Nothing in the closure Depends on or Recommends an icon theme. Adwaita + hicolor arrive only via `libqt5gui5t64 → Recommends qt5-gtk-platformtheme → libgtk-3 → adwaita-icon-theme`. Debian's filelight (all versions) has no icon-theme relation either, and on a real GNOME host the GTK platform theme supplies Adwaita. Cosmetic. |

### Bin 3: optional, `Suggests` or nothing

| Resource | Package | Note |
|---|---|---|
| Handbook viewer invoked by the Help action | `khelpcenter` | Handbook docbooks ship in the deb; only F1 degrades. Would drag in khtml, xapian, kinit. |
| Remote-URL scanning (sftp, smb, fish) | `kio-extras` | Local scan/delete/trash use `kio_file`/`kio_trash` from `kio`, already a Depends. |
| Crash dialog | `drkonqi` | `kf.crash: Could not find drkonqi`; KDE-wide, never a per-app dependency. |
| Native dialogs / Wayland | `qt5-gtk-platformtheme`, `qtwayland5` | Already Recommends of `libqt5gui5t64`; Qt's policy, not filelight's. |

### Noise (not findings)

- `kf.i18n: Loading the "qt_" catalog failed for locale QLocale(C)`: container locale is C.
- strace ENOENTs under `qt5/qml` and `qt5/plugins`: `.qmlc` cache and `.so.avx2` probes followed by successful loads; per-theme icon directory probing; per-locale catalog probing. Qt's normal search behaviour.
- Offscreen platform aborts with `Failed to create OpenGL context`: the offscreen QPA has no GL; Xvfb runs exit 0. Environmental.

## Execution review (interactive scenarios, automated)

A third dynamic pass drove every user-facing action through the closure-only image with
Xvfb + openbox, screenshots and a statx-aware strace (`analysis/interactive/RESULTS.md`).
It confirms the table above and adds the runtime-launched helper programs, which no static
or linker-level check can see:

| Action | Missing helper | Package | Bin |
|---|---|---|---|
| Open (context menu) | `xdg-open` (then browsers) | `xdg-utils` | 2, Recommends candidate; present on every Ubuntu desktop |
| Open Terminal Here | `konsole`, `xterm` only | `konsole` / `xterm` | KF5 limitation, silent no-op on GNOME hosts without xterm; not packaging |
| Open Handbook | `khelpcenter` | `khelpcenter` | 3 |
| Remote URL (sftp) | KIO worker | `kio-extras` | 3, clear error dialog |

Everything else (scan, navigation, dialogs, settings, delete, about, root scan) works on
the closure alone, and the only packages used outside the pristine closure are the three
the fix adds. The conclusion below is unchanged.

## Coverage limits

- Drag-and-drop onto the window was not exercised (needs a second X client); its code path
  uses only linked Qt Quick.

## Conclusion

The total deficiency of noble's filelight deb is **exactly two missing `Depends`**:
`qml-module-qtquick-shapes` and `qml-module-org-kde-kcoreaddons`. Both tracks agree,
and the fixed container proves sufficiency. The icon-theme observation is real but
cosmetic, matches Debian's own packaging choice, and should not go into a minimal SRU.

Translations (54 `.mo`), the app icons (hicolor PNGs) and the handbook are all shipped
inside the filelight deb itself and need no extra packages.
