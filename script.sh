#!/bin/bash

# Installera SSH om det inte redan är installerat
if ! command -v ssh &> /dev/null; then
    sudo apt update
    sudo apt install -y openssh-server
fi

# Aktivera IP forwarding om det inte redan är aktiverat
if [[ $(sysctl -n net.ipv4.ip_forward) != 1 ]]; then
    sudo sysctl -w net.ipv4.ip_forward=1
fi

# Ställ in statisk IP på ens5 och begär IP från DHCP på ens4
if ! ip addr show ens5 | grep -q "192.168.1.1/24"; then
    sudo ip addr add 192.168.1.1/255.255.255.0 dev ens5
    sudo ip link set dev ens5 up
fi
sudo ip addr flush dev ens4
sudo dhclient ens4

# Installera och konfigurera DHCP-server om det inte redan är installerat
if ! dpkg -l | grep -q isc-dhcp-server; then
    sudo apt install -y isc-dhcp-server
    # Ändra DHCP-serverkonfigurationen för att använda ens5
    sudo sed -i 's/INTERFACESv4=""/INTERFACESv4="ens5"/' /etc/default/isc-dhcp-server
    # Konfigurera DHCP-servern
    sudo cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.bak  # Säkerhetskopiera konfigurationsfilen
    sudo tee -a /etc/dhcp/dhcpd.conf > /dev/null <<EOF
subnet ens4 netmask 255.255.255.0 {
  range 192.168.1.100 192.168.1.200;
  option broadcast-adress 192.168.1.255;
}
EOF
    sudo systemctl restart isc-dhcp-server
fi

# Installera och konfigurera Nftables om det inte redan är installerat
if ! dpkg -l | grep -q nftables; then
    sudo apt install -y nftables
    # Skapa och applicera Nftables-regler
    sudo tee /etc/nftables.conf > /dev/null <<EOF
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
    chain input {
        type filter hook input priority 0; policy accept;
        tcp dport 22 accept
    }

    chain forward {
        type filter hook forward priority 0; policy accept;
    }

    chain output {
        type filter hook output priority 0; policy accept;
    }
}

table inet nat {
    chain prerouting {
        type nat hook prerouting priority 0; policy accept;
    }

    chain postrouting {
        type nat hook postrouting priority 100; policy accept;
        oif ens4 masquerade
    }
}
EOF
    sudo systemctl restart nftables
fi

echo "Installation och konfiguration av nätverkskomponenter är klar."
