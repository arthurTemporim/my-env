#!/usr/bin/env bash
#
# Arch Linux post-install script
# -------------------------------
# Finishes an Arch install right after the "arch-chroot /mnt" step of
# https://github.com/arthurTemporim/my-env/wiki/Arch-linux-Instalation-Guide
#
# HOW TO RUN (from the live ISO, inside arch-chroot):
#
#   arch-chroot /mnt
#   curl -fsSL https://raw.githubusercontent.com/arthurTemporim/my-env/main/arch/install.sh -o install.sh
#   bash install.sh
#
# A form asks for user, hostname, git data, passwords and which components
# to install (press Enter to keep the defaults). After that it runs unattended.
# Defaults can be pre-set by env, e.g.: USER_NAME=bob HOST_NAME=box bash install.sh
#
# When it ends: exit; umount -R /mnt; reboot
# Log file: /var/log/arch-install.log. Re-running is safe.

set -uo pipefail

#######################################################
# DEFAULTS (shown in the form)
#######################################################
USER_NAME="${USER_NAME:-arthur}"
HOST_NAME="${HOST_NAME:-tempoarch}"
GIT_NAME="${GIT_NAME:-arthurtemporim}"
GIT_EMAIL="${GIT_EMAIL:-arthurrtl@gmail.com}"
TIMEZONE="${TIMEZONE:-America/Sao_Paulo}"
KEYMAP="${KEYMAP:-br-abnt2}"
XKB_LAYOUT="${XKB_LAYOUT:-br,us}"
LANG_MAIN="${LANG_MAIN:-en_US.UTF-8}"
LANG_FORMATS="${LANG_FORMATS:-pt_BR.UTF-8}"
MIRROR_COUNTRIES="${MIRROR_COUNTRIES:-BR,CL,AR,US}"
PYTHON_VERSION="${PYTHON_VERSION:-3.14}"
ESP="${ESP:-/boot/efi}"
REPO_RAW="${REPO_RAW:-https://raw.githubusercontent.com/arthurTemporim/my-env/main}"

LOG=/var/log/arch-install.log
TITLE="Arch Linux install"
NOPASSWD_FILE=/etc/sudoers.d/99-install-nopasswd

#######################################################
# LOG HELPERS
#######################################################
RED=$'\e[1;31m'; GREEN=$'\e[1;32m'; YELLOW=$'\e[1;33m'; BLUE=$'\e[1;34m'; BOLD=$'\e[1m'; NC=$'\e[0m'

info() { echo "${BLUE}==>${NC} ${BOLD}$*${NC}"; }
ok()   { echo "${GREEN}  ✔${NC} $*"; }
warn() { echo "${YELLOW}  !${NC} $*"; WARNINGS+=("$*"); }
err()  { echo "${RED}  ✘${NC} $*"; }
die()  { err "$*"; exit 1; }

DONE=(); FAILED=(); FAILED_PKGS=(); WARNINGS=()

# step "description" function: runs it, records the result and keeps going
step() {
  local desc=$1; shift
  echo; info "$desc"
  if "$@"; then ok "$desc"; DONE+=("$desc")
  else err "$desc failed"; FAILED+=("$desc"); fi
}

# pkg p1 p2...: pacman install with retries, then one by one to find the bad ones
pkg() {
  local i p bad=()
  for i in 1 2 3; do
    pacman -S --needed --noconfirm "$@" && return 0
    echo "${YELLOW}  !${NC} pacman failed (try $i/3), retrying..."; sleep 3
  done
  for p in "$@"; do pacman -S --needed --noconfirm "$p" || bad+=("$p"); done
  ((${#bad[@]} == 0)) || { FAILED_PKGS+=("${bad[@]}"); return 1; }
}

as_user() { sudo -u "$USER_NAME" -H bash -c "cd ~ && $1"; }

# aur p1 p2...: same as pkg, but with yay as the normal user
aur() {
  local p bad=() yay="yay -S --needed --noconfirm --answerdiff None --answerclean None --removemake"
  as_user "$yay $*" && return 0
  for p in "$@"; do as_user "$yay $p" || bad+=("$p"); done
  ((${#bad[@]} == 0)) || { FAILED_PKGS+=("${bad[@]}"); return 1; }
}

svc() { local u rc=0; for u in "$@"; do systemctl enable "$u" || rc=1; done; return $rc; }

cleanup() { rm -f "$NOPASSWD_FILE"; rm -rf /tmp/yay; }
trap cleanup EXIT
trap 'echo; die "Interrupted"' INT

#######################################################
# PREFLIGHT
#######################################################
[[ $EUID -eq 0 ]] || die "Run as root (inside arch-chroot)."
[[ -t 0 ]] || die "Needs a terminal. Download the script and run 'bash install.sh' (don't pipe it)."
systemd-detect-virt --chroot &>/dev/null || echo "${YELLOW}  !${NC} Not in a chroot. This script is meant to run after 'arch-chroot /mnt'."
curl -fsI --max-time 10 https://archlinux.org >/dev/null || die "No internet connection."
pacman -S --needed --noconfirm libnewt pciutils >/dev/null 2>&1 || true   # whiptail + lspci

#######################################################
# NVIDIA DETECTION
#######################################################
NV_CARD=$(lspci -d 10de: 2>/dev/null | grep -E 'VGA|3D|Display' | head -n1 | sed 's/^[^:]*:[^:]*: //')
NV_PKGS=""; NV_AUR=0
nvidia_pick() {
  case "$1" in
    "")                                  NV_PKGS="" ;;
    *" TU"[0-9]*|*" GA"[0-9]*|*" AD"[0-9]*|*" GB"[0-9]*|*" GH"[0-9]*)
                                         NV_PKGS="nvidia-open nvidia-utils nvidia-settings"; NV_AUR=0 ;;  # Turing+
    *" GM"[0-9]*|*" GP"[0-9]*|*" GV"[0-9]*)
                                         NV_PKGS="nvidia-580xx-dkms nvidia-580xx-utils"; NV_AUR=1 ;;      # Maxwell/Pascal/Volta
    *" GK"[0-9]*)                        NV_PKGS="nvidia-470xx-dkms nvidia-470xx-utils"; NV_AUR=1 ;;      # Kepler
    *"Device "[0-9a-f]*)                 NV_PKGS="nvidia-open nvidia-utils nvidia-settings"; NV_AUR=0 ;;  # unknown to pci.ids = very new
    *)                                   NV_PKGS="" ;;                                                     # too old, keep nouveau
  esac
}
nvidia_pick "$NV_CARD"

#######################################################
# FORM
#######################################################
UI=plain; command -v whiptail >/dev/null && UI=whiptail
ROOT_PASS=""; USER_PASS=""
declare -A SEL=()

if [[ -z $NV_CARD ]]; then NV_LABEL="no NVIDIA GPU detected"; NV_DEF=OFF
elif [[ -z $NV_PKGS ]]; then NV_LABEL="$NV_CARD is too old, keeping nouveau"; NV_DEF=OFF
else NV_CARD_SHORT=${NV_CARD#NVIDIA Corporation }; NV_LABEL="${NV_PKGS%% *} for ${NV_CARD_SHORT:0:30}"; NV_DEF=ON; fi

COMPONENTS=(
  "pacman|Pacman extras: Color, ILoveCandy, multilib|ON"
  "mirrors|Best mirrors with reflector + weekly timer|ON"
  "nvidia|NVIDIA: $NV_LABEL|$NV_DEF"
  "gnome|Xorg + GNOME desktop (GDM)|ON"
  "audio|Audio (PipeWire) + Bluetooth|ON"
  "fonts|Fonts: Noto, emoji, CJK, JetBrains Mono|ON"
  "cli|CLI tools: git, htop, jq, ffmpeg, yt-dlp...|ON"
  "apps|Apps: Firefox, Chrome, VS Code, VLC, Obsidian...|ON"
  "vbox|VirtualBox|ON"
  "zoom|Zoom (AUR)|ON"
  "spotify|Spotify|ON"
  "pycharm|PyCharm (AUR)|ON"
  "docker|Docker + compose|ON"
  "python|Python: pyenv + virtualenvwrapper + uv|ON"
  "power|Power profiles (GNOME power modes)|ON"
  "firewall|Firewall: ufw, deny incoming|ON"
  "maint|SSD trim + pacman cache cleanup timers|ON"
  "zram|zram: compressed swap in RAM|ON"
  "snapshots|Snapshots: timeshift daily + before upgrades|ON"
  "dotfiles|Dotfiles from my-env: bashrc, aliases, vimrc|ON"
  "grub|GRUB bootloader + Windows dual boot|ON"
)
for c in "${COMPONENTS[@]}"; do IFS='|' read -r k _ d <<<"$c"; [[ $d == ON ]] && SEL[$k]=1; done
on() { [[ -n ${SEL[$1]:-} ]]; }

wt() { whiptail --title "$TITLE" "$@" 3>&1 1>&2 2>&3; }

# ask VAR "Label": Enter keeps the current value
ask() {
  local var=$1 label=$2 cur=${!1} val
  if [[ $UI == whiptail ]]; then val=$(wt --inputbox "$label" 9 72 "$cur") || die "Cancelled"
  else read -rp "$label [$cur]: " val || die "No input"; fi
  printf -v "$var" '%s' "${val:-$cur}"
}

# ask_pass VAR "Label": asked twice, must match and not be empty
ask_pass() {
  local var=$1 label=$2 a b
  [[ -n ${!1} ]] && return 0   # already set in a previous form round
  while true; do
    if [[ $UI == whiptail ]]; then
      a=$(wt --passwordbox "$label" 9 72) || die "Cancelled"
      b=$(wt --passwordbox "$label (again)" 9 72) || die "Cancelled"
    else
      read -rsp "$label: " a || die "No input"; echo
      read -rsp "$label (again): " b || die "No input"; echo
    fi
    if [[ -z $a ]]; then [[ $UI == whiptail ]] && wt --msgbox "Password can't be empty." 8 50 || echo "Password can't be empty."
    elif [[ $a != "$b" ]]; then [[ $UI == whiptail ]] && wt --msgbox "Passwords don't match." 8 50 || echo "Passwords don't match."
    else printf -v "$var" '%s' "$a"; return 0; fi
  done
}

choose() {
  local c k l items=() out
  if [[ $UI == whiptail ]]; then
    for c in "${COMPONENTS[@]}"; do
      IFS='|' read -r k l _ <<<"$c"; items+=("$k" "$l" "$(on "$k" && echo ON || echo OFF)")
    done
    local h; h=$(( $(tput lines 2>/dev/null || echo 30) - 2 )); ((h > 30)) && h=30
    out=$(wt --separate-output --checklist "Space selects, Enter confirms" "$h" 78 $((h - 8)) "${items[@]}") || die "Cancelled"
    SEL=(); for k in $out; do SEL[$k]=1; done
  else
    echo "${BOLD}Components${NC} (Enter keeps the default):"
    for c in "${COMPONENTS[@]}"; do
      IFS='|' read -r k l _ <<<"$c"
      local def=n; on "$k" && def=y
      read -rp "  $l [$( [[ $def == y ]] && echo Y/n || echo y/N )]: " a || die "No input"; a=${a:-$def}
      if [[ $a =~ ^[Yy] ]]; then SEL[$k]=1; else unset "SEL[$k]"; fi
    done
  fi
}

summary_text() {
  local c k l
  printf 'User: %s\nHostname: %s\nGit: %s <%s>\nTimezone: %s\nKeymap: %s / X: %s\nLocale: %s (formats %s)\nMirrors: %s\nPython: %s\nESP: %s\nPasswords: ****\n\nComponents:\n' \
    "$USER_NAME" "$HOST_NAME" "$GIT_NAME" "$GIT_EMAIL" "$TIMEZONE" "$KEYMAP" "$XKB_LAYOUT" \
    "$LANG_MAIN" "$LANG_FORMATS" "$MIRROR_COUNTRIES" "$PYTHON_VERSION" "$ESP"
  for c in "${COMPONENTS[@]}"; do IFS='|' read -r k l _ <<<"$c"; on "$k" && echo "  [x] $l"; done
}

while true; do
  [[ $UI == whiptail ]] || echo "${BOLD}${BLUE}== $TITLE ==${NC} (Enter keeps the value in brackets)"
  ask USER_NAME        "Username"
  ask HOST_NAME        "Hostname (machine name)"
  ask GIT_NAME         "Git user.name"
  ask GIT_EMAIL        "Git user.email"
  ask TIMEZONE         "Timezone (see /usr/share/zoneinfo)"
  ask KEYMAP           "Console keymap"
  ask XKB_LAYOUT       "X/GNOME keyboard layouts (comma separated)"
  ask LANG_MAIN        "System language (LANG)"
  ask LANG_FORMATS     "Formats locale: dates, money, units"
  ask MIRROR_COUNTRIES "Mirror countries (codes, comma separated)"
  ask PYTHON_VERSION   "Python version for pyenv"
  ask ESP              "EFI partition mount point"
  ask_pass ROOT_PASS   "Root password"
  ask_pass USER_PASS   "Password for $USER_NAME"
  choose
  if [[ $UI == whiptail ]]; then
    wt --scrolltext --yes-button "Install" --no-button "Edit" --yesno "$(summary_text)" 30 72 && break
  else
    echo; summary_text; echo; read -rp "Start installation? [y/N]: " a || die "No input"; [[ $a =~ ^[Yy] ]] && break
  fi
done
clear 2>/dev/null || true

if [[ -n ${FORM_ONLY:-} ]]; then summary_text; exit 0; fi   # debug: test the form only

exec > >(tee -a "$LOG") 2>&1
info "Starting installation: $(date)"

#######################################################
# STEPS
#######################################################
do_pacman() {
  sed -i -E 's/^#?ParallelDownloads.*/ParallelDownloads = 10/' /etc/pacman.conf
  if on pacman; then
    sed -i 's/^#Color$/Color/' /etc/pacman.conf
    grep -q '^ILoveCandy' /etc/pacman.conf || sed -i '/^Color$/a ILoveCandy' /etc/pacman.conf
    sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
  fi
  pacman -Sy --needed --noconfirm archlinux-keyring
}

do_mirrors() {
  pkg reflector || return 1
  cat > /etc/xdg/reflector/reflector.conf <<EOF
--save /etc/pacman.d/mirrorlist
--protocol https
--country $MIRROR_COUNTRIES
--latest 10
--sort rate
EOF
  cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
  reflector @/etc/xdg/reflector/reflector.conf \
    || { cp /etc/pacman.d/mirrorlist.bak /etc/pacman.d/mirrorlist; return 1; }
  svc reflector.timer
}

do_upgrade() { pacman -Syu --noconfirm; }

do_basics() {
  local rc=0 l
  [[ -f /usr/share/zoneinfo/$TIMEZONE ]] || { err "Unknown timezone $TIMEZONE"; return 1; }
  ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime && hwclock --systohc || rc=1
  for l in "$LANG_MAIN" "$LANG_FORMATS"; do sed -i "s/^#\s*\(${l//./\\.} \)/\1/" /etc/locale.gen; done
  locale-gen || rc=1
  cat > /etc/locale.conf <<EOF
LANG=$LANG_MAIN
LC_TIME=$LANG_FORMATS
LC_MONETARY=$LANG_FORMATS
LC_NUMERIC=$LANG_FORMATS
LC_MEASUREMENT=$LANG_FORMATS
LC_PAPER=$LANG_FORMATS
EOF
  echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf
  mkdir -p /etc/X11/xorg.conf.d
  cat > /etc/X11/xorg.conf.d/00-keyboard.conf <<EOF
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "$XKB_LAYOUT"
EndSection
EOF
  echo "$HOST_NAME" > /etc/hostname
  cat > /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOST_NAME.localdomain $HOST_NAME
EOF
  echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf
  return $rc
}

do_base_pkgs() {
  local ucode=""
  grep -q GenuineIntel /proc/cpuinfo && ucode=intel-ucode
  grep -q AuthenticAMD /proc/cpuinfo && ucode=amd-ucode
  pkg base-devel linux-headers sudo networkmanager grub efibootmgr os-prober ntfs-3g dosfstools \
      git curl wget vim $ucode || return 1
  svc NetworkManager.service systemd-timesyncd.service
}

do_users() {
  echo "root:$ROOT_PASS" | chpasswd || return 1
  id "$USER_NAME" &>/dev/null || useradd -m -g users -G wheel -s /bin/bash "$USER_NAME" || return 1
  usermod -aG wheel "$USER_NAME"
  echo "$USER_NAME:$USER_PASS" | chpasswd || return 1
  echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-wheel
  chmod 440 /etc/sudoers.d/10-wheel
  visudo -cf /etc/sudoers.d/10-wheel || { rm -f /etc/sudoers.d/10-wheel; return 1; }
  # Temporary, so yay/makepkg can run unattended. Removed on exit.
  echo "$USER_NAME ALL=(ALL) NOPASSWD: ALL" > "$NOPASSWD_FILE"
  chmod 440 "$NOPASSWD_FILE"
}

do_yay() {
  command -v yay >/dev/null && { ok "yay already installed"; return 0; }
  pkg git go base-devel || return 1
  as_user "rm -rf /tmp/yay && git clone --depth 1 https://aur.archlinux.org/yay.git /tmp/yay && cd /tmp/yay && makepkg -si --noconfirm"
}

do_git() {
  local git=(sudo -u "$USER_NAME" -H git config --global)
  [[ -n $GIT_NAME ]] && "${git[@]}" user.name "$GIT_NAME"
  [[ -n $GIT_EMAIL ]] && "${git[@]}" user.email "$GIT_EMAIL"
  "${git[@]}" init.defaultBranch main
}

do_nvidia() {
  info "GPU: $NV_CARD -> $NV_PKGS"
  if ((NV_AUR)); then aur $NV_PKGS || return 1; else pkg $NV_PKGS || return 1; fi
  # Hybrid laptop (Intel/AMD iGPU + NVIDIA): prime-run to use the NVIDIA GPU
  lspci | grep -E 'VGA|3D|Display' | grep -qvi nvidia && pkg nvidia-prime
  # Keep nouveau out of the initramfs (mkinitcpio runs later)
  sed -i -E '/^HOOKS=/s/ kms( |\))/\1/' /etc/mkinitcpio.conf
}

do_gnome() { pkg xorg-server xorg-xinit gnome gnome-browser-connector gdm && svc gdm.service; }

do_audio() {
  pkg pipewire pipewire-pulse pipewire-alsa wireplumber sof-firmware alsa-utils alsa-ucm-conf bluez bluez-utils \
    && svc bluetooth.service
}

do_fonts() { pkg noto-fonts noto-fonts-emoji noto-fonts-cjk ttf-jetbrains-mono; }

do_cli() {
  pkg vim git links make tree htop nvtop curl wget jq unzip zip openssh github-cli bash-completion \
      man-db ffmpeg yt-dlp bind qemu-img go
}

do_apps() {
  local rc=0
  pkg terminator firefox code vlc transmission-gtk libreoffice-fresh obsidian || rc=1
  aur google-chrome || rc=1
  return $rc
}

do_vbox() {
  pkg virtualbox virtualbox-host-modules-arch virtualbox-sdk && usermod -aG vboxusers "$USER_NAME"
}

do_docker() {
  pkg docker docker-compose docker-buildx || return 1
  svc docker.service && usermod -aG docker "$USER_NAME"
}

do_python() {
  pkg pyenv uv base-devel openssl zlib xz tk sqlite libffi bzip2 readline || return 1
  as_user "
    export PYENV_ROOT=\$HOME/.pyenv
    v=\$(pyenv latest -k $PYTHON_VERSION) || exit 1
    echo \"Installing Python \$v (compiling, takes a few minutes)...\"
    pyenv install -s \$v && pyenv global \$v &&
    \$PYENV_ROOT/versions/\$v/bin/python -m pip install -U pip virtualenv virtualenvwrapper"
}

do_power() { pkg power-profiles-daemon && svc power-profiles-daemon.service; }

do_firewall() {
  pkg ufw || return 1
  # 'ufw enable' needs a running kernel; this makes ufw.service enable it on boot.
  # Arch's default policy already denies incoming and allows outgoing.
  sed -i 's/^ENABLED=.*/ENABLED=yes/' /etc/ufw/ufw.conf
  svc ufw.service
}

do_maint() { pkg pacman-contrib && svc fstrim.timer paccache.timer; }

do_zram() {
  pkg zram-generator || return 1
  # Used before any disk swap (higher priority). Activated by systemd on boot.
  cat > /etc/systemd/zram-generator.conf <<EOF
[zram0]
zram-size = min(ram / 2, 8192)
compression-algorithm = zstd
swap-priority = 100
EOF
  # Recommended tuning for swap on zram (Arch wiki)
  cat > /etc/sysctl.d/99-vm-zram-parameters.conf <<EOF
vm.swappiness = 180
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
vm.page-cluster = 0
EOF
}

do_snapshots() {
  local uuid
  uuid=$(findmnt -no UUID /)
  [[ -n $uuid ]] || { err "Can't find the UUID of /"; return 1; }
  pkg timeshift cronie || return 1
  # rsync mode (works on ext4): 5 daily + 3 weekly snapshots of the system, homes excluded
  mkdir -p /etc/timeshift
  cat > /etc/timeshift/timeshift.json <<EOF
{
  "backup_device_uuid" : "$uuid",
  "parent_device_uuid" : "",
  "do_first_run" : "false",
  "btrfs_mode" : "false",
  "include_btrfs_home" : "false",
  "stop_cron_emails" : "true",
  "schedule_monthly" : "false",
  "schedule_weekly" : "true",
  "schedule_daily" : "true",
  "schedule_hourly" : "false",
  "schedule_boot" : "false",
  "count_monthly" : "2",
  "count_weekly" : "3",
  "count_daily" : "5",
  "count_hourly" : "6",
  "count_boot" : "5",
  "snapshot_size" : "0",
  "snapshot_count" : "0",
  "exclude" : [ "/root/**", "/home/$USER_NAME/**" ],
  "exclude-apps" : [ ]
}
EOF
  # Same job timeshift writes when scheduling is set in its GUI
  printf 'SHELL=/bin/bash\nPATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin\n0 * * * * root timeshift --check --scripted\n' \
    > /etc/cron.d/timeshift-hourly
  svc cronie.service || return 1
  # Snapshot before every pacman upgrade
  aur timeshift-autosnap || return 1
  [[ -f /etc/timeshift-autosnap.conf ]] && sed -i 's/^updateGrub=.*/updateGrub=false/' /etc/timeshift-autosnap.conf
  return 0
}

do_dotfiles() {
  local home f rc=0
  home=$(getent passwd "$USER_NAME" | cut -d: -f6)
  for f in bashrc bash_aliases vimrc; do
    [[ -f $home/.$f ]] && cp "$home/.$f" "$home/.$f.bak"
    curl -fsSL "$REPO_RAW/bash/$f" -o "$home/.$f" && chown "$USER_NAME:users" "$home/.$f" || rc=1
  done
  return $rc
}

do_initramfs() { mkinitcpio -P; }

do_grub() {
  [[ -d /sys/firmware/efi ]] || { err "Not booted in UEFI mode; install GRUB manually."; return 1; }
  mountpoint -q "$ESP" || { err "$ESP is not mounted."; return 1; }
  pkg grub efibootmgr os-prober ntfs-3g || return 1
  if grep -q '^#\?GRUB_DISABLE_OS_PROBER=' /etc/default/grub; then
    sed -i 's/^#\?GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
  else
    echo 'GRUB_DISABLE_OS_PROBER=false' >> /etc/default/grub
  fi
  printf '#!/bin/sh\nexec grub-mkconfig -o /boot/grub/grub.cfg "$@"\n' > /usr/local/bin/update-grub
  chmod +x /usr/local/bin/update-grub
  grub-install --target=x86_64-efi --efi-directory="$ESP" --bootloader-id=GRUB || return 1
  grub-mkconfig -o /boot/grub/grub.cfg || return 1
  grep -qi windows /boot/grub/grub.cfg \
    || warn "No Windows entry in GRUB (fine without dual boot). Otherwise, after reboot run: sudo update-grub"
}

#######################################################
# RUN
#######################################################
on zram || grep -qE '\sswap\s' /etc/fstab || warn "No swap in /etc/fstab (did you run swapon before genfstab?)"

step "Pacman config + keyring"            do_pacman
on mirrors  && step "Best mirrors (reflector)" do_mirrors
step "System upgrade"                     do_upgrade
step "Timezone, locale, keyboard, hostname" do_basics
step "Base packages + microcode"          do_base_pkgs
step "Users + sudo"                       do_users
unset ROOT_PASS USER_PASS
step "yay (AUR helper)"                   do_yay
step "Git config"                         do_git
if on nvidia; then
  if [[ -n $NV_PKGS ]]; then step "NVIDIA driver" do_nvidia; else warn "NVIDIA selected but no supported GPU found, skipped"; fi
else
  info "NVIDIA: ${NV_LABEL}, skipped"
fi
on gnome    && step "Xorg + GNOME"        do_gnome
on audio    && step "Audio + Bluetooth"   do_audio
on fonts    && step "Fonts"               do_fonts
on cli      && step "CLI tools"           do_cli
on apps     && step "Desktop apps"        do_apps
on vbox     && step "VirtualBox"          do_vbox
on zoom     && step "Zoom"                aur zoom
on spotify  && step "Spotify"             pkg spotify-launcher
on pycharm  && step "PyCharm"             aur pycharm
on docker   && step "Docker"              do_docker
on python   && step "Python (pyenv $PYTHON_VERSION)" do_python
on power    && step "Power profiles"      do_power
on firewall && step "Firewall (ufw)"      do_firewall
on maint    && step "Maintenance timers"  do_maint
on dotfiles && step "Dotfiles"            do_dotfiles
on zram     && step "zram swap"           do_zram
# After all packages, so the autosnap pacman hook doesn't run during the install
on snapshots && step "Snapshots (timeshift)" do_snapshots
step "Initramfs (mkinitcpio)"             do_initramfs
on grub     && step "GRUB + Windows dual boot" do_grub

#######################################################
# SUMMARY
#######################################################
echo
echo "${BOLD}================ SUMMARY ================${NC}"
for s in "${DONE[@]}"; do ok "$s"; done
for s in "${FAILED[@]}"; do err "$s"; done
((${#FAILED_PKGS[@]})) && err "Packages that failed: ${FAILED_PKGS[*]}"
for s in "${WARNINGS[@]}"; do echo "${YELLOW}  !${NC} $s"; done
echo
if ((${#FAILED[@]})); then
  echo "${RED}${#FAILED[@]} step(s) failed.${NC} See $LOG. Fix the problem and re-run; it's safe."
else
  echo "${GREEN}Everything installed.${NC} Log: $LOG"
fi
cat <<EOF

${BOLD}Next:${NC}
  exit && umount -R /mnt && reboot
  After login: ssh-keygen -t ed25519   (then add it to GitHub: gh auth login)
  Dual boot without Windows in the menu: sudo update-grub
EOF
grep -qi windows /boot/grub/grub.cfg 2>/dev/null && cat <<'EOF'
  Windows clock: Linux keeps the hardware clock in UTC. For Windows to show the
  right time too, run once in Windows (cmd as Administrator) and reboot:
    reg add "HKLM\System\CurrentControlSet\Control\TimeZoneInformation" /v RealTimeIsUniversal /d 1 /t REG_DWORD /f
EOF
((${#FAILED[@]} == 0))
