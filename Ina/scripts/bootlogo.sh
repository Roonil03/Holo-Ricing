#!/bin/bash

echo "Installing required packages..."
sudo apt-get install -y plymouth plymouth-themes imagemagick wget

# Create theme directory
THEME_DIR="/usr/share/plymouth/themes/ina-boot"
sudo mkdir -p $THEME_DIR

echo "Downloading Boot GIF... (Please change this URL to your preferred GIF)"
GIF_URL="https://media.tenor.com/AKeMkLsHqqEAAAAi/tako-takover-ninomae-ina%27nis.gif"
wget -O /tmp/bootlogo.gif "$GIF_URL"

echo "Extracting GIF frames smoothly (coalescing)..."
mkdir -p /tmp/ina-frames
rm -f /tmp/ina-frames/*.png
# Use -coalesce to ensure frames are fully rendered (smooth extraction)
convert -coalesce /tmp/bootlogo.gif /tmp/ina-frames/progress-%02d.png

echo "Removing empty (odd-numbered) frames..."
rm -f /tmp/ina-frames/progress-*[13579].png

echo "Renaming remaining frames sequentially..."
COUNT=0
for f in $(ls /tmp/ina-frames/progress-*.png | sort -V); do
    NEW_NAME=$(printf "/tmp/ina-frames/seq-%02d.png" $COUNT)
    mv "$f" "$NEW_NAME"
    COUNT=$((COUNT + 1))
done

# Copy sequentially named frames to theme directory
sudo rm -f $THEME_DIR/progress-*.png
if [ "$COUNT" -gt 0 ]; then
    for i in $(seq 0 $((COUNT - 1))); do
        SRC=$(printf "/tmp/ina-frames/seq-%02d.png" $i)
        DEST=$(printf "$THEME_DIR/progress-%02d.png" $i)
        sudo cp "$SRC" "$DEST"
    done
fi
NUM_FRAMES=$COUNT
rm -rf /tmp/ina-frames

# Create plymouth config file
sudo tee $THEME_DIR/ina-boot.plymouth > /dev/null <<EOF
[Plymouth Theme]
Name=Ina Boot
Description=Takodachi Boot Animation
ModuleName=script

[script]
ImageDir=$THEME_DIR
ScriptFile=$THEME_DIR/ina-boot.script
EOF

# Create plymouth script file
sudo tee $THEME_DIR/ina-boot.script > /dev/null <<EOF
# Simple Plymouth Script
Window.SetBackgroundTopColor (0.117, 0.094, 0.149); # Dark purple #1e1826
Window.SetBackgroundBottomColor (0.117, 0.094, 0.149);

for (i = 0; i < $NUM_FRAMES; i++) {
  if (i < 10) {
    image[i] = Image("progress-0" + i + ".png");
  } else {
    image[i] = Image("progress-" + i + ".png");
  }
}

sprite = Sprite();

progress = 0;
fun refresh_callback () {
  sprite.SetImage(image[Math.Int(progress / 2) % $NUM_FRAMES]);
  sprite.SetX(Window.GetWidth() / 2 - image[0].GetWidth() / 2);
  sprite.SetY(Window.GetHeight() / 2 - image[0].GetHeight() / 2);
  progress++;
}

Plymouth.SetRefreshFunction (refresh_callback);
EOF

echo "Applying Plymouth Theme..."
sudo update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth $THEME_DIR/ina-boot.plymouth 100
sudo update-alternatives --set default.plymouth $THEME_DIR/ina-boot.plymouth
sudo update-initramfs -u

echo "Boot logo configured successfully!"
