# Work log

Chronological record of what was done in this repository. Times are local (CEST).

## 2026-10-12

### 01:00 Problem observed
- `apt-get install filelight` on Ubuntu 24.04.5 (GNOME desktop) installed 4:23.08.5-0ubuntu3
  cleanly. Launching it opened a window whose buttons did nothing. Terminal output:
  `module "QtQuick.Shapes" is not installed` and `module "org.kde.kcoreaddons" is not installed`
  from `qrc:/ui/MapPage.qml`, followed by `QQmlComponent: Component is not ready`.

### 01:15 Repository created, first investigation
- `git init -b main` in `~/exp/filelight-broken-dependencies`.
- Verified apt/dpkg state is consistent: `apt-get check`, `dpkg --audit`, `apt-get -f install -s`,
  `dpkg -V filelight`, `ldd` all clean. No holds, no PPA/snap/flatpak copy involved.
- Confirmed every package in the deb's `Depends:` is installed, yet the two QML modules are
  absent from disk and their packages (`qml-module-qtquick-shapes`,
  `qml-module-org-kde-kcoreaddons`) are not in the dependency list of the deb.
- Found nothing else on the system pulls them in (only Plasma packages depend on them, which
  is why Kubuntu users never see the bug).
- Located prior reports: Launchpad #2084169 (oracular SRU, Won't Fix at EOL), #2097146
  (Ubuntu task New, Debian fixed), #2089868 (Confirmed); KDE bug 496765 closed as downstream.
- Commit `f922ccb`: README with findings, `evidence/` with raw command output.

### 01:25 Packaging source located
- Downloaded the exact packaging the installed binary was built from
  (`filelight_23.08.5-0ubuntu3.{dsc,debian.tar.xz}` from archive.ubuntu.com) and confirmed it
  matches branch `kubuntu_noble_archive` of the Kubuntu packagers git on Launchpad.
- `debian/control` hand-lists four QML modules; no automatic QML dependency scanning.
- Debian's control for the same upstream version already carried
  `qml-module-org-kde-kcoreaddons` (since 4:22.12.2-1, Feb 2023). Debian later switched to
  `dh-sequence-qmldeps` (4:25.03.90-1), which fixed Shapes. Current Ubuntu releases use the
  Qt6 build with qmldeps; only noble still has the hand-written list.
- Retrieved the never-landed oracular debdiff from #2084169 as a model.
- Commits `97e3a67`, `d67321e`: `reference/` directory, journal and dpkg.log evidence.
- Conclusion at this point: fix vehicle is a noble SRU (4:23.08.5-0ubuntu3.1), not a backport;
  the bug is already reported, so a noble task plus debdiff on the existing bug is the route.

### 01:33 Full dependency audit started
- Question raised: is the deficiency found on one long-lived machine complete?
  Decided to audit two ways, static (source review) and dynamic (execution tracing), both
  against a pristine environment rather than the original host.
- Built `filelight-noble-pristine` (container/Dockerfile): `ubuntu:24.04` + `apt install
  filelight` with Recommends, plus strace/xvfb/xdotool. Package lists before and after tooling
  saved; tooling added no Qt/KF/QML/icon packages.
- Downloaded upstream `filelight-23.08.5` source; extracted all QML imports per file, icon
  names, C++ runtime-by-name calls, CMake runtime hints (`analysis/static/`).
- Downloaded Debian's as-built `filelight_23.08.5-1_amd64.deb` from snapshot.debian.org and
  diffed its Depends against noble's: the only difference is kcoreaddons.
- Commit `2f8ded7`.

### 01:36 Static and dynamic reviews run in parallel
- Static review (`analysis/static/static-review.md`, `closure.txt`): mapped every QML module,
  the org.kde.desktop style, kio_file worker, xcb plugin, icon themes, translations, handbook,
  help viewer, file dialog and menubar to the providing noble package and checked each against
  the dependency closure. Result: no hard gaps beyond the two modules. Icon theme reachable only
  via a Recommends chain; khelpcenter, kio-extras not in closure (optional).
- Dynamic review pass 1 (`analysis/dynamic/`): offscreen, strace and Xvfb runs with
  `QML_IMPORT_TRACE`, `QT_DEBUG_PLUGINS`, `kf.*` logging. Reproduced both failures; no other
  QML/KF5/Qt plugin lookup failed; surfaced `Icon theme "breeze" not found` and missing drkonqi.
  Offscreen platform aborts on OpenGL (environmental); Xvfb runs exit 0.
- Commit `5410562`.

### 01:40 Dynamic review pass 2
- Built `filelight-noble-fixed` (container/Dockerfile.fixed): pristine + only the two modules
  + x11-apps for screenshots. Reran under Xvfb letting the scan complete.
- Scan page loads, 1,668-file scan completes, radial map renders
  (`analysis/dynamic-fixed/screenshot-after-scan.png`). No new errors. Toolbar renders text-only
  (icon theme). Settings/help/open-dialog keystrokes did not reach the window (no WM in Xvfb);
  recorded as a coverage limit covered by the static track.
- Commit `aca5eda`.

### 01:44 Consolidated audit
- `DEPENDENCY-AUDIT.md`: method, classified result (Bin 1 Depends: the two modules; Bin 2
  Recommends at most: icon theme; Bin 3 Suggests/none: khelpcenter, kio-extras, drkonqi),
  noise, coverage limits, conclusion that the deficiency is exactly two missing Depends.
- Commit `8640da0`.

### 02:10 Interactive trace harness and SRU preparation started
- Smoke-tested running the closure-only container's filelight on the real desktop
  (XWayland, uid 1000, GPU device). Works.
- Wrote `scripts/interactive-trace.sh` (launch with scenario-marker prompt) and
  `scripts/map-trace.sh` (map every loaded file to its package via the container's dpkg,
  diff against the pristine closure, list executed external programs, split per scenario).
  Rehearsal found and fixed: merged-usr `/lib` paths not resolved by `dpkg -S`; multi-owner
  `dpkg -S` output; missing session D-Bus in the container (now passed through). Control
  result after fixes: outside-closure set is exactly the three fix-added packages.
- `analysis/interactive/README.md`: how to run, scenario checklist, output description.
- Noted host root filesystem at 96 % (18 GB free); Docker holds 32 GB images / 41 GB build
  cache from unrelated work. Not pruned.
- Started preparation of the noble SRU debdiff (4:23.08.5-0ubuntu3.1) with a dedicated build
  container, end-to-end verification against the pristine image, lintian, and SRU text
  (`sru/`).

### 02:16 Noble SRU prepared and verified
- `container/Dockerfile.build`: noble build image with deb-src and filelight build-deps.
- `sru/build-debdiff.sh`: fetches 4:23.08.5-0ubuntu3 source, adds the two Depends, writes
  changelog 4:23.08.5-0ubuntu3.1 (LP: #2084169), builds source and binary, runs debdiff and
  lintian. Lintian: no tags.
- `container/Dockerfile.verify`: pristine image + the rebuilt deb. apt pulled both QML modules
  in automatically; trace shows zero "is not installed" / "Component is not ready" lines and
  both plugins loaded (`sru/verify-result.md`).
- `sru/SRU-TEXT.md` (Impact / Test Plan / Where problems could occur / Other Info) and
  `sru/HOWTO-FILE.md` (add noble task to LP #2084169, attach debdiff, subscribe sponsors).
- Housekeeping: untracked three raw strace dumps that had slipped into earlier commits;
  `.gitignore` now ignores `**/*.raw`.

### 02:35 Automated execution review (replaces the manual session)
- `container/Dockerfile.autotest` (fixed image + openbox for keyboard focus) and
  `scripts/autotest-lib.sh` (host-driven xdotool/xwd helpers with scenario markers).
- Session 1: 18 scenarios through toolbar, Overview, context menus, overflow menu, Configure.
  Found that Qt/KF resolve helpers with `statx`, invisible to the original strace filter.
- Session 2: statx-aware filter, software renderer, Configure tabs, Add… dialog, typed Scan
  Folder, full root scan. Attributed missing helpers per action: Open → xdg-open (+ browser
  fallbacks); Open Terminal Here → konsole/xterm; Handbook → khelpcenter.
- Session 3: `sftp://` URL → KIO "Unknown protocol" dialog (kio-extras).
- Outside-closure package set in every session: exactly the three fix-added packages.
- Found and documented: root-window xwd shows dialogs black under Xvfb (capture by id works);
  mapper filters for merged-usr paths, multi-owner files, directories, QML import-path noise.
- `analysis/interactive/RESULTS.md` written; audit updated with the execution-review table.
- Host note: this GNOME machine has xdg-utils and gnome-terminal but no konsole/xterm, so
  "Open Terminal Here" is a silent no-op here as well (KF5 looks only for konsole/xterm).

## 2026-10-13

### Repository published
- Created the public repository https://github.com/ivoitovych/filelight-broken-dependencies
  and pushed `main` (remote `origin`). Replaced the repository-link placeholder in
  `sru/SRU-TEXT.md` with the URL.
- Note on the 02:10 entry above: by 06:40 on 2026-10-12 the Docker footprint on this host was
  2.8 GB of images and 78 MB of build cache with 118 GB free on the root filesystem; the earlier
  figures no longer apply.

## Open items
- (done automatically, see 02:35) Manual session remains available via
  `scripts/interactive-trace.sh` for a real-desktop run if wanted.
- File the SRU (needs a Launchpad account): add a noble task to LP #2084169, paste
  `sru/SRU-TEXT.md`, attach `sru/filelight_23.08.5-0ubuntu3.1.debdiff`, subscribe
  ubuntu-sponsors. See `sru/HOWTO-FILE.md`.
