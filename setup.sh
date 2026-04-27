#!/bin/bash
# ==============================================================================
# SCRIPT MONOLÍTICO PARA REDES ESCALABLES (24 ROUTERS - 4 ESCENARIOS)
# ==============================================================================

if [[ $EUID -ne 0 ]]; then echo "ERROR: Ejecuta con sudo"; exit 1; fi

IP="/sbin/ip"
VTY="/usr/bin/vtysh"

read -p "Ingresa el número de este Router (del 0 al 23): " ID

if [[ $ID -lt 0 || $ID -gt 23 ]]; then
    echo "Número inválido. Debe ser entre 0 y 23."
    exit 1
fi

# Magia Matemática: Calcular el Rol (MOD) y el Escenario (GRP)
MOD=$((ID % 6))   # Da un número del 0 al 5 indicando la posición en la topología
GRP=$((ID / 6))   # Da un número del 0 al 3 indicando el bloque (Estático, OSPF, ACL, RIP)

ESCENARIOS=("Estático (R0-R5)" "OSPF (R6-R11)" "ACLs+Firewall (R12-R17)" "RIP/RIPng (R18-R23)")
echo "[*] Configurando Router R$ID | Topología: ${ESCENARIOS[$GRP]} | Posición Interna: $MOD"

# 1. Limpieza General y Preparación del Kernel
/sbin/modprobe sit 2>/dev/null; /sbin/modprobe ip6_tunnel 2>/dev/null
echo 1 > /proc/sys/net/ipv4/ip_forward; echo 1 > /proc/sys/net/ipv6/conf/all/forwarding
iptables -F 2>/dev/null; ip6tables -F 2>/dev/null
for t in tunR0 tunR1 tunR3 tunR4; do $IP tunnel del $t 2>/dev/null; done
for i in enp0s3 enp0s8 enp0s9; do $IP addr flush dev $i 2>/dev/null; done

# 2. Configurar Demonios de FRR según el Escenario
sed -i 's/ospfd=yes/ospfd=no/g' /etc/frr/daemons
sed -i 's/ospf6d=yes/ospf6d=no/g' /etc/frr/daemons
sed -i 's/ripd=yes/ripd=no/g' /etc/frr/daemons
sed -i 's/ripngd=yes/ripngd=no/g' /etc/frr/daemons

if [ $GRP -eq 1 ]; then
    sed -i 's/ospfd=no/ospfd=yes/g' /etc/frr/daemons
    sed -i 's/ospf6d=no/ospf6d=yes/g' /etc/frr/daemons
elif [ $GRP -eq 3 ]; then
    sed -i 's/ripd=no/ripd=yes/g' /etc/frr/daemons
    sed -i 's/ripngd=no/ripngd=yes/g' /etc/frr/daemons
fi
echo "" > /etc/frr/frr.conf
systemctl restart frr
sleep 2

# 3. Asignación de Direcciones IP y Túneles (Igual para todas las topologías)
case $MOD in
    0) 
        $IP addr add 2000::2/125 dev enp0s3; $IP addr add 200.0.0.1/30 dev enp0s8
        $IP link set enp0s3 up; $IP link set enp0s8 up
        $IP tunnel add tunR1 mode sit remote 200.0.0.2 local 200.0.0.1
        $IP link set tunR1 up; $IP addr add fd00:a::1/126 dev tunR1
        ;;
    1) 
        $IP addr add 200.0.0.2/30 dev enp0s3; $IP addr add 2000::19/125 dev enp0s8; $IP addr add 8.0.0.254/24 dev enp0s9
        $IP link set enp0s3 up; $IP link set enp0s8 up; $IP link set enp0s9 up
        $IP tunnel add tunR0 mode sit remote 200.0.0.1 local 200.0.0.2
        $IP link set tunR0 up; $IP addr add fd00:a::2/126 dev tunR0
        $IP -6 tunnel add tunR3 mode ipip6 remote 2000::22 local 2000::19
        $IP link set tunR3 up; $IP addr add 10.255.255.1/30 dev tunR3
        ;;
    2) 
        $IP addr add 2000::1a/125 dev enp0s3; $IP addr add 2000::21/125 dev enp0s8; $IP addr add 2000::a/125 dev enp0s9
        $IP link set enp0s3 up; $IP link set enp0s8 up; $IP link set enp0s9 up
        ;;
    3) 
        $IP addr add 2000::22/125 dev enp0s3; $IP addr add 200.0.0.5/30 dev enp0s8; $IP addr add 9.0.0.254/24 dev enp0s9
        $IP link set enp0s3 up; $IP link set enp0s8 up; $IP link set enp0s9 up
        $IP -6 tunnel add tunR1 mode ipip6 remote 2000::19 local 2000::22
        $IP link set tunR1 up; $IP addr add 10.255.255.2/30 dev tunR1
        $IP tunnel add tunR4 mode sit remote 200.0.0.6 local 200.0.0.5
        $IP link set tunR4 up; $IP addr add fd00:b::1/126 dev tunR4
        ;;
    4) 
        $IP addr add 200.0.0.6/30 dev enp0s3; $IP addr add 200.0.0.9/30 dev enp0s8; $IP addr add 2000::12/125 dev enp0s9
        $IP link set enp0s3 up; $IP link set enp0s8 up; $IP link set enp0s9 up
        $IP tunnel add tunR3 mode sit remote 200.0.0.5 local 200.0.0.6
        $IP link set tunR3 up; $IP addr add fd00:b::2/126 dev tunR3
        ;;
    5) 
        $IP addr add 200.0.0.10/30 dev enp0s3; $IP addr add 11.0.0.254/24 dev enp0s8
        $IP link set enp0s3 up; $IP link set enp0s8 up
        ;;
esac

# 4. Lógica de Enrutamiento según el Escenario (GRP)
if [[ $GRP -eq 0 || $GRP -eq 2 ]]; then
    # ESCENARIO 0 y 2: RUTAS ESTÁTICAS (Y ACLs más abajo)
    case $MOD in
        0) $VTY -c "conf t" -c "ipv6 route 2000::/110 fd00:a::2 tunR1" -c "exit" -c "write" ;;
        1) $VTY -c "conf t" -c "ipv6 route 2000::/125 fd00:a::1 tunR0" -c "ipv6 route 2000::8/125 2000::1a" -c "ipv6 route 2000::10/125 2000::1a" -c "ipv6 route 2000::20/125 2000::1a" -c "ip route 9.0.0.0/24 10.255.255.2 tunR3" -c "ip route 11.0.0.0/24 10.255.255.2 tunR3" -c "ip route 200.0.0.4/30 10.255.255.2 tunR3" -c "ip route 200.0.0.8/30 10.255.255.2 tunR3" -c "exit" -c "write" ;;
        2) $VTY -c "conf t" -c "ipv6 route 2000::/125 2000::19" -c "ipv6 route 2000::10/125 2000::22" -c "exit" -c "write" ;;
        3) $VTY -c "conf t" -c "ip route 8.0.0.0/24 10.255.255.1 tunR1" -c "ip route 200.0.0.0/30 10.255.255.1 tunR1" -c "ip route 11.0.0.0/24 200.0.0.6" -c "ipv6 route 2000::18/125 2000::21" -c "ipv6 route 2000::/125 2000::21" -c "ipv6 route 2000::8/125 2000::21" -c "ipv6 route 2000::10/125 fd00:b::2 tunR4" -c "exit" -c "write" ;;
        4) $VTY -c "conf t" -c "ip route 8.0.0.0/24 200.0.0.5" -c "ip route 9.0.0.0/24 200.0.0.5" -c "ip route 11.0.0.0/24 200.0.0.10" -c "ipv6 route 2000::/110 fd00:b::1 tunR3" -c "exit" -c "write" ;;
        5) $VTY -c "conf t" -c "ip route 0.0.0.0/0 200.0.0.9" -c "exit" -c "write" ;;
    esac

elif [[ $GRP -eq 1 ]]; then
    # ESCENARIO 1: OSPFv2 y OSPFv3
    case $MOD in
        0) $VTY -c "conf t" -c "router ospf6" -c "ospf6 router-id 0.0.0.$ID" -c "redistribute connected" -c "interface enp0s3 area 0.0.0.0" -c "interface tunR1 area 0.0.0.0" -c "exit" -c "write" ;;
        1) $VTY -c "conf t" -c "router ospf" -c "redistribute connected" -c "network 8.0.0.0/24 area 0" -c "network 10.255.255.0/30 area 0" -c "exit" -c "router ospf6" -c "ospf6 router-id 0.0.0.$ID" -c "redistribute connected" -c "interface enp0s8 area 0.0.0.0" -c "interface tunR0 area 0.0.0.0" -c "exit" -c "write" ;;
        2) $VTY -c "conf t" -c "router ospf6" -c "ospf6 router-id 0.0.0.$ID" -c "redistribute connected" -c "interface enp0s3 area 0.0.0.0" -c "interface enp0s8 area 0.0.0.0" -c "interface enp0s9 area 0.0.0.0" -c "exit" -c "write" ;;
        3) $VTY -c "conf t" -c "router ospf" -c "redistribute connected" -c "network 9.0.0.0/24 area 0" -c "network 10.255.255.0/30 area 0" -c "network 200.0.0.4/30 area 0" -c "exit" -c "router ospf6" -c "ospf6 router-id 0.0.0.$ID" -c "redistribute connected" -c "interface enp0s3 area 0.0.0.0" -c "exit" -c "write" ;;
        4) $VTY -c "conf t" -c "router ospf" -c "redistribute connected" -c "network 200.0.0.4/30 area 0" -c "network 200.0.0.8/30 area 0" -c "exit" -c "router ospf6" -c "ospf6 router-id 0.0.0.$ID" -c "redistribute connected" -c "interface enp0s9 area 0.0.0.0" -c "interface tunR3 area 0.0.0.0" -c "exit" -c "write" ;;
        5) $VTY -c "conf t" -c "router ospf" -c "redistribute connected" -c "network 200.0.0.8/30 area 0" -c "network 11.0.0.0/24 area 0" -c "exit" -c "write" ;;
    esac

elif [[ $GRP -eq 3 ]]; then
    # ESCENARIO 3: RIP y RIPng
    case $MOD in
        0) $VTY -c "conf t" -c "router ripng" -c "redistribute connected" -c "network enp0s3" -c "network tunR1" -c "exit" -c "write" ;;
        1) $VTY -c "conf t" -c "router rip" -c "redistribute connected" -c "network enp0s9" -c "network tunR3" -c "exit" -c "router ripng" -c "redistribute connected" -c "network enp0s8" -c "network tunR0" -c "exit" -c "write" ;;
        2) $VTY -c "conf t" -c "router ripng" -c "redistribute connected" -c "network enp0s3" -c "network enp0s8" -c "network enp0s9" -c "exit" -c "write" ;;
        3) $VTY -c "conf t" -c "router rip" -c "redistribute connected" -c "network enp0s8" -c "network enp0s9" -c "network tunR1" -c "exit" -c "router ripng" -c "redistribute connected" -c "network enp0s3" -c "exit" -c "write" ;;
        4) $VTY -c "conf t" -c "router rip" -c "redistribute connected" -c "network enp0s3" -c "network enp0s8" -c "exit" -c "router ripng" -c "redistribute connected" -c "network enp0s9" -c "network tunR3" -c "exit" -c "write" ;;
        5) $VTY -c "conf t" -c "router rip" -c "redistribute connected" -c "network enp0s3" -c "network enp0s8" -c "exit" -c "write" ;;
    esac
fi

# 5. Lógica Exclusiva de Seguridad (ACLs / Iptables) para el GRP 2
if [[ $GRP -eq 2 ]]; then
    echo "[*] Aplicando Firewall Estricto (Bloqueo Total + Túneles Permitidos)..."
    iptables -P FORWARD DROP
    ip6tables -P FORWARD DROP
    
    # Permitir Pings y Tráfico Local
    iptables -A FORWARD -p icmp -j ACCEPT
    ip6tables -A FORWARD -p ipv6-icmp -j ACCEPT
    
    # Permitir Protocolo 41 (SIT - IPv6 en IPv4) y Protocolo 4 (IPIP6 - IPv4 en IPv6)
    iptables -A FORWARD -p 41 -j ACCEPT
    ip6tables -A FORWARD -p 4 -j ACCEPT
    
    # Anti-Spoofing: Solo permitir tráfico nacido en tus LANs
    iptables -A FORWARD -s 8.0.0.0/8 -j ACCEPT
    iptables -A FORWARD -s 9.0.0.0/8 -j ACCEPT
    iptables -A FORWARD -s 11.0.0.0/8 -j ACCEPT
    ip6tables -A FORWARD -s 2000::/3 -j ACCEPT
fi

echo "[!] CONFIGURACIÓN EXITOSA DEL ROUTER $ID."