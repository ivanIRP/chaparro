#!/bin/bash
# Autoconfiguración y validación para Routers R0, R1, R2 y R3

# Función para detener el script y mostrar errores
manejar_error() {
    echo -e "\e[31m[ERROR] $1\e[0m"
    exit 1
}

if [ "$EUID" -ne 0 ]; then
    manejar_error "Debes ejecutar este script como root (sudo)."
fi

echo "=== Instalando paquetes y activando IPv6 ==="
apt-get update -y || manejar_error "No se pudieron actualizar los repositorios."
apt-get install -y frr traceroute iputils-ping || manejar_error "Falló la instalación de paquetes."

echo "net.ipv6.conf.all.forwarding=1" > /etc/sysctl.d/99-ipv6-forwarding.conf
sysctl -p /etc/sysctl.d/99-ipv6-forwarding.conf || manejar_error "No se pudo habilitar el forwarding IPv6."

sed -i 's/zebra=no/zebra=yes/' /etc/frr/daemons || manejar_error "Fallo al configurar demonio zebra."
sed -i 's/staticd=no/staticd=yes/' /etc/frr/daemons || manejar_error "Fallo al configurar demonio staticd."

# Detección dinámica de interfaces enp* (excluye loopback)
INTERFACES=($(ip -o link show | awk -F': ' '{print $2}' | grep '^enp'))

if [ ${#INTERFACES[@]} -lt 2 ]; then
    manejar_error "Se necesitan al menos 2 interfaces de red (enpX) activas en VirtualBox."
fi

# Se asignan en orden: Adaptador 1 (Izquierda), Adaptador 2 (Derecha), Adaptador 3 (LAN)
IF1=${INTERFACES[0]}
IF2=${INTERFACES[1]}
IF3=${INTERFACES[2]}

echo "Interfaces detectadas: $IF1, $IF2 ${IF3:+(y $IF3 para LAN)}"
echo "¿Qué router es esta máquina? (Ingresa 0, 1, 2 o 3):"
read R_NUM

CONF=""
if [ "$R_NUM" -eq 0 ]; then
    # Red AP (2000::/124) y Salto R0-R1 (2000::28/125)
    CONF="interface $IF1\n ipv6 address 2000::1/124\nexit\ninterface $IF2\n ipv6 address 2000::29/125\nexit\nipv6 route ::/0 2000::2a"
elif [ "$R_NUM" -eq 1 ]; then
    # Salto R0-R1 (2000::28/125) y Salto R1-R2 (2000::30/125)
    CONF="interface $IF1\n ipv6 address 2000::2a/125\nexit\ninterface $IF2\n ipv6 address 2000::31/125\nexit\nipv6 route 2000::/124 2000::29\nipv6 route ::/0 2000::32"
elif [ "$R_NUM" -eq 2 ]; then
    if [ -z "$IF3" ]; then manejar_error "R2 requiere un 3er adaptador de red habilitado para PC1."; fi
    # Salto R1-R2 (2000::30/125), Salto R2-R3 (2000::38/125) y LAN PC1 (2000::10/124)
    CONF="interface $IF1\n ipv6 address 2000::32/125\nexit\ninterface $IF2\n ipv6 address 2000::39/125\nexit\ninterface $IF3\n ipv6 address 2000::11/124\nexit\nipv6 route ::/0 2000::31\nipv6 route 2000::20/124 2000::3a"
elif [ "$R_NUM" -eq 3 ]; then
    # Salto R2-R3 (2000::38/125) y LAN PC2 (2000::20/124)
    CONF="interface $IF1\n ipv6 address 2000::3a/125\nexit\ninterface $IF2\n ipv6 address 2000::21/124\nexit\nipv6 route ::/0 2000::39"
else
    manejar_error "Número de router inválido."
fi

echo -e "$CONF" > /etc/frr/frr.conf || manejar_error "No se pudo escribir el archivo frr.conf"
chown frr:frr /etc/frr/frr.conf

systemctl restart frr || manejar_error "Falló el reinicio de FRR tras aplicar la configuración."
echo -e "\e[32m[ÉXITO] R$R_NUM configurado y enrutando correctamente.\e[0m"