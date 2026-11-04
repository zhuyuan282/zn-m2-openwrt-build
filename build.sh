#!/bin/bash
# ZN M2 firmware build — all heavy lifting lives here so the GitHub
# workflow file can stay a tiny stub (the repo owner had to paste the
# workflow by hand on mobile; long files get truncated there).
# Runs on the GitHub Actions runner with cwd = repo checkout root.
set -x

REPO_URL=https://github.com/VIKINGYFY/immortalwrt
REPO_BRANCH=main
CONFIG_FILE=configs/zn_m2_nowifi.config
DIY_P1_SH=diy-part1.sh
DIY_P2_SH=diy-part2.sh
export DEBIAN_FRONTEND=noninteractive
export TZ=Asia/Shanghai

# ---------- environment ----------
sudo rm -rf /etc/apt/sources.list.d/* /usr/share/dotnet /usr/local/lib/android /opt/ghc /opt/hostedtoolcache/CodeQL
sudo docker image prune --all --force
sudo -E apt-get -qq update
sudo -E apt-get -qq install ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential bzip2 ccache clang cmake cpio curl device-tree-compiler flex gawk gcc-multilib g++-multilib gettext genisoimage git gperf haveged help2man intltool libc6-dev-i386 libelf-dev libfuse-dev libglib2.0-dev libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses5-dev libncursesw5-dev libpython3-dev libreadline-dev libssl-dev libtool llvm lrzsz msmtp ninja-build p7zip p7zip-full patch pkgconf python3 python3-pyelftools python3-setuptools qemu-utils rsync scons squashfs-tools subversion swig texinfo uglifyjs upx-ucl unzip vim wget xmlto xxd zlib1g-dev
sudo -E apt-get -qq autoremove --purge
sudo -E apt-get -qq clean
sudo timedatectl set-timezone "$TZ" || true

# ---------- source ----------
df -hT "$PWD"
git clone "$REPO_URL" -b "$REPO_BRANCH" openwrt || exit 1

# ---------- feeds ----------
[ -e feeds.conf.default ] && mv feeds.conf.default openwrt/feeds.conf.default
chmod +x "$DIY_P1_SH" "$DIY_P2_SH"
(cd openwrt && "$OLDPWD/$DIY_P1_SH")
cd openwrt && ./scripts/feeds update -a && ./scripts/feeds install -a || exit 1
cd ..

# ---------- config ----------
if [ -d files ]; then
  mkdir -p openwrt/files
  cp -a files/. openwrt/files/
fi
# Prefer a WIFI-NO / nowifi seed shipped inside the source tree; append our
# package selections on top. Otherwise use our seed config as-is.
SEED=$(find openwrt -maxdepth 3 \( -iname '*wifi-no*.config' -o -iname '*nowifi*.config' \) 2>/dev/null | head -1)
if [ -n "$SEED" ]; then
  echo "Using source seed: $SEED"
  cp "$SEED" openwrt/.config
  grep -E '^CONFIG_PACKAGE|^# CONFIG_PACKAGE' "$CONFIG_FILE" >> openwrt/.config
else
  cp "$CONFIG_FILE" openwrt/.config
fi
(cd openwrt && "$OLDPWD/$DIY_P2_SH")

# ---------- download & compile ----------
cd openwrt || exit 1
make defconfig
# Fail fast (minute ~8, not hour ~2) if a must-have package silently dropped
# out of the config — this is how build #3 shipped without DDNSTO.
for sym in CONFIG_PACKAGE_luci-app-passwall CONFIG_PACKAGE_luci-app-ddnsto \
           CONFIG_PACKAGE_ddnsto CONFIG_PACKAGE_luci-app-filetransfer \
           CONFIG_PACKAGE_xray-core CONFIG_PACKAGE_sing-box \
           CONFIG_PACKAGE_hysteria CONFIG_PACKAGE_luci-app-cpufreq \
           CONFIG_PACKAGE_luci-app-upnp CONFIG_PACKAGE_luci-theme-argon; do
  grep -q "^${sym}=y" .config || { echo "FATAL: required symbol ${sym} missing from .config"; exit 1; }
done
make download -j8
find dl -size -1024c -exec ls -l {} \;
find dl -size -1024c -exec rm -f {} \;

echo -e "$(nproc) thread compile"
make -j$(nproc) || make -j1 || make -j1 V=s
if [ $? -ne 0 ] && ! ls bin/targets/*/*/*zn_m2* >/dev/null 2>&1; then
  echo "BUILD FAILED: no zn_m2 firmware produced"
  exit 1
fi
grep '^CONFIG_TARGET.*DEVICE.*=y' .config | sed -r 's/.*DEVICE_(.*)=y/\1/' > DEVICE_NAME || true
df -hT

# ---------- organize & release ----------
cd bin/targets/*/* || exit 1
rm -rf packages
ls -lh
# Final gate: the firmware manifest must actually contain the must-haves
# before anything is published as a Release.
MANIFEST=$(ls *.manifest 2>/dev/null | head -1)
if [ -n "$MANIFEST" ]; then
  for pkg in luci-app-passwall luci-app-ddnsto ddnsto luci-app-filetransfer xray-core sing-box hysteria; do
    grep -q "^${pkg} - " "$MANIFEST" || { echo "FATAL: ${pkg} missing from firmware manifest"; exit 1; }
  done
fi
TAG=$(date +"%Y.%m.%d-%H%M")
cat > /tmp/release-notes.txt <<EOF
ZN M2 wired-only (no WiFi/USB) · VIKINGYFY immortalwrt qualcommax NSS
PassWall (latest) + Xray + sing-box + Hysteria baked in · Argon theme · root password empty
Flash via U-Boot recovery (factory/ubi). Do NOT sysupgrade keeping config from the old 4.4 firmware.
EOF
gh release create "$TAG" --repo "$GITHUB_REPOSITORY" \
  --title "ZN M2 固件 $TAG" --notes-file /tmp/release-notes.txt ./*
