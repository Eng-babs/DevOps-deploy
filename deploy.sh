#!/bin/bash
# ==================================================
# 🚀 Hybrid Automated Deployment Script
# Author: Eng-babs (HNG DevOps Stage 1)
# Combines rsync + docker + optional NGINX
# ==================================================

set -e  # Exit on error

# === Step 1: Collect Parameters ===
echo ""
echo "=========================================="
echo "🚀 Starting Hybrid Automated Deployment"
echo "=========================================="
echo ""

read -p "Enter your Git repository URL: " GIT_URL
read -p "Enter your Personal Access Token (leave blank if public): " PAT
read -p "Enter branch name (default: main): " BRANCH
read -p "Enter remote server username: " SSH_USER
read -p "Enter remote server IP address: " SERVER_IP
read -p "Enter SSH private key path (e.g., ~/.ssh/key.pem): " SSH_KEY
# Expand tilde to full path
SSH_KEY="${SSH_KEY/#\~/$HOME}"
read -p "Enter app internal port (e.g., 3000): " APP_PORT
read -p "Configure NGINX reverse proxy? (yes/no): " CONFIGURE_NGINX

BRANCH=${BRANCH:-main}

# === Step 2: Clone or Update Repo Locally ===
echo ""
echo "📦 Cloning or updating repository..."
REPO_DIR=$(basename "$GIT_URL" .git)

if [[ -n "$PAT" ]]; then
  AUTH_URL=$(echo "$GIT_URL" | sed "s#https://#https://$PAT@#")
else
  AUTH_URL=$GIT_URL
fi

if [ -d "$REPO_DIR" ]; then
  cd "$REPO_DIR"
  git fetch origin "$BRANCH"
  git checkout "$BRANCH"
  git pull origin "$BRANCH"
else
  git clone -b "$BRANCH" "$AUTH_URL"
  cd "$REPO_DIR"
fi

echo "✅ Repository ready in $(pwd)"

# === Step 3: SSH Connectivity Check ===
echo ""
echo "🔐 Testing SSH connection..."
echo "Looking for key at: $SSH_KEY" # Add this line for debugging
if [ ! -f "$SSH_KEY" ]; then
  echo "❌ SSH key not found at: $SSH_KEY"
  exit 1
fi

ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@$SERVER_IP" "echo '✅ SSH connection successful on $(hostname)'" || {
  echo "❌ SSH connection failed! Check username, IP, or key."
  exit 1
}


# === Step 4: Transfer Files to Remote Server ===
# === Step 4: Transfer Files to Remote Server ===
echo ""
echo "📤 Copying project files to remote server..."
echo "========== DEBUG INFO =========="
echo "SSH_USER = [$SSH_USER]"
echo "SERVER_IP = [$SERVER_IP]"
echo "SSH_KEY = [$SSH_KEY]"
echo "Full destination = [$SSH_USER@$SERVER_IP:/home/$SSH_USER/app_deploy]"
echo "==============================="

# Create remote directory first
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@$SERVER_IP" \
  "mkdir -p /home/$SSH_USER/app_deploy"

# Use tar piped through SSH instead of rsync
echo "Transferring files via tar+ssh..."
tar czf - --exclude='.git' --exclude='deploy_*.log' --exclude='ssh_wrapper_temp.sh' . | \
  ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@$SERVER_IP" \
  "cd /home/$SSH_USER/app_deploy && tar xzf -"

echo "✅ Files copied successfully!"


# === Step 5: Deploy Docker Containers ===
echo ""
echo "🐳 Deploying Dockerized application on remote server..."

ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@$SERVER_IP" bash <<EOF
set -e
cd ~/app_deploy

echo "⚙️ Building and running Docker containers..."

if [ -f docker-compose.yml ]; then
  echo "📦 Using docker-compose..."
  sudo docker-compose down || true
  sudo docker-compose up -d --build
else
  APP_NAME=\$(basename "\$(pwd)")
  echo "🐳 Building and running single container..."
  sudo docker stop "\$APP_NAME" || true
  sudo docker rm "\$APP_NAME" || true
  sudo docker build -t "\$APP_NAME" .
  sudo docker run -d -p $APP_PORT:$APP_PORT --name "\$APP_NAME" "\$APP_NAME"
fi

echo "✅ Docker deployment successful!"
sudo docker ps
EOF

# === Step 6: Optional NGINX Reverse Proxy Setup ===
if [[ "$CONFIGURE_NGINX" =~ ^(yes|y|Y)$ ]]; then
  echo ""
  echo "🌐 Configuring NGINX reverse proxy on remote server..."
  ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@$SERVER_IP" bash <<EOF
  set -e
  sudo apt-get update -y
  sudo apt-get install -y nginx

  echo "🛠 Creating NGINX config for app on port $APP_PORT ..."
  sudo bash -c "cat > /etc/nginx/sites-available/app.conf" <<NGINXCONF
server {
    listen 80;
    server_name _;
    location / {
        proxy_pass http://localhost:$APP_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
NGINXCONF

  sudo ln -sf /etc/nginx/sites-available/app.conf /etc/nginx/sites-enabled/app.conf
  sudo nginx -t && sudo systemctl reload nginx
  echo "✅ NGINX configured successfully."
EOF
else
  echo "🛑 Skipping NGINX setup as requested."
fi

# === Step 7: Completion ===
echo ""
echo "🎉 Deployment completed successfully!"
echo "🌍 Access your app at: http://$SERVER_IP"
echo "==========================================="


# --- Step 10: Cleanup flag ---
if [[ "$1" == "--cleanup" ]]; then
  echo "🧹 Cleaning up deployed resources..."
  ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@$SERVER_IP" << EOF
    set -e
    echo "🧽 Stopping and removing containers..."
    sudo docker stop app_deploy || true
    sudo docker rm app_deploy || true

    echo "🗑 Removing deployment directory and NGINX config..."
    sudo rm -rf ~/app_deploy
    sudo rm -f /etc/nginx/sites-enabled/app.conf

    echo "🔁 Reloading NGINX..."
    sudo systemctl reload nginx
  EOF

  echo "✅ Cleanup complete!"
  exit 0
fi




---

