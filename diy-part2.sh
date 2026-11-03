#!/bin/bash
# DRAFT v0.1 — diy-part2: runs after .config is loaded, before defconfig/download.

# --- DDNSTO (linkease) : sparse-clone luci-app-ddnsto + ddnsto service ---
git_sparse_clone() {
  branch="$1" repourl="$2" && shift 2
  git clone --depth=1 -b "$branch" --single-branch --filter=blob:none --sparse "$repourl" tmp_ddnsto_src
  cd tmp_ddnsto_src
  git sparse-checkout set "$@"
  for d in "$@"; do
    [ -d "$d" ] && mv -f "$d" package/
  done
  cd ..
  rm -rf tmp_ddnsto_src
}
git_sparse_clone main https://github.com/linkease/nas-packages-luci luci/luci-app-ddnsto
git_sparse_clone master https://github.com/linkease/nas-packages network/services/ddnsto

# --- Remove GECOOS AC controller if the seed config pulled it in (not needed, saves space) ---
sed -i '/luci-app-gecoosac/d' .config || true

# Root password: force EMPTY (user requirement, 2026-11-03).
# Clears whatever the source tree preset; web/TTYD login then needs no password.
# Note: dropbear SSH still refuses password login with an empty password until one is set.
sed -i 's|^root:[^:]*:|root::|' package/base-files/files/etc/shadow

# Default LAN IP: keep source default (192.168.1.1) unless user asks to change.
# sed -i 's/192.168.1.1/192.168.2.1/g' package/base-files/files/bin/config_generate
