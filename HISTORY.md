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

## 2026-10-18

### Third-party review round and resubmission prep
- Four independent reviews of revision 11cf52e (debdiff, SRU text, audit, filing guide). All
  four endorsed the two-line control change unchanged; every requested change concerned the
  surrounding text, the test plan, the risk analysis and the filing procedure.
- Rechecked the archive first: noble still at 4:23.08.5-0ubuntu3, nothing in noble-proposed or
  noble-updates, no noble task on any bug, so no rebase was needed.
- Debdiff rebuilt (`sru/build-debdiff.sh`): changelog shortened to under 70 columns, names
  `debian/control`, no longer says "on any system without Plasma"; dead `sed` removed; the
  script now exits non-zero on any failed step. Lintian clean. The rebuilt package's Depends
  equal the archive package's plus the two modules (`sru/verify-newdeb-fields.txt`).
- Verification extended (`sru/verify-result.md`, `sru/verify-install/`): upgrade on the pristine
  image, upgrade where the modules already exist, fresh install on plain ubuntu:24.04, each
  with apt transaction, `apt-get check` and `dpkg --audit`; trace rerun in the new verify image.
- `sru/SRU-TEXT.md` rewritten: VM-based Test Plan with greppable pass/fail and pinned
  noble-proposed, concrete failure modes in "Where problems could occur" (rebuild and shlibs,
  typo, resolver removals, third module, Plasma no-op, per-architecture availability), corrected
  history (oracular 0ubuntu4 already had kcoreaddons, so the 0ubuntu4.1 debdiff added only
  Shapes), devel fixed since questing 4:25.08.1-0ubuntu1 via dh-sequence-qmldeps, LP #2083152
  added to the cluster, suggested bug title.
- `sru/HOWTO-FILE.md` rewritten: description not comment, retitle, nomination via sponsor, no
  Triaged/importance by the contributor, duplicate handling, five-line comment template, then
  verification in noble-proposed, tag swap, aging and post-release monitoring.
- Audit wording qualified: "two missing mandatory Depends for the reported failure, no further
  gap found in any mapped resource or exercised path" instead of "exactly two"; "outside this
  SRU's scope" instead of "not SRU material"; kdeglobals TerminalApplication workaround now
  sourced to KIO's `KTerminalLauncherJob` and marked as not exercised.
- README: status line, three-layer reading guide for sponsors, LP #2083152, first qmldeps
  version. Host-disk and Docker notes removed from this log.

### Second review pass (same day)
- Three reviewers re-read 2b1cfcb; all said file after text fixes, no rebuild. Applied: Test Plan
  step 2 expects a non-zero count (4 in all pre-fix traces: each module is reported twice), both
  grep checks use `timeout`; step 6 now describes a real upgrade with the modules pre-installed;
  "reporter" became "submitter"; one bug title; the "no other package depends on filelight"
  sentence was wrong (the kdeutils metapackage does, `>= 4:23.08.5`) and was corrected; LP
  #2083152 described precisely (kcoreaddons half, Kubuntu 24.10, Fix Released); Debian #1030549
  checked against the BTS. HOWTO no longer suggests marking duplicates. README conclusion
  aligned with the audit. `build-debdiff.sh` now checks the debdiff and lintian exit statuses
  (script-only change; the committed artefacts are from the 01:48 UTC build).

### Filed on Launchpad (04:26–04:40 CEST)
- LP #2084169, driven through the browser with the user watching, each step checked against the
  archive and the Launchpad API first (noble still 4:23.08.5-0ubuntu3, nothing in -proposed or
  -updates, bug untouched since 2025-07-03, debdiff checksum equal to the committed one, control
  hunk applies to the archive control).
- Title changed to the SRU title; description replaced with the four SRU sections, original
  oracular text kept below a heading. "Nominate for series" refused ("You do not have permission
  to nominate this bug"), left to the sponsor as planned. Comment posted with the debdiff attached
  and flagged as a patch; submitter subscribed; ubuntu-sponsors subscribed. All confirmed through
  the API (attachment present, comment by yaroslav-voytovych at 02:37:55 UTC, subscribers
  linneris, yaroslav-voytovych, ubuntu-sponsors).

### Public re-verification (after filing)
- Anonymous fetch of the bug page, the API and the attachment: new title and description render
  with all four sections and the original report below; comment and patch-flagged attachment
  present; the downloaded debdiff has the same sha256 as the committed one; direct subscribers
  linneris, yaroslav-voytovych, ubuntu-sponsors; two notification mails already in the
  kubuntu-bugs list archive.
- Flaw found: every task on the bug is closed, so `searchTasks(bug_subscriber=ubuntu-sponsors)`
  with the default (open) status filter, which is what the sponsoring queue report uses, does not
  return it. Until a bug supervisor adds the noble task the request is invisible in the sponsors'
  queue. HOWTO updated: ask in #ubuntu-bugs or #kubuntu-devel now, not in two weeks.

### Watcher and channel
- `scripts/watch-sru.sh`: daily anonymous check of LP #2084169 (tasks, tags, comments,
  subscribers) and of filelight in noble, noble-proposed and noble-updates; prints a CHANGE block
  and exits 10 when anything moved. Baseline recorded.
- Reviewer pass on the watcher: a failed download could previously be recorded as a result (the
  first baseline indeed contained a curl error line) and overwrite the baseline. Now every query
  must succeed or the run aborts with exit 1 and the baseline is kept; archive fetched over HTTPS;
  notification only on change. `scripts/systemd/` holds a user service (SuccessExitStatus=10)
  and a daily timer (Persistent=true) with an installer; installation is the user's call.
- HOWTO: the documented place to ask for the noble task is the Matrix room #devel:ubuntu.com
  (#ubuntu-bugs as fallback); one post in one place; name the 0ubuntu3.1 debdiff because the old
  oracular debdiff is also patch-flagged. Plan B after two weeks: merge proposal against
  `kubuntu_noble_archive`.

### Noble-task request posted (07:03 CEST)
- One message in the Matrix room #devel:ubuntu.com (Element web, the user's own account, sent
  after confirmation): asks a bug supervisor to add the noble task and set the devel task Fix
  Released, explains the closed-task invisibility, and names the 0ubuntu3.1 debdiff. Ubottu
  expanded the bug link in the room. No other channel used.

## Open items
- (done automatically, see 02:35) Manual session remains available via
  `scripts/interactive-trace.sh` for a real-desktop run if wanted.
- Wait for a bug supervisor to add the noble task to LP #2084169 (requested in #devel:ubuntu.com
  on 2026-10-18); fallback after a few quiet days: #ubuntu-bugs. Then wait for a sponsor; answer
  review requests; merge proposal against `kubuntu_noble_archive` only after two silent weeks.
- After acceptance into noble-proposed: run the Test Plan on a clean noble GNOME system with the
  archive build, post the result, swap `verification-needed-noble` for `verification-done-noble`,
  then watch for a week after release (see `sru/HOWTO-FILE.md`).
