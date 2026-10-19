#!/bin/bash
# Scripts/ppe-setup.sh —— openwrt-ppe-nss 专用：feeds 与外来包
# 在源码根目录执行，且必须在 ./scripts/feeds update 之前

set -e

# 1) feeds：packages/luci 用 immortalwrt 的（提供 daed/argon/filemanager/ramfree/cpufreq 等），
#    另加 ppe-nss 需要的两个专用 feed（hw-ppe-offload 的 sqm、luci-app-ppe-qos）
cat > feeds.conf.default <<'EOF'
src-git packages https://github.com/immortalwrt/packages.git
src-git luci https://github.com/immortalwrt/luci.git
src-git routing https://github.com/openwrt/routing.git
src-git telephony https://github.com/openwrt/telephony.git
src-git sqm_scripts_ppe https://github.com/JuliusBairaktaris/sqm-scripts.git;hw-ppe-offload
src-git luci_ppe_qos https://github.com/JuliusBairaktaris/luci.git;luci-app-ppe-qos
# nss-firmware 只在这个 feed 里；其余包（qca-nss-drv/ecm 旧栈）不选中即不编译
src-git nss https://github.com/JuliusBairaktaris/nss-packages.git;edma-nss
EOF

# 2) immortalwrt 私有包：autocore / cpufreq / default-settings / mhz / px5g-openssl
git clone --no-checkout --depth 1 https://github.com/immortalwrt/immortalwrt mwrt
cd mwrt
git sparse-checkout set \
	package/emortal/autocore \
	package/emortal/automount \
	package/emortal/cpufreq \
	package/emortal/default-settings \
	package/utils/mhz \
	package/utils/px5g-openssl
git checkout
cp -R package/emortal/* ../package/
cp -R package/utils/mhz ../package/
cp -R package/utils/px5g-openssl ../package/
cd .. && rm -rf mwrt

# 3) arm64 /proc/cpuinfo model name（autocore 显示 CPU 型号用），ppe-nss 未带此补丁
P=target/linux/generic/hack-6.18/312-arm64-cpuinfo-Add-model-name-in-proc-cpuinfo-for-64bit-ta.patch
if [ -d target/linux/generic/hack-6.18 ] && [ ! -f "$P" ]; then
	curl -sSL -o "$P" "https://raw.githubusercontent.com/immortalwrt/immortalwrt/master/$P" || rm -f "$P"
fi

# 4) aurora 主题与配置页（eamonxg，仓库根即包目录）
if [ ! -d package/luci-theme-aurora ]; then
	git clone --depth 1 -q https://github.com/eamonxg/luci-theme-aurora.git package/luci-theme-aurora
	git clone --depth 1 -q https://github.com/eamonxg/luci-app-aurora-config.git package/luci-app-aurora-config
	rm -rf package/luci-theme-aurora/.git package/luci-app-aurora-config/.git
fi

echo "ppe-setup done: feeds=$(grep -c '^src-' feeds.conf.default), emortal=$(ls -d package/autocore package/cpufreq package/default-settings 2>/dev/null | wc -l)"
