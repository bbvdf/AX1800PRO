#!/bin/bash
# Scripts/ppe-settings.sh —— openwrt-ppe-nss 专用：默认 IP / 主机名 / WiFi / 内核分区
# 在源码根目录执行，feeds install 之后、make defconfig 之前

set -e

WRT_THEME=${WRT_THEME:-argon}
WRT_NAME=${WRT_NAME:-OpenWrt}
WRT_SSID=${WRT_SSID:-OpenWrt}
WRT_WORD=${WRT_WORD:-1234567890}
WRT_IP=${WRT_IP:-10.0.0.1}

# 默认主题（luci 集合里的 bootstrap 换成 argon）
if [ -d ./feeds/luci/collections ]; then
	find ./feeds/luci/collections -type f -name Makefile \
		-exec sed -i "s/luci-theme-bootstrap/luci-theme-${WRT_THEME}/g" {} +
fi

# 默认 IP 与主机名
CG=./package/base-files/files/bin/config_generate
if [ -f "$CG" ]; then
	sed -i "s/192\.168\.[0-9]*\.[0-9]*/${WRT_IP}/g" "$CG"
	sed -i "s/hostname='.*'/hostname='${WRT_NAME}'/g" "$CG"
fi

# 默认 WiFi（mac80211.uc 是 ppe-nss 的默认无线生成脚本）
UC=./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc
if [ -f "$UC" ]; then
	sed -i "s/ssid='.*'/ssid='${WRT_SSID}'/g" "$UC"
	sed -i "s/key='.*'/key='${WRT_WORD}'/g" "$UC"
	sed -i "s/country='.*'/country='AU'/g" "$UC"
fi

# 内核分区：本机已换分区表/uboot，内核分区放到 12M（同原 set_kernel_size）
MK=./target/linux/qualcommax/image/ipq60xx.mk
if [ -f "$MK" ]; then
	sed -i "/^define Device\/jdcloud_re-ss-01/,/^endef/ { /KERNEL_SIZE := 6144k/s//KERNEL_SIZE := 12288k/ }" "$MK"
	echo "kernel size: $(sed -n '/^define Device\/jdcloud_re-ss-01/,/^endef/ { /KERNEL_SIZE/p }' "$MK")"
fi

echo "ppe-settings done: ip=${WRT_IP} ssid=${WRT_SSID} theme=${WRT_THEME}"
