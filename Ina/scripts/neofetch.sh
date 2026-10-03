#!/bin/bash
# 03-neofetch.sh - Installs and configures neofetch with a small Tako ASCII art

echo "Installing Neofetch..."
sudo apt-get install -y neofetch

# Setup config directories
mkdir -p ~/.config/neofetch

echo "Copying configs and processing ASCII art..."
# Check if running from Makefile (root of Ricing) or from scripts dir
if [ -d "dotfiles" ]; then
    SRC_DIR="dotfiles"
else
    SRC_DIR="../dotfiles"
fi

# Use the pre-shrunk neofetch art (20x37) so all stats fit side-by-side.
# Use neofetch-native ${c1}/${c2} color markers (NOT raw ANSI escapes):
# neofetch strips ${cN} when measuring ascii width, but counts raw
# escapes as visible chars, which pushes the stats far to the right.
# Apply Takodachi colors (c1=magenta body, c2=yellow halo)
cp "$SRC_DIR/tako-ascii-neofetch.txt" /tmp/tako-ascii.txt
sed -i 's/^/${c1}/' /tmp/tako-ascii.txt
sed -i 's/:/${c2}:${c1}/g' /tmp/tako-ascii.txt
cp /tmp/tako-ascii.txt ~/.config/neofetch/tako-ascii.txt

# Configure Neofetch (full stats to match fastfetch modules)
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
    info "Resolution" resolution
    info "DE" de
    info "WM" wm
    info "WM Theme" wm_theme
    info "Theme" theme
    info "Icons" icons
    info "Font" font
    info "Cursor" cursor
    info "Terminal" term
    info "Terminal Font" term_font
    info "CPU" cpu
    info "GPU" gpu
    info "Memory" memory
    info "Swap" swap
    info "Disk" disk
    info "Local IP" local_ip
    info "Battery" battery
    info "Locale" locale
    prin "" "\e[33mIna Ina Ina, Ina Ina!\e[0m"
}
image_backend="ascii"
image_source="$HOME/.config/neofetch/tako-ascii.txt"
ascii_distro="auto"
ascii_colors=(5 3)
ascii_bold="on"
gap=2
colors=(5 5 5 5 5 7)
EOF

# Terminal startup stays fastfetch-only: remove any neofetch autostart.
# (Run neofetch manually with the `neofetch` command.)
if grep -q "^neofetch" ~/.bashrc; then
    sed -i '/^neofetch$/d' ~/.bashrc
    echo "Removed neofetch from ~/.bashrc (fastfetch stays the default)"
fi
if grep -q "# Run neofetch on startup" ~/.bashrc; then
    sed -i '/# Run neofetch on startup/d' ~/.bashrc
fi

echo "Neofetch configured! Run 'neofetch' manually to see the small Takodachi."
