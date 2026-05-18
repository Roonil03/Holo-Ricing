# Toggle Ninomae Ina'nis Cursor
WAH() {
    if [ ! -d "$HOME/.icons/tako" ]; then
        echo "Installing Tako cursor..."
        mkdir -p "$HOME/.icons/tako"
        if [ -f "$HOME/Downloads/Ninomae-Ina-nis.tar.gz" ]; then
            tar -xzf "$HOME/Downloads/Ninomae-Ina-nis.tar.gz" -C "$HOME/.icons/tako" --strip-components=1
        else
            echo "Error: $HOME/Downloads/Ninomae-Ina-nis.tar.gz not found!"
            return 1
        fi
    fi

    CURRENT_CURSOR=$(gsettings get org.cinnamon.desktop.interface cursor-theme)
    if [ "$CURRENT_CURSOR" = "'tako'" ]; then
        echo "Wah... changing back to default."
        gsettings set org.cinnamon.desktop.interface cursor-theme 'DMZ-White'
    else
        echo "WAH! We are Takodachis now!"
        gsettings set org.cinnamon.desktop.interface cursor-theme 'tako'
    fi
}
