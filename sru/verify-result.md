# Verification of filelight 4:23.08.5-0ubuntu3.1 in pristine noble

## Install
```
Version: 4:23.08.5-0ubuntu3.1
Depends: qml-module-org-kde-kcoreaddons, qml-module-org-kde-kirigami2, qml-module-org-kde-qqc2desktopstyle, qml-module-org-kde-quickcharts, qml-module-qt-labs-platform, qml-module-qtquick-shapes, kio, libc6 (>= 2.34), libkf5configcore5 (>= 5.69.0), libkf5coreaddons5 (>= 5.96.0), libkf5i18n5 (>= 5.98.0~), libkf5kiocore5 (>= 5.100.0), libkf5kiogui5 (>= 5.98.0~), libkf5kiowidgets5 (>= 5.98.0~), libkf5widgetsaddons5 (>= 4.96.0), libkf5xmlgui5 (>= 5.98.0~), libqt5core5t64 (>= 5.15.2~), libqt5gui5t64 (>= 5.15.2~) | libqt5gui5-gles (>= 5.15.2~), libqt5qml5 (>= 5.15.2~), libqt5quick5 (>= 5.15.2~) | libqt5quick5-gles (>= 5.15.2~), libqt5quickcontrols2-5 (>= 5.15.2~), libqt5widgets5t64 (>= 5.15.2~), libstdc++6 (>= 9)
ii  qml-module-org-kde-kcoreaddons:amd64 5.115.0-0ubuntu5        amd64        provides integration of QML and KDE frameworks - kcoreaddons
ii  qml-module-qtquick-shapes:amd64      5.15.13+dfsg-1ubuntu0.1 amd64        Qt 5 Qt Quick Shapes QML module
```

## Trace greps (sru/verify-trace)

$ grep -c 'is not installed' xvfb-errors.txt xvfb-trace.log offscreen-trace.log
```
xvfb-errors.txt:0
offscreen-trace.log:0
xvfb-trace.log:0
```

$ grep -c 'Component is not ready' xvfb-errors.txt xvfb-trace.log offscreen-trace.log
```
xvfb-errors.txt:0
offscreen-trace.log:0
xvfb-trace.log:0
```

$ grep -E 'QtQuick/Shapes|org/kde/kcoreaddons' strace-loaded-qml-plugins.txt
```
/usr/lib/x86_64-linux-gnu/qt5/qml/QtQuick/Shapes/libqmlshapesplugin.so
/usr/lib/x86_64-linux-gnu/qt5/qml/QtQuick/Shapes/qmldir
/usr/lib/x86_64-linux-gnu/qt5/qml/org/kde/kcoreaddons/libkcoreaddonsplugin.so
/usr/lib/x86_64-linux-gnu/qt5/qml/org/kde/kcoreaddons/qmldir
```

$ grep -c -E 'QtQuick/Shapes/qmldir|org/kde/kcoreaddons/qmldir' strace-xvfb.raw
```
4
```

$ cat exitcodes.txt
```
step3 exit=134
step4 exit=134
step5 exit=0
step5-strace exit=0
```

## Verdict
PASS: both modules were pulled in by apt automatically; zero 'is not installed' and zero 'Component is not ready' lines in the xvfb and offscreen traces; the Shapes and kcoreaddons plugins are opened at runtime. Exit 134 in steps 3/4 (offscreen, 'Failed to create OpenGL context') is identical to the pre-fix baseline in analysis/dynamic/exitcodes.txt and is an environment limit (no GL), not a packaging gap. Large *.raw files removed.
