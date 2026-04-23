#!/bin/bash

# --- Comprobación de privilegios ---
if [[ $EUID -ne 0 ]]; then
   echo "Este script debe ejecutarse como root (sudo)." 
   exit 1
fi

# --- Configuración Global de Forwarding ---
echo "[*] Habilitando IP Forwarding (v4 y v6)..."
sysctl -w net.ipv4.ip_forward=1 > /dev/null
sysctl -w net.ipv6.conf.all.forwarding=1 > /dev/null

# --- Menú de Selección ---
echo "------------------------------------------------"
echo " CONFIGURACIÓN DE ROUTERS FRR - PROYECTO REDES "
echo "------------------------------------------------"
echo "Selecciona el router que deseas configurar:"
echo "0) R0 (Borde IPv6 -> IPv4)"
echo "1) R1 (Gateway Dual Stack)"
echo "2) R2 (Core IPv6)"
echo "3) R3 (Gateway Dual Stack)"
echo "4) R4 (Core IPv4)"
echo "5) R5 (Borde IPv4 -> IPv6)"
read -p "Opción [0-5]: " OPCION

case $OPCION in
    0)
        echo "Configurando R0..."
        # Interfaces
        ip addr add 2000::2/125 dev eth0 2>/dev/null
        ip addr add 200.0.0.1/30 dev eth1 2>/dev/null
        ip link set eth0 up && ip link set eth1 up
        # Túnel SIT (IPv6 over IPv4) hacia R1
        ip tunnel add tunR1 mode sit remote 200.0.0.2 local 200.0.0.1
        ip link set tunR1 up
        ip addr add 2000::19/125 dev tunR1
        # Enrutamiento FRR
        vtysh -c "conf t" -c "ipv6 route 2000::/121 tunR1" -c "exit" -c "write"
        ;;
    1)
        echo "Configurando R1..."
        ip addr add 200.0.0.2/30 dev eth0 2>/dev/null
        ip addr add 2000::17/125 dev eth1 2>/dev/null
        ip addr add 8.0.0.254/24 dev eth2 2>/dev/null
        ip link set eth0 up && ip link set eth1 up && ip link set eth2 up
        # Túnel v6 sobre v4 hacia R0
        ip tunnel add tunR0 mode sit remote 200.0.0.1 local 200.0.0.2
        ip link set tunR0 up
        # Túnel GRE (v4 sobre v6) hacia R3
        ip link add tunR3 type ip6gre local 2000::17 remote 2000::22
        ip link set tunR3 up
        ip addr add 10.255.0.1/30 dev tunR3
        # Enrutamiento
        vtysh -c "conf t" -c "ipv6 route 2000::/125 tunR0" -c "ip route 9.0.0.0/24 tunR3" -c "ip route 11.0.0.0/24 tunR3" -c "exit" -c "write"
        ;;
    2)
        echo "Configurando R2..."
        ip addr add 2000::18/125 dev eth0 2>/dev/null
        ip addr add 2000::21/125 dev eth1 2>/dev/null
        ip addr add 2000::14/125 dev eth2 2>/dev/null
        ip link set eth0 up && ip link set eth1 up && ip link set eth2 up
        # Solo rutas estáticas IPv6
        vtysh -c "conf t" -c "ipv6 route 2000::/125 2000::17" -c "exit" -c "write"
        ;;
    3)
        echo "Configurando R3..."
        ip addr add 2000::22/125 dev eth0 2>/dev/null
        ip addr add 200.0.0.5/30 dev eth1 2>/dev/null
        ip addr add 9.0.0.254/24 dev eth2 2>/dev/null
        ip link set eth0 up && ip link set eth1 up && ip link set eth2 up
        # Túnel v4 sobre v6 hacia R1
        ip link add tunR1 type ip6gre local 2000::22 remote 2000::17
        ip link set tunR1 up
        ip addr add 10.255.0.2/30 dev tunR1
        # Túnel v6 sobre v4 hacia R4
        ip tunnel add tunR4 mode sit remote 200.0.0.6 local 200.0.0.5
        ip link set tunR4 up
        # Enrutamiento
        vtysh -c "conf t" -c "ip route 8.0.0.0/24 tunR1" -c "ipv6 route 2000::10/125 tunR4" -c "exit" -c "write"
        ;;
    4)
        echo "Configurando R4..."
        ip addr add 200.0.0.6/30 dev eth0 2>/dev/null
        ip addr add 200.0.0.9/30 dev eth1 2>/dev/null
        ip addr add 2000::13/125 dev eth2 2>/dev/null
        ip link set eth0 up && ip link set eth1 up && ip link set eth2 up
        # El Core v4 encamina tráfico IPv4 de los túneles de otros routers
        vtysh -c "conf t" -c "ip route 8.0.0.0/24 200.0.0.5" -c "ip route 11.0.0.0/24 200.0.0.10" -c "exit" -c "write"
        ;;
    5)
        echo "Configurando R5..."
        ip addr add 200.0.0.10/30 dev eth0 2>/dev/null
        ip addr add 11.0.0.254/24 dev eth1 2>/dev/null
        ip link set eth0 up && ip link set eth1 up
        # Túnel hacia R3 (cruzando el core v4)
        ip tunnel add tunR3 mode sit remote 200.0.0.5 local 200.0.0.10
        ip link set tunR3 up
        # Enrutamiento
        vtysh -c "conf t" -c "ip route 8.0.0.0/24 200.0.0.9" -c "ip route 9.0.0.0/24 200.0.0.9" -c "exit" -c "write"
        ;;
    *)
        echo "Opción no válida."
        exit 1
        ;;
esac

echo "[!] Configuración aplicada con éxito para el router seleccionado."