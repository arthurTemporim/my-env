#!/bin/bash
# Update and install core software
echo "Updating system"
sudo apt update && sudo apt upgrade -y && sudo apt install vim git links htop tree -y && sudo reboot
# Docker
echo "Installing docker"
curl -fsSL https://get.docker.com -o get-docker.sh && sudo bash get-docker.sh && sudo usermod -aG docker $(whoami) && sudo systemctl enable docker && sudo systemctl start docker
# OMV
echo "Installing Open Meedia Vault"
wget -O - https://raw.githubusercontent.com/OpenMediaVault-Plugin-Developers/installScript/master/install | sudo bash
# Home Assistant
echo "Installing Home Assistant"
sudo mkdir -p ~/.config/lxsession/LXDE-pi
sudo echo -e "\n\
@lxpanel --profile LXDE-pi\n\
@pcmanfm --desktop --profile LXDE-pi\n\
#@xscreensaver -no-splash\n\
point-rpi\n\
@chromium-browser --start-fullscreen --start-maximized http://localhost:8123\n\
" >> ~/.config/lxsession/LXDE-pi/autostart
#
# Connect to keyboard
# bluetoothctl agent on && bluetoothctl pair 08:21:01:16:05:89 && bluetoothctl connect 08:21:01:16:05:89
