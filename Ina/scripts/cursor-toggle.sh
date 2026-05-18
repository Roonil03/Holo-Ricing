#!/bin/bash
# 02-cursor-toggle.sh - Installs Ninomae Ina'nis cursor and sets up global WAH command

echo "Installing Tako cursor..."
if [ ! -d "$HOME/.icons/tako" ]; then
    mkdir -p "$HOME/.icons/tako"
    if [ -f "$HOME/Downloads/Ninomae-Ina-nis.tar.gz" ]; then
        tar -xzf "$HOME/Downloads/Ninomae-Ina-nis.tar.gz" -C "$HOME/.icons/tako" --strip-components=1
        echo "Cursor extracted to $HOME/.icons/tako."
    else
        echo "Error: $HOME/Downloads/Ninomae-Ina-nis.tar.gz not found!"
        exit 1
    fi
else
    echo "Tako cursor already installed."
fi

echo "Creating global WAH command..."

# Create the script in a temporary file first
cat << 'EOF' > /tmp/WAH
#!/bin/bash
# Toggle Ninomae Ina'nis Cursor

CURRENT_CURSOR=$(gsettings get org.cinnamon.desktop.interface cursor-theme)
if [ "$CURRENT_CURSOR" = "'tako'" ]; then
    echo "Wah... changing back to default."
    gsettings set org.cinnamon.desktop.interface cursor-theme 'DMZ-White'
else
    echo "WAH! We are Takodachis now!"
    gsettings set org.cinnamon.desktop.interface cursor-theme 'tako'
fi
EOF

# Move it to /usr/local/bin with sudo
echo "This will require sudo privileges to install WAH globally in /usr/local/bin"
sudo mv /tmp/WAH /usr/local/bin/WAH
sudo chmod +x /usr/local/bin/WAH

# Clean up aliases if they were previously created
if [ -f "../dotfiles/.bash_aliases" ]; then
    > ../dotfiles/.bash_aliases
fi

if [ -f "$HOME/.bash_aliases" ]; then
    sed -i '/WAH() {/,/^}/d' "$HOME/.bash_aliases"
    sed -i '/# Toggle Ninomae Ina'\''nis Cursor/d' "$HOME/.bash_aliases"
fi

echo "Setup complete! You can now type 'WAH' globally from anywhere to toggle the cursor."
