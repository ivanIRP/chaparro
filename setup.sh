#!/bin/bash

# Validación de privilegios
if [[ $EUID -ne 0 ]]; then 
    echo "ERROR: Debes ejecutar este script con sudo."
    exit 1
fi

IP_CMD="/sbin/ip"
VTY_CMD="/usr/bin/vtysh"

echo "[*] Limpiando configuraciones previas y preparando kernel..."
# Cargar módulos críticos para túneles
/sbin/modprobe sit 2>/dev/null
/sbin/modprobe ip6_tunnel 2>/dev/null

# Activar Forwarding (Reenvío de paquetes)
echo 1 > /proc/sys/net/ipv4/ip_forward
echo 1 > /proc/sys/net/ipv6/conf/all/forwarding

# Limpiar firewalls e interfaces de intentos fallidos
iptables -F 2>/dev/null; ip6tables -F 2>/dev/null
for t in tunR0 tunR1 tunR3 tunR4; do $IP_CMD tunnel del $t 2>/dev/null; $IP_CMD link del $t 2>/dev/null; done
for i in enp0s3 enp0s8 enp0s9; do $IP_CMD addr flush dev $i 2>/dev/null; done

# Reiniciar FRR para asegurar una tabla de rutas limpia
echo "" > /etc/frr/frr.conf
systemctl restart frr
sleep 1

echo "================================================="
echo "   CONFIGURACIÓN COMPLETA (IPv4 & IPv6 TUNNELS) "
echo "================================================="
echo "Selecciona el Router: 0)R0 1)R1 2)R2 3)R3 4)R4 5)R5"
read -p "Opción: " OPC

case $OPC in
    0) # R0: LAN v6 -> WAN v4
        $IP_CMD addr add 2000::2/125 dev enp0s3
        $IP_CMD addr add 200.0.0.1/30 dev enp0s8
        $IP_CMD link set enp0s3 up; $IP_CMD link set enp0s8 up
        # Túnel SIT (Encapsula IPv6 en IPv4 hacia R1)
        $IP_CMD tunnel add tunR1 mode sit remote 200.0.0.2 local 200.0.0.1
        $IP_CMD link set tunR1 up; $IP_CMD addr add fd00:a::1/126 dev tunR1
        # Ruta IPv6 hacia el resto de la red vía túnel
        $VTY_CMD -c "conf t" -c "ipv6 route 2000::/110 fd00:a::2 tunR1" -c "exit" -c "write"
        ;;
    1) # R1: Gateway Dual (Puente SIT y IPIP6)
        $IP_CMD addr add 200.0.0.2/30 dev enp0s3
        $IP_CMD addr add 2000::19/125 dev enp0s8
        $IP_CMD addr add 8.0.0.254/24 dev enp0s9
        $IP_CMD link set enp0s3 up; $IP_CMD link set enp0s8 up; $IP_CMD link set enp0s9 up
        # Túnel SIT (Desde R0)
        $IP_CMD tunnel add tunR0 mode sit remote 200.0.0.1 local 200.0.0.2
        $IP_CMD link set tunR0 up; $IP_CMD addr add fd00:a::2/126 dev tunR0
        # Túnel IPIP6 (Encapsula IPv4 en IPv6 hacia R3 cruzando R2)
        $IP_CMD -6 tunnel add tunR3 mode ipip6 remote 2000::22 local 2000::19
        $IP_CMD link set tunR3 up; $IP_CMD addr add 10.255.255.1/30 dev tunR3
        # Rutas blindadas
        $VTY_CMD -c "conf t" \
             -c "ipv6 route 2000::/125 fd00:a::1 tunR0" \
             -c "ipv6 route 2000::8/125 2000::1a enp0s8" \
             -c "ipv6 route 2000::10/125 2000::1a enp0s8" \
             -c "ip route 9.0.0.0/24 10.255.255.2 tunR3" \
             -c "ip route 11.0.0.0/24 10.255.255.2 tunR3" -c "exit" -c "write"
        ;;
    2) # R2: Núcleo IPv6 Puro
        $IP_CMD addr add 2000::1a/125 dev enp0s3; $IP_CMD addr add 2000::21/125 dev enp0s8; $IP_CMD addr add 2000::a/125 dev enp0s9
        $IP_CMD link set enp0s3 up; $IP_CMD link set enp0s8 up; $IP_CMD link set enp0s9 up
        $VTY_CMD -c "conf t" \
             -c "ipv6 route 2000::/125 2000::19 enp0s3" \
             -c "ipv6 route 2000::10/125 2000::22 enp0s8" -c "exit" -c "write"
        ;;
    3) # R3: Gateway Dual (Puente IPIP6 y SIT)
        $IP_CMD addr add 2000::22/125 dev enp0s3; $IP_CMD addr add 200.0.0.5/30 dev enp0s8; $IP_CMD addr add 9.0.0.254/24 dev enp0s9
        $IP_CMD link set enp0s3 up; $IP_CMD link set enp0s8 up; $IP_CMD link set enp0s9 up
        # Túnel IPIP6 (Desde R1)
        $IP_CMD -6 tunnel add tunR1 mode ipip6 remote 2000::19 local 2000::22
        $IP_CMD link set tunR1 up; $IP_CMD addr add 10.255.255.2/30 dev tunR1
        # Túnel SIT (Hacia R4)
        $IP_CMD tunnel add tunR4 mode sit remote 200.0.0.6 local 200.0.0.5
        $IP_CMD link set tunR4 up; $IP_CMD addr add fd00:b::1/126 dev tunR4
        # Rutas de retorno y salto
        $VTY_CMD -c "conf t" \
             -c "ip route 8.0.0.0/24 10.255.255.1 tunR1" \
             -c "ip route 11.0.0.0/24 200.0.0.6 enp0s8" \
             -c "ipv6 route 2000::/125 2000::21 enp0s3" \
             -c "ipv6 route 2000::10/125 fd00:b::2 tunR4" -c "exit" -c "write"
        ;;
    4) # R4: LAN v6 -> WAN v4
        $IP_CMD addr add 200.0.0.6/30 dev enp0s3; $IP_CMD addr add 200.0.0.9/30 dev enp0s8; $IP_CMD addr add 2000::12/125 dev enp0s9
        $IP_CMD link set enp0s3 up; $IP_CMD link set enp0s8 up; $IP_CMD link set enp0s9 up
        # Túnel SIT (Desde R3)
        $IP_CMD tunnel add tunR3 mode sit remote 200.0.0.5 local 200.0.0.6
        $IP_CMD link set tunR3 up; $IP_CMD addr add fd00:b::2/126 dev tunR3
        $VTY_CMD -c "conf t" \
             -c "ip route 8.0.0.0/24 200.0.0.5 enp0s3" \
             -c "ip route 9.0.0.0/24 200.0.0.5 enp0s3" \
             -c "ip route 11.0.0.0/24 200.0.0.10 enp0s8" \
             -c "ipv6 route 2000::/110 fd00:b::1 tunR3" -c "exit" -c "write"
        ;;
    5) # R5: LAN v4 final
        $IP_CMD addr add 200.0.0.10/30 dev enp0s3; $IP_CMD addr add 11.0.0.254/24 dev enp0s8
        $IP_CMD link set enp0s3 up; $IP_CMD link set enp0s8 up
        $VTY_CMD -c "conf t" -c "ip route 0.0.0.0/0 200.0.0.9 enp0s3" -c "exit" -c "write"
        ;;
esac

echo "[!] Configuración aplicada correctamente en R$OPC."