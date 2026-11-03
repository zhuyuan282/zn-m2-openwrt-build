#!/bin/bash
# DRAFT v0.1 — diy-part1: runs before feeds update. Add extra feeds here.
# PassWall official feeds (Openwrt-Passwall org)
cat >> feeds.conf.default <<'EOF'
src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main
src-git passwall_luci https://github.com/Openwrt-Passwall/openwrt-passwall.git;main
EOF
