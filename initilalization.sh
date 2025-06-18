#!/bin/bash

set -e

command_exists() {
    command -v "$1" >dev/null 2>&1
}

sudo apt update
echo 'Updated'

if ! command_exists python3; then
    sudo apt install -y python3-pip python3-venv
fi

sudo apt install -y\
    git \
    curl \
    wget \
    vim \
    nano \
    htop \
    tree \
    unzip \
    zip \
    build-essential \
    software-properties-common \
    apt-transport-https 

sudo apt install -y \
    ripgrep \
    fd-find \
    bat \
    exa \
    fzf \
    tldr \
    neovim \
    zoxide

sudo apt install -y \
    neofetch \
    ncdu \
    gping \
    bandwhich 

sudo apt install emacs --no-install-recommends

if ! command_exists fastfetch; then
    sudo apt install -y fastfetch
fi

if ! command_exists go; then
    sudo apt install -y golang-go
fi

if ! command_exists wine; then
    sudo apt install -y wine-winetricks
fi

if ! command_exists speedtest; then
    curl -s https://install.speedtest.net/app/cli/install.deb.sh | sudo bash
    sudo apt-get install -y speedtest
elif ! command_exists speedtest-cli; then
    sudo apt install -y speedtest-cli
fi

if ! command_exists code; then
    echo 'Install VSC from site'
fi

if ! command_exists brave-browser; then
    curl -fsS https://dl.brave.com/install.sh | sh
fi

sudo apt update
echo 'Installed'
sudo apt autoremove -y
sudo apt autoclean
