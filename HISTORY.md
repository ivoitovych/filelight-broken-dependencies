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

## Open items
- Interactive manual test session: run the fixed container image on the real display with
  full tracing while scenarios are exercised by hand (segment navigation, context-menu actions
  that launch external programs, settings, about, help, open dialog, drag-and-drop, remote URL),
  then map every loaded path to its package via the container's dpkg database.
- Prepare noble debdiff 4:23.08.5-0ubuntu3.1, test-build and verify in the pristine container,
  draft SRU text, then add a noble task to Launchpad #2084169 with the debdiff attached.
