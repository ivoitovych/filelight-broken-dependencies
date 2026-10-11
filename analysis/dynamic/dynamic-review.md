# Dynamic review: filelight 4:23.08.5-0ubuntu3 in pristine ubuntu:24.04

Image: filelight-noble-pristine (ubuntu:24.04 + `apt install filelight` with Recommends + strace, xvfb, xdotool, x11-utils).
All runs as root in the container, scripted in `run-trace.sh`. Raw logs sit next to this file.

## Commands and exit codes

Reproduce with:

    docker run --rm -v "$PWD/analysis/dynamic:/out" filelight-noble-pristine bash /out/run-trace.sh

Package lists: `docker run --rm filelight-noble-pristine cat /pkgs-after-{filelight,tooling}.txt` (exit 0), diff saved to `tooling-added-pkgs.txt` (diff exit 1 = differences exist).

Inside the container (HOME=/root, XDG_RUNTIME_DIR=/tmp/runtime mode 700, /scan with a 5 MB random file and a copy of /etc/apt):

| Step | Command (abridged) | Exit |
|---|---|---|
| 3 | `QT_QPA_PLATFORM=offscreen QML_IMPORT_TRACE=1 QT_DEBUG_PLUGINS=1 QT_LOGGING_RULES='qt.qpa.*=true;kf.*=true;qt.qml.*=true' timeout 25 filelight /scan` | **134 (SIGABRT, not 124)** |
| 4 | `QT_QPA_PLATFORM=offscreen strace -f -o strace-offscreen.raw -e trace=openat,stat,newfstatat,access,readlink -s 300 timeout 25 filelight /scan` | 134 (same abort, "dumped core") |
| 5 | `xvfb-run -a -s "-screen 0 1280x800x24" bash -c '... filelight /scan & ... xdotool ctrl+comma, Escape, F1, ctrl+o, Escape, ctrl+q ...'` | 0 |
| 5s | same under `strace -f -o strace-xvfb.raw` | 0 |

The offscreen abort is caused by the last log line: `Failed to create OpenGL context for format QSurfaceFormat(version 2.0 ...)`. The Qt `offscreen` platform plugin has no GL integration, so this is a limitation of the offscreen QPA plugin (Mesa libgl1-mesa-dri, libglx-mesa0, libegl-mesa0 are installed), not a missing package. The program got as far as loading QML (MapPage errors are logged before it) so the offscreen log is still useful, and the Xvfb run (GLX software rendering) did not abort.

Screenshot: not taken. Neither ImageMagick `import` nor `xwd` is present (`xwd` is in x11-apps, not x11-utils on noble). The script skips it silently.
xdotool `search` printed nothing, so the window class lookup did not match; keystrokes were sent to the focused window anyway. UI behaviour was therefore not verified visually; no dialog-related error showed up in the log.

## Step 1: tooling diff verdict

The tooling layer added 33 diff lines (20 packages): libfontenc1, libunwind8, libxaw7, libxdo3, libxfont2, libxft2, libxkbfile1, libxmu6, libxmuu1, libxpm4, libxt6t64, libxv1, libxxf86dga1, strace, x11-utils, x11-xkb-utils, xauth, xdotool, xserver-common, xvfb.

**Verdict: no qml-module-*, libkf5*, libqt5* or *-icon-theme package was added by the tooling** (grep on the diff returned nothing). The tooling cannot have masked or caused a Qt/KF dependency gap. Only X libraries and Xvfb were added, which the pristine package set did not contain; that is irrelevant for QML/KF lookups.

## Distinct Qt/KF error and warning lines

(Same set in the offscreen and Xvfb logs unless noted. Source: `offscreen-errors.txt`, `xvfb-errors.txt`, and manual review of the logs; plugin-debug noise from the `icon` pattern, e.g. iconengines factory lines, is not an error.)

| Line | Resource | Provider (noble) | Status |
|---|---|---|---|
| `qrc:/ui/MapPage.qml:9 module "QtQuick.Shapes" is not installed` | QML module QtQuick.Shapes | qml-module-qtquick-shapes | KNOWN |
| `qrc:/ui/MapPage.qml:8 module "org.kde.kcoreaddons" is not installed` | QML module org.kde.kcoreaddons | qml-module-org-kde-kcoreaddons | KNOWN |
| `QQmlComponent: Component is not ready` and `.../kirigami.2/PageRow.qml:914: Error: Error while loading page: qrc:/ui/MapPage.qml...` | consequence of the two above: main page fails to load | n/a | KNOWN (follow-on) |
| `kf.iconthemes: Icon theme "breeze-internal" not found.` (offscreen only) | /usr/share/icons/breeze-internal | breeze-icon-theme (ships /usr/share/icons/breeze) | NEW (see below) |
| `kf.iconthemes: Icon theme "breeze" not found.` (twice) and `Couldn't find current icon theme, falling back to default.` | /usr/share/icons/breeze | breeze-icon-theme 4:5.115.0-0ubuntu3 (Depends: hicolor-icon-theme only; not a Depends/Recommends of filelight, kio or libkf5iconthemes5; apt-cache rdepends of it is empty in the installed set) | NEW |
| `kf.crash: Could not find drkonqi in search paths: (/usr/bin, .../qt5/libexec, .../libexec)` | crash handler helper | drkonqi 5.27.11-0ubuntu3 | NEW but benign: only used on crash, optional by design |
| `kf.i18n: Loading the "qt_" catalog failed for locale QLocale(C, ...)` | Qt translation catalog for locale C | none (container has no locale set, LANG unset) | NEW but environmental, not a package gap |
| `qt.qml.binding.removal: Overwriting binding on ApplicationWindow ... width/height` | filelight's own main.qml vs Kirigami | n/a | NEW but a code warning, no missing resource |
| `Failed to create OpenGL context ...` (offscreen only, fatal) | GL on `offscreen` QPA | n/a | environmental, see above |

## ENOENT summary (offscreen run, filtered set: 8344 unique paths)

A bare ENOENT is not a finding. Qt/KDE search a list of locations in order and the first hit wins; most misses are the expected probing of the other locations, and only a miss that is followed by an error, a fallback message or a visible defect counts.

`strace-enoent-summary.txt`:

| Prefix | Missed paths | Assessment |
|---|---|---|
| /usr/share/icons/hicolor | 8112 | Normal probing noise from the icon loader: for each icon name x size dir x extension (png, svg, svgz, xpm) in hicolor. Examples: `/usr/share/icons/hicolor/128x128/mimetypes/folder.png`, `.../folder-root.svg`, `.../go-next-symbolic.xpm`. Volume is high because hicolor is the only theme found. |
| /usr/lib/x86_64-linux-gnu/qt5/qml | 207 | Normal: `.qmlc` caches (`QtGraphicalEffects/LinearGradient.qmlc`), `.so.avx2` hwcaps variants (`QtQml/libqmlplugin.so.avx2`, `Qt/labs/platform/libqtlabsplatformplugin.so.avx2`), and style fallbacks (kirigami.2/styles/org.kde.desktop/*, Controls.2/Default). All resolved by a later hit. |
| /usr/share/qt5/translations | 7 | Normal: `qt_C.qm`, `qt_c.qm`, `qt.qm`, locale C probing. Matches the benign `kf.i18n` line. |
| /usr/lib/x86_64-linux-gnu/qt5/plugins | 5 | Normal: `.so.avx2` variants (`platforms/libqoffscreen.so.avx2`, `kf5/kirigami/org.kde.desktop.so.avx2`) and `accessible/.`, `styles/.` (empty plugin dirs). Real plugins load (see `strace-loaded-qml-plugins.txt`, 93 files). |
| /usr/share/locale/en | 3 | Normal: `kcoreaddons5_qt.qm.qm`, `kjobwidgets5_qt.qm.qm`, `kwidgetsaddons5_qt.qm.qm` (the `.qm.qm` name is probed first; the plain `kcoreaddons5_qt.qm` is then opened successfully). |
| /usr/share/fonts | 3 | Normal: fontconfig `.uuid` files. |
| /usr/share/icons/breeze, breeze-internal, /usr/share/pixmaps/{breeze,breeze-internal,hicolor}, /usr/share/filelight/icons | 1 each | **Not noise.** These are the theme directories KIconLoader tried and which are absent; they coincide with the `Icon theme "breeze" not found` warnings. |
| /usr/share/qt5/qtlogging.ini | 1 | Normal optional config file. |

In the Xvfb run the filtered list grows to 12524 paths (12188 under hicolor, the rest the same categories). No ENOENT was recorded under kxmlgui5, knotifications5, kservices5, mime, doc, color-schemes or /etc/xdg in either run, i.e. no missing resources there. (Those directories either exist or were never probed with the traced syscalls.)

Icon names that were looked up under every directory and never opened in any theme in the Xvfb run (the only icon file opened was hicolor `filelight.png`): configure, folder, folder-root, go-next(-symbolic), go-previous(-symbolic), go-up, help, help-browser, open-menu(-symbolic), overflow-menu, unknown, user-home. These are the UI icons for the toolbar, hamburger menu, scan/open buttons and folder display. They are looked up in hicolor (which has no such icons) and the Adwaita/default cursor themes only; nothing provides them. This combines a warning from KIconLoader, a fallback, and probable visible defect (missing icons), so it is a real finding, but see caveat: screenshots could not be taken, so the visual effect is inferred, not seen.

## New candidate gaps found by execution

1. **breeze-icon-theme missing (icon theme).**
   Evidence: `kf.iconthemes: Icon theme "breeze" not found.` / `Icon theme "breeze-internal" not found.` / `Couldn't find current icon theme, falling back to default.`; strace ENOENT `/usr/share/icons/breeze/`, `/usr/share/pixmaps/breeze/`; icon names `configure`, `folder`, `go-next`, `open-menu`, `help-browser` etc. probed under hicolor and never found anywhere. Package providing it: `breeze-icon-theme` 4:5.115.0-0ubuntu3. Nothing in filelight's Depends, nor in the installed set's Recommends, pulls it in. Impact: Kirigami/KDE icons missing (blank buttons) on a system without a KDE icon theme; confidence medium-high for the cause, visual impact unconfirmed.
2. **drkonqi (optional, low).** Evidence: `kf.crash: Could not find drkonqi in search paths`. Only affects the crash dialog; an expected optional helper, not a runtime dependency. Listed for completeness, not a recommended fix.

Not gaps (environmental): `qt_` catalog for locale C; `Failed to create OpenGL context` under `QT_QPA_PLATFORM=offscreen`; the `qt.qml.binding.removal` warnings.

No further QML module, KF5 plugin or Qt plugin lookup failed: all other `qt5/qml` and `qt5/plugins` misses are `.so.avx2`/`.qmlc` probing or style fallbacks followed by a successful load. The only missing QML modules are the two already known.
