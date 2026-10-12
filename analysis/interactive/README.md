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

## Automated variant (no person at the keyboard)

`scripts/autotest-lib.sh` drives the same closure-only image under Xvfb plus openbox
(image `filelight-noble-autotest`, Dockerfile `container/Dockerfile.autotest`; openbox is
needed so synthetic input gets keyboard focus). Source it and call:

```
source scripts/autotest-lib.sh
ft_start analysis/interactive/auto-$(date +%Y%m%d-%H%M%S)   # Xvfb, openbox, traced filelight /scratch
ft_mark "scenario label"        # timestamped marker (container clock, matches strace -tt)
ft_click X Y [button]           # ft_move, ft_key, ft_type likewise
ft_shot name                    # root-window screenshot -> shots/name.png
ft_shotwin name 'Title regex'   # capture one top-level window by id (dialogs show black in
                                #   root captures under Xvfb; by-id capture is accurate)
ft_stop
scripts/map-trace.sh <dir>
```

Coordinates used in the recorded sessions (1280x800 screen, window maximised):
toolbar Back 858,20 / Forward 921,20 / Up 978,20 / Go to Overview 1062,20 / Rescan 1160,20 /
Stop 1222,20 / overflow (Zoom, Configure, Handbook, About) 1262,20; Overview buttons Scan
Folder 508,474 / Scan Home 623,474 / Scan Root 754,474; context menu entries are 30 px apart
starting ~15 px below the click point (file: Open, Copy, Delete; folder: Open, Open Terminal
Here, Center Map Here, Add to Do Not Scan List, Rescan, Copy, Delete).

Important tracing detail: Qt and KF resolve helper executables with `statx`/`access` before
forking, so a missing helper never produces an `execve`. The strace filter therefore includes
`statx,faccessat,faccessat2`, and the mapper reports failed PATH/libexec lookups as
"helper programs looked up but missing", attributed per scenario.

Results of the recorded sessions: see `RESULTS.md` in this directory.
