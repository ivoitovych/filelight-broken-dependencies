# filelight "broken dependencies" investigation

Date: 2026-10-12. Host: Ubuntu 24.04.5 LTS (noble), GNOME desktop, no Plasma installed.

## Symptom

`filelight` (4:23.08.5-0ubuntu3, noble/universe) installs cleanly and opens a
window, but the start-page buttons do nothing and the terminal shows:

```
QQmlComponent: Component is not ready
file:///usr/lib/x86_64-linux-gnu/qt5/qml/org/kde/kirigami.2/PageRow.qml:914: Error: Error while loading page:
  qrc:/ui/MapPage.qml:9 module "QtQuick.Shapes" is not installed
  qrc:/ui/MapPage.qml:8 module "org.kde.kcoreaddons" is not installed
```

Full capture: `evidence/user-reported-output.txt`.

## What is NOT wrong

- apt and dpkg are fully consistent: `apt-get check`, `dpkg --audit`,
  `apt-get -f install -s` all report nothing. No held packages.
- Every package in filelight's `Depends:` is installed (`evidence/dpkg-s-filelight.txt`).
- The ELF binary has no unresolved shared libraries (`evidence/ldd-filelight.txt`).
- `dpkg -V filelight` reports no modified/missing files.
- No snap, flatpak or PPA copy of filelight is involved; it came from
  `archive.ubuntu.com noble/universe` via `apt-get install filelight`
  on 2026-10-12 01:00 (`evidence/apt-history-install.txt`).

So this is not a broken apt state. It is a packaging bug: the deb's
dependency list is incomplete.

## Root cause

filelight's compiled-in QML (`qrc:/ui/MapPage.qml`) imports ten modules
(`evidence/filelight-qml-imports.txt`). Two of them are not provided by any
package in filelight's dependency closure:

| QML import                | Providing package                 | In filelight Depends? | Installed? |
|---------------------------|-----------------------------------|-----------------------|------------|
| `QtQuick.Shapes 1.15`     | `qml-module-qtquick-shapes`       | no                    | no         |
| `org.kde.kcoreaddons 1.0` | `qml-module-org-kde-kcoreaddons`  | no                    | no         |

(`evidence/qml-module-dirs.txt` shows the other eight resolve to installed packages.)

Nothing else on this machine pulls them in either. The only reverse
relations are from Plasma packages (`plasma-workspace`, `plasma-desktop`,
`systemsettings`, ...) and a `Breaks:` from `libkf5coreaddons5`. On a
Kubuntu system these modules are always present as a side effect of
Plasma, which is why the bug is masked there and shows up on GNOME/Ubuntu
Desktop installs.

QML module imports are resolved at runtime, so neither apt nor `ldd` can
detect the gap. The failing component is the Kirigami page that hosts the
scan UI, which is why the window appears but does nothing.

## Upstream / distro tracking

- Launchpad #2084169 "[SRU] Oracular: Missing dependency on
  qml-module-qtquick-shapes" (filelight 23.08.5, Won't Fix for 24.10;
  noble was never targeted). Proposed debdiff added exactly this Depends.
- Launchpad #2097146 "Fails without qml-module-qtquick-shapes package"
  (Ubuntu task: New; Debian task: Fix Released via Debian #1082018).
- Launchpad #2089868 "Window opens, fails to start scan (QQmlComponent:
  Component is not ready)" (Confirmed; workaround confirmed by reporter).
- Arch FS#76849 and Alpine aports #15795 report the same class of missing
  runtime QML dependency (kdeclarative / kcoreaddons) for filelight.
- KDE MR utilities/filelight!161 adds Shapes/Layouts/Window to the upstream
  CMake dependency hints so packagers pick them up.

None of the Ubuntu fixes were backported to noble; the noble package is
still 4:23.08.5-0ubuntu3 with the incomplete Depends.

## Fix

Install the two missing QML modules (both are in noble/universe, ~160 KB total):

```
sudo apt install qml-module-qtquick-shapes qml-module-org-kde-kcoreaddons
```

No reinstall of filelight is needed; QML modules are discovered at launch.

## Reproduction / verification commands

```
dpkg -s filelight | grep ^Depends
strings -n 6 /usr/bin/filelight | grep '^import ' | sort -u
ls -d /usr/lib/x86_64-linux-gnu/qt5/qml/QtQuick/Shapes /usr/lib/x86_64-linux-gnu/qt5/qml/org/kde/kcoreaddons
apt-cache policy qml-module-qtquick-shapes qml-module-org-kde-kcoreaddons
```
