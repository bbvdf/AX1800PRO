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

# 高通平台调整
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
# 1. 注入内核分区识别 (地基)
echo "CONFIG_PARTITION_ADVANCED=y" >> .config
echo "CONFIG_MMC_BLOCK=y" >> .config
echo "CONFIG_PARTLABEL=y" >> .config
echo "CONFIG_EFI_PARTITION=y" >> .config

# 2. 修改热插拔脚本 (钥匙)
# 定位文件
CAL_FILE=$(find target/linux/qualcommax -name "11-ath11k-caldata" | head -n1)

if [ -f "$CAL_FILE" ]; then
    echo "[Settings] 正在对 11-ath11k-caldata 执行终极物理路径修正..."

    # 1. 修正提取路径：把脚本里所有的 caldata_extract_mmc "0:ART" 替换为物理路径
    # 注意：这里我们连同单引号的情况也考虑进去
    sed -i 's@caldata_extract_mmc "0:ART"@caldata_extract_mmc "/dev/mmcblk0p15"@g' "$CAL_FILE"
    sed -i "s@caldata_extract_mmc '0:ART'@caldata_extract_mmc '/dev/mmcblk0p15'@g" "$CAL_FILE"

    # 2. 修正文件名：把脚本请求的所有 .wifi.bin 替换为 .wifi.JDC-RE-SS-01
    # 这样不管是 case 判断还是输出，都会指向带 Variant 后缀的文件
    sed -i 's@wifi.bin@wifi.JDC-RE-SS-01@g' "$CAL_FILE"

    # 3. 打印关键区域进行结果确认 (这次我们用 grep，更直观)
    echo "--- 修改结果自检 (过滤关键字: mmcblk0p15) ---"
    grep -C 2 "mmcblk0p15" "$CAL_FILE"
    
    echo "--- 修改结果自检 (过滤关键字: JDC-RE-SS-01) ---"
    grep "JDC-RE-SS-01" "$CAL_FILE" | head -n 5
fi
