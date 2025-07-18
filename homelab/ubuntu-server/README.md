# Ubuntu-server

## Server configs

### NVIDIA Tesla P4 GPU installation

```sh
sudo apt install nvidia-driver-470 nvidia-utils-470
```

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

## Softwares configs

### Cockpit

* [Cockpit doc](https://www.techrepublic.com/article/install-cockpit-ubuntu-better-server/)

```sh
sudo apt-get install cockpit -y
sudo systemctl enable --now cockpit.socket
sudo usermod -aG sudo $USER
```

* Install podman for container monitoring:

```sh
sudo apt-get install podman cockpit-podman -y
sudo systemctl enable --now podman
```

* Install cockpit-pcp: "For spotting performance problems in the past, we need to enable historical metrics, which are provided by Performance Co-Pilot, aka. “PCP”."

```sh
sudo apt install cockpit-pcp
```

### Docker

* No sudo user docker:

```sh
sudo groupadd docker
sudo usermod -aG docker $USER
```

### Microk8s

* [Microk8s doc](https://microk8s.io/?_gl=1*14hbytt*_gcl_au*MTAzNTYzMzIyNC4xNzIyNzEwNjcw#install-microk8s)


* Installation:

```sh
sudo snap install microk8s --classic
sudo usermod -a -G microk8s gpu-server
sudo chown -R gpu-server ~/.kube # Maybe not work for not having the folder
newgrp microk8s
```

* Access the microk8s dashboard:

```sh
microk8s dashboard-proxy
```

* Access the dashboard at `https://192.168.0.21:10443/` and paste the token printed at the terminal

### LXD

* [LXD doc](https://documentation.ubuntu.com/lxd/en/latest/installing/)


```sh
sudo snap install lxd
lxd init
```

* The lxd init config contet is:

```yaml
config:
  core.https_address: '[::]:8443'
networks:
- config:
    ipv4.address: auto
    ipv6.address: auto
  description: ""
  name: lxdbr0
  type: ""
  project: default
storage_pools:
- config:
    size: 100GiB
  description: ""
  name: default
  driver: zfs
storage_volumes: []
profiles:
- config: {}
  description: ""
  devices:
    eth0:
      name: eth0
      network: lxdbr0
      type: nic
    root:
      path: /
      pool: default
      type: disk
  name: default
projects: []
cluster: null
```

* [LXD GUI](https://documentation.ubuntu.com/lxd/en/latest/howto/access_ui/)

* In the server:
```sh
lxc config set core.https_address :8443
```

* In the client, access `https://192.168.0.21:9090`


### NextCloud WIP

* [Nextcloud doc](https://docs.nextcloud.com/server/latest/admin_manual/installation/example_ubuntu.html)



### GPU passtrought LXD

#### WIP CONFIG NOT WORKING CORRECTLY YET

* [LXD GPU doc](https://ubuntu.com/tutorials/gpu-data-processing-inside-lxd#4-install-the-cuda-toolkit)
* [Nvidia cuda install doc](https://developer.nvidia.com/cuda-11-8-0-download-archive?target_os=Linux&target_arch=x86_64&Distribution=Ubuntu&target_version=22.04&target_type=deb_local)


* Run `nvidia-smi` if prints the gpu data, is ok;
* Else, intall nvidia drivers:

```sh
sudo apt install nvidia-utils-470 nvidia-driver-470
```

* Nvidia cuda 11.8 (Tesla P4 compatible) instalation commands:
```sh
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-ubuntu2204.pin
sudo mv cuda-ubuntu2204.pin /etc/apt/preferences.d/cuda-repository-pin-600
wget https://developer.download.nvidia.com/compute/cuda/11.8.0/local_installers/cuda-repo-ubuntu2204-11-8-local_11.8.0-520.61.05-1_amd64.deb
sudo dpkg -i cuda-repo-ubuntu2204-11-8-local_11.8.0-520.61.05-1_amd64.deb
sudo cp /var/cuda-repo-ubuntu2204-11-8-local/cuda-*-keyring.gpg /usr/share/keyrings/
sudo apt-get update
sudo apt-get -y install cuda
```

* Verify if its ok:
```sh
/usr/local/cuda-12.6/bin/nvcc -V
nvcc: NVIDIA (R) Cuda compiler driver
Copyright (c) 2005-2024 NVIDIA Corporation
Built on Thu_Sep_12_02:18:05_PDT_2024
Cuda compilation tools, release 12.6, V12.6.77
Build cuda_12.6.r12.6/compiler.34841621_0
```
