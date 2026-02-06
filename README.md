[![Netlify Status](https://api.netlify.com/api/v1/badges/703975f3-d832-4bd3-8051-d6ca4f375a5a/deploy-status)](https://app.netlify.com/sites/serene-lollipop-e973ed/deploys)
# My website!
Heey

# First Time Setup

## Prerequisites

You need Nix, devenv, and direnv installed on your system.

### Linux Setup

```bash
# 1. Install Nix (multi-user installation recommended)
sh <(curl -L https://nixos.org/nix/install) --daemon

# 2. Enable nix-command and flakes
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf

# 3. Install direnv (if not already installed)
# For Ubuntu/Debian:
sudo apt install direnv

# For Arch Linux:
sudo pacman -S direnv

# For other distros, check: https://direnv.net/docs/installation.html

# 4. Add direnv hook to your shell
# For bash, add to ~/.bashrc:
echo 'eval "$(direnv hook bash)"' >> ~/.bashrc

# For zsh, add to ~/.zshrc:
echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc

# Then reload your shell
source ~/.bashrc  # or source ~/.zshrc

# 5. Install devenv
nix profile install --accept-flake-config nixpkgs#devenv
```

### WSL (Windows Subsystem for Linux) Setup

```bash
# 1. Install Nix (use single-user installation for WSL)
sh <(curl -L https://nixos.org/nix/install) --no-daemon

# 2. Enable nix-command and flakes
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf

# 3. Install direnv
sudo apt install direnv

# 4. Add direnv hook to your shell
# For bash, add to ~/.bashrc:
echo 'eval "$(direnv hook bash)"' >> ~/.bashrc

# For zsh, add to ~/.zshrc:
echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc

# Then reload your shell
source ~/.bashrc  # or source ~/.zshrc

# 5. Install devenv
nix profile install --accept-flake-config nixpkgs#devenv
```

## Getting Started

Once you have the prerequisites installed:

```bash
# Clone the repository
git clone <your-repo-url>
cd website

# Allow direnv (first time only)
direnv allow

# The environment will automatically:
# - Build the development shell
# - Install bun
# - Install all project dependencies
# This may take a few minutes on first run
```

# Developing

The development environment is automatically loaded when you enter the directory (thanks to direnv + devenv):

```sh
cd /path/to/website
# Environment is automatically loaded!
```

## Available Commands

- `bun run start` - Start development server with live reload
- `bun run build` - Create a production build
- `bun run clean` - Clean the dist folder

Or use the devenv scripts:
- `build` - Alias for `bun run build`
- `clean` - Alias for `bun run clean`

## Package Management

This project uses [Bun](https://bun.sh/) as the package manager instead of pnpm or npm.
