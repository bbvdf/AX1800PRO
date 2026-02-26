#!/bin/bash
. $(dirname "$(realpath "$0")")/function.sh
#修改默认主题
sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改immortalwrt.lan关联IP
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
#添加编译日期标识
sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ DaeWRT-$WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")

WIFI_SH=$(find ./target/linux/{mediatek/filogic,qualcommax}/base-files/etc/uci-defaults/ -type f -name "*set-wireless.sh" 2>/dev/null)
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
if [ -f "$WIFI_SH" ]; then
	#修改WIFI名称
	sed -i "s/BASE_SSID='.*'/BASE_SSID='$WRT_SSID'/g" $WIFI_SH
	#修改WIFI密码
	sed -i "s/BASE_WORD='.*'/BASE_WORD='$WRT_WORD'/g" $WIFI_SH
elif [ -f "$WIFI_UC" ]; then
	#修改WIFI名称
	sed -i "s/ssid='.*'/ssid='$WRT_SSID'/g" $WIFI_UC
	#修改WIFI密码
	sed -i "s/key='.*'/key='$WRT_WORD'/g" $WIFI_UC
	#修改WIFI地区
	sed -i "s/country='.*'/country='AU'/g" $WIFI_UC
	#修改WIFI加密
	sed -i "s/encryption='.*'/encryption='psk2+ccmp'/g" $WIFI_UC
fi

CFG_FILE="./package/base-files/files/bin/config_generate"
#修改默认IP地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
#修改默认主机名
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE

# vlmcsd_patches="./feeds/packages/net/vlmcsd/patches/"
# mkdir -p $vlmcsd_patches && cp -f ../patches/001-fix_compile_with_ccache.patch $vlmcsd_patches

#修复dropbear
# #sed -i "s/Interface/DirectInterface/" ./package/network/services/dropbear/files/dropbear.config
# sed -i "/Interface/d" ./package/network/services/dropbear/files/dropbear.config
# #拷贝files 文件夹到编译目录
# cp -r ../files ./

#配置文件修改
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config

#手动调整的插件
if [ -n "$WRT_PACKAGE" ]; then
	echo -e "$WRT_PACKAGE" >> ./.config
fi

高通平台调整
DTS_PATH="./target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/"
if [[ $WRT_TARGET == *"QUALCOMMAX"* ]]; then
	#取消nss相关feed
	echo "CONFIG_FEED_nss_packages=n" >> ./.config
	echo "CONFIG_FEED_sqm_scripts_nss=n" >> ./.config
	#设置NSS版本
	echo "CONFIG_NSS_FIRMWARE_VERSION_11_4=n" >> ./.config
	echo "CONFIG_NSS_FIRMWARE_VERSION_12_5=y" >> ./.config
	#开启sqm-nss插件
	echo "CONFIG_PACKAGE_luci-app-sqm=y" >> ./.config
	echo "CONFIG_PACKAGE_sqm-scripts-nss=y" >> ./.config
	#无WIFI配置调整Q6大小
	if [[ "${WRT_CONFIG}" == *"NOWIFI"* ]]; then
		find $DTS_PATH -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
		echo "qualcommax set up nowifi successfully!"
	fi
fi

# 去掉attendedsysupgrade
sed -i 's/+luci-app-attendedsysupgrade//g' feeds/luci/collections/luci/Makefile
sed -i '/CONFIG_PACKAGE_luci-app-attendedsysupgrade/d' ./.config
echo "CONFIG_PACKAGE_luci-app-attendedsysupgrade=n" >> ./.config

# 无线数据修复
# --- 强制注入内核分区支持配置 ---
echo "CONFIG_PARTITION_ADVANCED=y" >> .config
echo "CONFIG_MMC_BLOCK=y" >> .config
echo "CONFIG_PARTLABEL=y" >> .config
echo "CONFIG_EFI_PARTITION=y" >> .config
# 定位该脚本
CAL_DATA_FILE=$(find target/linux/qualcommax -name "11-ath11k-caldata")

if [ -f "$CAL_DATA_FILE" ]; then
    echo "正在对 11-ath11k-caldata 进行京东云专项适配..."

    # 1. 关键修改：将针对京东云的提取源 0:ART 替换为物理分区 mmcblk0p15
    # 并且把输出文件名改为驱动期待的 Variant 后缀
    sed -i '/jdcloud,re-ss-01/,/;;/ {
        s/"0:ART"/"\/dev\/mmcblk0p15"/
        s/wifi.bin/wifi.JDC-RE-SS-01/
    }' "$CAL_DATA_FILE"

    echo "适配完成！提取路径已指向 mmcblk0p15，且文件名已匹配 JDC-RE-SS-01"
fi
