#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Main script starts here
DESIREDVER=${1-1100}
echo "Building for $DESIREDVER . To use another PS4 Firmware Version, execute this script as so: $0 <version>"

# Step 1: Check and install Homebrew if needed
if ! command_exists brew; then
    echo "Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add homebrew to PATH for Apple Silicon Macs
    if [[ $(uname -m) == "arm64" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
else
    echo "Homebrew is already installed."
fi

# Step 2: Check and install Docker if needed
if ! command_exists docker; then
    echo "Docker not found. Installing Docker via Homebrew..."
    brew install --cask docker
    echo "Docker installation completed."
else
    echo "Docker is already installed."
fi

# Step 3: Start Docker Desktop and wait for it to be ready
echo "Starting Docker Desktop..."
open -a Docker

echo "Waiting for Docker to be ready..."
while ! docker info >/dev/null 2>&1; do
    sleep 2
    echo -n "."
done
echo ""
echo "Docker is ready!"

# Step 4: Proceed with the build
echo "Starting PPPwn build process..."
pwd=$(pwd)
docker build --build-arg="PS4FWVER=$DESIREDVER" -t pppwn-docker . --platform linux/amd64
docker run -v "$pwd:/host" pppwn-docker
mv stage1.bin stage1/
mv stage2.bin stage2/

# Check if build files were created
if [[ -f "stage1/stage1.bin" && -f "stage2/stage2.bin" ]]; then
    echo "✅ Build completed successfully!"
    echo "Generated files:"
    echo "  - $(pwd)/stage1/stage1.bin"
    echo "  - $(pwd)/stage2/stage2.bin"
    
    # Ask user if they want to remove Docker
    echo ""
    echo "Docker was used for building. Would you like to remove Docker to free up space?"
    read -p "Remove Docker? (y/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Stopping Docker Desktop..."
        pkill -f "Docker Desktop" 2>/dev/null || true
        echo "Removing Docker..."
        brew uninstall --cask docker
        echo "Docker has been removed."
    else
        echo "Docker will remain installed."
    fi
else
    echo "❌ Build failed - stage files not found!"
    echo "Missing files:"
    [[ ! -f "stage1/stage1.bin" ]] && echo "  - $(pwd)/stage1/stage1.bin"
    [[ ! -f "stage2/stage2.bin" ]] && echo "  - $(pwd)/stage2/stage2.bin"
    exit 1
fi