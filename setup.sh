#!/bin/bash
# Auto-configurador de Routers Debian 12 (Topologia IPv6 sobre IPv4) v3

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

# ==========================================
# HABILITAR FORWARDING EN KERNEL
# ==========================================
echo 1 > /proc/sys/net/ipv4/ip_forward
echo 1 > /proc/sys/net/ipv6/conf/all/forwarding
echo 1 > /proc/sys/net/ipv6/conf/default/forwarding

# Hacer el forwarding persistente en reinicios
cat <<EOF > /etc/sysctl.d/99-forwarding.conf
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.ipv6.conf.default.forwarding = 1
EOF
sysctl -p /etc/sysctl.d/99-forwarding.conf > /dev/null 2>&1

# ==========================================
# INSTALAR FRR SI NO ESTA
# ==========================================
if ! command -v vtysh &> /dev/null; then
    echo "Instalando FRRouting (FRR)..."
    apt-get update
    apt-get install -y frr
fi

# Habilitar RIP y OSPF6 en FRR
sed -i 's/ripd=no/ripd=yes/' /etc/frr/daemons
sed -i 's/ospf6d=no/ospf6d=yes/' /etc/frr/daemons

# ==========================================
# LIMPIAR CONFIGURACION PREVIA
# ==========================================
ip -6 addr flush dev $IF_G0 scope global 2>/dev/null
ip -6 addr flush dev $IF_S0 scope global 2>/dev/null
ip -6 addr flush dev $IF_S1 scope global 2>/dev/null
ip -4 addr flush dev $IF_S0 2>/dev/null
ip -4 addr flush dev $IF_S1 2>/dev/null
ip tunnel del tun0 2>/dev/null

# ==========================================
# ARCHIVO FRR
# CORRECCION CRITICA: NO incluir "no ipv6 forwarding"
# Esa linea deshabilita el reenvio IPv6 en FRR aunque el kernel
# lo tenga activo, bloqueando todo el trafico entre redes IPv6
# ==========================================
FRR_CONF="/etc/frr/frr.conf"
cat <<EOF > $FRR_CONF
frr defaults traditional
hostname R$ROUTER_NUM
!
EOF

case $ROUTER_NUM in
  0)
    echo "Configurando R0 (Extremo IPv6 - lado izquierdo)..."
    # Red LAN: 2000::/64  |  Enlace a R1: 2002::/64
    ip link set up dev $IF_G0
    ip -6 addr add 2000::1/64 dev $IF_G0

    ip link set up dev $IF_S0
    ip -6 addr add 2002::1/64 dev $IF_S0
    ip -6 addr add fe80::10/64 dev $IF_S0 scope link

    cat <<EOF >> $FRR_CONF
interface $IF_G0
 ipv6 ospf6 area 0
!
interface $IF_S0
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
    echo "Configurando R1 (Inicio del Tunel)..."
    # LAN: 2001::/64  |  Enlace IPv6 a R0: 2002::/64
    # Enlace IPv4 a R2: 192.168.0.0/30 -> R1=.1
    # Tunel SIT: 3000::/64, R1=3000::1 <-> R4=3000::2
    ip link set up dev $IF_G0
    ip -6 addr add 2001::1/64 dev $IF_G0

    ip link set up dev $IF_S0
    ip -6 addr add 2002::2/64 dev $IF_S0
    ip -6 addr add fe80::11/64 dev $IF_S0 scope link

    ip link set up dev $IF_S1
    ip addr add 192.168.0.1/30 dev $IF_S1

    # Ruta estatica para que el tunel pueda alcanzar R4
    # antes de que RIP converja completamente
    ip route add 192.168.0.8/30 via 192.168.0.2 2>/dev/null || true

    # Crear Tunel SIT (IPv6 encapsulado en IPv4)
    ip tunnel add tun0 mode sit remote 192.168.0.10 local 192.168.0.1 ttl 255
    ip link set up dev tun0
    ip -6 addr add 3000::1/64 dev tun0
    echo 1 > /proc/sys/net/ipv6/conf/tun0/forwarding 2>/dev/null

    cat <<EOF >> $FRR_CONF
interface $IF_G0
 ipv6 ospf6 area 0
!
interface $IF_S0
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
    echo "Configurando R2 (Transito IPv4)..."
    # Segmento R1-R2: 192.168.0.0/30  -> R2=.2
    # Segmento R2-R3: 192.168.0.4/30  -> R2=.5
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
    # Segmento R2-R3: 192.168.0.4/30  -> R3=.6
    # Segmento R3-R4: 192.168.0.8/30  -> R3=.9
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
    # LAN: 2003::/64  |  Enlace IPv4 a R3: 192.168.0.8/30 -> R4=.10
    # Enlace IPv6 a R5: 2005::/64  |  Tunel SIT: 3000::2
    ip link set up dev $IF_G0
    ip -6 addr add 2003::1/64 dev $IF_G0

    ip link set up dev $IF_S0
    ip addr add 192.168.0.10/30 dev $IF_S0

    ip link set up dev $IF_S1
    ip -6 addr add 2005::1/64 dev $IF_S1
    ip -6 addr add fe80::14/64 dev $IF_S1 scope link

    # Ruta estatica para que el tunel pueda alcanzar R1
    # antes de que RIP converja completamente
    ip route add 192.168.0.0/30 via 192.168.0.9 2>/dev/null || true

    # Crear Tunel SIT (IPv6 encapsulado en IPv4)
    ip tunnel add tun0 mode sit remote 192.168.0.1 local 192.168.0.10 ttl 255
    ip link set up dev tun0
    ip -6 addr add 3000::2/64 dev tun0
    echo 1 > /proc/sys/net/ipv6/conf/tun0/forwarding 2>/dev/null

    cat <<EOF >> $FRR_CONF
interface $IF_G0
 ipv6 ospf6 area 0
!
interface $IF_S1
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
    echo "Configurando R5 (Extremo IPv6 - lado derecho)..."
    # LAN: 2004::/64  |  Enlace a R4: 2005::/64
    ip link set up dev $IF_G0
    ip -6 addr add 2004::1/64 dev $IF_G0

    ip link set up dev $IF_S0
    ip -6 addr add 2005::2/64 dev $IF_S0
    ip -6 addr add fe80::15/64 dev $IF_S0 scope link

    cat <<EOF >> $FRR_CONF
interface $IF_G0
 ipv6 ospf6 area 0
!
interface $IF_S0
 ipv6 ospf6 network point-to-point
 ipv6 ospf6 area 0
!
router ospf6
 ospf6 router-id 1.1.1.4
 redistribute connected
!
EOF
    ;;

  *)
    echo "Error: Numero no valido. Debe ser del 0 al 5."
    exit 1
    ;;
esac

# Reiniciar FRR
systemctl restart frr

echo "======================================="
echo "Configuracion de R$ROUTER_NUM completada."
echo "======================================="
echo ""
echo "IMPORTANTE: Espera 30-60 segundos para que OSPF6 y RIP converjan."
echo "Verifica con:"
echo "  vtysh -c 'show ipv6 ospf6 neighbor'"
echo "  vtysh -c 'show ipv6 route'"
echo "  vtysh -c 'show ip rip'"