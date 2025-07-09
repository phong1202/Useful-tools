#!/bin/bash

# Zsh Complete Setup Script with Comprehensive Error Handling
# Installs: Zsh, Oh My Zsh, Powerlevel10k, zsh-autosuggestions, zsh-syntax-highlighting

set -e  # Exit on any error (we'll handle them with trap)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration variables
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
BACKUP_DIR="$HOME/.zsh_backup_$(date +%Y%m%d_%H%M%S)"

# Logging functions
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

header() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root directly."
        error "It will use sudo when needed for specific commands."
        exit 1
    fi
}

# Function to detect OS and package manager
detect_os() {
    log "Detecting operating system..."
    
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        error "Cannot detect operating system."
        error "This script supports Ubuntu/Debian, CentOS/RHEL/Fedora, and macOS."
        exit 1
    fi
    
    case $OS in
        ubuntu|debian)
            PACKAGE_MANAGER="apt"
            INSTALL_CMD="sudo apt install -y"
            UPDATE_CMD="sudo apt update"
            ;;
        centos|rhel|fedora)
            if command -v dnf >/dev/null 2>&1; then
                PACKAGE_MANAGER="dnf"
                INSTALL_CMD="sudo dnf install -y"
                UPDATE_CMD="sudo dnf update -y"
            else
                PACKAGE_MANAGER="yum"
                INSTALL_CMD="sudo yum install -y"
                UPDATE_CMD="sudo yum update -y"
            fi
            ;;
        *)
            if [[ "$OSTYPE" == "darwin"* ]]; then
                OS="macos"
                PACKAGE_MANAGER="brew"
                INSTALL_CMD="brew install"
                UPDATE_CMD="brew update"
            else
                error "Unsupported operating system: $OS"
                error "This script supports Ubuntu/Debian, CentOS/RHEL/Fedora, and macOS."
                exit 1
            fi
            ;;
    esac
    
    success "Detected OS: $OS with package manager: $PACKAGE_MANAGER"
}

# Function to check network connectivity
check_network() {
    log "Checking network connectivity..."
    
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        error "No internet connection detected."
        error "Please check your network connection and try again."
        exit 1
    fi
    
    # Test GitHub connectivity (required for Oh My Zsh and plugins)
    if ! curl -s --connect-timeout 10 https://github.com >/dev/null; then
        error "Cannot reach GitHub."
        error "Please check if your firewall or proxy is blocking the connection."
        exit 1
    fi
    
    success "Network connectivity confirmed."
}

# Function to check available disk space
check_disk_space() {
    log "Checking available disk space..."
    
    available_space=$(df "$HOME" | awk 'NR==2 {print $4}')
    required_space=102400  # 100MB in KB
    
    if [[ $available_space -lt $required_space ]]; then
        error "Insufficient disk space. At least 100MB free space is required."
        error "Available space: $(( available_space / 1024 ))MB"
        exit 1
    fi
    
    success "Sufficient disk space available."
}

# Function to backup existing configurations
backup_existing_config() {
    log "Backing up existing configurations..."
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup existing files
    local files_to_backup=(".zshrc" ".oh-my-zsh" ".p10k.zsh")
    local backed_up=false
    
    for file in "${files_to_backup[@]}"; do
        if [[ -e "$HOME/$file" ]]; then
            cp -r "$HOME/$file" "$BACKUP_DIR/" 2>/dev/null || {
                warning "Failed to backup $file"
                continue
            }
            backed_up=true
            log "Backed up: $file"
        fi
    done
    
    if [[ $backed_up == true ]]; then
        success "Configurations backed up to: $BACKUP_DIR"
    else
        log "No existing configurations found to backup."
        rmdir "$BACKUP_DIR" 2>/dev/null || true
    fi
}

# Function to update package manager
update_packages() {
    header "Updating package manager..."
    
    case $PACKAGE_MANAGER in
        apt)
            if ! sudo apt update 2>/dev/null; then
                error "Failed to update package lists."
                error "Please check your repository sources and network connection."
                exit 1
            fi
            ;;
        dnf|yum)
            if ! $UPDATE_CMD >/dev/null 2>&1; then
                warning "Package manager update failed, continuing anyway..."
            fi
            ;;
        brew)
            if ! brew update >/dev/null 2>&1; then
                warning "Homebrew update failed, continuing anyway..."
            fi
            ;;
    esac
    
    success "Package manager updated successfully."
}

# Function to install prerequisites
install_prerequisites() {
    header "Installing prerequisites..."
    
    local prerequisites=""
    
    case $PACKAGE_MANAGER in
        apt)
            prerequisites="curl git wget"
            ;;
        dnf|yum)
            prerequisites="curl git wget"
            ;;
        brew)
            prerequisites="curl git wget"
            ;;
    esac
    
    if ! $INSTALL_CMD $prerequisites 2>/dev/null; then
        error "Failed to install prerequisites: $prerequisites"
        error "Please ensure you have sufficient permissions and network access."
        exit 1
    fi
    
    success "Prerequisites installed successfully."
}

# Function to install Zsh
install_zsh() {
    header "Installing Zsh..."
    
    # Check if Zsh is already installed
    if command -v zsh >/dev/null 2>&1; then
        local current_version=$(zsh --version | cut -d' ' -f2)
        log "Zsh is already installed (version: $current_version)"
        return 0
    fi
    
    case $PACKAGE_MANAGER in
        apt)
            if ! sudo apt install -y zsh; then
                error "Failed to install Zsh via apt."
                error "Try running: sudo apt update && sudo apt install zsh"
                exit 1
            fi
            ;;
        dnf)
            if ! sudo dnf install -y zsh; then
                error "Failed to install Zsh via dnf."
                exit 1
            fi
            ;;
        yum)
            if ! sudo yum install -y zsh; then
                error "Failed to install Zsh via yum."
                exit 1
            fi
            ;;
        brew)
            if ! brew install zsh; then
                error "Failed to install Zsh via Homebrew."
                error "Make sure Homebrew is properly installed and updated."
                exit 1
            fi
            ;;
    esac
    
    # Verify installation
    if ! command -v zsh >/dev/null 2>&1; then
        error "Zsh installation failed - command not found after installation."
        exit 1
    fi
    
    local zsh_version=$(zsh --version | cut -d' ' -f2)
    success "Zsh installed successfully (version: $zsh_version)"
}

# Function to install Oh My Zsh
install_oh_my_zsh() {
    header "Installing Oh My Zsh..."
    
    # Check if Oh My Zsh is already installed
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        log "Oh My Zsh is already installed."
        return 0
    fi
    
    # Download and install Oh My Zsh
    local install_script_url="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
    
    if ! curl -fsSL "$install_script_url" -o /tmp/install_oh_my_zsh.sh; then
        error "Failed to download Oh My Zsh installation script."
        error "Please check your internet connection and GitHub access."
        exit 1
    fi
    
    # Run the installation script with unattended mode
    if ! RUNZSH=no CHSH=no sh /tmp/install_oh_my_zsh.sh; then
        error "Oh My Zsh installation failed."
        error "Check the error messages above for more details."
        exit 1
    fi
    
    # Clean up
    rm -f /tmp/install_oh_my_zsh.sh
    
    success "Oh My Zsh installed successfully."
}

# Function to install Powerlevel10k theme
install_powerlevel10k() {
    header "Installing Powerlevel10k theme..."
    
    local p10k_dir="${ZSH_CUSTOM}/themes/powerlevel10k"
    
    # Check if Powerlevel10k is already installed
    if [[ -d "$p10k_dir" ]]; then
        log "Powerlevel10k is already installed."
        return 0
    fi
    
    # Clone Powerlevel10k repository
    if ! git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k_dir"; then
        error "Failed to clone Powerlevel10k repository."
        error "Please check your internet connection and GitHub access."
        exit 1
    fi
    
    success "Powerlevel10k theme installed successfully."
}

# Function to install zsh-autosuggestions plugin
install_autosuggestions() {
    header "Installing zsh-autosuggestions plugin..."
    
    local plugin_dir="${ZSH_CUSTOM}/plugins/zsh-autosuggestions"
    
    # Check if plugin is already installed
    if [[ -d "$plugin_dir" ]]; then
        log "zsh-autosuggestions is already installed."
        return 0
    fi
    
    # Clone plugin repository
    if ! git clone https://github.com/zsh-users/zsh-autosuggestions "$plugin_dir"; then
        error "Failed to clone zsh-autosuggestions repository."
        error "Please check your internet connection and GitHub access."
        exit 1
    fi
    
    success "zsh-autosuggestions plugin installed successfully."
}

# Function to install zsh-syntax-highlighting plugin
install_syntax_highlighting() {
    header "Installing zsh-syntax-highlighting plugin..."
    
    local plugin_dir="${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting"
    
    # Check if plugin is already installed
    if [[ -d "$plugin_dir" ]]; then
        log "zsh-syntax-highlighting is already installed."
        return 0
    fi
    
    # Clone plugin repository
    if ! git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$plugin_dir"; then
        error "Failed to clone zsh-syntax-highlighting repository."
        error "Please check your internet connection and GitHub access."
        exit 1
    fi
    
    success "zsh-syntax-highlighting plugin installed successfully."
}

# Function to configure .zshrc
configure_zshrc() {
    header "Configuring .zshrc..."
    
    local zshrc_file="$HOME/.zshrc"
    
    # Create a new .zshrc with our configuration
    cat > "$zshrc_file" << 'EOF'
# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load
ZSH_THEME="powerlevel10k/powerlevel10k"

# Plugins to load
plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
)

# Load Oh My Zsh
source $ZSH/oh-my-zsh.sh

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# User configuration
# Add any custom configurations below this line

EOF

    success ".zshrc configured with Powerlevel10k theme and plugins."
}

# Function to set Zsh as default shell
set_default_shell() {
    header "Setting Zsh as default shell..."
    
    local zsh_path=$(which zsh)
    local current_shell=$(echo $SHELL)
    
    if [[ "$current_shell" == "$zsh_path" ]]; then
        success "Zsh is already the default shell."
        return 0
    fi
    
    # Check if zsh is in /etc/shells
    if ! grep -q "$zsh_path" /etc/shells 2>/dev/null; then
        log "Adding Zsh to /etc/shells..."
        if ! echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null; then
            warning "Failed to add Zsh to /etc/shells."
            warning "You may need to change your default shell manually."
            return 1
        fi
    fi
    
    # Change default shell
    if ! chsh -s "$zsh_path"; then
        warning "Failed to change default shell to Zsh."
        warning "You can change it manually by running: chsh -s $zsh_path"
        warning "Or use Zsh by running: zsh"
        return 1
    fi
    
    success "Default shell changed to Zsh."
    success "Please log out and log back in for the change to take effect."
}

# Function to install recommended fonts
install_fonts() {
    header "Installing recommended fonts..."
    
    case $OS in
        ubuntu|debian)
            log "Installing fonts for better Powerlevel10k experience..."
            if ! sudo apt install -y fonts-powerline fonts-font-awesome; then
                warning "Failed to install fonts via package manager."
                warning "You may need to install fonts manually for best experience."
            else
                success "Fonts installed successfully."
            fi
            ;;
        centos|rhel|fedora)
            log "Installing fonts for better Powerlevel10k experience..."
            if ! $INSTALL_CMD powerline-fonts fontawesome-fonts 2>/dev/null; then
                warning "Failed to install fonts via package manager."
                warning "You may need to install fonts manually for best experience."
            else
                success "Fonts installed successfully."
            fi
            ;;
        macos)
            log "On macOS, you may want to install a Nerd Font for best experience."
            log "Visit: https://github.com/ryanoasis/nerd-fonts"
            ;;
        *)
            warning "Font installation not automated for your OS."
            warning "Consider installing a Nerd Font for best Powerlevel10k experience."
            ;;
    esac
}

# Function to run initial Powerlevel10k configuration
run_p10k_config() {
    header "Preparing Powerlevel10k configuration..."
    
    log "Powerlevel10k configuration wizard will run when you first start Zsh."
    log "You can also run it manually anytime with: p10k configure"
    success "Powerlevel10k is ready for configuration."
}

# Function to verify installation
verify_installation() {
    header "Verifying installation..."
    
    local issues=0
    
    # Check Zsh
    if ! command -v zsh >/dev/null 2>&1; then
        error "Zsh is not installed or not in PATH."
        ((issues++))
    else
        success "✓ Zsh is installed: $(zsh --version)"
    fi
    
    # Check Oh My Zsh
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        error "Oh My Zsh is not installed."
        ((issues++))
    else
        success "✓ Oh My Zsh is installed"
    fi
    
    # Check Powerlevel10k
    if [[ ! -d "${ZSH_CUSTOM}/themes/powerlevel10k" ]]; then
        error "Powerlevel10k theme is not installed."
        ((issues++))
    else
        success "✓ Powerlevel10k theme is installed"
    fi
    
    # Check plugins
    if [[ ! -d "${ZSH_CUSTOM}/plugins/zsh-autosuggestions" ]]; then
        error "zsh-autosuggestions plugin is not installed."
        ((issues++))
    else
        success "✓ zsh-autosuggestions plugin is installed"
    fi
    
    if [[ ! -d "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting" ]]; then
        error "zsh-syntax-highlighting plugin is not installed."
        ((issues++))
    else
        success "✓ zsh-syntax-highlighting plugin is installed"
    fi
    
    # Check .zshrc
    if [[ ! -f "$HOME/.zshrc" ]]; then
        error ".zshrc file is missing."
        ((issues++))
    else
        success "✓ .zshrc is configured"
    fi
    
    if [[ $issues -eq 0 ]]; then
        success "All components verified successfully!"
        return 0
    else
        error "$issues issue(s) found during verification."
        return 1
    fi
}

# Function to show post-installation information
show_post_install_info() {
    echo ""
    echo "=================================================="
    echo "           Installation Complete!                 "
    echo "=================================================="
    echo ""
    
    success "Zsh setup completed successfully!"
    echo ""
    
    log "What was installed:"
    echo "  ✓ Zsh shell"
    echo "  ✓ Oh My Zsh framework"
    echo "  ✓ Powerlevel10k theme"
    echo "  ✓ zsh-autosuggestions plugin"
    echo "  ✓ zsh-syntax-highlighting plugin"
    echo ""
    
    log "Next steps:"
    echo "  1. Start a new Zsh session: zsh"
    echo "  2. Run Powerlevel10k configuration: p10k configure"
    echo "  3. Restart your terminal or run: source ~/.zshrc"
    echo ""
    
    if [[ -d "$BACKUP_DIR" ]]; then
        log "Your previous configurations are backed up in:"
        echo "  $BACKUP_DIR"
        echo ""
    fi
    
    log "Useful commands:"
    echo "  p10k configure        # Configure Powerlevel10k theme"
    echo "  omz update           # Update Oh My Zsh"
    echo "  omz plugin list      # List available plugins"
    echo "  omz theme list       # List available themes"
    echo ""
    
    warning "Note: If you changed your default shell, please log out and log back in."
    success "Enjoy your new Zsh setup with Powerlevel10k!"
}

# Main execution function
main() {
    echo "=================================================="
    echo "    Zsh Complete Setup with Error Handling       "
    echo "=================================================="
    echo ""
    echo "This script will install:"
    echo "  • Zsh shell"
    echo "  • Oh My Zsh framework"
    echo "  • Powerlevel10k theme"
    echo "  • zsh-autosuggestions plugin"
    echo "  • zsh-syntax-highlighting plugin"
    echo ""
    
    # Pre-flight checks
    check_root
    detect_os
    check_network
    check_disk_space
    backup_existing_config
    
    # Installation process
    update_packages
    install_prerequisites
    install_zsh
    install_oh_my_zsh
    install_powerlevel10k
    install_autosuggestions
    install_syntax_highlighting
    configure_zshrc
    install_fonts
    run_p10k_config
    
    # Verification and completion
    if verify_installation; then
        set_default_shell
        show_post_install_info
        success "Installation completed successfully!"
    else
        error "Installation completed with some issues."
        error "Please check the error messages above and try to resolve them."
        exit 1
    fi
}

# Error handling trap
handle_error() {
    local exit_code=$?
    echo ""
    error "Script failed with exit code: $exit_code"
    error "Check the error messages above for troubleshooting steps."
    
    if [[ -d "$BACKUP_DIR" ]]; then
        log "Your configurations have been backed up to: $BACKUP_DIR"
    fi
    
    echo ""
    log "Common troubleshooting steps:"
    echo "  • Check your internet connection"
    echo "  • Ensure you have sufficient disk space"
    echo "  • Verify you have necessary permissions"
    echo "  • Try running the script again"
    echo ""
    
    exit $exit_code
}

# Set trap for error handling
trap 'handle_error' EXIT

# Run main function
main "$@"

# Remove trap on successful completion
trap - EXIT
