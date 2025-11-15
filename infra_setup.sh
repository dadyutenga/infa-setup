#!/bin/bash
set -e

echo "🚀 Starting full infra setup..."

echo "🔧 Updating system..."
sudo apt update -y
sudo apt upgrade -y

echo "📦 Installing prerequisites..."
sudo apt install -y ca-certificates curl gnupg lsb-release software-properties-common ufw

###############################################
# Remove Apache if installed (avoid port 80 conflict)
###############################################
echo "🛑 Checking for Apache..."
if systemctl is-active --quiet apache2; then
    echo "⚠️ Apache is running. Stopping and removing it..."
    sudo systemctl stop apache2
    sudo systemctl disable apache2
    sudo apt purge -y apache2 apache2-utils apache2-bin apache2.2-common
    sudo apt autoremove -y
else
    echo "✅ Apache is not installed, skipping."
fi

###############################################
# Install Nginx (Native)
###############################################
echo "📦 Installing Nginx..."
sudo apt install -y nginx
sudo systemctl enable nginx
sudo systemctl start nginx

###############################################
# Install Docker Properly (Engine + Compose Plugin)
###############################################
echo "🐳 Adding Docker GPG key..."
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "🔗 Adding Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "🔄 Updating package lists..."
sudo apt update -y

echo "🐳 Installing Docker Engine + CLI + Buildx + Compose Plugin..."
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "👤 Adding user '$USER' to Docker group..."
sudo usermod -aG docker $USER

###############################################
# Install MySQL (Native)
###############################################
echo "🛢️ Installing MySQL Server..."
sudo apt install -y mysql-server
sudo systemctl enable mysql
sudo systemctl start mysql

###############################################
# Install PostgreSQL (Native)
###############################################
echo "🐘 Installing PostgreSQL..."
sudo apt install -y postgresql postgresql-contrib
sudo systemctl enable postgresql
sudo systemctl start postgresql

###############################################
# Firewall Rules (optional but smart)
###############################################
echo "🔥 Setting recommended firewall rules..."
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

echo "🎉 INFRA SETUP COMPLETE!"
echo "🔁 Logout & login again for Docker group changes."
