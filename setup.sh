#!/bin/bash
# =========================================================
# SCRIPT DE CONFIGURACIÓN COMPLETA - CONECTIVIDAD TOTAL
# Permite ping entre TODOS los routers (IPv4 e IPv6)
# =========================================================

echo "==========================================="
echo "   CONFIGURACIÓN TOTAL DE RED (V6/V4)    "
echo "==========================================="

read -p "Introduce el número del Router (0-5): " ID

# Validar entrada
if ! [[ "$ID" =~ ^[0-5]$ ]]; then
    echo "ERROR: Introduce un número entre 0 y 5"
    exit 1
fi

echo ""
echo "--- 1. LIMPIEZA DE CONFIGURACIONES PREVIAS ---"

# Limpiar caché de rutas
/usr/bin/ip route flush cache 2>/dev/null
/usr/bin/ip -6 route flush cache 2>/dev/null

# Resetear iptables (permitir forward)
/sbin/iptables -F 2>/dev/null
/sbin/ip6tables -F 2>/dev/null
/sbin/iptables -P FORWARD ACCEPT 2>/dev/null
/sbin/iptables -P INPUT ACCEPT 2>/dev/null
/sbin/iptables -P OUTPUT ACCEPT 2>/dev/null
/sbin/ip6tables -P FORWARD ACCEPT 2>/dev/null
/sbin/ip6tables -P INPUT ACCEPT 2>/dev/null
/sbin/ip6tables -P OUTPUT ACCEPT 2>/dev/null

echo "--- 2. HABILITAR IP_FORWARD ---"

# Habilitar IPv4 forwarding
/sbin/sysctl -w net.ipv4.ip_forward=1 > /dev/null 2>&1
/sbin/sysctl -w net.ipv4.conf.all.forwarding=1 > /dev/null 2>&1

# Habilitar IPv6 forwarding
/sbin/sysctl -w net.ipv6.conf.all.forwarding=1 > /dev/null 2>&1
/sbin/sysctl -w net.ipv6.conf.default.forwarding=1 > /dev/null 2>&1
/sbin/sysctl -w net.ipv6.conf.all.disable_ipv6=0 > /dev/null 2>&1
/sbin/sysctl -w net.ipv6.conf.default.disable_ipv6=0 > /dev/null 2>&1

# Limpiar vecinos IPv6
/usr/bin/ip -6 neigh flush all 2>/dev/null

echo "--- 3. CONFIGURACIÓN DEL ROUTER $ID ---"

case $ID in
    0)
        echo "Configurando R0 (Local: 200.0.0.0/30 | Remota: 2000::1/128)"
        
        # Rutas que necesita R0 para alcanzar TODAS las redes
        vtysh <<EOF
configure terminal
! Rutas IPv4
ip route 8.0.0.0/24 200.0.0.2
ip route 9.0.0.0/24 200.0.0.2
ip route 11.0.0.0/24 200.0.0.2
! Rutas IPv6
ipv6 route 2000::/125 2000::1
ipv6 route 2000::8/125 2000::1
ipv6 route 2000::10/125 2000::1
ipv6 route 2000::18/125 2000::1
end
write memory
exit
EOF
        echo "✓ R0 - Rutas configuradas: 8.0.0.0/24, 9.0.0.0/24, 11.0.0.0/24, 2000::/125, 2000::8/125, 2000::10/125, 2000::18/125"
        ;;

    1)
        echo "Configurando R1 (Local: 8.0.0.0/24 + 2000::18/125 | Remota: 200.0.0.0/30)"
        
        vtysh <<EOF
configure terminal
! Rutas IPv4 - hacia todas las redes remotas
ip route 200.0.0.0/30 8.0.0.1
ip route 9.0.0.0/24 200.0.0.4
ip route 11.0.0.0/24 200.0.0.4
! Rutas IPv6 - hacia redes IPv6 por el túnel IPv6
ipv6 route 2000::/125 2000::19
ipv6 route 2000::8/125 2000::19
ipv6 route 2000::10/125 2000::19
ipv6 route 2000::20/125 2000::19
end
write memory
exit
EOF
        echo "✓ R1 - Rutas configuradas: todas las redes IPv4 e IPv6"
        ;;

    2)
        echo "Configurando R2 (Local: 2000::20/125 | Tránsito IPv6)"
        
        vtysh <<EOF
configure terminal
! Rutas IPv6 - reenvío entre redes extremas
ipv6 route 2000::/125 2000::19
ipv6 route 2000::8/125 2000::21
ipv6 route 2000::18/125 2000::21
ipv6 route 2000::10/125 2000::21
end
write memory
exit
EOF
        echo "✓ R2 - Rutas configuradas: tránsito IPv6 completo"
        ;;

    3)
        echo "Configurando R3 (Local: 2000::4/30 | Tránsito IPv6)"
        
        vtysh <<EOF
configure terminal
! Rutas IPv6 - reenvío entre redes extremas
ipv6 route 2000::/125 2000::22
ipv6 route 2000::18/125 2000::22
ipv6 route 2000::20/125 2000::22
ipv6 route 2000::10/125 2000::22
end
write memory
exit
EOF
        echo "✓ R3 - Rutas configuradas: tránsito IPv6 completo"
        ;;

    4)
        echo "Configurando R4 (Local: 9.0.0.0/24 + 2000::10/125 | Remota: 200.0.0.4/30)"
        
        vtysh <<EOF
configure terminal
! Rutas IPv4 - hacia todas las redes remotas
ip route 200.0.0.4/30 9.0.0.1
ip route 8.0.0.0/24 200.0.0.3
ip route 200.0.0.0/30 200.0.0.3
! Rutas IPv6 - hacia redes IPv6 por el túnel IPv6
ipv6 route 2000::/125 2000::21
ipv6 route 2000::18/125 2000::21
ipv6 route 2000::20/125 2000::21
ipv6 route 2000::8/125 2000::21
end
write memory
exit
EOF
        echo "✓ R4 - Rutas configuradas: todas las redes IPv4 e IPv6"
        ;;

    5)
        echo "Configurando R5 (Local: 11.0.0.0/24 | Remota: 200.0.0.8/30)"
        
        vtysh <<EOF
configure terminal
! Rutas IPv4
ip route 8.0.0.0/24 11.0.0.1
ip route 9.0.0.0/24 11.0.0.1
ip route 200.0.0.0/30 11.0.0.1
! Rutas IPv6
ipv6 route 2000::/125 2000::11
ipv6 route 2000::8/125 2000::11
ipv6 route 2000::18/125 2000::11
ipv6 route 2000::20/125 2000::11
end
write memory
exit
EOF
        echo "✓ R5 - Rutas configuradas: 8.0.0.0/24, 9.0.0.0/24, 200.0.0.0/30, todas IPv6"
        ;;
esac

echo ""
echo "==========================================="
echo "   Router $ID CONFIGURADO EXITOSAMENTE   "
echo "==========================================="
echo ""
echo "PRÓXIMOS PASOS:"
echo "1. Ejecuta este script en los 6 routers (R0 a R5)"
echo "2. Después, prueba conectividad:"
echo ""
echo "   # Desde cualquier router:"
echo "   ping 200.0.0.1      # IPv4 - R0"
echo "   ping 8.0.0.2        # IPv4 - R1"
echo "   ping 9.0.0.1        # IPv4 - R4"
echo "   ping 11.0.0.1       # IPv4 - R5"
echo ""
echo "   ping6 2000::1       # IPv6 - Local"
echo "   ping6 2000::19      # IPv6 - R1"
echo "   ping6 2000::21      # IPv6 - R3"
echo "   ping6 2000::10      # IPv6 - R4"
echo ""
echo "Para ver rutas:"
echo "   vtysh -c 'show ip route'"
echo "   vtysh -c 'show ipv6 route'"
echo "   ip route show"
echo "   ip -6 route show"