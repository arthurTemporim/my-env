## Ubuntu-server

### Network

* Backup `/etc/netplan/50-cloud-init.yaml backup.txt`

* create `/etc/netplan/static.yaml`

```sh
network:
    version: 2
    renderer: networkd
    ethernets:
        enp4s0:
            addresses:
                - 192.168.0.21/24
            nameservers:
                addresses:   [8.8.8.8, 8.8.4.4]
            routes:
                - to: default
                  via: 192.168.0.21
```

* Execute:

```sh
sudo netplan apply
```

