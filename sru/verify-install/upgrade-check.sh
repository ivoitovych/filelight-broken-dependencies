#!/bin/bash
# Installs the rebuilt .deb with apt on whatever image this runs in and records
# what apt did. Usage inside a container: bash /sru/verify-install/upgrade-check.sh <label>
export DEBIAN_FRONTEND=noninteractive
L=$1; O=/sru/verify-install/$L.txt
{
echo "== image label: $L"
echo "== before:"; dpkg-query -W -f='${Package} ${Version} ${Status}\n' filelight qml-module-qtquick-shapes qml-module-org-kde-kcoreaddons libqt5quickshapes5 2>&1
apt-get update -qq
echo "== apt-get install -y /sru/filelight_23.08.5-0ubuntu3.1_amd64.deb"
apt-get install -y /sru/filelight_23.08.5-0ubuntu3.1_amd64.deb 2>&1 | grep -E 'NEW packages|will be upgraded|to remove|newly installed|^Setting up|^Unpacking|^Preparing|^E:|^W:' 
echo "== after:"; dpkg-query -W -f='${Package} ${Version} ${Status}\n' filelight qml-module-qtquick-shapes qml-module-org-kde-kcoreaddons libqt5quickshapes5 2>&1
echo "== apt-get check:"; apt-get check 2>&1; echo "apt-get check exit=$?"
echo "== dpkg --audit:"; dpkg --audit 2>&1; echo "dpkg --audit exit=$?"
} > "$O" 2>&1
cat "$O"
