# GPU passtrought

## Tutorial:

* [GPU passtrought medium](https://akashrajvanshi.medium.com/step-by-step-guide-for-proxmox-gpu-passthrough-6e885898fdae)
* [Proxmox PCI docu](https://pve.proxmox.com/wiki/PCI_Passthrough#Nvidia_specific_issues)


## Commands:

* `/etc/default/grub`

```sh
# If you change this file, run 'update-grub' afterwards to update
# /boot/grub/grub.cfg.
# For full documentation of the options in this file, see:
#   info -f grub -n 'Simple configuration'

GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR=`lsb_release -i -s 2> /dev/null || echo Debian`
GRUB_CMDLINE_LINUX=""
# GPU Passtrought
#GRUB_CMDLINE_LINUX_DEFAULT="quiet"
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt initcall_blacklist=sysfb_init"
```

* `/etc/modules/`

```sh
# Added PCI Passtrought
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
vfio_nvidia
```

* `/etc/modprobe.d/blacklist.conf`

```sh
# GPU Passtrought
blacklist nouveau
blacklist nvidia
blacklist nvidiafb
#blacklist snd_hda_intel
```

* `/etc/modprobe.d/vfio.conf`

```sh
# GPU Passtrought
options vfio-pci ids=10de:11d8 disable_vga=1 disable_idle_d3=1 initcall_blacklist=sysfb_init
```

* Execute:

```sh
update-grup
update-initramfs -u -k all
reboot
```
