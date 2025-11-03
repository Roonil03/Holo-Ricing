# LOCK SCREEN WALLPAPER

# Download the image you want to load into the lockscreen

wget -U "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
     -O ~/Pictures/ina-lockscreen.jpg \
     https://img.goodfon.com/original/3840x2160/1/4a/virtual-youtuber-hololive-ninomae-ina-nis-puzyri-anime-ulybk.jpg
    
sudo cp ~/Pictures/ina-lockscreen.jpg /usr/share/backgrounds/

sudo chmod 644 /usr/share/backgrounds/ina-lockscreen.jpg
sudo chown root:root /usr/share/backgrounds/ina-lockscreen.jpg

# Linux Cinnamon Mint Configuration:
sudo tee /etc/lightdm/slick-greeter.conf > /dev/null <<EOF
[Greeter]
background=/usr/share/backgrounds/ina-lockscreen.jpg
draw-user-backgrounds=false
EOF

# sudo systemctl restart lightdm #Restarts the laptop

#Configures the normal desktop to the normal desktop wallpaper
gsettings set org.cinnamon.desktop.background picture-uri 'file:///usr/share/backgrounds/linuxmint-default.jpg'


# MOUSE POINTER CONFIGURATION FOR LOCK SCREEN

# Download the mouse pointer you want, I am going with this GIF
wget -O ~/Downloads/tako.gif "https://media.tenor.com/1vhgkHU7lI0AAAAj/takodachi-ina.gif"

mkdir -p ~/tako-cursor && cd ~/tako-cursor
convert ~/Downloads/tako.gif frame-%03d.png

rm frame-006.png

for img in frame-*.png; do
    convert "$img" -resize 40x40! "$img"
done

for img in frame-*.png; do
  echo "40 0 0 $img 40" >> metadata
done

xcursorgen metadata tako-cursor

sudo mkdir -p /usr/share/icons/tako/cursors
sudo cp tako-cursor /usr/share/icons/tako/cursors/
sudo chmod -R 755 /usr/share/icons/tako

sudo mv /usr/share/icons/tako/cursors/tako-cursor  /usr/share/icons/tako/cursors/left_ptr
sudo chmod 644 /usr/share/icons/tako/cursors/left_ptr
sudo chown root:root /usr/share/icons/tako/cursors/left_ptr
sudo fc-cache -fv

sudo tee /usr/share/icons/tako/index.theme <<EOF
[Icon Theme]
Name=Tako Cursor
Inherits=Adwaita
Comment=Animated Tako Cursor Theme
EOF

sudo tee /etc/lightdm/slick-greeter.conf > /dev/null <<EOF
[Greeter]
cursor-theme-name = tako
cursor-theme-size = 40
background=/usr/share/backgrounds/ina-lockscreen.jpg
draw-user-backgrounds=false
show-hostname=false
layout=center
EOF

# sudo systemctl restart lightdm

# To keep changing and altering the files, without causing issues, you can keep running these three commands until you're satisfied
# rm -r tako-cursor/
# rm Downloads/tako.gif
# sudo rm -r /usr/share/icons/tako/


# PANEL FONT CHANGE VIA CSS FOR LOCK SCREEN
sudo apt install lynx
direct_url=$(lynx -dump "https://www.dafont.com/electroharmonix.font" | grep -E 'https://dl.dafont.com/dl/\?f=electroharmonix' | awk '{print $2}')

wget --trust-server-names "$direct_url" -O electroharmonix.zip

sudo unzip electroharmonix.zip -d /usr/share/fonts/electroharmonix/
sudo chmod -R 755 /usr/share/fonts/electroharmonix
sudo fc-cache -fv

sudo mkdir -p /usr/share/themes/SlickCustom/gtk-3.0

sudo tee /usr/share/themes/SlickCustom/gtk-3.0/gtk.css > /dev/null << EOF
* {
  font-family: "Electroharmonix", "Ubuntu", sans-serif !important;
  font-size: 14px !important;
}

.slick-greeter #panel_window {
  font-family: "Electroharmonix", "Ubuntu", sans-serif !important;
  font-size: 14px !important;
}

.slick-greeter #login_window.lightdm {
  font-family: "Electroharmonix", "Ubuntu", sans-serif !important;
  font-size: 14px !important;
}

.slick-greeter entry {
  font-family: "Electroharmonix", "Ubuntu", sans-serif !important;
  font-size: 14px !important;
}
EOF

sudo tee /usr/share/themes/SlickCustom/index.theme > /dev/null << EOF
[Desktop Entry]
Type=X-GNOME-Metatheme
Name=SlickCustom
Comment=Custom theme for slick-greeter
Encoding=UTF-8

[X-GNOME-Metatheme]
GtkTheme=SlickCustom
MetacityTheme=SlickCustom
IconTheme=Mint-X
CursorTheme=DMZ-White
ButtonLayout=menu:minimize,maximize,close
EOF

sudo tee /etc/lightdm/slick-greeter.conf > /dev/null <<EOF
[Greeter]
cursor-theme-name = tako
cursor-theme-size = 40
background=/usr/share/backgrounds/ina-lockscreen.jpg
draw-user-backgrounds=false
show-hostname=false
layout=center
theme-name=SlickCustom
icon-theme-name=Mint-X
font-name=Electroharmonix 14
EOF

sudo systemctl restart lightdm