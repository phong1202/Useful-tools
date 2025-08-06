#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "Installing Microsoft Edge on Ubuntu..."

# Download Microsoft GPG key
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg

# Move the key and add it to the trusted keyring
sudo install -o root -g root -m 644 microsoft.gpg /usr/share/keyrings/
rm microsoft.gpg

# Add the Microsoft Edge repository
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/edge stable main" | sudo tee /etc/apt/sources.list.d/microsoft-edge.list

# Update package list and install Edge
sudo apt update
sudo apt install -y microsoft-edge-stable

echo "Microsoft Edge has been installed successfully!"
