#!/bin/sh
set -eu

: "${VPN_CIDR:?VPN_CIDR is required}"
: "${PRIVATE_CIDRS:?PRIVATE_CIDRS is required}"
case "$VPN_CIDR $PRIVATE_CIDRS ${VPN_DNS:-}" in
  *REPLACE*|*[!0-9./\ ]*) echo 'Configure numeric VPN_CIDR, PRIVATE_CIDRS and VPN_DNS first.' >&2; exit 1 ;;
esac
[ "$(cat /proc/sys/net/ipv4/ip_forward)" = 1 ] || {
  echo 'The pod requires net.ipv4.ip_forward=1.' >&2; exit 1;
}

# emptyDir must remain writable after OpenVPN drops to nobody.
chmod 1777 /run/openvpn
cp /etc/openvpn/config/server.conf /run/openvpn/server.conf
network=$(ipcalc -n "$VPN_CIDR" | cut -d= -f2)
netmask=$(ipcalc -m "$VPN_CIDR" | cut -d= -f2)
printf '\nserver %s %s\n' "$network" "$netmask" >> /run/openvpn/server.conf

# Limit forwarded VPN traffic to the explicit route allowlist, even if a
# client adds its own routes. Rules live in this pod's network namespace.
iptables -N MVPN-OUT 2>/dev/null || true
iptables -F MVPN-OUT
iptables -C FORWARD -i tun0 -j MVPN-OUT 2>/dev/null || iptables -I FORWARD 1 -i tun0 -j MVPN-OUT
iptables -C FORWARD -o tun0 -j DROP 2>/dev/null || iptables -A FORWARD -o tun0 -j DROP
iptables -C FORWARD -i eth0 -o tun0 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || \
  iptables -I FORWARD 1 -i eth0 -o tun0 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -C INPUT -i tun0 -j DROP 2>/dev/null || iptables -I INPUT 1 -i tun0 -j DROP

for cidr in $PRIVATE_CIDRS; do
  [ "$cidr" != '0.0.0.0/0' ] || { echo 'Use explicit private routes, not a default route.' >&2; exit 1; }
  network=$(ipcalc -n "$cidr" | cut -d= -f2)
  netmask=$(ipcalc -m "$cidr" | cut -d= -f2)
  printf 'push "route %s %s"\n' "$network" "$netmask" >> /run/openvpn/server.conf
  iptables -A MVPN-OUT -s "$VPN_CIDR" -d "$cidr" -o eth0 -j ACCEPT
  iptables -t nat -C POSTROUTING -s "$VPN_CIDR" -d "$cidr" -o eth0 -j MASQUERADE 2>/dev/null || \
    iptables -t nat -A POSTROUTING -s "$VPN_CIDR" -d "$cidr" -o eth0 -j MASQUERADE
done
iptables -A MVPN-OUT -j DROP
if [ -n "${VPN_DNS:-}" ]; then
  printf 'push "dhcp-option DNS %s"\n' "$VPN_DNS" >> /run/openvpn/server.conf
fi
exec openvpn --config /run/openvpn/server.conf
