#!/usr/bin/env bash
set -euo pipefail

echo "Installing development tools..."
sudo apt-get update -y

echo "Checking Docker..."
if ! command -v docker >/dev/null 2>&1 || ! docker --version 2>&1 | grep -q "^Docker version "; then
  echo "Installing Docker (docker.io)..."
  sudo apt-get install -y docker.io
else
  echo "Docker already installed: $(docker --version | awk '{print $1,$2,$3}')"
fi

echo "Ensuring user is in 'docker' group..."
if id -nG "$USER" | grep -qw docker; then
  echo "User already in 'docker' group."
else
  sudo usermod -aG docker "$USER"
  echo "Added $USER to 'docker' group. Open a new shell or run: newgrp docker"
fi

echo "Checking Docker Compose..."
if command -v docker-compose >/dev/null 2>&1 && docker-compose --version 2>&1 | grep -q "^docker-compose version "; then
  echo "Docker Compose already installed: $(docker-compose --version | awk '{print $1,$2,$3}')"
else
  echo "Installing Docker Compose (classic)..."
  sudo apt-get install -y docker-compose
fi

echo "Installing Python, pip, and venv..."
sudo apt-get install -y python3 python3-pip python3-venv
PY_VER="$(python3 --version | awk '{print $2}')"
if dpkg --compare-versions "$PY_VER" ge 3.9; then
  echo "Python $PY_VER OK (>= 3.9)."
else
  echo "Error: Python >= 3.9 required, found $PY_VER"
  exit 1
fi

PROJECT_DIR="$(pwd)"
echo "Ensuring virtual environment in $PROJECT_DIR/.venv..."
if [ -d "$PROJECT_DIR/.venv" ]; then
  echo ".venv already exists."
else
  python3 -m venv "$PROJECT_DIR/.venv"
  echo "Virtual environment created at $PROJECT_DIR/.venv"
fi

echo "Installing Django in .venv..."
. "$PROJECT_DIR/.venv/bin/activate"
pip install --upgrade pip
pip install django
DJ_VER="$(python -m django --version)"
deactivate
echo "Django installed in $PROJECT_DIR/.venv: $DJ_VER"

echo "All development tools installed."
echo "Activate your venv with: source .venv/bin/activate"

