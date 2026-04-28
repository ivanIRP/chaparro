#!/bin/bash
# =========================================================
# SCRIPT DE VICTORIA FINAL - PROYECTO REDES (Basado en Imagen v6.2)
# Iván, asegúrate de cambiar el ID antes de ejecutar:
# =========================================================
ID=1  # <--- CAMBIA ESTO (0, 1, 2, 3, 4, or 5)

echo "--- Aplicando configuración maestra al Router $ID ---"

# --- CAPA 1: LIMPIEZA TOTAL Y FIREWALL (Abrir compuertas) ---
iptables -F && ip6tables -F
iptables -P FORWARD ACCEPT && ip6tables -P FORWARD ACCEPT
iptables -P INPUT ACCEPT && ip6tables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT && ip6tables -P OUTPUT ACCEPT
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv6.conf.all.forwarding=1
ip -6 neigh flush all

# --- CAPA 2: MARTILLAZOS AL KERNEL (Rutas Directas para Túneles y Extremos) ---
# Esto soluciona los problemas de VirtualBox forzando la salida por interfaz
if [ $ID -eq 1 ]; then
    # Rutas para el Túnel IPv4 (R1-R4)
    ip route add 11.0.0.0/24 dev tunR4 2>/dev/null
    # Rutas para el Túnel IPv6 (R1-R4)
    ip -6 route add 2000::/125 via 2000::1a 2>/dev/null # Hacia R4 por R2
    ip -6 route add 2000::10/125 dev tunR4_v6 2>/dev/null # Hacia PC5 por túnel v6
    # Rutas hacia los extremos locales
    ip route add 8.0.0.0/24 dev enp0s3 2>/dev/null
    ip -6 route add 2000::/125 dev enp0s3 2>/dev/null

elif [ $ID -eq 2 ]; then
    # R2 es el puente central IPv6
    ip -6 route add 2000::19/128 dev enp0s3 2>/dev/null # Hacia R1
    ip -6 route add 2000::1a/128 dev enp0s8 2>/dev/null # Hacia R3

elif [ $ID -eq 3 ]; then
    # R3 es el puente central IPv6
    ip -6 route add 2000::21/128 dev enp0s3 2>/dev/null # Hacia R2
    ip -6 route add 2000::22/128 dev enp0s8 2>/dev/null # Hacia R4

elif [ $ID -eq 4 ]; then
    # Rutas de regreso para el Túnel IPv4 (R4-R1)
    ip route add 8.0.0.0/24 dev tunR1 2>/dev/null
    # Rutas de regreso para el Túnel IPv6 (R4-R1)
    ip -6 route add 2000::8/125 via 2000::21 2>/dev/null # Hacia R1 por R3
    ip -6 route add 2000::/125 dev tunR1_v6 2>/dev/null # Hacia PC0 por túnel v6
    # Rutas hacia los extremos locales
    ip route add 11.0.0.0/24 dev enp0s8 2>/dev/null
    ip -6 route add 2000::10/125 dev enp0s8 2>/dev/null
fi

# --- CAPA 3: CONFIGURACIÓN FRR (VTYSH) ---
# Esta sección configura las rutas estáticas de FRR según la imagen
case $ID in
  0)
    vtysh -c "conf t" \
    -c "ip route 0.0.0.0/0 8.0.0.254" \
    -c "ipv6 route ::/0 2000::1" \
    -c "exit" -c "write"
    ;;
  1)
    vtysh -c "conf t" \
    -c "ip route 11.0.0.0/24 10.255.255.2" \
    -c "ipv6 route 2000::10/125 2000::22" \
    -c "ipv6 route 2000::10/125 fd00:b::2" \
    -c "ipv6 route 2000::/125 2000::" \
    -c "exit" -c "write"
    ;;
  2)
    vtysh -c "conf t" \
    -c "ipv6 route 2000::/125 2000::19" \
    -c "ipv6 route 2000::20/125 2000::1a" \
    -c "exit" -c "write"
    ;;
  3)
    vtysh -c "conf t" \
    -c "ipv6 route 2000::8/125 2000::21" \
    -c "ipv6 route 2000::10/125 2000::22" \
    -c "exit" -c "write"
    ;;
  4)
    vtysh -c "conf t" \
    -c "ip route 8.0.0.0/24 10.255.255.1" \
    -c "ipv6 route 2000::/125 2000::21" \
    -c "ipv6 route 2000::/125 fd00:a::1" \
    -c "ipv6 route 2000::10/125 2000::110" \
    -c "exit" -c "write"
    ;;
  5)
    vtysh -c "conf t" \
    -c "ip route 0.0.0.0/0 11.0.0.254" \
    -c "ipv6 route ::/0 2000::110" \
    -c "exit" -c "write"
    ;;
esac

echo "--- Router $ID LISTO. El escenario de la imagen está configurado. ---"