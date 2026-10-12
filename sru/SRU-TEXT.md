# [SRU] filelight: missing runtime dependencies on qml-module-qtquick-shapes and qml-module-org-kde-kcoreaddons (noble)

[ Impact ]

On Ubuntu 24.04 LTS (noble) systems without KDE Plasma (for example Ubuntu Desktop with GNOME), filelight 4:23.08.5-0ubuntu3 starts and shows its window, but the scan page never loads. The terminal shows:

    module "QtQuick.Shapes" is not installed
    module "org.kde.kcoreaddons" is not installed

The application is unusable. Both QML modules are imported by filelight's QML UI but are not declared in debian/control, so they are only present by accident on Plasma systems.

The fix adds the two missing dependencies, qml-module-org-kde-kcoreaddons and qml-module-qtquick-shapes, to the filelight binary package. No code changes.

[ Test Plan ]

1. On a clean noble system without KDE Plasma (a fresh ubuntu:24.04 container with an X server, or an Ubuntu Desktop VM), run:

       sudo apt install filelight
       filelight /usr

2. Before the fix: the two errors above are printed in the terminal, and the window shows no scan (the radial map never appears).
3. Enable noble-proposed, then run `sudo apt install filelight/noble-proposed`.
4. After the fix: apt pulls in qml-module-org-kde-kcoreaddons and qml-module-qtquick-shapes automatically, no "is not installed" error is printed, and the radial map renders.

A reproducible container-based check exists in the investigation repository (link to be added when published): the container/ directory holds the Dockerfiles (pristine noble image, build image, verify image) and the analysis/ directory holds the trace script and results (xvfb + strace). With the fixed package, the trace shows no "is not installed" or "Component is not ready" lines, and QtQuick/Shapes and org/kde/kcoreaddons are loaded from /usr/lib/x86_64-linux-gnu/qt5/qml/.

[ Where problems could occur ]

The change only adds two dependencies on existing noble/universe packages, qml-module-org-kde-kcoreaddons (74 KB installed) and qml-module-qtquick-shapes (86 KB installed, which in turn pulls in libqt5quickshapes5, 349 KB). All three are library/QML-only packages with no executables and no maintainer scripts, already in noble since release. The only new behaviour is the dependency resolver installing them on upgrade; on systems that already have them (any Plasma install) the upgrade is a no-op apart from the version bump. There are no code changes, so the binary is functionally identical to the current one except that its QML scan page can now load.

[ Other Info ]

* Debian has declared qml-module-org-kde-kcoreaddons since 4:22.12.2-1, and fixed the Shapes dependency by moving to dh-sequence-qmldeps in 4:25.03.90-1 (Debian #1082018).
* All current Ubuntu releases ship the Qt6 build with qmldeps, so only noble is affected.
* The identical fix for oracular (23.08.5-0ubuntu4.1) was proposed in LP: #2084169 and expired as Won't Fix at EOL.
* Related reports: LP: #2097146, LP: #2089868, KDE bug 496765 (closed downstream).
* Proposed upload: filelight 4:23.08.5-0ubuntu3.1 (debdiff attached: filelight_23.08.5-0ubuntu3.1.debdiff).
