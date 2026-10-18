#!/bin/bash
# Builds the noble SRU source and binary packages and the debdiff.
# Runs inside the filelight-noble-build image with this directory mounted at /out:
#   docker run --rm -v "$PWD/sru:/out" filelight-noble-build bash /out/build-debdiff.sh
# Any failing step makes the script exit non-zero.
set -x
set -o pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update && mkdir /build && cd /build || exit 1
apt-get source filelight=4:23.08.5-0ubuntu3 || {
  B=http://archive.ubuntu.com/ubuntu/pool/universe/f/filelight
  dget -u $B/filelight_23.08.5-0ubuntu3.dsc || exit 1; }
cd filelight-23.08.5 || exit 1
# kcoreaddons sorts before kirigami2 (first line of Depends); shapes goes after qt-labs-platform
sed -i 's/^Depends: qml-module-org-kde-kirigami2,$/Depends: qml-module-org-kde-kcoreaddons,\n         qml-module-org-kde-kirigami2,/' debian/control
sed -i 's/^\( *\)qml-module-qt-labs-platform,$/&\n\1qml-module-qtquick-shapes,/' debian/control
grep -q '^Depends: qml-module-org-kde-kcoreaddons,$' debian/control || exit 1
grep -q '^ *qml-module-qtquick-shapes,$' debian/control || exit 1
export TZ=UTC
D=$(date -R)
{ cat <<EOT
filelight (4:23.08.5-0ubuntu3.1) noble; urgency=medium

  * debian/control: add missing runtime dependencies on
    qml-module-org-kde-kcoreaddons and qml-module-qtquick-shapes.
    Without them the scan page never loads (module "QtQuick.Shapes"
    is not installed) wherever these modules are not otherwise
    installed, e.g. on Ubuntu Desktop (GNOME). (LP: #2084169)

 -- Iaroslav Voitovych <yaroslav.voytovych@gmail.com>  $D

EOT
cat debian/changelog; } > /tmp/cl && mv /tmp/cl debian/changelog
dpkg-buildpackage -S -us -uc -d || exit 1
cd /build || exit 1
debdiff filelight_23.08.5-0ubuntu3.dsc filelight_23.08.5-0ubuntu3.1.dsc > /out/filelight_23.08.5-0ubuntu3.1.debdiff
rc=$?; [ "$rc" -le 1 ] || exit 1   # debdiff exits 1 when the packages differ, which is expected
[ -s /out/filelight_23.08.5-0ubuntu3.1.debdiff ] || exit 1
cd filelight-23.08.5 || exit 1
dpkg-buildpackage -b -us -uc || { echo "BUILD FAILED"; exit 1; }
cd /build || exit 1
cp filelight_23.08.5-0ubuntu3.1_amd64.deb filelight_23.08.5-0ubuntu3.1_*.changes /out/ || exit 1
lintian -i filelight_23.08.5-0ubuntu3.1_amd64.deb filelight_23.08.5-0ubuntu3.1.dsc > /out/lintian.txt 2>&1
rc=$?; echo "lintian exit=$rc" >> /out/lintian.txt
exit "$rc"
