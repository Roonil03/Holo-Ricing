# Holo-Ricing

**A Linux customization project themed around Hololive VTubers**

Holo-Rice is a comprehensive collection of Linux customization scripts and configurations that transforms your Linux environment with beautiful Hololive-themed aesthetics. This project brings the colorful and engaging world of Hololive VTubers to your desktop through carefully crafted ricing configurations.

## What is Ricing? 🔧

"Ricing" is the art of customizing and personalizing your Linux operating system to improve both its appearance and functionality. The term originated from the car enthusiast community, where "RICE" stood for "Race Inspired Cosmetic Enhancement," referring to visual modifications that enhanced the aesthetic appeal of vehicles. In the Linux world, ricing involves:

- Customizing desktop environments and window managers
- Modifying system themes, icons, and color schemes
- Configuring terminal appearances and behaviors
- Personalizing boot screens, lock screens, and wallpapers
- Optimizing workflows and system interfaces

Ricing allows users to create a fully personalized computing environment that reflects their preferences and enhances their daily computing experience.

## What is Hololive? 🌟

Hololive is one of the world's largest VTuber (Virtual YouTuber) agencies, operated by Cover Corporation. VTubers are content creators who use virtual avatars to stream games, chat with audiences, and create entertainment content. Hololive has produced many globally recognized VTubers who engage with fans through:

- Daily live streaming sessions
- Interactive gaming content
- Music releases and virtual concerts
- Collaborative projects and events
- Community interaction and fan art creation

The agency operates multiple branches including Hololive Japan, Hololive English, and Hololive Indonesia, featuring dozens of unique VTuber personalities, each with their own distinctive character designs, personalities, and fan communities.

## Project Structure 

This repository contains themed customization scripts for various Hololive characters, with each character having their own dedicated directory containing specific ricing configurations.

### Root Directory Scripts

#### `gitConfig.sh` - Git Environment Configuration

Core Functionality:

- Automated Installation

   - Installs Git through system package manager

   - Verifies successful installation with version check

- Configuration Workflow

   - Interactive username/email setup with existing config detection

   - Text editor selection (nano/vim/VS Code/emacs/gedit)

   - Preconfigured aliases for common commands (st, co, br, lg)

- Security & Compliance

   - Credential helper configuration with 1-hour cache

   - Line ending conversion based on OS detection

   - Default branch initialization as main

Perfect for users who have just installed Linux and want to quickly establish a proper Git workflow environment.

#### `initialization.sh`
A system initialization script that prepares your fresh Linux installation with essential applications and configurations. This script handles:
- Package Management

   - Installs 35+ essential packages across categories

   - Includes CLI tools (ripgrep, bat, exa), sysadmin utilities (ncdu, bandwhich), and development environments (Go, Python)

- Application Setup

   - Installs Brave browser via official script

   - Configures Wine/winetricks for Windows compatibility

   - Lightweight editor setup (Neovim, Emacs minimal install)
   
This script is specifically designed for new Linux users who want to quickly transform a minimal installation into a fully functional desktop environment.

## Getting Started 🚀

### Prerequisites
- A Linux distribution (Ubuntu, Debian, Mint, Fedora, etc.)
- Basic terminal/command line knowledge
- Administrator privileges (sudo access)

### Quick Setup
1. Clone this repository:
   ```bash
   git clone https://github.com/roonil03/holo-ricing.git
   cd holo-rice
   ```

2. Make scripts executable:
   ```bash
   chmod +x git.sh initialization.sh
   ```

3. Run the initialization script:
   ```bash
   ./initialization.sh
   ```

4. Set up Git (if needed):
   ```bash
   ./git.sh
   ```

5. Choose your favorite Hololive character directory and follow the specific README instructions within each character folder.

## Available Characters 🎭

Each character directory contains:
- Custom themes and color schemes
- Wallpapers and desktop backgrounds
- Terminal configurations
- System UI modifications
- Character-specific scripts and configurations

### Currently Available:
- **Ina** - Ninomae Ina'nis themed configurations 🐙

### Coming Soon:
- **Suisei** - Hoshimachi Suisei themed configurations ☄️

## Contributing 🤝

We welcome contributions from the community! Whether you want to:
- Add new character themes
- Improve existing configurations
- Fix bugs or issues
- Add support for new Linux distributions
- Create documentation improvements

Please feel free to submit pull requests or open issues for discussion.

## Disclaimer ⚠️

This project is a fan-made tribute to Hololive and is not officially affiliated with Cover Corporation or Hololive Production. All Hololive character designs and intellectual property belong to their respective owners.

## License 📄

This project is released under the MIT License. See the [LICENSE file](https://github.com/Roonil03/HoloRicing/blob/main/LICENSE) for details.

## Support 💝

If you enjoy this project and want to support Hololive:
- Subscribe to your favorite Hololive VTuber channels
- Watch their streams and content
- Support them through official merchandise and donations
- Respect their guidelines and community rules

---

**Have fun ricing and enjoy your Hololive-themed Linux experience!** 🎉