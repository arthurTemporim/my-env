#!/bin/bash

# Stop execution if any command fails
set -e

# Color definitions
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Identify the correct user (even if running with sudo)
REAL_USER=${SUDO_USER:-$USER}
USER_HOME="/home/$REAL_USER"
ENV_FILE="$USER_HOME/.env"

# URLs
VIMRC_URL="https://raw.githubusercontent.com/arthurTemporim/my-env/refs/heads/main/bash/simple_vimrc"
BASHRC_URL="https://raw.githubusercontent.com/arthurTemporim/my-env/main/bash/bashrc_server"

echo -e "${YELLOW}--- Ubuntu Post-Install Initialization ---${NC}"
echo -e "${YELLOW}User detected: ${GREEN}$REAL_USER${NC}"

# 1. Summary & Env Check
echo -e "${YELLOW}Checking for configuration file...${NC}"
if [ -f "$ENV_FILE" ]; then
    echo -e "${GREEN}Found .env file at $ENV_FILE${NC}"
else
    echo -e "${RED}WARNING: .env file not found at $ENV_FILE${NC}"
    echo -e "To configure Git automatically, create this file with:"
    echo -e "  export GIT_NAME=\"Your Name\""
    echo -e "  export GIT_EMAIL=\"your@email.com\""
    echo -e "${YELLOW}Continuing installation (Git config will be skipped)...${NC}"
fi

echo -e "${YELLOW}Starting installation in 3 seconds...${NC}"
sleep 3

# 2. System Update & Packages
echo -e "${GREEN}[1/7] Installing system packages...${NC}"
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl vim htop terminator nvtop links git tree bat openssh-server

# Fix for 'bat' command (Ubuntu installs it as 'batcat')
if [ ! -f /usr/local/bin/bat ]; then
    echo "Linking batcat to bat..."
    sudo ln -s /usr/bin/batcat /usr/local/bin/bat
fi

# 3. Configure Git (Conditional)
echo -e "${GREEN}[2/7] configuring Git...${NC}"
if [ -f "$ENV_FILE" ]; then
    # Source the file as the real user to get variables
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    
    if [ -n "$GIT_NAME" ] && [ -n "$GIT_EMAIL" ]; then
        sudo -u "$REAL_USER" git config --global user.name "$GIT_NAME"
        sudo -u "$REAL_USER" git config --global user.email "$GIT_EMAIL"
        sudo -u "$REAL_USER" git config --global init.defaultBranch main
        echo -e "${BLUE}Git Configured for: $GIT_NAME <$GIT_EMAIL>${NC}"
    else
        echo -e "${RED}Variables GIT_NAME or GIT_EMAIL missing in .env. Skipping Git config.${NC}"
    fi
else
    echo -e "${YELLOW}Skipping Git configuration (.env missing).${NC}"
fi

# 4. Vim Configuration
echo -e "${GREEN}[3/7] Configuring Vim...${NC}"
# Download .vimrc as user
sudo -u "$REAL_USER" curl -fsSL "$VIMRC_URL" -o "$USER_HOME/.vimrc"

# Set Vim as default editor system-wide
echo "Setting Vim as default system editor..."
sudo update-alternatives --set editor /usr/bin/vim.basic

# 5. Docker Setup
echo -e "${GREEN}[4/7] Installing Docker...${NC}"
sudo apt install -y ca-certificates gnupg
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Use .list file (classic deb line) instead of .sources to avoid "malformed stanza" error
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 6. Docker Permissions
echo -e "${GREEN}[5/7] Setting Docker permissions...${NC}"
sudo systemctl start docker
sudo systemctl enable docker
if ! getent group docker > /dev/null 2>&1; then
  sudo groupadd docker
fi
sudo usermod -aG docker "$REAL_USER"

# 7. Custom .bashrc
echo -e "${GREEN}[6/7] Downloading custom .bashrc...${NC}"
if [ -f "$USER_HOME/.bashrc" ]; then
    # Backup existing
    cp "$USER_HOME/.bashrc" "$USER_HOME/.bashrc.backup"
fi
sudo -u "$REAL_USER" curl -fsSL "$BASHRC_URL" -o "$USER_HOME/.bashrc"
touch ~/.bash_aliases

# 8. Finish
echo -e "${GREEN}-------------------------------------------------${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${YELLOW}IMPORTANT:${NC} Please Log Out and Log Back In for Docker permissions to take effect."
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}REMINDER:${NC} Git was NOT configured. Create ~/.env and run git config manually."
fi
echo -e "${GREEN}-------------------------------------------------${NC}"
