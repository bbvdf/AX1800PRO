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

#高通平台调整
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
	if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
		find $DTS_PATH -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
		echo "qualcommax set up nowifi successfully!"
	fi
fi

# 去掉attendedsysupgrade
sed -i 's/+luci-app-attendedsysupgrade//g' feeds/luci/collections/luci/Makefile
sed -i '/CONFIG_PACKAGE_luci-app-attendedsysupgrade/d' ./.config
echo "CONFIG_PACKAGE_luci-app-attendedsysupgrade=n" >> ./.config



# --- 修复源码脚本语法错误 (仅在检测到错误时执行) ---
TARGET_FILE="target/linux/qualcommax/ipq60xx/base-files/etc/hotplug.d/firmware/11-ath11k-caldata"

if [ -f "$TARGET_FILE" ]; then
    # 逻辑：查找包含 rbs350 的行，且该行不包含续行符 '|'
    if grep -q "netgear,rbs350" "$TARGET_FILE" && ! grep -q "netgear,rbs350[[:space:]]*|" "$TARGET_FILE"; then
        echo "[FIX] 检测到 11-ath11k-caldata 语法错误，正在修复..."
        # 兼容可能存在的空格，将其替换为标准续行格式
        sed -i 's/netgear,rbs350[[:space:]]*$/netgear,rbs350 | \\/g' "$TARGET_FILE"
        
        # 验证修复结果
        if grep -q "netgear,rbs350 | \\\\" "$TARGET_FILE"; then
            echo "[SUCCESS] 语法修复成功！"
        else
            echo "[ERROR] 语法修复失败，请检查 sed 匹配规则。"
        fi
    else
        echo "[SKIP] 11-ath11k-caldata 语法正常或已修复，跳过。"
    fi
fi

# --- 2. 建立 by-partlabel 链接 (这是 caldata_extract_mmc 函数运行的前提) ---
# 这个脚本建议保留，因为它不修改源码，只在固件运行时提供必要的设备映射
mkdir -p files/etc/hotplug.d/block
cat > files/etc/hotplug.d/block/05-partlabel <<EOF
#!/bin/sh
[ "\$ACTION" = "add" ] || exit 0
case "\$DEVNAME" in
    mmcblk*)
        ID_PART_NAME=\$(blkid -s PARTLABEL -o value /dev/\$DEVNAME)
        [ -z "\$ID_PART_NAME" ] && ID_PART_NAME=\$(blkid -s PART_ENTRY_NAME -o value /dev/\$DEVNAME)
        if [ -n "\$ID_PART_NAME" ]; then
            mkdir -p /dev/disk/by-partlabel
            ln -sf /dev/\$DEVNAME /dev/disk/by-partlabel/\$ID_PART_NAME
        fi
        ;;
esac
EOF
chmod +x files/etc/hotplug.d/block/05-partlabel
