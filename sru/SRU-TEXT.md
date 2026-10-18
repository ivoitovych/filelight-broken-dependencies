# [SRU] filelight (noble): missing runtime dependencies on qml-module-qtquick-shapes and qml-module-org-kde-kcoreaddons

Suggested bug title: `[SRU] filelight: scan page never loads, missing Depends on qml-module-qtquick-shapes and qml-module-org-kde-kcoreaddons`

[ Impact ]

filelight 4:23.08.5-0ubuntu3 in Ubuntu 24.04 LTS (noble) starts and shows its window, but the scan page never loads. Clicking Scan Home Folder, Scan Root Folder or Scan Folder does nothing, and the terminal shows:

    qrc:/ui/MapPage.qml:9 module "QtQuick.Shapes" is not installed
    qrc:/ui/MapPage.qml:8 module "org.kde.kcoreaddons" is not installed
    QQmlComponent: Component is not ready

The application cannot perform its only function. Both QML modules are imported by filelight's compiled-in QML but are not declared in debian/control, so they are present only where something else installs them (KDE Plasma does; Ubuntu Desktop with GNOME does not).

The fix adds the two missing dependencies, qml-module-org-kde-kcoreaddons and qml-module-qtquick-shapes, to the filelight binary package's Depends. No application source changes are included.

[ Test Plan ]

Primary recipe (any tester, no knowledge of the package needed). Use a disposable noble system without KDE Plasma, for example an Ubuntu Desktop 24.04 VM. The two QML modules must be absent at the start; check with:

    dpkg -l qml-module-qtquick-shapes qml-module-org-kde-kcoreaddons 2>/dev/null | grep '^ii' || echo "modules absent (good)"

1. Install the current package and record the version:

       sudo apt install filelight
       dpkg-query -W filelight          # expect 4:23.08.5-0ubuntu3

2. Reproduce the failure: launch `filelight` from a terminal, click Scan Home Folder. Nothing happens. Greppable check:

       filelight /usr 2>&1 | grep -c 'is not installed'     # expect 2 (close the window to end it)

3. Close filelight. Enable noble-proposed with pinning so only filelight is taken from it, following https://wiki.ubuntu.com/Testing/EnableProposed, then:

       sudo apt update
       sudo apt install filelight/noble-proposed

   apt must report that qml-module-org-kde-kcoreaddons, qml-module-qtquick-shapes and libqt5quickshapes5 will be installed and that nothing will be removed.

4. Record the installed version and origin:

       dpkg-query -W filelight          # expect 4:23.08.5-0ubuntu3.1
       apt-cache policy filelight       # Installed from noble-proposed
       dpkg -l qml-module-qtquick-shapes qml-module-org-kde-kcoreaddons | grep '^ii'   # both present

5. Launch `filelight`, click Scan Home Folder, wait for the scan to finish. The radial map renders; clicking a segment navigates into it; Back returns. Greppable check:

       filelight /usr 2>&1 | grep -c 'is not installed'     # expect 0

6. Regression check on a system that already has the modules (any Kubuntu or Plasma install, or the VM after step 4): `sudo apt install filelight/noble-proposed` upgrades only filelight, removes nothing, and the scan still works.

Alternative, fully scripted: the investigation repository https://github.com/ivoitovych/filelight-broken-dependencies contains Dockerfiles for a pristine noble image and a verify image, and a trace script that runs filelight under Xvfb with QML import tracing and strace. With the fixed package the trace shows zero "is not installed" and zero "Component is not ready" lines and both QML plugins loading from /usr/lib/x86_64-linux-gnu/qt5/qml/. The steps above are sufficient on their own; the repository is supporting evidence.

[ Where problems could occur ]

The change is two added Depends on packages that have been in noble/universe since release: qml-module-org-kde-kcoreaddons (74 KB installed) and qml-module-qtquick-shapes (86 KB installed, pulling libqt5quickshapes5, 349 KB). All three are QML/library-only packages without maintainer scripts. The places where this update could still go wrong:

1. The package is rebuilt, not metadata-edited. The build daemons compile filelight against the current noble libraries, so ${shlibs:Depends} could come out tighter than in the April 2024 build and an upgrade could pull in newer library versions that are already in noble-updates. The locally rebuilt package was compared field by field with the archive package: the only Depends difference is the two added modules (see sru/verify-result.md in the repository). Test Plan step 3 shows any extra packages apt wants to install.
2. A typo in either package name would make filelight uninstallable from noble-proposed. The exact built .deb was installed with apt in a pristine noble container and both names resolved (Test Plan steps 3 and 4 repeat this on the archive build).
3. The dependency resolver could propose removals or unexpected changes on upgrade. Test Plan step 3 requires "0 to remove".
4. The scan could still fail after the modules arrive if a third module were missing. A static review of every QML import and a traced run of every user-facing action in the fixed environment found none; Test Plan step 5 checks the user-visible result.
5. Systems that already have the modules (Plasma) see only the version bump. Test Plan step 6 covers this.
6. A dependency missing on one architecture would make filelight uninstallable there. Both modules (and libqt5quickshapes5) are published in noble for every architecture filelight is built on: amd64, arm64, armhf, ppc64el, riscv64 and s390x.

If the update were wrong in one of these ways, filelight would remain as unusable as it is today; no other package depends on filelight.

[ Other Info ]

* Fixed in the development release and all later releases: Ubuntu switched filelight to dh-sequence-qmldeps (automatic QML dependencies) with 4:25.08.1-0ubuntu1 in questing. resolute (4:25.12.3-0ubuntu1), stonking (4:26.08.1-0ubuntu1) and the development series carry the generated dependencies; stonking's binary package depends on qml6-module-qtquick-shapes and qml6-module-org-kde-coreaddons. jammy ships the pre-QML 4:21.12.3 and is not affected. noble is therefore the only supported release with the defect.
* Debian declared qml-module-org-kde-kcoreaddons in 4:22.12.2-1 (Debian #1030549) and fixed the Shapes dependency through dh-sequence-qmldeps in 4:25.03.90-1 (Debian #1082018).
* History on this bug: oracular's 4:23.08.5-0ubuntu4 had already added qml-module-org-kde-kcoreaddons, so the earlier debdiff here (23.08.5-0ubuntu4.1, by Maia Everett) added only qml-module-qtquick-shapes. It expired as Won't Fix at oracular's end of life, not on technical grounds. noble's package has neither module, so the noble debdiff adds both.
* Same defect reported in LP: #2097146, LP: #2089868 and LP: #2083152; upstream KDE bug 496765 was closed as a downstream packaging issue.
* Proposed upload: filelight 4:23.08.5-0ubuntu3.1 (debdiff attached: filelight_23.08.5-0ubuntu3.1.debdiff). Changes limited to debian/control and debian/changelog. Built and lintian-clean in a noble build container; installed and traced in a pristine noble container.
* The reporter will verify the package from noble-proposed following the Test Plan and will watch for regressions after release.
