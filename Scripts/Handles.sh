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

# 1. 修正 NSS 加载顺序 (ZqinKing 精华)
sed -i 's/START=30/START=11/g' package/kernel/qca-nss-drv/files/qca-nss-drv.init

# 2. 针对 1G 内存提升 NSS PBUF 性能
# 将预留缓冲从默认值提升到 2048 (硬改 1G 建议值)
NSS_DRV_MK="package/kernel/qca-nss-drv/Makefile"
if [ -f "$NSS_DRV_MK" ]; then
    # 移除可能存在的旧定义并添加新定义
    sed -i '/DNSS_DRV_FREE_RESERVE_PBUF_COUNT/d' "$NSS_DRV_MK"
    sed -i '/PKG_RELEASE:=/a\\nEXTRA_CFLAGS += -DNSS_DRV_FREE_RESERVE_PBUF_COUNT=2048' "$NSS_DRV_MK"
    echo "NSS PBUF for 1GB RAM optimized."
fi

# 3. 强制开启 nss-ifb
echo "CONFIG_PACKAGE_kmod-qca-nss-drv-ifb=y" >> .config

