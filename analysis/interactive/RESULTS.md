# Execution review of filelight in the closure-only environment: results

Three automated sessions drove filelight 4:23.08.5-0ubuntu3 inside the pristine noble image
plus the two known QML modules (`filelight-noble-autotest`), under Xvfb + openbox, with
`QML_IMPORT_TRACE`, `QT_DEBUG_PLUGINS`, `kf.*` logging and a timestamped strace of
openat/stat/statx/access/readlink/execve. Every loaded file was mapped to its owning package
with the container's dpkg database and compared with the pristine closure.

| Session | Directory | Purpose |
|---|---|---|
| 1 | `auto-20261012-023522/` | 18 scenarios: scan, hover, navigation, Overview, Scan Folder dialog, Scan Home, Rescan/Stop, zoom, file context menu (Open, Copy, Delete + confirm), folder context menu (Open Terminal Here, Center Map Here, Add to Do Not Scan List), overflow menu (Handbook, About), Configure |
| 2 | `auto2-20261012-024123/` | re-run of the helper-launching actions with `statx` in the strace filter (see below), Configure dialog tabs, Add… file dialog, typed Scan Folder path, Scan Root Folder of the container (28,399 files, 947 MiB) |
| 3 | `auto3-remote-url/` | `filelight sftp://localhost/` |

Screenshots for every step are in each session's `shots/`.

## Packages used outside the pristine closure

Both traced sessions: exactly `qml-module-qtquick-shapes`, `qml-module-org-kde-kcoreaddons`
and `libqt5quickshapes5`, i.e. only what the fix adds. No other file loaded by any scenario
belongs to a package outside filelight's declared closure. No QML module, Qt plugin or KF5
plugin lookup failed in any scenario.

## Helper programs filelight tried to launch and could not find

Qt and KF resolve external executables with `statx`/`access` before forking, so a missing
helper never produces an `execve` and never logs anything (session 1 missed these entirely;
session 2 caught them after widening the filter). Attribution per scenario from
`auto2-*/per-scenario.md`:

| Action | Looked up (in order) | What the user sees without them | Package on noble | Classification |
|---|---|---|---|---|
| Context menu **Open** (`Qt.openUrlExternally`) | `xdg-open`, then Qt's browser fallback list `firefox`, `mozilla`, `google-chrome`, `opera` | nothing happens, no message | `xdg-utils` | Recommends candidate. Present on every Ubuntu desktop (`ubuntu-desktop-minimal` depends on it). Debian's filelight has no relation either. Not SRU material. |
| Context menu **Open Terminal Here** (`KTerminalLauncherJob`) | `konsole`, `systemsettings5`, `xterm` | nothing happens, no message | `konsole` or `xterm` | KF5 design limit, not packaging: it never looks for `gnome-terminal` or `x-terminal-emulator`. On this GNOME host neither konsole nor xterm is installed, so the action is a silent no-op there too. Workaround: `TerminalApplication=gnome-terminal` in `~/.config/kdeglobals`. |
| Overflow **Open Handbook** (`help:/filelight`) | `khelpcenter`, then `kf.guiaddons: Could not find a suitable handler for "help:/filelight"` | nothing happens, warning only in terminal | `khelpcenter` | Suggests at most (would drag in khtml, xapian, kinit). Debian: no relation. |
| Startup (`KCrash`) | `drkonqi`, `drkonqi-coredump-processor` | crash dialog unavailable | `drkonqi` | none; KDE-wide, never per-app. |
| Startup, Qt D-Bus autolaunch | `dbus-launch` | n/a | `dbus-x11` | noise: the Xvfb container has no session bus; a real desktop always has one. |

## Everything else exercised and working on the closure alone

Initial scan, segment tooltips, click-into, Back, Forward, Up, Go to Overview, Scan Folder
(QFileDialog, both from Overview and from Configure > Add…), Scan Home Folder, Scan Root
Folder (full container filesystem), Rescan, Stop, Zoom In/Out, Center Map Here, Add to Do
Not Scan List (persisted to `~/.config/filelightrc`), Copy to clipboard, Delete with KIO
confirmation dialog (file verified gone, via `kio_file` worker), Configure dialog with both
tabs (Scanning: ignore list, Add…, checkboxes; Appearance: colour scheme radios, contrast
slider, show-small-files), About page, window close. Remote URL `sftp://` produces the KIO
dialog "Unable to create KIO worker. Unknown protocol 'sftp'" (`kio-extras` would add it;
Suggests at most).

## Remaining known cosmetic issue

`kf.iconthemes: Icon theme "breeze" not found` in every session: toolbar and menu entries
render as text only (visible in all screenshots). `breeze-icon-theme` is a Recommends-level
candidate; on this GNOME host Adwaita is present via the GTK platform theme.

## Not covered

Drag-and-drop of a folder onto the window (needs a second X client as drag source). Its
code path (`DropperItem`, QtQuick drop handling) uses only linked Qt Quick.

## Tracing artefacts to know about

- Root-window `xwd` captures show secondary top-level windows (Configure dialog) black
  under Xvfb; capturing the window by id (`ft_shotwin`) shows the real content. Not a
  rendering failure (verified with and without `QT_QUICK_BACKEND=software`).
- `qt.qml.diskcache` "Error loading ... from disk cache" lines are first-run cache misses.
- `kf.service.sycoca: Menu "applications-kmenuedit.menu" not found` appeared once during
  the root scan; KService noise.
