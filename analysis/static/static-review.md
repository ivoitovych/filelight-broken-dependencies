# Static review of runtime-by-name resources: filelight 4:23.08.5-0ubuntu3 on noble

## Method

- `analysis/dynamic/pkgs-after-filelight.txt` did NOT exist, so the closure is the approximation:
  `apt-cache depends --recurse --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances filelight | grep '^[a-z]' | sort -u` -> `closure.txt` (1226 names, includes Recommends, includes some `:i386` multiarch noise).
- Chains were computed with a BFS over `apt-cache depends` (Depends only, or Depends+Recommends) from `filelight`.
  "Depends-only" means the package is reachable without Recommends (survives `--no-install-recommends`).
- Files were checked with `dpkg -S` / `dpkg -L` on this host (filelight and its Recommends-closure are installed here) and `apt-cache show`.
- filelight itself: Depends = qml-module-org-kde-kirigami2, qml-module-org-kde-qqc2desktopstyle, qml-module-org-kde-quickcharts, qml-module-qt-labs-platform, kio, libkf5{configcore,coreaddons,i18n,kiocore,kiogui,kiowidgets,widgetsaddons,xmlgui}5, libqt5{core,gui,widgets,qml,quick,quickcontrols2}, no Recommends/Suggests.

## Table

| Resource | Looked-up file/path | Providing noble package (version) | In closure? | Severity if missing | Proposed relation |
|---|---|---|---|---|---|
| QML QtQuick 2.15 | qt5/qml/QtQuick.2/qmldir | qml-module-qtquick2 5.15.13+dfsg-1ubuntu0.1 | yes, Depends: filelight -> qqc2desktopstyle -> qml-module-qtquick2 (also via quickcontrols2/kirigami) | hard failure | none (transitive) |
| QML QtQuick.Controls 2.15 | qt5/qml/QtQuick/Controls.2/qmldir | qml-module-qtquick-controls2 5.15.13+dfsg-1 | yes, Depends: via qml-module-org-kde-qqc2desktopstyle / kirigami2 | hard failure | none (transitive) |
| QML QtQuick.Layouts 1.15 | qt5/qml/QtQuick/Layouts/qmldir | qml-module-qtquick-layouts 5.15.13+dfsg-1ubuntu0.1 | yes, Depends: via qqc2desktopstyle | hard failure | none (transitive) |
| QML QtQuick.Window 2.15 | qt5/qml/QtQuick/Window.2/qmldir | qml-module-qtquick-window2 5.15.13+dfsg-1ubuntu0.1 | yes, Depends: via qqc2desktopstyle | hard failure | none (transitive) |
| QML QtQuick.Shapes 1.15 | qt5/qml/QtQuick/Shapes/qmldir | qml-module-qtquick-shapes 5.15.13+dfsg-1ubuntu0.1 | NO (known gap) | hard failure | Depends (known) |
| QML Qt.labs.platform 1.1 | qt5/qml/Qt/labs/platform/qmldir | qml-module-qt-labs-platform 5.15.13+dfsg-1 | yes, Depends: filelight direct | hard failure | already Depends |
| QML org.kde.kirigami 2.19 | qt5/qml/org/kde/kirigami.2/qmldir | qml-module-org-kde-kirigami2 5.115.0-0ubuntu6 (Depends libkf5kirigami2-5) | yes, Depends: filelight direct | hard failure | already Depends |
| QML org.kde.kcoreaddons 1.0 | qt5/qml/org/kde/kcoreaddons/qmldir | qml-module-org-kde-kcoreaddons 5.115.0-0ubuntu5 | NO (known gap) | hard failure | Depends (known) |
| QML org.kde.quickcharts 1.0 | qt5/qml/org/kde/quickcharts/qmldir | qml-module-org-kde-quickcharts 5.115.0-0ubuntu4 | yes, Depends: filelight direct | hard failure | already Depends |
| QQC2 style org.kde.desktop | qt5/qml/QtQuick/Controls.2/org.kde.desktop/ (NOT qml/org/kde/desktop/qmldir, which does not exist) + qt5/plugins/kf5/kirigami/org.kde.desktop.so | qml-module-org-kde-qqc2desktopstyle 5.115.0-0ubuntu4 | yes, Depends: filelight direct | hard failure (QML falls back to Default style; map still works but UI differs) | already Depends |
| org.kde.desktop style's own deps | style needs QtQuick.Templates, QtGraphicalEffects, QtQml.Models, org.kde.kirigami, org.kde.sonnet; links libkf5configwidgets5, libkf5iconthemes5, libqt5widgets (uses QStyle of the QApplication; no plasma-integration required) | qml-module-qtquick-templates2, qml-module-qtgraphicaleffects, qml-module-qtqml-models2, qml-module-org-kde-sonnet (declared Depends of qqc2desktopstyle) | yes, Depends (all declared by qqc2desktopstyle) | hard failure | none (transitive) |
| Icon names (application-exit, document-open, edit-copy, edit-delete, folder, folder-open, go-home, go-up, help-browser, list-remove, process-stop, user-home, utilities-terminal, view-refresh, zoom-in/out, go-previous, go-next) | icon theme lookup via QIcon::fromTheme | adwaita-icon-theme 46.0-1 (all found in /usr/share/icons/Adwaita on this host); breeze-icon-theme 4:5.115.0-0ubuntu3 is NOT present | adwaita-icon-theme: yes, but ONLY via Recommends: filelight -Depends-> libqt5gui5t64 -Recommends-> qt5-gtk-platformtheme -Depends-> libgtk-3-0t64 -Depends-> adwaita-icon-theme. With `--no-install-recommends` no full theme; only hicolor-icon-theme (0.17-2, only Depends via libgtk) and nothing guaranteed. breeze-icon-theme: no | cosmetic (missing toolbar/menu icons; text labels remain) | none or Recommends breeze-icon-theme (see below) |
| Icon names `configure`, `folder-root` | same | in neither Adwaita nor hicolor on this host (0 matches); only breeze/Humanity/Yaru-type themes ship them | no | cosmetic | none |
| Do kirigami2 / libkf5kirigami2-5 / qqc2desktopstyle / libkf5iconthemes5 / kio pull breeze-icon-theme? | apt-cache depends | n.a. | No: none of them has Depends/Recommends on any icon theme. libkf5iconthemes5 Recommends only libkf5iconthemes-bin; kio Recommends only switcheroo-control; libkf5iconthemes-data has none. Only breeze-icon-theme itself Depends hicolor-icon-theme | n.a. | n.a. |
| App icon `filelight` | /usr/share/icons/hicolor/{16..128}/apps/filelight.png | filelight (6 PNGs, via `dpkg -L`) | yes, shipped by filelight itself | n.a. | n.a. |
| KIO file worker (KIO::del, KDirLister, upUrl) | qt5/plugins/kf5/kio/kio_file.so (Ubuntu names it kio_file.so, not file.so) | kio 5.115.0-0ubuntu6 (`dpkg -S` confirmed) | yes, Depends: filelight direct | hard failure | already Depends |
| KIO other bundled workers (kio_trash, kio_http, kio_ftp, kio_help, kio_remote, kio_ghelp) | qt5/plugins/kf5/kio/ | kio | yes, Depends | degraded | none |
| KIO remote workers: sftp, smb, fish, mtp, etc. | kio_sftp.so, kio_smb.so ... | kio-extras 4:23.08.5-0ubuntu5 (universe) | no (nothing in the closure Depends/Recommends it) | degraded (only non-local URL scanning; local path scanning unaffected) | none (optional; could be Suggests) |
| Qt xcb platform plugin | qt5/plugins/platforms/libqxcb.so | libqt5gui5t64 5.15.13+dfsg-1ubuntu1 (`dpkg -S` confirmed) | yes, Depends: filelight direct | hard failure | already Depends |
| Qt wayland platform plugin | qt5/plugins/platforms/libqwayland-generic.so | qtwayland5 5.15.13-1 | yes, but only Recommends: filelight -Depends-> libqt5gui5t64 -Recommends-> qtwayland5 (also libkf5windowsystem5 Recommends) | degraded (runs via XWayland/xcb fallback) | none (Qt's own relation; not filelight's) |
| Qt GTK platform theme (GNOME host) | qt5/plugins/platformthemes/libqgtk3.so | qt5-gtk-platformtheme 5.15.13+dfsg-1ubuntu1 | yes, Recommends only: libqt5gui5t64 -Recommends-> qt5-gtk-platformtheme | cosmetic (no GTK file dialog / theme) | none |
| qt5ct / plasma-integration platform themes | platformthemes/qt5ct.so, KDEPlasmaPlatformTheme5.so | qt5ct 1.5-1build11 (universe/utils), plasma-integration 5.27.11-0ubuntu3 (universe/kde) | no | cosmetic | none (optional, user choice) |
| Translations (filelight domain) | /usr/share/locale/*/LC_MESSAGES/filelight.mo | filelight itself (54 .mo files in `dpkg -L filelight`) | yes | n.a. | n.a. |
| Translations of KF5/Qt strings | kf5 catalogs | language-pack-kde-* 1:24.04.0ubuntu1 (universe/translations) | no | cosmetic (framework strings stay English) | none (installed by language-selector) |
| Handbook files | /usr/share/doc/HTML/<lang>/filelight/index.docbook + index.cache.bz2 | filelight itself (shipped in deb, 4:23.08.5-0ubuntu3) | yes | n.a. | n.a. |
| Handbook viewer (KHelpClient, F1 / help-browser) | executable `khelpcenter` (string present in libKF5GuiAddons.so.5.115.0, libkf5guiaddons5) | khelpcenter 4:23.08.5-0ubuntu4 (universe/doc; Depends kdoctools5, kinit, kio, libkf5khtml5, libkf5parts5, libxapian30 ...) | no (nothing in closure refers to it) | degraded (help action does nothing/errors; app fully usable) | none (a Depends would drag in a large KHTML/Xapian stack; at most Suggests) |
| QFileDialog::getExistingDirectory | only Qt Widgets (libqt5widgets5t64, linked) and optionally a platform theme | libqt5widgets5t64 (Depends via declared libqt5widgets5t64) | yes | n.a. (Qt non-native fallback dialog works without any theme plugin; native GTK dialog only with qt5-gtk-platformtheme, Recommends-level) | none |
| Qt.labs.platform MenuBar | same QML module as above (Qt.labs.platform uses QPlatformMenuBar; no global menu -> falls back to nothing/no-op on plain X11/Wayland) | qml-module-qt-labs-platform 5.15.13+dfsg-1 | yes, Depends: direct | cosmetic | already Depends |
| shared-mime-info (KDE MIME lookups) | /usr/share/mime | shared-mime-info | yes, Depends: filelight -> libkf5coreaddons5 -> shared-mime-info | degraded | none (transitive) |
| libqt5svg5 (SVG icon loading) | qt5/plugins/iconengines/libqsvgicon.so | libqt5svg5 | yes, Depends: filelight -> qqc2desktopstyle -> libkf5iconthemes5 -> libqt5svg5 | cosmetic | none (transitive) |

## Candidates beyond the two known gaps

(Resources NOT in the closure.)

1. breeze-icon-theme 4:5.115.0-0ubuntu3 (universe/kde). Nothing in the closure Depends or Recommends any KDE/Breeze icon theme; the only full theme present comes from `libqt5gui5t64 Recommends qt5-gtk-platformtheme -> libgtk-3-0t64 -> adwaita-icon-theme`, so a `--no-install-recommends` install on a minimal system has no icon theme beyond hicolor (and filelight's own icon). Impact: toolbar/menu icons missing, text remains; no functional loss. `configure` and `folder-root` are absent even from Adwaita. Proposed relation: Recommends breeze-icon-theme (the KDE convention, and the upstream-intended look), NOT Depends. Reasoning: cosmetic only, and breeze-icon-theme is in universe like filelight, so it is a legal relation.
2. khelpcenter 4:23.08.5-0ubuntu4 (universe/doc). F1/help-browser action invokes `khelpcenter` (KHelpClient); handbook docbook files are shipped by filelight itself but unreadable without a viewer. Missing viewer degrades only the Help action. Proposed relation: none (or Suggests). A Depends/Recommends pulls in khelpcenter's large stack (libkf5khtml5, libxapian30, libkf5parts5, kinit, kdoctools5).
3. kio-extras 4:23.08.5-0ubuntu5 (universe/utils). Provides sftp/smb/fish/mtp/etc. KIO workers; only needed to scan non-local URLs. Local scanning, deletion and trash use kio's own kio_file/kio_trash. Proposed relation: none (optional); Suggests at most.
4. plasma-integration 5.27.11-0ubuntu3 / qt5ct 1.5-1build11 (platform theme plugins) and language-pack-kde-* (framework translations): all optional cosmetic. Proposed relation: none.

No further hard-failure gaps found: every other QML module, the kio file worker, xcb plugin, and org.kde.desktop style are in the closure by Depends only (not merely Recommends). Note that kirigami2/qqc2desktopstyle/quickcharts QML imports (QtQuick.Templates, QtGraphicalEffects, QtQml.Models, org.kde.sonnet) are declared in qqc2desktopstyle's Depends, so they are covered. The Qt wayland plugin (qtwayland5) is Recommends-only through libqt5gui5t64, which is Qt's own policy, so no filelight relation is proposed.

## Could not determine

- `analysis/dynamic/pkgs-after-filelight.txt` did not exist; closure is the `apt-cache depends --recurse` approximation (includes `:i386` noise lines).
- KHelpClient's fallback behavior when `khelpcenter` is absent (does it fall back to xdg-open / browser?) was not verified: no KF5 source available on this host. Only the string "khelpcenter" was confirmed in `strings -a /usr/lib/x86_64-linux-gnu/libKF5GuiAddons.so.5.115.0`. Needs source check (kguiaddons/khelpclient.cpp) or a dynamic test.
- `dpkg -S` on host for QtQuick/Shapes/qmldir, org/kde/kcoreaddons/qmldir, and the org.kde.desktop style path returned "no path found" because those packages are not installed here (Shapes/kcoreaddons) or the path guess was wrong (style lives under QtQuick/Controls.2/org.kde.desktop/, shipped by qml-module-org-kde-qqc2desktopstyle). File-level confirmation of Shapes and kcoreaddons paths relies on package names (apt-cache show), not contents.
- packages.ubuntu.com contents search was attempted with curl (HTTP 200 returned for `https://packages.ubuntu.com/search?searchon=contents&keywords=QtQuick/Shapes/qmldir&mode=filename&suite=noble&arch=amd64`) but not used for results; the second query (`keywords=org.kde.desktop%2Fqmldir`) returned no parseable package names.
- Whether `file.so` exists: Ubuntu names it `kio_file.so`; the path in the task description does not exist.
- Whether hicolor-icon-theme is reachable by Depends-only from filelight: BFS found no Depends-only path (it appeared only through Recommends -> libgtk-3-0t64). An earlier `--no-recommends` apt-cache run listed it, but that flag is unreliable and its output was discarded.
