#!/bin/bash
# Auto-configurador de Routers Debian 12 (Topologia IPv6 sobre IPv4)

# ==========================================
# 1. DEFINE TUS INTERFACES DE LINUX AQUI
# ==========================================
IF_G0="enp0s3"  # Hacia la PC local
IF_S0="enp0s8"  # Conexion Izquierda
IF_S1="enp0s9"  # Conexion Derecha

# ==========================================
# Inicio del Script
# ==========================================
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, ejecuta este script como root (sudo o su -)"
  exit 1
fi

echo "======================================="
echo "   CONFIGURACION DE ROUTER DEBIAN 12   "
echo "======================================="
read -p "Que router vas a configurar? (Ingresa del 0 al 5): " ROUTER_NUM

# Habilitar IP Forwarding directo en el sistema de archivos (A prueba de fallos)
echo 1 > /proc/sys/net/ipv4/ip_forward
echo 1 > /proc/sys/net/ipv6/conf/all/forwarding

# Instalar FRR si no esta instalado
if ! command -v vtysh &> /dev/null; then
    echo "Instalando FRRouting (FRR)..."
    apt-get update
    apt-get install -y frr
fi

# Habilitar RIP y OSPF6 en FRR
sed -i 's/ripd=no/ripd=yes/' /etc/frr/daemons
sed -i 's/ospf6d=no/ospf6d=yes/' /etc/frr/daemons

# Limpiar interfaces y tuneles previos
ip addr flush dev $IF_G0 2>/dev/null
ip addr flush dev $IF_S0 2>/dev/null
ip addr flush dev $IF_S1 2>/dev/null
ip tunnel del tun0 2>/dev/null

# Preparar archivo FRR
FRR_CONF="/etc/frr/frr.conf"
cat <<EOF > $FRR_CONF
frr defaults traditional
hostname R$ROUTER_NUM
no ipv6 forwarding
!
EOF

case $ROUTER_NUM in
  0)
    echo "Configurando R0 (Extremo IPv6)..."
    ip link set up dev $IF_G0
    ip -6 addr add 2000::1/64 dev $IF_G0
    
    ip link set up dev $IF_S0
    ip -6 addr add 2002::1/64 dev $IF_S0

    cat <<EOF >> $FRR_CONF
interface $IF_G0
 ipv6 ospf6 area 0
!
interface $IF_S0
 ipv6 ospf6 area 0
!
router ospf6
 ospf6 router-id 1.1.1.1
!
EOF
    ;;
    
  1)
    echo "Configurando R1 (Inicio del Tunel)..."
    ip link set up dev $IF_G0
    ip -6 addr add 2001::1/64 dev $IF_G0
    
    ip link set up dev $IF_S0
    ip -6 addr add 2002::2/64 dev $IF_S0
    
    ip link set up dev $IF_S1
    ip addr add 192.168.0.1/30 dev $IF_S1
    
    # Crear Tunel IPv6 sobre IPv4 (sit)
    ip tunnel add tun0 mode sit remote 192.168.0.10 local 192.168.0.1 ttl 255
    ip link set up dev tun0
    ip -6 addr add 3000::1/64 dev tun0

    cat <<EOF >> $FRR_CONF
interface $IF_G0
 ipv6 ospf6 area 0
!
interface $IF_S0
 ipv6 ospf6 area 0
!
interface tun0
 ipv6 ospf6 area 0
!
router rip
 version 2
 network 192.168.0.0/24
!
router ospf6
 ospf6 router-id 1.1.1.2
!
EOF
    ;;
    
  2)
    echo "Configurando R2 (Transito IPv4)..."
    ip link set up dev $IF_S0
    ip addr add 192.168.0.2/30 dev $IF_S0
    
    ip link set up dev $IF_S1
    ip addr add 192.168.0.5/30 dev $IF_S1

    cat <<EOF >> $FRR_CONF
router rip
 version 2
 network 192.168.0.0/24
!
EOF
    ;;
    
  3)
    echo "Configurando R3 (Transito IPv4)..."
    ip link set up dev $IF_S0
    ip addr add 192.168.0.6/30 dev $IF_S0
    
    ip link set up dev $IF_S1
    ip addr add 192.168.0.9/30 dev $IF_S1

    cat <<EOF >> $FRR_CONF
router rip
 version 2
 network 192.168.0.0/24
!
EOF
    ;;
    
  4)
    echo "Configurando R4 (Fin del Tunel)..."
    ip link set up dev $IF_G0
    ip -6 addr add 2003::1/64 dev $IF_G0
    
    ip link set up dev $IF_S0
    ip addr add 192.168.0.10/30 dev $IF_S0
    
    ip link set up dev $IF_S1
    ip -6 addr add 2005::1/64 dev $IF_S1
    
    # Crear Tunel IPv6 sobre IPv4 (sit)
    ip tunnel add tun0 mode sit remote 192.168.0.1 local 192.168.0.10 ttl 255
    ip link set up dev tun0
    ip -6 addr add 3000::2/64 dev tun0

    cat <<EOF >> $FRR_CONF
interface $IF_G0
 ipv6 ospf6 area 0
!
interface $IF_S1
 ipv6 ospf6 area 0
!
interface tun0
 ipv6 ospf6 area 0
!
router rip
 version 2
 network 192.168.0.0/24
!
router ospf6
 ospf6 router-id 1.1.1.3
!
EOF
    ;;
    
  5)
    echo "Configurando R5 (Extremo IPv6)..."
    ip link set up dev $IF_G0
    ip -6 addr add 2004::1/64 dev $IF_G0
    
    ip link set up dev $IF_S0
    ip -6 addr add 2005::2/64 dev $IF_S0

    cat <<EOF >> $FRR_CONF
interface $IF_G0
 ipv6 ospf6 area 0
!
interface $IF_S0
 ipv6 ospf6 area 0
!
router ospf6
 ospf6 router-id 1.1.1.4
!
EOF
    ;;
    
  *)
    echo "Error: Numero no valido. Debe ser del 0 al 5."
    exit 1
    ;;
esac

# Reiniciar FRR para aplicar los protocolos (aqui si se usa systemctl)
systemctl restart frr

echo "======================================="
echo "Configuracion de R$ROUTER_NUM completada."
echo "Puedes verificar FRR usando el comando: vtysh"
echo "======================================="