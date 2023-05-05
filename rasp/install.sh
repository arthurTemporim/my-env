#!/bin/bash
# Update and install core software
sudo apt update && sudo apt upgrade -y && sudo apt install vim git links htop tree -y && sudo reboot
# Docker
curl -fsSL https://get.docker.com -o get-docker.sh && sudo bash get-docker.sh && sudo usermod -aG docker $(whoami) && sudo systemctl enable docker && sudo systemctl start docker
# OMV
# wget -O - https://raw.githubusercontent.com/OpenMediaVault-Plugin-Developers/installScript/master/install | sudo bash
# Connect to keyboard
# bluetoothctl agent on && bluetoothctl pair 08:21:01:16:05:89 && bluetoothctl connect 08:21:01:16:05:89
# PiHole
curl -sSL https://install.pi-hole.net | bash
