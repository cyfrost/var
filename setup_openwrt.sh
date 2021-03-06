echo "======================================="
echo "	Configuring OpenWRT	     "
echo "======================================="

if [ -z ${ROOT_PASSWD+x} ] || [ -z ${ZONENAME+x} ] || [ -z ${TIMEZONE+x} ] || [ -z ${PPPOE_USERNAME+x} ] || [ -z ${PPPOE_PASSWORD+x} ] || [ -z ${SSID_5GHZ+x} ] || [ -z ${SSID_2GHZ+x} ] || [ -z ${AP_PASSWORD+x} ] || [ -z ${RADIO_LOC_CODE+x} ]; then
	printf "\n\nError: one or more config variables are not set, Abort.\n\n"
	exit 2
fi

if [ "$HOSTNAME" != "OpenWrt" ]; then
  echo 'Error: intended use of this script is on a fresh OpenWrt install only. Abort!'
  exit 2
fi

echo 'Updating root password...'
passwd <<EOF
$ROOT_PASSWD
$ROOT_PASSWD
EOF

HOSTNAME="openwrt"
echo 'Setting hostname to ' $HOSTNAME
uci set system.@system[0].hostname="$HOSTNAME"
uci commit system

echo 'Setting up few ash aliases...'
cat <<EOT >> /etc/profile

alias u='opkg update'
alias ins='opkg install'
alias no_chess='uci del dhcp.@dnsmasq[0].server; uci add_list dhcp.@dnsmasq[0].server=/chess.com/ && uci add_list dhcp.@dnsmasq[0].server=/lichess.org/ && uci commit dhcp && /etc/init.d/dnsmasq restart'
alias chess='uci del dhcp.@dnsmasq[0].server && uci commit dhcp && /etc/init.d/dnsmasq restart'
alias ~='cd ~'
alias ..='cd ..'
alias ...='cd ../../../'
alias ....='cd ../../../../'
alias .....='cd ../../../../'
alias c='reset'
alias e='exit'
alias rmd='rm -rf'
alias j='jobs -l'
alias ping='ping -c 5 google.com'
alias mem='free -mlht'
alias l='ls -AltchF --color=auto --group-directories-first'
alias g='grep -i'
alias v='vim'
alias fs='df -hT'
alias path='echo -e ${PATH//:/\\n}'
alias ipe='curl -s ipinfo.io/ip'
alias tn='tmux new-session -s '
alias ta='tmux attach -t '
alias tl='tmux ls '
alias tk='tmux kill-session -s '
alias ipl='ip -o -4 addr list $(ls /sys/class/net | grep enp) | awk "{print $4}" | cut -d/ -f1'

EOT

echo 'Setting timezone info...'
uci set system.@system[0].zonename="$ZONENAME"
uci set system.@system[0].timezone="$TIMEZONE"
uci commit system

echo 'Deleting default radios...'
uci delete wireless.default_radio0
uci delete wireless.default_radio1

echo 'Setting up PPPoE on WAN intef...'
uci add luci ifstate
uci set luci.@ifstate[-1].interface='wan'
uci set luci.@ifstate[-1].ifname='eth0'
uci set luci.@ifstate[-1].bridge='false'
uci del network.wan.proto
uci set network.wan.proto='pppoe'
uci set network.wan.username="$PPPOE_USERNAME"
uci set network.wan.password="$PPPOE_PASSWORD"
uci set network.wan.ipv6='auto'
uci commit network
uci commit luci

echo 'Staging a 5Ghz AP...'
uci set wireless.cyrus5="wifi-iface"
uci set wireless.cyrus5.device='radio0'
uci set wireless.cyrus5.mode='ap'
uci set wireless.cyrus5.network='lan'
uci set wireless.cyrus5.hidden='0'
uci set wireless.cyrus5.ssid="$SSID_5GHZ"
uci set wireless.cyrus5.encryption='psk2'
uci set wireless.cyrus5.key="$AP_PASSWORD"

echo 'Staging a 2.4Ghz AP...'
uci set wireless.cyrus="wifi-iface"
uci set wireless.cyrus.device='radio1'
uci set wireless.cyrus.mode='ap'
uci set wireless.cyrus.network='lan'
uci set wireless.cyrus.hidden='0'
uci set wireless.cyrus.ssid="$SSID_2GHZ"
uci set wireless.cyrus.encryption='psk2'
uci set wireless.cyrus.key="$AP_PASSWORD"

echo 'Disabling a few sites in network...'
uci add_list dhcp.@dnsmasq[0].server='/chess.com/'
uci add_list dhcp.@dnsmasq[0].server='/lichess.org/'
uci commit dhcp

echo "Setting radios' locations..."
uci set wireless.radio0.country="$RADIO_LOC_CODE"
uci set wireless.radio1.country="$RADIO_LOC_CODE"

echo 'Enabling radios...'
uci set wireless.radio0.disabled="0"
uci set wireless.radio1.disabled="0"

uci commit wireless
echo "======================================="
echo "	Configuration complete!	     "
echo "	Rebooting!	     "
echo "======================================="
reboot
