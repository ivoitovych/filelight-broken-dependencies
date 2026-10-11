# Pristine Ubuntu 24.04 (noble) with nothing but filelight and its declared
# dependency closure. Any runtime lookup that fails in here is a packaging gap.
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y -o APT::Install-Recommends=true filelight \
 && dpkg-query -W -f='${Package}\t${Version}\n' | sort > /pkgs-after-filelight.txt
# Diagnostic tooling only. None of these pull QML modules or KF5 packages
# (verified by diffing the two package lists after the build).
RUN apt-get install -y --no-install-recommends strace xvfb xdotool x11-utils \
 && dpkg-query -W -f='${Package}\t${Version}\n' | sort > /pkgs-after-tooling.txt \
 && rm -rf /var/lib/apt/lists/*
