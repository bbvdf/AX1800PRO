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



######################################################################################################
# 无线数据修复：终极四重保险方案 (Preinit抢跑 + 内核驱动内置 + Init.d补救 + 自动重载)
######################################################################################################

# 1. 核心修正：确保内核内置 MMC 驱动，否则启动初期根本看不见 eMMC 分区
# 仅仅 echo 到 .config 没用，必须修改 target 平台的内核模板配置
TARGET_CONF=$(find target/linux/qualcommax -name "config-6.12" -o -name "config-6.6" | head -n 1)
if [ -n "$TARGET_CONF" ]; then
    echo "[Settings] 正在将 MMC 驱动硬焊进内核..."
    # 强制将驱动从模块 (m) 改为内置 (y)
    sed -i 's/CONFIG_MMC=m/CONFIG_MMC=y/g' "$TARGET_CONF"
    sed -i 's/CONFIG_MMC_BLOCK=m/CONFIG_MMC_BLOCK=y/g' "$TARGET_CONF"
    # 追加必要的分区支持
    {
        echo "CONFIG_MMC_QCOM_DML=y"
        echo "CONFIG_MMC_SDHCI_MSM=y"
        echo "CONFIG_PARTITION_ADVANCED=y"
        echo "CONFIG_EFI_PARTITION=y"
        echo "CONFIG_MSDOS_PARTITION=y"
    } >> "$TARGET_CONF"
fi

# 2. 动态修正 Hotplug 脚本 (针对不同固件源码的兼容性处理)
CAL_FILES=$(find target/linux/qualcommax -name "11-ath11k-caldata")
for FILE in $CAL_FILES; do
    echo "[PROCESSING] 修正补丁: $FILE"
    sed -i 's/caldata_extract_mmc "[^"]*".*/dd if=\/dev\/mmcblk0p15 of=\/lib\/firmware\/ath11k\/IPQ6018\/hw1.0\/cal-ahb-c000000.wifi.bin skip=4 bs=1024 count=64/g' "$FILE"
    sed -i 's@wifi.JDC-RE-SS-01@wifi.bin@g' "$FILE"
done

# 3. 改进 Preinit 脚本：增加“死等”逻辑 (第一道防线：驱动加载前抠出数据)
PREINIT_DIR="target/linux/qualcommax/ipq60xx/base-files/lib/preinit"
mkdir -p "$PREINIT_DIR"
cat > "$PREINIT_DIR/80_extract_caldata" << 'EOF'
#!/bin/sh
do_extract_caldata() {
    mkdir -p /lib/firmware/ath11k/IPQ6018/hw1.0/
    
    # 增加死等逻辑：最多等 10 秒，直到 mmcblk0p15 出现
    local timeout=10
    while [ ! -b /dev/mmcblk0p15 ] && [ $timeout -gt 0 ]; do
        echo "Preinit: Waiting for /dev/mmcblk0p15... ($timeout)" > /dev/kmsg
        sleep 1
        timeout=$((timeout - 1))
    done

    if [ -b /dev/mmcblk0p15 ]; then
        if [ ! -f /lib/firmware/ath11k/IPQ6018/hw1.0/cal-ahb-c000000.wifi.bin ]; then
            echo "Preinit: Extracting caldata from p15..." > /dev/kmsg
            dd if=/dev/mmcblk0p15 of=/lib/firmware/ath11k/IPQ6018/hw1.0/cal-ahb-c000000.wifi.bin skip=4 bs=1024 count=64
            # 标记成功，防止后期重复操作
            touch /tmp/caldata_ready
        fi
    else
        echo "Preinit ERROR: mmcblk0p15 not found after timeout!" > /dev/kmsg
    fi
}
boot_hook_add preinit_main do_extract_caldata
EOF
chmod +x "$PREINIT_DIR/80_extract_caldata"

# 4. 注入 Init.d 服务：强制重载补救 (第二道防线：如果文件来晚了，重启无线)
INITD_DIR="target/linux/qualcommax/ipq60xx/base-files/etc/init.d"
mkdir -p "$INITD_DIR"
cat > "$INITD_DIR/fix-caldata" << 'EOF'
#!/bin/sh /etc/rc.common
START=99  # 尽量靠后，确保系统已经稳固

start() {
    # 检查文件是否存在
    local CAL_FILE="/lib/firmware/ath11k/IPQ6018/hw1.0/cal-ahb-c000000.wifi.bin"
    
    # 如果 Preinit 没搞定，这里最后补救一次
    if [ ! -f "$CAL_FILE" ] && [ -b /dev/mmcblk0p15 ]; then
        mkdir -p /lib/firmware/ath11k/IPQ6018/hw1.0/
        dd if=/dev/mmcblk0p15 of="$CAL_FILE" skip=4 bs=1024 count=64
        echo "Init.d: Caldata fixed late, reloading wifi..." > /dev/kmsg
        /sbin/wifi up
        /sbin/wifi reload
    fi
}
EOF
chmod +x "$INITD_DIR/fix-caldata"
