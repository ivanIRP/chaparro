# Limpiar interfaces
ip addr flush dev $IF_S0 2>/dev/null
ip addr flush dev $IF_S1 2>/dev/null

# Encender interfaces y poner IPs IPv4
ip link set up dev $IF_S0
ip addr add 192.168.0.2/30 dev $IF_S0

ip link set up dev $IF_S1
ip addr add 192.168.0.5/30 dev $IF_S1

# Configurar FRR solo con RIP
cat <<EOF > /etc/frr/frr.conf
frr defaults traditional
hostname R2
!
router rip
 version 2
 network 192.168.0.0/24
!
EOF

systemctl restart frr