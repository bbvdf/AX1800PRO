#!/bin/bash

PKG_PATH="$GITHUB_WORKSPACE/$WRT_DIR/package/"

#预置HomeProxy数据
# if [ -d *"homeproxy"* ]; then
# 	echo " "

# 	HP_RULE="surge"
# 	HP_PATH="homeproxy/root/etc/homeproxy"

# 	rm -rf ./$HP_PATH/resources/*

# 	git clone -q --depth=1 --single-branch --branch "release" "https://github.com/Loyalsoldier/surge-rules.git" ./$HP_RULE/
# 	cd ./$HP_RULE/ && RES_VER=$(git log -1 --pretty=format:'%s' | grep -o "[0-9]*")

# 	echo $RES_VER | tee china_ip4.ver china_ip6.ver china_list.ver gfw_list.ver
# 	awk -F, '/^IP-CIDR,/{print $2 > "china_ip4.txt"} /^IP-CIDR6,/{print $2 > "china_ip6.txt"}' cncidr.txt
# 	sed 's/^\.//g' direct.txt > china_list.txt ; sed 's/^\.//g' gfw.txt > gfw_list.txt
# 	mv -f ./{china_*,gfw_list}.{ver,txt} ../$HP_PATH/resources/

# 	cd .. && rm -rf ./$HP_RULE/

# 	cd $PKG_PATH && echo "homeproxy date has been updated!"
# fi



#修改qca-nss-pbuf启动顺序
NSS_PBUF="./kernel/mac80211/files/qca-nss-pbuf.init"
if [ -f "$NSS_PBUF" ]; then
	echo " "

	sed -i 's/START=.*/START=86/g' $NSS_PBUF

	cd $PKG_PATH && echo "qca-nss-pbuf has been fixed!"
fi

#修复TailScale配置文件冲突
TS_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/tailscale/Makefile")
if [ -f "$TS_FILE" ]; then
	echo " "

	sed -i '/\/files/d' $TS_FILE

	cd $PKG_PATH && echo "tailscale has been fixed!"
fi

# 修改 Handles.sh 中的第一项修正
# 尝试使用 find 自动定位文件，避免路径硬编码错误
NSS_DRV_INIT=$(find . -maxdepth 4 -name "qca-nss-drv.init")
if [ -f "$NSS_DRV_INIT" ]; then
    sed -i 's/START=30/START=11/g' "$NSS_DRV_INIT"
    echo "NSS drv fixed at $NSS_DRV_INIT"
fi

# 修改第二项：NSS PBUF 性能优化
NSS_DRV_MK=$(find . -maxdepth 4 -name "Makefile" | grep "qca-nss-drv/Makefile")
if [ -f "$NSS_DRV_MK" ]; then
    sed -i '/DNSS_DRV_FREE_RESERVE_PBUF_COUNT/d' "$NSS_DRV_MK"
    sed -i '/PKG_RELEASE:=/a\\nEXTRA_CFLAGS += -DNSS_DRV_FREE_RESERVE_PBUF_COUNT=2048' "$NSS_DRV_MK"
    echo "NSS PBUF optimized at $NSS_DRV_MK"
fi

# 强制开启 nss-ifb
echo "CONFIG_PACKAGE_kmod-qca-nss-drv-ifb=y" >> .config

# # ===== 修正 luci-app-adguardhome 兼容 24.x =====
# AGH_DIR="./luci-app-adguardhome"
# AGH_MK="$AGH_DIR/Makefile"

# if [ -f "$AGH_MK" ]; then
#     echo "Patching luci-app-adguardhome Makefile..."

#     # 1️⃣ 构建系统从 package.mk 改为 luci.mk
#     if grep -q 'include $(INCLUDE_DIR)/package.mk' "$AGH_MK"; then
#         sed -i 's|include $(INCLUDE_DIR)/package.mk|include ../../luci.mk|g' "$AGH_MK"
#         echo " - Switched to luci.mk"
#     fi

#     # 2️⃣ 修正 SUBMENU（防止 defconfig 清洗）
#     if grep -q 'SUBMENU:=' "$AGH_MK"; then
#         sed -i 's|SUBMENU:=.*|SUBMENU:=Applications|g' "$AGH_MK"
#         echo " - Fixed SUBMENU"
#     fi

#     # 3️⃣ 可选：强依赖官方 adguardhome（防止被清）
#     if ! grep -q '+adguardhome' "$AGH_MK"; then
#         sed -i 's|DEPENDS:=|DEPENDS:=+adguardhome |g' "$AGH_MK"
#         echo " - Added dependency: +adguardhome"
#     fi

#     echo "luci-app-adguardhome patch complete."
# fi
