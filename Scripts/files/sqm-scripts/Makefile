#
# OpenWrt package for sqm-scripts, sourced from JuliusBairaktaris'
# hw-ppe-offload branch instead of tohojo's master.
#
# The stock feed (feeds/packages/net/sqm-scripts) pulls tohojo/sqm-scripts,
# which has no hw_ppe.qos; the PPE hardware shaper cannot be driven without
# it. Only the source changes here: package name, dependencies and the
# install rule stay identical to the stock package, so everything that
# depends on sqm-scripts keeps resolving.
#
# Upstream of this branch: https://github.com/JuliusBairaktaris/sqm-scripts
#
include $(TOPDIR)/rules.mk

PKG_NAME:=sqm-scripts
PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/JuliusBairaktaris/sqm-scripts.git
PKG_SOURCE_VERSION:=ad4a2416ead00b55cedb3fcff92269f915a8b36a
PKG_VERSION:=1.8.0
PKG_RELEASE:=1

PKG_MAINTAINER:=Toke Høiland-Jørgensen <toke@toke.dk>
PKG_LICENSE:=GPL-2.0-only

include $(INCLUDE_DIR)/package.mk

define Package/sqm-scripts
  SECTION:=net
  CATEGORY:=Base system
  DEPENDS:=+tc +ip +kmod-sched-cake +kmod-ifb +nftables
  TITLE:=SQM Scripts (QoS), with the PPE hardware shaper
  PKGARCH:=all
endef

define Package/sqm-scripts/description
 A set of scripts that does simple SQM configuration. This build carries
 hw_ppe.qos, which shapes in the switch so that connections offloaded to the
 PPE flow engine are shaped too.
endef

define Package/sqm-scripts/conffiles
/etc/config/sqm
/etc/sqm/sqm.conf
endef

define Package/sqm-scripts/install
	make -C $(PKG_BUILD_DIR) DESTDIR=$(1) PLATFORM=openwrt install
endef

$(eval $(call BuildPackage,sqm-scripts))
