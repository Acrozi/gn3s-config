#!/bin/bash

# Add Unstable Repository
echo "deb http://deb.debian.org/debian/ unstable main contrib non-free" | sudo tee /etc/apt/sources.list.d/unstable.list

# Create APT Preferences File
sudo tee /etc/apt/preferences.d/unstable > /dev/null <<EOF
Package: *
Pin: release a=stable
Pin-Priority: 900

Package: *
Pin: release a=unstable
Pin-Priority: 10

Package: snort
Pin: release a=unstable
Pin-Priority: 990
EOF

# Update Package Sources and Install Snort
sudo apt update
sudo apt install -y -t unstable snort

# Configure Snort as an IPS
#sudo sed -i '/^config.*$/a config daq: afpacket\nconfig daq_mode: inline' /etc/snort/snort.conf

# Configure SYN Flood Protection Rule
#sudo tee -a /etc/snort/rules/local.rules > /dev/null <<EOF
#drop tcp any any -> \$HOME_NET any (msg:"Possible SYN Flood Attack Detected"; flags:S; threshold:type threshold, track by_src, count 100, seconds 10; classtype:attempted-dos; sid:1000003; rev:1;)
#EOF

# Configure SSH Brute Force Protection Rule
#sudo tee -a /etc/snort/rules/local.rules > /dev/null <<EOF
#drop tcp any any -> \$HOME_NET 22 (msg:"Potential SSH Brute Force Attack"; flow:to_server,established; content:"Failed password"; nocase; threshold:type threshold, track by_src, count 5, seconds 120; classtype:attempted-admin; sid:1000004; rev:1;)
#EOF

# Restart Snort Service
sudo systemctl restart snort

echo "Snort installation and configuration completed."
