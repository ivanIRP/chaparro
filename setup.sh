#!/bin/bash
# =========================================================
# SCRIPT DE CONFIGURACIÓN DE RED - TUNELIZACIÓN IPv4/IPv6
# OBJETIVO: Comunicar redes IPv4 a través de IPv6 y viceversa
# =========================================================

echo "==========================================="
echo "   CONFIGURADOR DE ROUTERS (Proyecto V6)  "
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
/sbin/ip6tables -P FORWARD ACCEPT 2>/dev/null

echo "--- 2. HABILITAR IP_FORWARD ---"

# Habilitar IPv4 forwarding
/sbin/sysctl -w net.ipv4.ip_forward=1 > /dev/null 2>&1

# Habilitar IPv6 forwarding
/sbin/sysctl -w net.ipv6.conf.all.forwarding=1 > /dev/null 2>&1
/sbin/sysctl -w net.ipv6.conf.default.forwarding=1 > /dev/null 2>&1

# Limpiar vecinos IPv6
/usr/bin/ip -6 neigh flush all 2>/dev/null

echo "--- 3. APLICANDO CONFIGURACIÓN DEL ROUTER $ID ---"

case $ID in
    0)
        echo "Configurando R0 (Origen IPv4: 200.0.0.0/30)"
        # R0 envía todo IPv4 al siguiente router (R1) via IPv6
        vtysh <<EOF
configure terminal
ip route 0.0.0.0/0 8.0.0.254
ipv6 route ::/0 2000::1
end
write memory
exit
EOF
        echo "✓ R0 configurado"
        ;;

    1)
        echo "Configurando R1 (Túnel IPv4 sobre IPv6)"
        # R1 es la entrada del túnel: recibe IPv6 y lo traduce a IPv4
        vtysh <<EOF
configure terminal
ip route 11.0.0.0/24 10.255.255.2
ipv6 route 2000::10/125 2000::1a
ipv6 route 2000::20/125 2000::19
end
write memory
exit
EOF
        # Rutas kernel para asegurar tránsito
        /usr/bin/ip route add 11.0.0.0/24 via 10.255.255.2 2>/dev/null
        /usr/bin/ip -6 route add 2000::10/125 via 2000::1a 2>/dev/null
        echo "✓ R1 configurado"
        ;;

    2)
        echo "Configurando R2 (Puente central - IPv6)"
        # R2 es un puente que solo reenvía tráfico IPv6
        vtysh <<EOF
configure terminal
ipv6 route 2000::/125 2000::19
ipv6 route 2000::20/125 2000::1a
ipv6 route 2000::8/125 2000::21
end
write memory
exit
EOF
        # Asegurar vecindario IPv6
        /usr/bin/ip -6 neigh replace 2000::19 dev enp0s3 lladdr 52:54:00:12:34:02 2>/dev/null
        /usr/bin/ip -6 neigh replace 2000::1a dev enp0s8 lladdr 52:54:00:12:34:03 2>/dev/null
        echo "✓ R2 configurado"
        ;;

    3)
        echo "Configurando R3 (Puente central - IPv6)"
        # R3 es otro puente que reenvía tráfico IPv6
        vtysh <<EOF
configure terminal
ipv6 route 2000::/125 2000::21
ipv6 route 2000::10/125 2000::22
ipv6 route 2000::20/125 2000::22
end
write memory
exit
EOF
        # Asegurar vecindario IPv6
        /usr/bin/ip -6 neigh replace 2000::21 dev enp0s3 lladdr 52:54:00:12:34:04 2>/dev/null
        /usr/bin/ip -6 neigh replace 2000::22 dev enp0s8 lladdr 52:54:00:12:34:05 2>/dev/null
        echo "✓ R3 configurado"
        ;;

    4)
        echo "Configurando R4 (Salida del túnel - IPv4 sobre IPv6)"
        # R4 es la salida del túnel: recibe IPv4 y lo reenvia via IPv6
        vtysh <<EOF
configure terminal
ip route 8.0.0.0/24 10.255.255.1
ipv6 route 2000::/125 2000::21
ipv6 route 2000::10/125 2000::22
end
write memory
exit
EOF
        # Rutas kernel para asegurar tránsito
        /usr/bin/ip route add 8.0.0.0/24 via 10.255.255.1 2>/dev/null
        /usr/bin/ip -6 route add 2000::/125 via 2000::21 2>/dev/null
        echo "✓ R4 configurado"
        ;;

    5)
        echo "Configurando R5 (Destino IPv4: 200.0.0.8/30)"
        # R5 envía todo de regreso al anterior router (R4) via IPv6
        vtysh <<EOF
configure terminal
ip route 0.0.0.0/0 11.0.0.254
ipv6 route ::/0 2000::10
end
write memory
exit
EOF
        echo "✓ R5 configurado"
        ;;
esac

echo ""
echo "==========================================="
echo "   Router $ID CONFIGURADO EXITOSAMENTE   "
echo "==========================================="
echo ""
echo "Para verificar la configuración:"
echo "  vtysh -c 'show ip route'"
echo "  vtysh -c 'show ipv6 route'"
echo "  ip route show"
echo "  ip -6 route show"