# Interactive trace session (manual testing with full dependency logging)

Purpose: exercise filelight by hand, inside the closure-only container shown on the real
desktop, while every file lookup, plugin/QML load, external program launch and KF5/Qt
diagnostic is recorded. Anything filelight needs that is not in its declared dependency
closure fails visibly here and shows up in the logs.

Environment: image `filelight-noble-fixed` = pristine noble + filelight closure + the two
known QML modules (`qml-module-qtquick-shapes`, `qml-module-org-kde-kcoreaddons`). Runs
as your uid, on your display (XWayland by default, `wayland` optional), with your session
D-Bus passed in, GPU device passed in, scanning a disposable scratch tree.

## Run

```
scripts/interactive-trace.sh            # xcb/XWayland, like an unmodified filelight on GNOME
scripts/interactive-trace.sh wayland    # native Wayland via qtwayland5
```

The terminal shows a `scenario>` prompt. Before each action, type a short label and press
Enter (it is timestamped into `markers.log`). Type `q` when finished. Then:

```
scripts/map-trace.sh analysis/interactive/<timestamp>
```

## Scenario checklist

1. Initial scan of /scratch finishes; map renders; hover segments (tooltips).
2. Click into `a/`, then Back, Forward, Up, Go to Overview, Rescan, Stop mid-scan.
3. Overview page (QuickCharts), then back to the map.
4. Right-click a segment: **Open in file manager**, **Open terminal here**, Copy path,
   **Move to trash** (use `to-trash/`), **Delete** (use `to-delete/`). The bold ones launch
   external programs or KIO workers at runtime.
5. Zoom in / out. Toggle any Appearance settings (Ctrl+,): colour scheme, antialiasing,
   show small files, minimum font size; Scanning tab: add/remove an ignore path (opens a
   folder dialog).
6. Help menu: About Filelight, About KDE, **Handbook (F1)**, Report Bug.
7. File > Open Folder (Ctrl+O): the file dialog; pick a folder.
8. Drag a folder from your file manager onto the window.
9. Optional: scan a remote URL via Ctrl+O or the location field (e.g. `sftp://localhost/`).
10. Quit via Ctrl+Q.

## Outputs (per session directory)

| File | Meaning |
|---|---|
| `filelight.log` | Qt/KF diagnostics (`QML_IMPORT_TRACE`, `QT_DEBUG_PLUGINS`, `kf.*`) |
| `strace.raw` | every openat/stat/access/readlink/execve with timestamps (git-ignored, large) |
| `markers.log` | your scenario labels with timestamps |
| `loaded-paths.txt` | first-time successful loads, with timestamp |
| `path-to-package.txt`, `packages-used.txt` | each loaded file mapped to its owning package via the container's dpkg |
| `packages-used-outside-closure.txt` | **the finding list**: packages used that are not in the pristine closure (control result: only the three fix-added ones) |
| `files-without-package.txt` | loaded files no package owns (generated caches etc.) |
| `execve.txt`, `execve-failed.txt` | external programs launched / attempted |
| `log-errors.txt` | deduplicated error/warning lines |
| `enoent-filtered.txt` | failed lookups under resource dirs (noise-filtered; not findings by themselves) |
| `per-scenario.md` | first-time resource loads grouped under your scenario labels |

Rehearsal result (20 s automatic run, initial scan only): outside-closure packages were
exactly `libqt5quickshapes5`, `qml-module-org-kde-kcoreaddons`, `qml-module-qtquick-shapes`;
no file without a package; no external program executed; Qt/KF errors limited to the
known icon-theme / drkonqi / locale-catalog lines.
