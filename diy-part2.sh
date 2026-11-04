#!/bin/bash
# DRAFT v0.1 — diy-part2: runs after .config is loaded, before defconfig/download.

# --- Extra packages cloned into package/ -------------------------------------
# Fail-fast helper: build #3 silently shipped WITHOUT DDNSTO because the old
# mv-based helper moved the clone into a non-existent package/ dir inside the
# temp clone and then deleted it. This version copies from the openwrt root,
# verifies the Makefile exists, and aborts the whole build if a required
# package did not land.
clone_pkg() {
  # $1=branch $2=repo-url $3=path-in-repo ; lands in package/<basename>
  local base
  base=$(basename "$3")
  rm -rf tmp_clone_src
  git clone --depth=1 -b "$1" --single-branch --filter=blob:none --sparse "$2" tmp_clone_src || return 1
  git -C tmp_clone_src sparse-checkout set "$3" || return 1
  if [ ! -f "tmp_clone_src/$3/Makefile" ]; then
    echo "ERROR: $3/Makefile not found in $2" >&2
    return 1
  fi
  rm -rf "package/$base"
  cp -a "tmp_clone_src/$3" "package/$base"
  rm -rf tmp_clone_src
  echo "cloned package/$base from $2"
}
# DDNSTO (linkease) — hard requirement: the user's remote-access path.
clone_pkg main https://github.com/linkease/nas-packages-luci luci/luci-app-ddnsto || exit 1
clone_pkg master https://github.com/linkease/nas-packages network/services/ddnsto || exit 1
# File transfer — dropped from upstream LuCI feeds; take it from LEDE's feed.
clone_pkg master https://github.com/coolsnowwolf/luci applications/luci-app-filetransfer || exit 1
# LEDE apps end their Makefile with a relative `include ../../luci.mk`, which
# only resolves inside a luci feed tree. In package/ it points at a missing
# file, the package metadata scan skips it, and defconfig silently drops it
# (this is what tripped build #4's config gate). Rewrite to the absolute path.
FT_MK="package/luci-app-filetransfer/Makefile"
sed -i 's|include ../../luci.mk|include $(TOPDIR)/feeds/luci/luci.mk|' "$FT_MK"
grep -q 'feeds/luci/luci.mk' "$FT_MK" || { echo "ERROR: filetransfer luci.mk include patch did not apply" >&2; exit 1; }
echo 'filetransfer luci.mk include fixed'

# --- Fix build #2 failure: immortalwrt's sing-box force-enables its Naive
# outbound (def_bool y), which drags in libcronet -> gn (host). The latest gn
# snapshot needs -std=c++23 but the GitHub runner's clang stops at c++2b, so
# the build died at gn after ~2.5h. NaiveProxy is not used here (PassWall's own
# NaiveProxy include is off too), so turn the symbol off at the source. Fail
# fast if the patch does not apply, instead of burning another long build.
SB_MK="package/feeds/packages/sing-box/Makefile"
if [ -f "$SB_MK" ]; then
  sed -i '/config SING_BOX_BUILD_NAIVE_OUTBOUND/,/depends on/s/def_bool y/def_bool n/' "$SB_MK"
  if grep -A1 'config SING_BOX_BUILD_NAIVE_OUTBOUND' "$SB_MK" | grep -q 'def_bool y'; then
    echo 'ERROR: sing-box NAIVE_OUTBOUND patch did not apply, aborting early' >&2
    exit 1
  fi
  echo 'sing-box NAIVE_OUTBOUND disabled (no libcronet, no gn)'
else
  echo 'WARN: sing-box Makefile not found, skipping NAIVE_OUTBOUND patch'
fi

# --- Remove GECOOS AC controller if the seed config pulled it in (not needed, saves space) ---
sed -i '/luci-app-gecoosac/d' .config || true

# Root password: force EMPTY (user requirement, 2026-11-03).
# Clears whatever the source tree preset; web/TTYD login then needs no password.
# Note: dropbear SSH still refuses password login with an empty password until one is set.
sed -i 's|^root:[^:]*:|root::|' package/base-files/files/etc/shadow

# Default LAN IP: keep source default (192.168.1.1) unless user asks to change.
# sed -i 's/192.168.1.1/192.168.2.1/g' package/base-files/files/bin/config_generate
