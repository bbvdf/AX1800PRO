#!/bin/bash
. $(dirname "$(realpath "$0")")/function.sh

# 修改默认主题 [cite: 1]
sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")

# 修改immortalwrt.lan关联IP [cite: 1]
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")

# 添加编译日期标识 [cite: 1]
sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ DaeWRT-$WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")

# 无线配置调整 [cite: 1]
WIFI_SH=$(find ./target/linux/{mediatek/filogic,qualcommax}/base-files/etc/uci-defaults/ -type f -name "*set-wireless.sh" 2>/dev/null)
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
if [ -f "$WIFI_SH" ]; then
    # 修改WIFI名称和密码 [cite: 1]
    sed -i "s/BASE_SSID='.*'/BASE_SSID='$WRT_SSID'/g" $WIFI_SH
    sed -i "s/BASE_WORD='.*'/BASE_WORD='$WRT_WORD'/g" $WIFI_SH
elif [ -f "$WIFI_UC" ]; then
    sed -i "s/ssid='.*'/ssid='$WRT_SSID'/g" $WIFI_UC
    sed -i "s/key='.*'/key='$WRT_WORD'/g" $WIFI_UC
    sed -i "s/country='.*'/country='AU'/g" $WIFI_UC
    sed -i "s/encryption='.*'/encryption='psk2+ccmp'/g" $WIFI_UC
fi

# 基础系统配置 [cite: 1]
CFG_FILE="./package/base-files/files/bin/config_generate"
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE


# 写入基础 .config 配置 [cite: 1]
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config


# 手动调整的插件 [cite: 1]
if [ -n "$WRT_PACKAGE" ]; then
    echo -e "$WRT_PACKAGE" >> ./.config
fi

# 高通平台专项调整 [cite: 1, 5]
DTS_PATH="./target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/"
if [[ $WRT_TARGET == *"QUALCOMMAX"* ]]; then
    # 1. 强制跳过 NSS 固件哈希校验 (修复 Error 161) [cite: 2]
    # 路径基于 wrt 根目录
    sed -i 's/PKG_MIRROR_HASH:=.*/PKG_MIRROR_HASH:=skip/g' feeds/nss_packages/firmware/nss-firmware/Makefile




    # 3. 其他原有配置 [cite: 1]
    echo "CONFIG_FEED_nss_packages=n" >> .config
    echo "CONFIG_FEED_sqm_scripts_nss=n" >> .config
    echo "CONFIG_PACKAGE_luci-app-sqm=y" >> .config
    echo "CONFIG_PACKAGE_sqm-scripts-nss=y" >> .config

    # 无WIFI配置调整 [cite: 1]
    if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
        find $DTS_PATH -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
        echo "qualcommax set up nowifi successfully!"
    fi
fi

# 去掉attendedsysupgrade
sed -i 's/+luci-app-attendedsysupgrade//g' feeds/luci/collections/luci/Makefile
sed -i '/CONFIG_PACKAGE_luci-app-attendedsysupgrade/d' .config
echo "CONFIG_PACKAGE_luci-app-attendedsysupgrade=n" >> .config



# --- 修复 253: vlmcsd 补丁路径 ---
vlmcsd_patches="$GITHUB_WORKSPACE/$WRT_DIR/feeds/packages/net/vlmcsd/patches/"
# 使用绝对路径定位 patches 文件夹
if [ -f "$GITHUB_WORKSPACE/patches/001-fix_compile_with_ccache.patch" ]; then
    mkdir -p $vlmcsd_patches
    cp -f "$GITHUB_WORKSPACE/patches/001-fix_compile_with_ccache.patch" "$vlmcsd_patches"
    echo "vlmcsd patch applied using absolute path."
else
    echo "Warning: Patch not found at $GITHUB_WORKSPACE/patches/"
fi

# --- 修复 254/255: daed 路径 ---
# 不再迷信 ./feeds，直接从 wrt 根目录全局搜索
DAED_MK=$(find "$GITHUB_WORKSPACE/$WRT_DIR" -type f -name "Makefile" -path "*/daed/*" | head -n 1)

if [ -n "$DAED_MK" ]; then
    echo "Found daed Makefile at: $DAED_MK"
    sed -i 's/+v2ray-geoip//g' "$DAED_MK"
    sed -i 's/+v2ray-geosite//g' "$DAED_MK"
    echo "daed Makefile patched."
else
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "警告: 全局搜索也没找到 daed Makefile！"
    echo "请检查 Packages.sh 是否下载了 daed，或者名字是否叫 luci-app-dae"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
fi

# --- 强制清理 .config 防止依赖报错 ---
sed -i '/CONFIG_PACKAGE_v2ray-geoip/d' .config
sed -i '/CONFIG_PACKAGE_v2ray-geosite/d' .config

# 激活硬改 1G 的内核优化
cat_kernel_config ".config"   # 开启 eBPF 支持，daed 必需
enable_skb_recycler ".config" # 开启 NSS 极速转发
set_kernel_size               # 确保内核分区扩展到 12M，否则 6.x 内核+NSS 极易爆空间
