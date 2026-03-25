#!/bin/bash
# Auto-configurador de Routers Debian 12 - FIX CABLES CRUZADOS

# ==========================================
# TU CABLEADO FÍSICO (VIRTUALBOX)
# ==========================================
IF_PC="enp0s3"   # Hacia la PC (Abajo)
IF_IZQ="enp0s9"  # Hacia el router de la Izquierda
IF_DER="enp0s8"  # Hacia el router de la Derecha

if [ "$EUID" -ne 0 ]; then
  echo "Por favor, ejecuta este script como root (sudo)"
  exit 1
fi

echo "======================================="
echo "   CONFIGURACION DE ROUTER DEBIAN 12   "
echo "======================================="
read -p "Que router vas a configurar? (Ingresa del 0 al 5): " ROUTER_NUM

# Habilitar IP Forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward
echo 1 > /proc/sys/net/ipv6/conf/all/forwarding
echo 1 > /proc/sys/net/ipv6/conf/default/forwarding

# Limpiar interfaces (Borrón y cuenta nueva)
ip -6 addr flush dev $IF_PC scope global 2>/dev/null
ip -6 addr flush dev $IF_IZQ scope global 2>/dev/null
ip -6 addr flush dev $IF_DER scope global 2>/dev/null
ip -4 addr flush dev $IF_IZQ 2>/dev/null
ip -4 addr flush dev $IF_DER 2>/dev/null
ip tunnel del tun0 2>/dev/null

FRR_CONF="/etc/frr/frr.conf"
cat <<EOF > $FRR_CONF
frr defaults traditional
hostname R$ROUTER_NUM
no ipv6 forwarding
!
EOF

case $ROUTER_NUM in
  0)
    echo "Configurando R0 (Solo conecta a la Derecha)..."
    ip link set up dev $IF_PC
    ip -6 addr add 2000::1/64 dev $IF_PC
    
    ip link set up dev $IF_DER
    ip -6 addr add 2002::1/64 dev $IF_DER
    ip -6 addr add fe80::10/64 dev $IF_DER scope link

    cat <<EOF >> $FRR_CONF
interface $IF_PC
 ipv6 ospf6 area 0
!
interface $IF_DER
 ipv6 ospf6 network point-to-point
 ipv6 ospf6 area 0
!
router ospf6
 ospf6 router-id 1.1.1.1
 redistribute connected
!
EOF
    ;;
    
  1)
    echo "Configurando R1 (Izquierda IPv6, Derecha IPv4)..."
    ip link set up dev $IF_PC
    ip -6 addr add 2001::1/64 dev $IF_PC
    
    # Izquierda hacia R0 (IPv6)
    ip link set up dev $IF_IZQ
    ip -6 addr add 2002::2/64 dev $IF_IZQ
    ip -6 addr add fe80::11/64 dev $IF_IZQ scope link
    
    # Derecha hacia R2 (IPv4)
    ip link set up dev $IF_DER
    ip addr add 192.168.0.1/30 dev $IF_DER
    
    # Tunel
    ip tunnel add tun0 mode sit remote 192.168.0.10 local 192.168.0.1 ttl 255
    ip link set up dev tun0
    ip -6 addr add 3000::1/64 dev tun0
    ip -6 addr add fe80::1/64 dev tun0 scope link
    echo 1 > /proc/sys/net/ipv6/conf/tun0/forwarding 2>/dev/null

    cat <<EOF >> $FRR_CONF
interface $IF_PC
 ipv6 ospf6 area 0
!
interface $IF_IZQ
 ipv6 ospf6 network point-to-point
 ipv6 ospf6 area 0
!
interface tun0
 ipv6 ospf6 network point-to-point
 ipv6 ospf6 area 0
!
router rip
 version 2
 network 192.168.0.0/24
!
router ospf6
 ospf6 router-id 1.1.1.2
 redistribute connected
!
EOF
    ;;
    
  2)
    echo "Configurando R2 (Izquierda y Derecha IPv4)..."
    ip link set up dev $IF_IZQ
    ip addr add 192.168.0.2/30 dev $IF_IZQ
    
    ip link set up dev $IF_DER
    ip addr add 192.168.0.5/30 dev $IF_DER

    cat <<EOF >> $FRR_CONF
router rip
 version 2
 network 192.168.0.0/24
!
EOF
    ;;
    
  3)
    echo "Configurando R3 (Izquierda y Derecha IPv4)..."
    ip link set up dev $IF_IZQ
    ip addr add 192.168.0.6/30 dev $IF_IZQ
    
    ip link set up dev $IF_DER
    ip addr add 192.168.0.9/30 dev $IF_DER

    cat <<EOF >> $FRR_CONF
router rip
 version 2
 network 192.168.0.0/24
!
EOF
    ;;
    
  4)
    echo "Configurando R4 (Izquierda IPv4, Derecha IPv6)..."
    ip link set up dev $IF_PC
    ip -6 addr add 2003::1/64 dev $IF_PC
    
    # Izquierda hacia R3 (IPv4)
    ip link set up dev $IF_IZQ
    ip addr add 192.168.0.10/30 dev $IF_IZQ
    
    # Derecha hacia R5 (IPv6)
    ip link set up dev $IF_DER
    ip -6 addr add 2005::1/64 dev $IF_DER
    ip -6 addr add fe80::14/64 dev $IF_DER scope link
    
    # Tunel
    ip tunnel add tun0 mode sit remote 192.168.0.1 local 192.168.0.10 ttl 255
    ip link set up dev tun0
    ip -6 addr add 3000::2/64 dev tun0
    ip -6 addr add fe80::4/64 dev tun0 scope link
    echo 1 > /proc/sys/net/ipv6/conf/tun0/forwarding 2>/dev/null

    cat <<EOF >> $FRR_CONF
interface $IF_PC
 ipv6 ospf6 area 0
!
interface $IF_DER
 ipv6 ospf6 network point-to-point
 ipv6 ospf6 area 0
!
interface tun0
 ipv6 ospf6 network point-to-point
 ipv6 ospf6 area 0
!
router rip
 version 2
 network 192.168.0.0/24
!
router ospf6
 ospf6 router-id 1.1.1.3
 redistribute connected
!
EOF
    ;;
    
  5)
    echo "Configurando R5 (Solo conecta a la Izquierda)..."
    ip link set up dev $IF_PC
    ip -6 addr add 2004::1/64 dev $IF_PC
    
    ip link set up dev $IF_IZQ
    ip -6 addr add 2005::2/64 dev $IF_IZQ
    ip -6 addr add fe80::15/64 dev $IF_IZQ scope link

    cat <<EOF >> $FRR_CONF
interface $IF_PC
 ipv6 ospf6 area 0
!
interface $IF_IZQ
 ipv6 ospf6 network point-to-point
 ipv6 ospf6 area 0
!
router ospf6
 ospf6 router-id 1.1.1.4
 redistribute connected
!
EOF
    ;;
esac

systemctl restart frr
echo "Configuracion de R$ROUTER_NUM completada con los cables corregidos."