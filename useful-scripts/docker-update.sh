#!/bin/bash

# Docker Update Script with Comprehensive Error Handling
# This script updates Docker to the latest version with user-friendly error messages

set -e  # Exit on any error (we'll handle them with trap)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
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

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root directly."
        error "It will use sudo when needed for specific commands."
        exit 1
    fi
}

# Function to check if user is in docker group
check_docker_group() {
    if groups $USER | grep -q '\bdocker\b'; then
        return 0
    else
        return 1
    fi
}

# Function to check network connectivity
check_network() {
    log "Checking network connectivity..."
    
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        error "No internet connection detected."
        error "Please check your network connection and try again."
        exit 1
    fi
    
    if ! curl -s --connect-timeout 10 https://download.docker.com >/dev/null; then
        error "Cannot reach Docker repository."
        error "Please check if your firewall or proxy is blocking the connection."
        exit 1
    fi
    
    success "Network connectivity confirmed."
}

# Function to check available disk space
check_disk_space() {
    log "Checking available disk space..."
    
    available_space=$(df / | awk 'NR==2 {print $4}')
    required_space=1048576  # 1GB in KB
    
    if [[ $available_space -lt $required_space ]]; then
        error "Insufficient disk space. At least 1GB free space is required."
        error "Available space: $(( available_space / 1024 ))MB"
        exit 1
    fi
    
    success "Sufficient disk space available."
}

# Function to backup current Docker version info
backup_docker_info() {
    log "Backing up current Docker information..."
    
    if command -v docker >/dev/null 2>&1; then
        docker --version > /tmp/docker_version_backup.txt 2>/dev/null || true
        success "Docker version info backed up to /tmp/docker_version_backup.txt"
    else
        log "Docker not currently installed."
    fi
}

# Function to update package lists
update_package_lists() {
    log "Updating package lists..."
    
    if ! sudo apt update 2>/dev/null; then
        error "Failed to update package lists."
        error "This could be due to:"
        error "  - Network connectivity issues"
        error "  - Invalid repository sources"
        error "  - Permission problems"
        error ""
        error "Try running: sudo apt update"
        error "Check the error messages for more details."
        exit 1
    fi
    
    success "Package lists updated successfully."
}

# Function to install prerequisites
install_prerequisites() {
    log "Installing prerequisites..."
    
    local packages="ca-certificates curl gnupg lsb-release"
    
    if ! sudo apt install -y $packages 2>/dev/null; then
        error "Failed to install prerequisite packages."
        error "Required packages: $packages"
        error "Please ensure you have sufficient permissions and disk space."
        exit 1
    fi
    
    success "Prerequisites installed successfully."
}

# Function to add Docker GPG key
add_docker_gpg_key() {
    log "Adding Docker's official GPG key..."
    
    # Create directory for apt keyrings
    sudo mkdir -p /etc/apt/keyrings
    
    # Remove old key if exists
    sudo rm -f /etc/apt/keyrings/docker.gpg
    
    if ! curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg; then
        error "Failed to add Docker's GPG key."
        error "This could be due to:"
        error "  - Network connectivity issues"
        error "  - Firewall blocking the connection"
        error "  - GPG key server unavailable"
        exit 1
    fi
    
    success "Docker GPG key added successfully."
}

# Function to add Docker repository
add_docker_repository() {
    log "Adding Docker repository..."
    
    local repo_line="deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    
    if ! echo "$repo_line" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null; then
        error "Failed to add Docker repository."
        error "Check if you have write permissions to /etc/apt/sources.list.d/"
        exit 1
    fi
    
    success "Docker repository added successfully."
}

# Function to install/update Docker
install_update_docker() {
    log "Installing/updating Docker packages..."
    
    # Update package lists again after adding repository
    if ! sudo apt update 2>/dev/null; then
        error "Failed to update package lists after adding Docker repository."
        exit 1
    fi
    
    local docker_packages="docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
    
    if ! sudo apt install -y $docker_packages; then
        error "Failed to install Docker packages."
        error "This could be due to:"
        error "  - Insufficient disk space"
        error "  - Package conflicts"
        error "  - Permission issues"
        error ""
        error "Try running the following commands manually:"
        error "  sudo apt --fix-broken install"
        error "  sudo apt install $docker_packages"
        exit 1
    fi
    
    success "Docker packages installed/updated successfully."
}

# Function to start and enable Docker service
setup_docker_service() {
    log "Setting up Docker service..."
    
    if ! sudo systemctl start docker; then
        error "Failed to start Docker service."
        error "Check system logs: sudo journalctl -u docker"
        exit 1
    fi
    
    if ! sudo systemctl enable docker; then
        warning "Failed to enable Docker service for auto-start."
        warning "Docker is running but won't start automatically on boot."
    fi
    
    success "Docker service started and enabled."
}

# Function to add user to docker group
setup_docker_group() {
    if ! check_docker_group; then
        log "Adding user to docker group..."
        
        if ! sudo usermod -aG docker $USER; then
            warning "Failed to add user to docker group."
            warning "You'll need to use 'sudo' with docker commands."
        else
            success "User added to docker group."
            warning "Please log out and log back in for group changes to take effect."
            warning "Or run: newgrp docker"
        fi
    else
        success "User is already in docker group."
    fi
}

# Function to verify Docker installation
verify_installation() {
    log "Verifying Docker installation..."
    
    # Check Docker version
    if ! docker --version >/dev/null 2>&1; then
        error "Docker command not available. Installation may have failed."
        exit 1
    fi
    
    local docker_version=$(docker --version)
    success "Docker installed: $docker_version"
    
    # Test Docker with hello-world (if user is in docker group or using sudo)
    log "Testing Docker functionality..."
    
    if check_docker_group; then
        if docker run --rm hello-world >/dev/null 2>&1; then
            success "Docker is working correctly!"
        else
            warning "Docker installed but test failed. You may need to restart your session."
        fi
    else
        if sudo docker run --rm hello-world >/dev/null 2>&1; then
            success "Docker is working correctly!"
            warning "Remember to add yourself to docker group to avoid using sudo."
        else
            warning "Docker installed but test failed."
        fi
    fi
}

# Function to show post-installation information
show_post_install_info() {
    echo ""
    success "Docker update completed successfully!"
    echo ""
    log "Post-installation information:"
    echo "  - Docker version: $(docker --version 2>/dev/null || sudo docker --version)"
    echo "  - Docker service status: $(sudo systemctl is-active docker)"
    echo "  - Docker enabled on boot: $(sudo systemctl is-enabled docker)"
    echo ""
    
    if ! check_docker_group; then
        warning "To use Docker without sudo, run these commands:"
        echo "  sudo usermod -aG docker $USER"
        echo "  newgrp docker"
        echo "  # Or log out and log back in"
        echo ""
    fi
    
    log "Useful Docker commands:"
    echo "  docker --version                 # Check Docker version"
    echo "  docker info                      # Show Docker system information"
    echo "  docker run hello-world           # Test Docker installation"
    echo "  docker ps                        # List running containers"
    echo "  docker images                    # List Docker images"
    echo ""
}

# Main execution function
main() {
    echo "=============================="
    echo "     Docker Update Script    "
    echo "=============================="
    echo ""
    
    # Pre-flight checks
    check_root
    check_network
    check_disk_space
    backup_docker_info
    
    # Update process
    update_package_lists
    install_prerequisites
    add_docker_gpg_key
    add_docker_repository
    install_update_docker
    setup_docker_service
    setup_docker_group
    verify_installation
    show_post_install_info
    
    success "All done! Docker has been updated to the latest version."
}

# Error handling trap
handle_error() {
    local exit_code=$?
    error "Script failed with exit code: $exit_code"
    error "Check the error messages above for troubleshooting steps."
    
    if [[ -f /tmp/docker_version_backup.txt ]]; then
        log "Previous Docker version info saved in: /tmp/docker_version_backup.txt"
    fi
    
    exit $exit_code
}

# Set trap for error handling
trap 'handle_error' ERR

# Run main function
main "$@"