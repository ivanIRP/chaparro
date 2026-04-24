#!/bin/bash

if [[ $EUID -ne 0 ]]; then echo "Ejecuta como root"; exit 1; fi

# 1. PREPARACIÓN DEL KERNEL
echo "[*] Cargando módulos y habilitando forwarding..."
modprobe sit       # Para IPv6 sobre IPv4
modprobe ip6_gre   # Para IPv4 sobre IPv6
echo 1 > /proc/sys/net/ipv4/ip_forward
echo 1 > /proc/sys/net/ipv6/conf/all/forwarding

# 2. SELECCIÓN DE ROUTER
echo "================================================="
echo "   CONFIGURACIÓN FINAL (VALIDADA POR IMAGEN)    "
echo "================================================="
echo "0) R0 | 1) R1 | 2) R2 | 3) R3 | 4) R4 | 5) R5"
read -p "Router: " OPC

# 3. LIMPIEZA DE RESIDUOS (Para evitar "File exists" y "No buffer space")
ip tunnel del tunR0 2>/dev/null; ip tunnel del tunR1 2>/dev/null
ip tunnel del tunR3 2>/dev/null; ip tunnel del tunR4 2>/dev/null
ip link del tunR3 2>/dev/null; ip link del tunR1 2>/dev/null
ip addr flush dev enp0s3 2>/dev/null; ip addr flush dev enp0s8 2>/dev/null; ip addr flush dev enp0s9 2>/dev/null

case $OPC in
    0) # R0: LAN v6 -> Enlace v4
        ip addr add 2000::2/125 dev enp0s3
        ip addr add 200.0.0.1/30 dev enp0s8
        ip link set enp0s3 up; ip link set enp0s8 up
        ip tunnel add tunR1 mode sit remote 200.0.0.2 local 200.0.0.1
        ip link set tunR1 up
        ip addr add 2000::19/125 dev tunR1
        vtysh -c "conf t" -c "ipv6 route 2000::/110 2000::25 tunR1" -c "exit" -c "write"
        ;;
    1) # R1: Dual Stack (Puente GRE e SIT)
        ip addr add 200.0.0.2/30 dev enp0s3
        ip addr add 2000::17/125 dev enp0s8
        ip addr add 8.0.0.254/24 dev enp0s9
        ip link set enp0s3 up; ip link set enp0s8 up; ip link set enp0s9 up
        # SIT hacia R0
        ip tunnel add tunR0 mode sit remote 200.0.0.1 local 200.0.0.2
        ip link set tunR0 up
        # GRE hacia R3 (Cruza R2)
        ip link add tunR3 type ip6gre local 2000::17 remote 2000::22
        ip link set tunR3 up
        ip addr add 10.0.0.1/30 dev tunR3
        vtysh -c "conf t" \
              -c "ipv6 route 2000::/125 tunR0" \
              -c "ip route 9.0.0.0/24 10.0.0.2" \
              -c "ip route 11.0.0.0/24 10.0.0.2" \
              -c "exit" -c "write"
        ;;
    2) # R2: Core IPv6 puro
        ip addr add 2000::18/125 dev enp0s3
        ip addr add 2000::21/125 dev enp0s8
        ip addr add 2000::14/125 dev enp0s9
        ip link set enp0s3 up; ip link set enp0s8 up; ip link set enp0s9 up
        vtysh -c "conf t" -c "ipv6 route 2000::/115 2000::17" -c "ipv6 route 2000::22/125 2000::21" -c "exit" -c "write"
        ;;
    3) # R3: Dual Stack (Puente GRE e SIT)
        ip addr add 2000::22/125 dev enp0s3
        ip addr add 200.0.0.5/30 dev enp0s8
        ip addr add 9.0.0.254/24 dev enp0s9
        ip link set enp0s3 up; ip link set enp0s8 up; ip link set enp0s9 up
        # GRE hacia R1
        ip link add tunR1 type ip6gre local 2000::22 remote 2000::17
        ip link set tunR1 up
        ip addr add 10.0.0.2/30 dev tunR1
        # SIT hacia R4
        ip tunnel add tunR4 mode sit remote 200.0.0.6 local 200.0.0.5
        ip link set tunR4 up
        ip addr add 2000::25/125 dev tunR4
        vtysh -c "conf t" \
              -c "ip route 8.0.0.0/24 10.0.0.1" \
              -c "ipv6 route 2000::10/125 2000::13 tunR4" \
              -c "exit" -c "write"
        ;;
    4) # R4: Core IPv4 puro
        ip addr add 200.0.0.6/30 dev enp0s3
        ip addr add 200.0.0.9/30 dev enp0s8
        ip addr add 2000::13/125 dev enp0s9
        ip link set enp0s3 up; ip link set enp0s8 up; ip link set enp0s9 up
        vtysh -c "conf t" -c "ip route 8.0.0.0/24 200.0.0.5" -c "ip route 11.0.0.0/24 200.0.0.10" -c "exit" -c "write"
        ;;
    5) # R5: Borde IPv4
        ip addr add 200.0.0.10/30 dev enp0s3
        ip addr add 11.0.0.254/24 dev enp0s8
        ip link set enp0s3 up; ip link set enp0s8 up
        vtysh -c "conf t" -c "ip route 0.0.0.0/0 200.0.0.9" -c "exit" -c "write"
        ;;
esac

# 4. REINICIO DE SERVICIOS
systemctl restart frr
echo "[!] Configuración aplicada para R$OPC."