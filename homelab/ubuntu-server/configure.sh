#!/bin/bash

# ==============================================================================
# Server Setup Script 
# ==============================================================================
# 1. System Updates & Tools
# 2. Docker Installation & Permission Fix (No Sudo)
# 3. NVIDIA Stack (Drivers + CUDA + Container Toolkit)
# 4. User Environment (Bashrc + Vimrc)
# ==============================================================================

# --- Configuration & Logging ---
LOG_FILE="/var/log/server_setup.log"
exec > >(tee -i $LOG_FILE)
exec 2>&1

# ANSI Color Codes (Bold & Bright)
B_RED='\033[1;31m'
B_GREEN='\033[1;32m'
B_YELLOW='\033[1;33m'
B_BLUE='\033[1;34m'
B_CYAN='\033[1;36m'
B_WHITE='\033[1;37m'
NC='\033[0m'

# Track failures
FAILURES=()

# --- Helper Functions ---

log_header() {
    echo -e "\n${B_BLUE}################################################################################${NC}"
    echo -e "${B_BLUE}  $1${NC}"
    echo -e "${B_BLUE}################################################################################${NC}"
}

log_info() { echo -e "${B_WHITE}[INFO]${NC} $1"; }

log_success() { echo -e "${B_GREEN}[OK]${NC} $1"; }

log_error() { 
    echo -e "${B_RED}[ERROR]${NC} $1"; 
    FAILURES+=("$1")
}

# Resilient Command Runner
# Usage: run_safe "Description of task" command_to_run
run_safe() {
    local desc="$1"
    shift
    echo -ne "${B_CYAN}[RUN]${NC} $desc... "
    
    # Run command, capture output to log only if needed, silence stdout usually
    if "$@" > /dev/null 2>&1; then
        echo -e "${B_GREEN}DONE${NC}"
    else
        echo -e "${B_RED}FAILED${NC}"
        log_error "Failed: $desc"
        # We do NOT exit, we continue
    fi
}

# --- Pre-flight Checks ---

if [[ $EUID -ne 0 ]]; then
   echo -e "${B_RED}CRITICAL: This script must be run as root (sudo).${NC}"
   exit 1
fi

# Detect actual user
REAL_USER=${SUDO_USER:-$(whoami)}
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

log_header "STARTING SETUP FOR USER: $REAL_USER"
log_info "Home: $USER_HOME"
log_info "Log file: $LOG_FILE"

# ==============================================================================
# 1. System Updates & Tools
# ==============================================================================
log_header "1. SYSTEM UPDATES & TOOLS"

run_safe "Updating apt repositories" apt-get update
run_safe "Upgrading existing packages" apt-get upgrade -y

# Install tools individually so one failure doesn't stop others
TOOLS=(vim htop curl wget tree git make ca-certificates gnupg lsb-release ubuntu-drivers-common software-properties-common)

for tool in "${TOOLS[@]}"; do
    run_safe "Installing $tool" apt-get install -y $tool
done

# ==============================================================================
# 2. Docker Installation & Permissions
# ==============================================================================
log_header "2. DOCKER SETUP"

log_info "Cleaning old Docker versions..."
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do 
    run_safe "Removing $pkg" apt-get remove -y $pkg
done

log_info "Setting up Docker Repo..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

run_safe "Updating apt after Docker repo add" apt-get update
run_safe "Installing Docker Engine" apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

log_info "Configuring Docker Permissions (No Sudo)..."
# 1. Create group
run_safe "Ensuring docker group exists" groupadd docker

# 2. Add user
run_safe "Adding $REAL_USER to docker group" usermod -aG docker "$REAL_USER"

# 3. Enable service
run_safe "Enabling Docker service" systemctl enable docker
run_safe "Starting Docker service" systemctl start docker

# ==============================================================================
# 3. NVIDIA Stack (Drivers & Toolkit)
# ==============================================================================
log_header "3. NVIDIA CONFIGURATION"

log_info "Detecting hardware..."
run_safe "Auto-installing recommended drivers" ubuntu-drivers autoinstall

run_safe "Installing CUDA Toolkit" apt-get install -y nvidia-cuda-toolkit
run_safe "Installing nvtop" apt-get install -y nvtop

log_info "Setting up NVIDIA Container Toolkit..."
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg --yes \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

run_safe "Updating apt for NVIDIA Toolkit" apt-get update
run_safe "Installing NVIDIA Container Toolkit" apt-get install -y nvidia-container-toolkit

# Configure Runtime
run_safe "Configuring Docker Runtime for GPU" nvidia-ctk runtime configure --runtime=docker
run_safe "Restarting Docker to apply GPU config" systemctl restart docker

# ==============================================================================
# 4. User Environment
# ==============================================================================
log_header "4. USER CONFIGURATION (.bashrc / .vimrc)"

VIMRC_URL="https://raw.githubusercontent.com/arthurTemporim/my-env/refs/heads/main/bash/simple_vimrc"
BASHRC_URL="https://raw.githubusercontent.com/arthurTemporim/my-env/refs/heads/main/bash/bashrc_server"

log_info "Applying configs for user: $REAL_USER"

# Backup and Download
if [ -f "$USER_HOME/.bashrc" ]; then
    run_safe "Backing up .bashrc" cp "$USER_HOME/.bashrc" "$USER_HOME/.bashrc.backup.$(date +%s)"
fi

# We use sudo -u to run curl AS THE USER to avoid permission issues later
run_safe "Downloading .vimrc" sudo -u "$REAL_USER" curl -fsSL "$VIMRC_URL" -o "$USER_HOME/.vimrc"
run_safe "Downloading .bashrc" sudo -u "$REAL_USER" curl -fsSL "$BASHRC_URL" -o "$USER_HOME/.bashrc"

# Double check ownership just in case
chown "$REAL_USER":"$REAL_USER" "$USER_HOME/.vimrc" "$USER_HOME/.bashrc"

# ==============================================================================
# Final Report
# ==============================================================================
echo -e "\n${B_BLUE}################################################################################${NC}"
if [ ${#FAILURES[@]} -eq 0 ]; then
    echo -e "${B_GREEN}  SETUP COMPLETED SUCCESSFULLY WITH NO ERRORS!${NC}"
else
    echo -e "${B_YELLOW}  SETUP COMPLETED WITH ${#FAILURES[@]} ERRORS:${NC}"
    for fail in "${FAILURES[@]}"; do
        echo -e "   - ${B_RED}$fail${NC}"
    done
fi
echo -e "${B_BLUE}################################################################################${NC}"

echo -e "\n${B_WHITE}NEXT STEPS:${NC}"
echo -e "1. ${B_YELLOW}REBOOT YOUR SERVER${NC} (Required for NVIDIA drivers and Docker group changes)."
echo -e "2. Or, for Docker only (temp), run: ${B_CYAN}newgrp docker${NC}"
echo -e "3. Verify installation: ${B_CYAN}docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu20.04 nvidia-smi${NC}"
echo ""

