#!/bin/bash
# Pihole tutorial
# https://www.crosstalksolutions.com/the-worlds-greatest-pi-hole-and-unbound-tutorial-2023/
# Update and install core software
sudo apt update
sudo apt upgrade -y
sudo apt install vim git links htop tree -y
# Configure pihole dhcp IP address
# sudo echo -e "\n\
# # Static IP configuration: \n\
# interface eth0 \n\
# static ip_address=192.168.200.52/24 \n\
# static routers=192.168.200.1 \n\
# static domain_name_servers=192.168.200.1 1.1.1.1" >> /etc/dhcpcd.conf
# PiHole
curl -sSL https://install.pi-hole.net | sudo bash
# Restart 
sudo reboot
# Change Password
# pihole -a -p
# Ad Blocklist
# https://firebog.net/
# Get webpass to create disable link
# cat /etc/pihole/setupVars.conf | grep WEBPASSWORD
# http://192.168.5.200/admin/api.php?disable=300&auth=WEBPASSWORD
