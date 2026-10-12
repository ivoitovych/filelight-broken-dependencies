#!/bin/bash
# Runs inside filelight-noble-build with $PWD/sru mounted at /out.
set -x
export DEBIAN_FRONTEND=noninteractive
apt-get update && mkdir /build && cd /build || exit 1
apt-get source filelight=4:23.08.5-0ubuntu3 || {
  B=http://archive.ubuntu.com/ubuntu/pool/universe/f/filelight
  dget -u $B/filelight_23.08.5-0ubuntu3.dsc || exit 1; }
cd filelight-23.08.5 || exit 1
sed -i 's/^\( *\)qml-module-org-kde-kconfig,/&/' debian/control
# kcoreaddons sorts before kirigami2 (first line of Depends); shapes goes after qt-labs-platform
sed -i 's/^Depends: qml-module-org-kde-kirigami2,$/Depends: qml-module-org-kde-kcoreaddons,\n         qml-module-org-kde-kirigami2,/' debian/control
sed -i 's/^\( *\)qml-module-qt-labs-platform,$/&\n\1qml-module-qtquick-shapes,/' debian/control
export TZ=UTC
D=$(date -R)
{ cat <<EOT
filelight (4:23.08.5-0ubuntu3.1) noble; urgency=medium

  * Add missing runtime dependencies on qml-module-org-kde-kcoreaddons and
    qml-module-qtquick-shapes. Without them the scan page fails to load with
    'module "QtQuick.Shapes" is not installed' / 'module "org.kde.kcoreaddons"
    is not installed' on any system without Plasma. (LP: #2084169)

 -- Iaroslav Voitovych <yaroslav.voytovych@gmail.com>  $D

EOT
cat debian/changelog; } > /tmp/cl && mv /tmp/cl debian/changelog
dpkg-buildpackage -S -us -uc -d || exit 1
cd /build
debdiff filelight_23.08.5-0ubuntu3.dsc filelight_23.08.5-0ubuntu3.1.dsc > /out/filelight_23.08.5-0ubuntu3.1.debdiff
cd filelight-23.08.5
dpkg-buildpackage -b -us -uc || echo "BUILD FAILED"
cd /build
cp filelight_23.08.5-0ubuntu3.1_amd64.deb filelight_23.08.5-0ubuntu3.1_*.changes /out/
lintian -i filelight_23.08.5-0ubuntu3.1_amd64.deb filelight_23.08.5-0ubuntu3.1.dsc > /out/lintian.txt 2>&1
echo "lintian exit=$?" >> /out/lintian.txt
