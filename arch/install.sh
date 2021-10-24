# Install

## System
sudo pacman -S --needed base-devel openssl zlib xz
yay -S vim git links htop terminator
git config --global user.name arthurtemporim
git config --global user.email arthurrtl@gmail.com
ssh-keygen

## Python
yay -S pyenv pyenv-virtualenvwrapper
echo $PATH | grep --color=auto "$(pyenv root)/shims"
pyenv install 3.7.9
pyenv global 3.7.9
pip install --upgrade pip
pip install virtualenvwrapper


# Docker
yay -S docker docker-compose
sudo systemctl enable docker
sudo systemctl start docker
sudo groupadd docker
newgrp docker 

# Ruby
yay -S ruby
#curl -L get.rvm.io > rvm-install
#bash < ./rvm-installu
#source ~/.bash_profile
