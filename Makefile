include $(TOPDIR)/rules.mk

PKG_NAME:=frt
PKG_VERSION:=1.1.9_beta-11
PKG_RELEASE:=20
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)-$(PKG_RELEASE)
MOLOT_UNINSTALL:=frt uninstall full

include $(INCLUDE_DIR)/package.mk

define Package/frt
	SECTION:=utils
	CATEGORY:=Keendev
	DEPENDS:=+libpcre +jq +curl +knot-dig +nano-full +cron +bind-dig +dnsmasq-full +ipset +iptables +shadowsocks-libev-ss-redir +shadowsocks-libev-config +libmbedtls +stubby
	URL:=no
	TITLE:=Forest Router Tool (FRT) - VPN client for whitelist hosts
	PKGARCH:=all
endef

define Package/frt/description
	Forest Router Tool (FRT). Maintains a protected whitelist of hosts.
	Traffic to any host in the list is routed via VPN or Shadowsocks on the router.
endef

define Build/Prepare
endef
define Build/Configure
endef
define Build/Compile
endef

define Package/frt/install
	$(INSTALL_DIR) $(1)/opt/etc/init.d
	$(INSTALL_DIR) $(1)/opt/etc/ndm/fs.d
	$(INSTALL_DIR) $(1)/opt/etc/ndm/netfilter.d
	$(INSTALL_DIR) $(1)/opt/apps/frt

	$(INSTALL_BIN) opt/etc/ndm/fs.d/15-frt-start.sh $(1)/opt/etc/ndm/fs.d
	$(INSTALL_BIN) opt/etc/ndm/netfilter.d/100-dns-local $(1)/opt/etc/ndm/netfilter.d

	$(INSTALL_BIN) opt/etc/init.d/S96frt $(1)/opt/etc/init.d
	$(CP) ./opt/. $(1)/opt/apps/frt
endef

define Package/frt/postinst

#!/bin/sh

BLUE="\033[36m";
NOCL="\033[m";

print_line()(printf "%83s\n" | tr " " "=")

chmod -R +x /opt/apps/frt/bin/*
chmod -R +x /opt/apps/frt/etc/init.d/*
chmod -R +x /opt/apps/frt/etc/ndm/*

ln -sf /opt/apps/frt/bin/frt /opt/bin/frt

cp -f /opt/apps/frt/etc/conf/frt.conf /opt/etc/frt.conf
[ -f /opt/etc/frt.list ] || cp -f /opt/apps/frt/etc/conf/frt.list /opt/etc/frt.list
mkdir -p /opt/etc/dnsmasq.d
cp -f /opt/apps/frt/etc/ndm/ndm /opt/apps/frt/bin/libs/ndm

sed -i "s/\(APP_VERSION=\).*/\1$(PKG_VERSION)/; s/^,//; s/\,/ /g;" "/opt/etc/frt.conf"
sed -i "s/\(APP_RELEASE=\).*/\1$(PKG_RELEASE)/; s/^,//; s/\,/ /g;" "/opt/etc/frt.conf"

print_line
echo -e "Для настройки пакета FRT наберите \033[36mfrt setup\033[m"
print_line

endef

define Package/frt/postrm

#!/bin/sh

endef

$(eval $(call BuildPackage,frt))
