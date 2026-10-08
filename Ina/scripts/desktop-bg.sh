#!/bin/bash

echo "Downloading Desktop Wallpaper... (Change URL to your preferred image)"
BG_URL="https://images8.alphacoders.com/127/1279500.png"
BG_PATH="$HOME/Pictures/ina-desktop.jpg"

wget -U "Mozilla/5.0 (X11; Linux x86_64)" -O "$BG_PATH" "$BG_URL"

echo "Applying Desktop Wallpaper to Cinnamon..."
gsettings set org.cinnamon.desktop.background picture-uri "file://$BG_PATH"

echo "Wallpaper applied!"
