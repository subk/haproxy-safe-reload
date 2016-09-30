#!/bin/bash

haproxy_get_ports () {
  netstat -anp | egrep "tcp.*haproxy" | sed -n 's/.*:\([0-9]\+\).*/\1/p' \
    | sort | uniq | paste -sd ',' -
}

iptables_add_drop () {
  iptables -I INPUT -p tcp --match multiport --dports "$1" --syn -j DROP
}

iptables_remove_drop () {
  iptables -D INPUT -p tcp --match multiport --dports "$1" --syn -j DROP
}

echo "[*] Getting HAProxy opened ports.."
HAPROXY_PORTS=$(haproxy_get_ports)
if [ -z "$HAPROXY_PORTS" ]; then
  echo "[!] Could not find any port opened by HAProxy. Aborting."
  exit 1
fi

echo "[*] Found $HAPROXY_PORTS"

echo "[*] Adding DROP rule for SYN packets using iptables.."
iptables_add_drop "$HAPROXY_PORTS"
if [ $? -ne 0 ]; then
  exit 1
fi

echo "[*] Sleeping 1s.."
sleep 1

echo "[*] Reloading HAProxy.."
service haproxy reload
STATUS=$?
if [ $STATUS -ne 0 ]; then
  echo "[!] An error occured while reloading HAProxy."
fi

echo "[*] Removing DROP rule for SYN packets from iptables.."
iptables_remove_drop "$HAPROXY_PORTS"

exit $STATUS
