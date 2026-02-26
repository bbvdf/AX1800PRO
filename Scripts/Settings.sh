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
# DTS_PATH="./target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/"
# if [[ $WRT_TARGET == *"QUALCOMMAX"* ]]; then
# 	#取消nss相关feed
# 	echo "CONFIG_FEED_nss_packages=n" >> ./.config
# 	echo "CONFIG_FEED_sqm_scripts_nss=n" >> ./.config
# 	#设置NSS版本
# 	echo "CONFIG_NSS_FIRMWARE_VERSION_11_4=n" >> ./.config
# 	echo "CONFIG_NSS_FIRMWARE_VERSION_12_5=y" >> ./.config
# 	#开启sqm-nss插件
# 	echo "CONFIG_PACKAGE_luci-app-sqm=y" >> ./.config
# 	echo "CONFIG_PACKAGE_sqm-scripts-nss=y" >> ./.config
# 	#无WIFI配置调整Q6大小
# 	if [[ "${WRT_CONFIG}" == *"NOWIFI"* ]]; then
# 		find $DTS_PATH -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
# 		echo "qualcommax set up nowifi successfully!"
# 	fi
# fi

# --- 高通平台 DTS 自动化处理 ---
if [[ $WRT_TARGET == *"QUALCOMMAX"* ]]; then
    echo "开始执行 QUALCOMMAX 平台特定优化..."

    # 1. 自动搜索京东云 RE-SS-01 的 DTS 文件
    # 搜索范围限定在 target/linux/qualcommax，避免全盘搜索浪费时间
    RE_DTS=$(find target/linux/qualcommax -name "ipq6000-re-ss-01.dts" | head -n 1)

    if [ -n "$RE_DTS" ]; then
        echo "日志: 成功定位 DTS 文件 -> $RE_DTS"
        
        # 修改 SSID 或其他原本你脚本里的逻辑（如果有的话）
        # sed -i 's/OpenWrt/MyWiFi/g' "$RE_DTS"
        
        # 即使你现在只想尝试改路径，我也强烈建议你打印一下该文件内容作为日志
        echo "日志: 该 DTS 当前内容片段:"
        grep "calibration-variant" "$RE_DTS" || echo "日志: 未在该文件中发现 variant 限制"
    else
        echo "错误: 无法在源码中找到 ipq6000-re-ss-01.dts，请检查 Commit 路径变动！"
    fi

    # 2. NSS 和插件配置
	#取消nss相关feed
    echo "CONFIG_FEED_nss_packages=n" >> ./.config
    echo "CONFIG_FEED_sqm_scripts_nss=n" >> ./.config
	#设置NSS版本
    echo "CONFIG_NSS_FIRMWARE_VERSION_11_4=n" >> ./.config
    echo "CONFIG_NSS_FIRMWARE_VERSION_12_5=y" >> ./.config
	#开启sqm-nss插件
    echo "CONFIG_PACKAGE_luci-app-sqm=y" >> ./.config
    echo "CONFIG_PACKAGE_sqm-scripts-nss=y" >> ./.config

    # 3. 修正 NOWIFI 逻辑 (使用模糊路径搜索)
    if [[ "${WRT_CONFIG}" == *"NOWIFI"* ]]; then
        # 这里的路径改为动态搜索到的目录
        DTS_SEARCH_DIR=$(dirname "$RE_DTS")
        if [ -d "$DTS_SEARCH_DIR" ]; then
            find "$DTS_SEARCH_DIR" -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
            echo "日志: 已在 $DTS_SEARCH_DIR 成功应用 NOWIFI 补丁"
        fi
    fi
    
    echo "QUALCOMMAX 平台优化执行完毕。"
fi


# 去掉attendedsysupgrade
sed -i 's/+luci-app-attendedsysupgrade//g' feeds/luci/collections/luci/Makefile
sed -i '/CONFIG_PACKAGE_luci-app-attendedsysupgrade/d' ./.config
echo "CONFIG_PACKAGE_luci-app-attendedsysupgrade=n" >> ./.config
