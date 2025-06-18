#!/bin/bash
set -e
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
print_header() {
    echo -e "${CYAN}=============================================${NC}"
    echo -e "${CYAN}          Git Configuration Script          ${NC}"
    echo -e "${CYAN}=============================================${NC}"
    echo
}
print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}
print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}
check_git_installation() {
    if ! command -v git &> /dev/null; then
        echo -e "${RED}[ERROR]${NC} Git is not installed on this system."
        echo "Please install Git first using: sudo apt install git"
        exit 1
    fi
    print_success "Git is installed: $(git --version)"
}
configure_user_info() {
    echo -e "${BLUE}=== Basic User Configuration ===${NC}"
    echo
    current_name=$(git config --global user.name 2>/dev/null || echo "Not set")
    current_email=$(git config --global user.email 2>/dev/null || echo "Not set")
    echo "Current Git configuration:"
    echo "  Name: $current_name"
    echo "  Email: $current_email"
    echo
    echo -n "Enter your full name (e.g., John Doe): "
    read -r user_name
    if [[ -n "$user_name" ]]; then
        git config --global user.name "$user_name"
        print_success "Name set to: $user_name"
    else
        print_warning "Name not changed"
    fi
    echo -n "Enter your email address: "
    read -r user_email
    if [[ -n "$user_email" ]]; then
        git config --global user.email "$user_email"
        print_success "Email set to: $user_email"
    else
        print_warning "Email not changed"
    fi
    echo
}
configure_editor() {
    echo -e "${BLUE}=== Text Editor Configuration ===${NC}"
    echo
    echo "Choose your preferred text editor for Git:"
    echo "1) nano (beginner-friendly)"
    echo "2) vim (advanced)"
    echo "3) emacs"
    echo "4) code (VS Code)"
    echo "5) gedit"
    echo "6) Skip this step"
    echo
    echo -n "Enter your choice (1-6): "
    read -r editor_choice
    case $editor_choice in
        1)
            git config --global core.editor nano
            print_success "Text editor set to: nano"
            ;;
        2)
            git config --global core.editor vim
            print_success "Text editor set to: vim"
            ;;
        3)
            git config --global core.editor emacs
            print_success "Text editor set to: emacs"
            ;;
        4)
            git config --global core.editor "code --wait"
            print_success "Text editor set to: VS Code"
            ;;
        5)
            git config --global core.editor gedit
            print_success "Text editor set to: gedit"
            ;;
        6)
            print_info "Text editor configuration skipped"
            ;;
        *)
            print_warning "Invalid choice. Text editor not changed"
            ;;
    esac
    echo
}
configure_aliases() {
    echo -e "${BLUE}=== Git Aliases Configuration ===${NC}"
    echo
    echo "Would you like to set up useful Git aliases? (y/n)"
    echo "This will add shortcuts for common Git commands."
    echo
    echo -n "Configure aliases? (y/n): "
    read -r setup_aliases
    if [[ $setup_aliases =~ ^[Yy]$ ]]; then
        git config --global alias.st status
        git config --global alias.co checkout
        git config --global alias.br branch
        git config --global alias.ci commit
        git config --global alias.up rebase
        git config --global alias.lg "log --oneline --graph --decorate --all"
        git config --global alias.unstage "reset HEAD --"
        git config --global alias.last "log -1 HEAD"
        git config --global alias.visual "!gitk"
        print_success "Git aliases configured successfully!"
        echo "Available aliases:"
        echo "  git st       -> git status"
        echo "  git co       -> git checkout"
        echo "  git br       -> git branch"
        echo "  git ci       -> git commit"
        echo "  git up       -> git rebase"
        echo "  git lg       -> git log --oneline --graph --decorate --all"
        echo "  git unstage  -> git reset HEAD --"
        echo "  git last     -> git log -1 HEAD"
        echo "  git visual   -> gitk"
    else
        print_info "Git aliases configuration skipped"
    fi
    echo
}
configure_additional_settings() {
    echo -e "${BLUE}=== Additional Settings ===${NC}"
    echo
    echo -n "Set default branch name to 'main'? (y/n): "
    read -r set_main_branch
    if [[ $set_main_branch =~ ^[Yy]$ ]]; then
        git config --global init.defaultBranch main
        print_success "Default branch name set to 'main'"
    fi
    echo -n "Configure automatic line ending conversion? (y/n): "
    read -r configure_crlf
    if [[ $configure_crlf =~ ^[Yy]$ ]]; then
        if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
            git config --global core.autocrlf true
            print_success "Line ending conversion set for Windows"
        else
            git config --global core.autocrlf input
            print_success "Line ending conversion set for Unix/Linux"
        fi
    fi
    echo -n "Set push behavior to simple (recommended)? (y/n): "
    read -r set_push_simple
    if [[ $set_push_simple =~ ^[Yy]$ ]]; then
        git config --global push.default simple
        print_success "Push behavior set to 'simple'"
    fi
    echo -n "Configure credential helper to cache passwords? (y/n): "
    read -r set_credential_helper
    if [[ $set_credential_helper =~ ^[Yy]$ ]]; then
        git config --global credential.helper cache
        git config --global credential.helper 'cache --timeout=3600'
        print_success "Credential helper configured (1 hour cache)"
    fi
    echo
}
display_configuration() {
    echo -e "${CYAN}=== Final Git Configuration ===${NC}"
    echo
    echo "Your current Git configuration:"
    echo
    git config --global --list | grep -E "(user\.|core\.|alias\.|init\.|push\.|credential\.)" | sort
    echo
    print_success "Git configuration completed successfully!"
    echo
    echo "You can view your complete configuration anytime with:"
    echo "  git config --global --list"
    echo
    echo "To edit configuration manually:"
    echo "  git config --global --edit"
}
backup_configuration() {
    echo -e "${BLUE}=== Configuration Backup ===${NC}"
    echo
    echo -n "Would you like to backup your Git configuration? (y/n): "
    read -r backup_config
    if [[ $backup_config =~ ^[Yy]$ ]]; then
        backup_dir="$HOME/git-config-backups"
        mkdir -p "$backup_dir"
        backup_file="$backup_dir/git-config-backup-$(date +%Y-%m-%d_%H-%M-%S).txt"
        git config --global --list > "$backup_file"
        print_success "Configuration backed up to: $backup_file"
    fi
    echo
}
main() {
    print_header
    check_git_installation
    backup_configuration
    configure_user_info
    configure_editor
    configure_aliases
    configure_additional_settings
    display_configuration
    echo -e "${GREEN}Git configuration script completed!${NC}"
}
main
