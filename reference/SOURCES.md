# Where these files came from

- `noble-4:23.08.5-0ubuntu3/` — the exact packaging the installed binary was built from.
  Pulled from http://archive.ubuntu.com/ubuntu/pool/universe/f/filelight/filelight_23.08.5-0ubuntu3.{dsc,debian.tar.xz}
  Packaging VCS: https://git.launchpad.net/~kubuntu-packagers/kubuntu-packaging/+git/filelight branch `kubuntu_noble_archive`
  (debian/control there is identical to the archive copy).
  The Depends list is hand-written in debian/control; no dh_qmldeps / QML scanning is used.
- `oracular/filelight_23.08.5-0ubuntu4.1.debdiff` — the proposed (never landed) oracular SRU from LP #2084169,
  adding qml-module-qtquick-shapes. Oracular's 0ubuntu4 had already added qml-module-org-kde-kcoreaddons.
- `debian/control-4:23.08.5-1` — Debian's control for the same upstream version. Debian already carried
  qml-module-org-kde-kcoreaddons since 4:22.12.2-1 (Debian #1030549, Feb 2023); Kubuntu's branch never picked it up.
  Debian fixed Shapes by switching to dh-sequence-qmldeps in 4:25.03.90-1 (Debian #1082018 / #1101828).
- `ubuntu-resolute-control-4:25.12.3` — current Ubuntu packaging (Qt6/KF6, dh-sequence-qmldeps, ${qml6:Depends}).
  Shows mainline Ubuntu is fixed; only noble (LTS, Qt5 build) still has the hand-written incomplete list.
