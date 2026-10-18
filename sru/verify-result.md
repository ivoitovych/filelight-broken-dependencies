# Verification of filelight 4:23.08.5-0ubuntu3.1 (rebuilt 2026-10-18)

Package under test: `filelight_23.08.5-0ubuntu3.1_amd64.deb`, built by `build-debdiff.sh` in the
`filelight-noble-build` container from the archive source 4:23.08.5-0ubuntu3 plus the attached
debdiff. Lintian: no tags (`lintian.txt`). This is pre-upload evidence with a locally built
package; the formal SRU verification is done later with the package from noble-proposed.

## 1. Rebuilt package versus the archive package

`dpkg-deb -f` of the rebuilt .deb (`verify-newdeb-fields.txt`) compared with `dpkg -s filelight`
of the archive 0ubuntu3 (`evidence/dpkg-s-filelight.txt`): the Depends fields are identical
except for the two added entries, `qml-module-org-kde-kcoreaddons` and
`qml-module-qtquick-shapes`. The rebuild against current noble libraries did not tighten any
`${shlibs:Depends}` version.

## 2. Installation and upgrade paths (`verify-install/`)

Each run installs the rebuilt .deb with `apt-get install` and records the apt transaction,
`apt-get check` and `dpkg --audit`.

| Image | Starting state | apt result | After |
|---|---|---|---|
| `filelight-noble-pristine` (`upgrade-from-pristine.txt`) | filelight 0ubuntu3, modules absent | 1 upgraded, 3 newly installed (both modules + libqt5quickshapes5), 0 to remove | 0ubuntu3.1, both modules `ii`, apt-get check 0, dpkg --audit 0 |
| `filelight-noble-fixed` (`upgrade-modules-already-present.txt`) | filelight 0ubuntu3, modules present | 1 upgraded, 0 newly installed, 0 to remove | 0ubuntu3.1, apt-get check 0, dpkg --audit 0 |
| plain `ubuntu:24.04` (`fresh-install-ubuntu-24.04.txt`) | nothing installed | 378 newly installed (the normal closure plus the two modules), 0 to remove | 0ubuntu3.1, both modules `ii`, apt-get check 0, dpkg --audit 0 |

`verify-install.txt`: the `filelight-noble-verify` image (pristine + the .deb) shows version
0ubuntu3.1, the new Depends, both modules and libqt5quickshapes5 installed, `apt-get check` 0.

## 3. Runtime trace in the verify image (`verify-trace/`)

`run-trace.sh` runs filelight with `QML_IMPORT_TRACE`, `QT_DEBUG_PLUGINS`, `kf.*` logging and
strace, offscreen and under Xvfb.

| Check | Result |
|---|---|
| `grep -c 'is not installed'` in xvfb-errors.txt, xvfb-trace.log, offscreen-trace.log | 0, 0, 0 |
| `grep -c 'Component is not ready'` in the same three files | 0, 0, 0 |
| QML plugins opened (`strace-loaded-qml-plugins.txt`) | `QtQuick/Shapes/libqmlshapesplugin.so`, `QtQuick/Shapes/qmldir`, `org/kde/kcoreaddons/libkcoreaddonsplugin.so`, `org/kde/kcoreaddons/qmldir` |
| Exit codes (`exitcodes.txt`) | step3 134, step4 134 (offscreen QPA, "Failed to create OpenGL context", identical to the pre-fix baseline in `analysis/dynamic/exitcodes.txt`), step5 0, step5-strace 0 (Xvfb) |

The offscreen aborts are an environment limit of the `offscreen` platform plugin, not a package
defect; the Xvfb runs, which have GLX software rendering, exit 0. A completed scan with the
radial map rendered, using the same two modules on top of the archive package, is shown in
`analysis/dynamic-fixed/screenshot-after-scan.png` and in the execution-review screenshots
under `analysis/interactive/`.

## Verdict

PASS. The rebuilt package differs from the archive package only by the two intended Depends;
apt installs both modules automatically on upgrade and on fresh install, removes nothing, and
is a plain version bump where the modules already exist; the fixed runtime shows zero
"is not installed" / "Component is not ready" lines and loads both QML plugins.
