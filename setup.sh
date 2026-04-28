#!/bin/bash
# =========================================================
# SCRIPT DE VICTORIA FINAL - VERSIÓN BLINDADA (Ivan Robles)
# =========================================================
ID=1  # <--- CAMBIA ESTO (0, 1, 2, 3, 4, o 5)

echo "--- Forzando configuración maestra en Router $ID ---"

# --- 1. APERTURA DE FIREWALL (Rutas absolutas para evitar 'orden no encontrada') ---
/sbin/iptables -F 2>/dev/null
/sbin/ip6tables -F 2>/dev/null
/sbin/iptables -P FORWARD ACCEPT 2>/dev/null
/sbin/ip6tables -P FORWARD ACCEPT 2>/dev/null

# --- 2. ACTIVACIÓN DE REENVÍO (Kernel) ---
/sbin/sysctl -w net.ipv4.ip_forward=1 2>/dev/null
/sbin/sysctl -w net.ipv6.conf.all.forwarding=1 2>/dev/null
/usr/bin/ip -6 neigh flush all 2>/dev/null

# --- 3. RUTAS DE KERNEL ESPECÍFICAS (Martillazos) ---
if [ $ID -eq 1 ]; then
    /usr/bin/ip route add 11.0.0.0/24 dev tunR4 2>/dev/null
    /usr/bin/ip -6 route add 2000::22/128 via 2000::1a 2>/dev/null
    /usr/bin/ip -6 route add 2000::/125 dev tunR0 2>/dev/null
elif [ $ID -eq 4 ]; then
    /usr/bin/ip route add 8.0.0.0/24 dev tunR1 2>/dev/null
    /usr/bin/ip -6 route add 2000::19/128 via 2000::21 2>/dev/null
    /usr/bin/ip -6 route add 2000::10/125 dev tunR4_v6 2>/dev/null
fi

# --- 4. CONFIGURACIÓN FRR (VTYSH) ---
case $ID in
  0) vtysh -c "conf t" -c "ip route 0.0.0.0/0 8.0.0.254" -c "ipv6 route ::/0 2000::1" -c "exit" -c "write" ;;
  1) vtysh -c "conf t" -c "ip route 11.0.0.0/24 10.255.255.2" -c "ipv6 route 2000::10/125 2000::22" -c "exit" -c "write" ;;
  2) vtysh -c "conf t" -c "ipv6 route 2000::/125 2000::19" -c "ipv6 route 2000::20/125 2000::1a" -c "exit" -c "write" ;;
  3) vtysh -c "conf t" -c "ipv6 route 2000::8/125 2000::21" -c "ipv6 route 2000::10/125 2000::22" -c "exit" -c "write" ;;
  4) vtysh -c "conf t" -c "ip route 8.0.0.0/24 10.255.255.1" -c "ipv6 route 2000::/125 2000::21" -c "exit" -c "write" ;;
  5) vtysh -c "conf t" -c "ip route 0.0.0.0/0 11.0.0.254" -c "ipv6 route ::/0 2000::110" -c "exit" -c "write" ;;
esac

echo "--- Router $ID LISTO. Ahora sí, dale a los pings. ---"