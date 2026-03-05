#!/bin/bash
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

pausa_exito() {
    echo -e "\e[32m[OK] $1 verificado correctamente.\e[0m"
    read -rp "Presiona Enter para continuar al siguiente paso..."
}

die() {
    echo -e "\e[41m\e[97m[ERROR] $1\e[0m"
    exit 1
}

if [ "$EUID" -ne 0 ]; then die "Debes ejecutar este script como root."; fi

echo -e "\e[36m=== PASO 1: Instalacion de Paquetes ===\e[0m"
apt-get update -y || die "Fallo al actualizar repositorios."
apt-get install -y frr traceroute iputils-ping || die "Fallo al instalar paquetes."

if ! command -v vtysh &> /dev/null; then
    die "El paquete FRR no se instalo correctamente."
fi
pausa_exito "Paquetes instalados"

echo -e "\n\e[36m=== PASO 2: Habilitar IPv6 Forwarding ===\e[0m"
echo "net.ipv6.conf.all.forwarding=1" > /etc/sysctl.d/99-ipv6-forwarding.conf
sysctl -p /etc/sysctl.d/99-ipv6-forwarding.conf > /dev/null 2>&1

if [ "$(cat /proc/sys/net/ipv6/conf/all/forwarding)" != "1" ]; then
    die "El forwarding IPv6 no se activo en el kernel."
fi
pausa_exito "IPv6 Forwarding activo"

echo -e "\n\e[36m=== PASO 3: Configuracion de Demonios FRR ===\e[0m"
mkdir -p /etc/frr
cat <<EOF > /etc/frr/daemons
zebra=yes
bgpd=no
ospfd=no
ospf6d=no
ripd=no
ripngd=no
isisd=no
pimd=no
ldpd=no
nhrpd=no
eigrpd=no
babeld=no
sharpd=no
pbrd=no
bfdd=no
fabricd=no
vrrpd=no
pathd=no
staticd=yes
vtysh_enable=yes
EOF

if ! grep -q "zebra=yes" /etc/frr/daemons; then die "Zebra no se configuro."; fi
if ! grep -q "staticd=yes" /etc/frr/daemons; then die "Staticd no se configuro."; fi
pausa_exito "Demonios configurados"

echo -e "\n\e[36m=== PASO 4: Asignacion de Interfaces y Topologia ===\e[0m"
mapfile -t INTERFACES < <(ip -o link show | awk -F': ' '{print $2}' | grep -v 'lo')
NUM_IFACES=${#INTERFACES[@]}

if [ "$NUM_IFACES" -lt 2 ]; then die "Necesitas al menos 2 interfaces activas."; fi

for iface in "${INTERFACES[@]}"; do ip link set dev "$iface" up; done

IF1=${INTERFACES[0]}
IF2=${INTERFACES[1]}
IF3=${INTERFACES[2]:-""}

echo -e "Interfaces disponibles: \e[33m$IF1, $IF2 ${IF3:+(y $IF3)}\e[0m"
while true; do
    read -rp "Que router es esta maquina? (0, 1, 2 o 3): " R_NUM
    case $R_NUM in
        0|1|2|3) break ;;
        *) echo "Invalido. Usa 0, 1, 2 o 3." ;;
    esac
done

CONF="! Configuracion autogenerada para R$R_NUM\n"
if [ "$R_NUM" -eq 0 ]; then
    CONF+="interface $IF1\n ipv6 address 2000::1/124\nexit\ninterface $IF2\n ipv6 address 2000::29/125\nexit\nipv6 route ::/0 2000::2a\n"
elif [ "$R_NUM" -eq 1 ]; then
    CONF+="interface $IF1\n ipv6 address 2000::2a/125\nexit\ninterface $IF2\n ipv6 address 2000::31/125\nexit\nipv6 route 2000::/124 2000::29\nipv6 route ::/0 2000::32\n"
elif [ "$R_NUM" -eq 2 ]; then
    if [ -z "$IF3" ]; then die "R2 necesita 3 adaptadores de red."; fi
    CONF+="interface $IF1\n ipv6 address 2000::32/125\nexit\ninterface $IF2\n ipv6 address 2000::39/125\nexit\ninterface $IF3\n ipv6 address 2000::11/124\nexit\nipv6 route ::/0 2000::31\nipv6 route 2000::20/124 2000::3a\n"
elif [ "$R_NUM" -eq 3 ]; then
    CONF+="interface $IF1\n ipv6 address 2000::3a/125\nexit\ninterface $IF2\n ipv6 address 2000::21/124\nexit\nipv6 route ::/0 2000::39\n"
fi

echo -e "$CONF" > /etc/frr/frr.conf
chown frr:frr /etc/frr/frr.conf

if [ ! -s /etc/frr/frr.conf ]; then die "El archivo frr.conf no se creo."; fi
pausa_exito "Archivo de rutas generado"

echo -e "\n\e[36m=== PASO 5: Reinicio de Servicios FRR ===\e[0m"
systemctl restart frr
sleep 2

if ! systemctl is-active --quiet frr; then
    die "FRR fallo al iniciar."
fi

echo -e "\n\e[1;32m[EXITO TOTAL] El Router R$R_NUM esta configurado y operando.\e[0m"