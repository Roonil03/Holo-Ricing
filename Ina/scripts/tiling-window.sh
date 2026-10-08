#!/bin/bash

echo "Installing gTile Cinnamon extension..."

# Download gTile using the correct UUID
wget https://cinnamon-spices.linuxmint.com/files/extensions/gTile@shuairan.zip -O /tmp/gtile.zip

# Extract directly to the extensions folder
# (The zip natively contains the 'gTile@shuairan' folder structure)
unzip -o /tmp/gtile.zip -d ~/.local/share/cinnamon/extensions/

# Enable the extension via gsettings
ENABLED_EXTENSIONS=$(gsettings get org.cinnamon enabled-extensions)

if [[ $ENABLED_EXTENSIONS != *"gTile@shuairan"* ]]; then
    # Prevent the leading comma syntax error if the array is currently empty
    if [[ "$ENABLED_EXTENSIONS" == "@as []" ]] || [[ "$ENABLED_EXTENSIONS" == "[]" ]]; then
        NEW_EXTENSIONS="['gTile@shuairan']"
    else
        NEW_EXTENSIONS=$(echo "$ENABLED_EXTENSIONS" | sed "s/]/, 'gTile@shuairan']/")
    fi
    
    gsettings set org.cinnamon enabled-extensions "$NEW_EXTENSIONS"
    echo "gTile enabled."
else
    echo "gTile is already enabled."
fi

# Configure gTile grid sizes and hotkey (Super+G is default)
echo "gTile installed! Press Super+G in Cinnamon to activate the tiling grid."