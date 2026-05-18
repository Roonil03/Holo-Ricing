#!/bin/bash
# 03-fastfetch.sh - Installs and configures fastfetch & neofetch with a Tako ASCII art

echo "Installing Fastfetch and Neofetch..."
sudo add-apt-repository ppa:zhangsongcui3371/fastfetch -y
sudo apt-get install -y fastfetch neofetch

# Setup config directories
mkdir -p ~/.config/fastfetch
mkdir -p ~/.config/neofetch

echo "Copying configs and processing ASCII art..."
# Check if running from Makefile (root of Ricing) or from scripts dir
if [ -d "dotfiles" ]; then
    SRC_DIR="dotfiles"
else
    SRC_DIR="../dotfiles"
fi

cp "$SRC_DIR/fastfetch_config.jsonc" ~/.config/fastfetch/config.jsonc

# Fix the fastfetch separator icon that renders as a missing character
sed -i 's/ 󰇙 / -> /g' ~/.config/fastfetch/config.jsonc

# Inject the custom text at the end of the fastfetch modules list (after locale)
sed -i '/"locale",/a \    {\n      "type": "custom",\n      "format": "\\u001b[33mIna Ina Ina, Ina Ina!\\u001b[0m"\n    },' ~/.config/fastfetch/config.jsonc

# Process the ASCII art to apply Takodachi colors (Yellow halo, Magenta body)
# First, delete any lines that are just empty '-' padding to reduce vertical height
sed '/^-\+$/d' "$SRC_DIR/tako-ascii.txt" > /tmp/tako-ascii.txt
# Replace remaining '-' padding with spaces
sed -i 's/-/ /g' /tmp/tako-ascii.txt
sed -i 's/^/\x1b[35m/' /tmp/tako-ascii.txt
sed -i 's/:/\x1b[33m:\x1b[35m/g' /tmp/tako-ascii.txt
sed -i 's/$/\x1b[0m/' /tmp/tako-ascii.txt
cp /tmp/tako-ascii.txt ~/.config/fastfetch/tako-ascii.txt
cp /tmp/tako-ascii.txt ~/.config/neofetch/tako-ascii.txt

# Configure Neofetch
cat << 'EOF' > ~/.config/neofetch/config.conf
print_info() {
    info title
    info underline
    info "OS" distro
    info "Host" model
    info "Kernel" kernel
    info "Uptime" uptime
    info "Packages" packages
    info "Shell" shell
    info "DE" de
    info "WM" wm
    info "Theme" theme
    info "Icons" icons
    info "Terminal" term
    info "Terminal Font" term_font
    info "CPU" cpu
    info "GPU" gpu
    info "Memory" memory
    prin "" "\e[33mIna Ina Ina, Ina Ina!\e[0m"
}
image_backend="ascii"
image_source="$HOME/.config/neofetch/tako-ascii.txt"
ascii_distro="auto"
ascii_colors=(5 5)
ascii_bold="on"
colors=(5 5 5 5 5 7)
EOF

# Make fastfetch run on terminal startup
if ! grep -q "fastfetch" ~/.bashrc; then
    echo -e "\n# Run fastfetch on startup\nfastfetch" >> ~/.bashrc
    echo "Added fastfetch to ~/.bashrc"
fi

echo "Fastfetch and Neofetch configured! Open a new terminal to see the Takodachi!"
