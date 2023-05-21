sudo rm -Rf /var/run/wpa_supplicant/wlan0
sudo systemctl stop dhcpcd.service
sudo echo -e "\n\
network={\n\
	ssid=\"network\"\n\
	psk=\"password\"\n\
}\n\
" >> /etc/wpa_supplicant/wpa_supplicant.conf
sudo wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant.conf -D nl80211
sudo dhclient wlan0
