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



# --- 1. 创建 hotplug 脚本生成 by-partlabel 软链接 ---
# 此段代码完美，保持不变
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

# --- 2. 修复源码脚本语法错误 ---
# 建议：由于源码路径在不同分支可能略有不同，建议使用 find 动态匹配，更稳健
find target/linux/qualcommax -name "11-ath11k-caldata" | xargs -i sed -i 's/netgear,rbs350$/netgear,rbs350 | \\/g' {}

# --- 3. 增加 uci-defaults 增强版重载逻辑 ---
# --- 提前生成 caldata（真正解决第一次启动无WiFi） ---
mkdir -p files/etc/init.d
cat > files/etc/init.d/caldata-fix <<'EOF'
#!/bin/sh /etc/rc.common

START=02
STOP=01

start() {
    TARGET_DIR="/lib/firmware/ath11k/IPQ6018/hw1.0"
    TARGET_FILE="$TARGET_DIR/cal-ahb-c000000.wifi.bin"
    PART="/dev/disk/by-partlabel/ART"

    if [ ! -s "$TARGET_FILE" ] && [ -e "$PART" ]; then
        mkdir -p "$TARGET_DIR"
        dd if="$PART" of="$TARGET_FILE" \
           bs=1 skip=4096 count=65536 2>/dev/null
    fi
}
EOF

chmod +x files/etc/init.d/caldata-fix

# 关键：默认启用
mkdir -p files/etc/rc.d
ln -sf ../init.d/caldata-fix files/etc/rc.d/S02caldata-fix
