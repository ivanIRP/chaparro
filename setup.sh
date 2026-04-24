#!/bin/bash

# Comprobación de root
if [[ $EUID -ne 0 ]]; then echo "Debes ejecutar el script con sudo."; exit 1; fi

echo "[*] Preparando el sistema y limpiando configuraciones previas..."
/sbin/modprobe sit 2>/dev/null
/sbin/modprobe ip6_gre 2>/dev/null
echo 1 > /proc/sys/net/ipv4/ip_forward
echo 1 > /proc/sys/net/ipv6/conf/all/forwarding

# Limpiamos túneles y direcciones de intentos anteriores
for t in tunR0 tunR1 tunR3 tunR4; do /sbin/ip tunnel del $t 2>/dev/null; /sbin/ip link del $t 2>/dev/null; done
for i in enp0s3 enp0s8 enp0s9; do /sbin/ip addr flush dev $i 2>/dev/null; done

echo "================================================="
echo "   CONFIGURACIÓN DE REDES ESCALABLES (FRR)      "
echo "================================================="
echo "Selecciona el Router actual:"
echo "0) R0 | 1) R1 | 2) R2 | 3) R3 | 4) R4 | 5) R5"
read -p "Opción: " OPC

case $OPC in
    0) 
        echo "Configurando R0..."
        /sbin/ip addr add 2000::2/125 dev enp0s3
        /sbin/ip addr add 200.0.0.1/30 dev enp0s8
        /sbin/ip link set enp0s3 up; /sbin/ip link set enp0s8 up
        
        # Túnel SIT hacia R1 (IPv6 dentro de IPv4)
        /sbin/ip tunnel add tunR1 mode sit remote 200.0.0.2 local 200.0.0.1
        /sbin/ip link set tunR1 up
        /sbin/ip addr add fd00:1::1/126 dev tunR1
        
        vtysh -c "conf t" -c "ipv6 route 2000::/110 fd00:1::2" -c "exit" -c "write"
        ;;
    1) 
        echo "Configurando R1..."
        /sbin/ip addr add 200.0.0.2/30 dev enp0s3
        /sbin/ip addr add 2000::19/125 dev enp0s8
        /sbin/ip addr add 8.0.0.254/24 dev enp0s9
        /sbin/ip link set enp0s3 up; /sbin/ip link set enp0s8 up; /sbin/ip link set enp0s9 up
        
        # Recibir túnel SIT de R0
        /sbin/ip tunnel add tunR0 mode sit remote 200.0.0.1 local 200.0.0.2
        /sbin/ip link set tunR0 up; /sbin/ip addr add fd00:1::2/126 dev tunR0
        
        # Túnel GRE6 hacia R3 (IPv4 dentro de IPv6)
        /sbin/ip link add tunR3 type ip6gre local 2000::19 remote 2000::22
        /sbin/ip link set tunR3 up; /sbin/ip addr add 10.255.0.1/30 dev tunR3
        
        vtysh -c "conf t" \
             -c "ipv6 route 2000::/125 fd00:1::1" \
             -c "ip route 9.0.0.0/24 10.255.0.2" \
             -c "ip route 11.0.0.0/24 10.255.0.2" \
             -c "ip route 200.0.0.4/30 10.255.0.2" \
             -c "ip route 200.0.0.8/30 10.255.0.2" -c "exit" -c "write"
        ;;
    2) 
        echo "Configurando R2 (Core IPv6)..."
        /sbin/ip addr add 2000::1a/125 dev enp0s3  # Hacia R1
        /sbin/ip addr add 2000::21/125 dev enp0s8  # Hacia R3
        /sbin/ip addr add 2000::a/125 dev enp0s9   # LAN
        /sbin/ip link set enp0s3 up; /sbin/ip link set enp0s8 up; /sbin/ip link set enp0s9 up
        
        vtysh -c "conf t" \
             -c "ipv6 route 2000::/125 2000::19" \
             -c "ipv6 route 2000::10/125 2000::22" -c "exit" -c "write"
        ;;
    3) 
        echo "Configurando R3..."
        /sbin/ip addr add 2000::22/125 dev enp0s3
        /sbin/ip addr add 200.0.0.5/30 dev enp0s8
        /sbin/ip addr add 9.0.0.254/24 dev enp0s9
        /sbin/ip link set enp0s3 up; /sbin/ip link set enp0s8 up; /sbin/ip link set enp0s9 up
        
        # Recibir túnel GRE6 de R1
        /sbin/ip link add tunR1 type ip6gre local 2000::22 remote 2000::19
        /sbin/ip link set tunR1 up; /sbin/ip addr add 10.255.0.2/30 dev tunR1
        
        # Túnel SIT hacia R4 (IPv6 dentro de IPv4)
        /sbin/ip tunnel add tunR4 mode sit remote 200.0.0.6 local 200.0.0.5
        /sbin/ip link set tunR4 up; /sbin/ip addr add fd00:2::1/126 dev tunR4
        
        vtysh -c "conf t" \
             -c "ip route 8.0.0.0/24 10.255.0.1" \
             -c "ip route 200.0.0.0/30 10.255.0.1" \
             -c "ip route 11.0.0.0/24 200.0.0.6" \
             -c "ipv6 route 2000::/125 2000::21" \
             -c "ipv6 route 2000::8/125 2000::21" \
             -c "ipv6 route 2000::10/125 fd00:2::2" -c "exit" -c "write"
        ;;
    4) 
        echo "Configurando R4..."
        /sbin/ip addr add 200.0.0.6/30 dev enp0s3
        /sbin/ip addr add 200.0.0.9/30 dev enp0s8
        /sbin/ip addr add 2000::12/125 dev enp0s9
        /sbin/ip link set enp0s3 up; /sbin/ip link set enp0s8 up; /sbin/ip link set enp0s9 up
        
        # Recibir túnel SIT de R3
        /sbin/ip tunnel add tunR3 mode sit remote 200.0.0.5 local 200.0.0.6
        /sbin/ip link set tunR3 up; /sbin/ip addr add fd00:2::2/126 dev tunR3
        
        vtysh -c "conf t" \
             -c "ip route 8.0.0.0/24 200.0.0.5" \
             -c "ip route 9.0.0.0/24 200.0.0.5" \
             -c "ip route 11.0.0.0/24 200.0.0.10" \
             -c "ipv6 route 2000::/110 fd00:2::1" -c "exit" -c "write"
        ;;
    5) 
        echo "Configurando R5..."
        /sbin/ip addr add 200.0.0.10/30 dev enp0s3
        /sbin/ip addr add 11.0.0.254/24 dev enp0s8
        /sbin/ip link set enp0s3 up; /sbin/ip link set enp0s8 up
        
        vtysh -c "conf t" -c "ip route 0.0.0.0/0 200.0.0.9" -c "exit" -c "write"
        ;;
esac

systemctl restart frr
echo "[!] Configuración aplicada en R$OPC."