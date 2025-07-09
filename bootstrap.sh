#!/bin/bash
set -e

# Prompt for variables with defaults
read -p "Enter app name [civil]: " APP_NAME
APP_NAME=${APP_NAME:-civil}

read -p "Enter system username [robert]: " USERNAME
USERNAME=${USERNAME:-robert}

read -p "Enter timezone [America/Denver]: " TIMEZONE
TIMEZONE=${TIMEZONE:-America/Denver}

read -p "Set Git user.name (optional): " GIT_NAME
read -p "Set Git user.email (optional): " GIT_EMAIL

WEB_ROOT="/var/www/$APP_NAME"

echo "Updating system..."
apt update && apt upgrade -y

echo "Creating non-root user ($USERNAME)..."
adduser "$USERNAME"
usermod -aG sudo "$USERNAME"

echo "Setting timezone to $TIMEZONE..."
timedatectl set-timezone "$TIMEZONE"

echo "Installing essentials..."
apt install -y \
  sudo \
  curl \
  vim \
  git \
  unzip \
  logrotate \
  ufw \
  fail2ban \
  nginx \
  certbot \
  python3-certbot-nginx \
  ca-certificates \
  gnupg \
  lsb-release \
  htop \
  bash-completion

echo "Configuring firewall..."
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw --force enable

echo "Enabling fail2ban..."
systemctl enable fail2ban
systemctl start fail2ban

echo "Installing Node.js LTS..."
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt install -y nodejs

echo "Verifying installs..."
node -v
npm -v
nginx -v
certbot --version

echo "Ensuring nginx and firewall start on boot..."
systemctl enable nginx
systemctl enable ufw

echo "Creating web root at $WEB_ROOT..."
mkdir -p "$WEB_ROOT"
chown -R www-data:www-data "$WEB_ROOT"

echo "Creating fallback 404 page..."
cat >"$WEB_ROOT/index.html" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>404 Not Found</title>
  <style>
    body { font-family: sans-serif; background: #fefefe; text-align: center; padding: 100px; color: #444; }
    h1 { font-size: 3em; margin-bottom: 0.2em; }
    p { font-size: 1.2em; }
  </style>
</head>
<body>
  <h1>404</h1>
  <p>The page you're looking for doesn't exist.</p>
</body>
</html>
EOF

echo "Creating default .vimrc for $USERNAME..."
cat >/home/$USERNAME/.vimrc <<EOF
set nocompatible
set number
set relativenumber
set tabstop=2
set shiftwidth=2
set expandtab
set autoindent
set smartindent
set wrap
set backspace=indent,eol,start
syntax on
set hlsearch
set incsearch
set ignorecase
set smartcase
set mouse=a
set clipboard=unnamed
EOF

chown $USERNAME:$USERNAME /home/$USERNAME/.vimrc
cp /home/$USERNAME/.vimrc /root/.vimrc

echo "Setting up .bashrc for $USERNAME..."
cat >>/home/$USERNAME/.bashrc <<'EOF'

# Custom Bash prompt and aliases
export PS1='\u@\h:\w\$ '
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias vim='vim -u ~/.vimrc'

# Persistent command history
export HISTFILESIZE=10000
export HISTSIZE=10000
export PROMPT_COMMAND='history -a'
EOF

chown $USERNAME:$USERNAME /home/$USERNAME/.bashrc

echo "Ensuring .bashrc is sourced in .profile..."
PROFILE_PATH="/home/$USERNAME/.profile"
if ! grep -q '.bashrc' "$PROFILE_PATH"; then
  echo '[[ -f ~/.bashrc ]] && . ~/.bashrc' >>"$PROFILE_PATH"
fi
chown $USERNAME:$USERNAME "$PROFILE_PATH"

echo "Copying root's SSH key to $USERNAME..."
mkdir -p /home/$USERNAME/.ssh
cp /root/.ssh/authorized_keys /home/$USERNAME/.ssh/
chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh
chmod 700 /home/$USERNAME/.ssh
chmod 600 /home/$USERNAME/.ssh/authorized_keys

echo "Setting enhanced dynamic MOTD..."

cat >/etc/profile.d/motd.sh <<'EOF'
#!/bin/bash
APP_NAME="__APP_NAME__"
HOSTNAME=$(hostname)
UPTIME=$(uptime -p)
LOAD=$(uptime | awk -F'load average:' '{ print $2 }' | xargs)
USER=$(whoami)
IP=$(hostname -I | awk '{print $1}')
DISK=$(df -h / | awk 'NR==2 {print $5 " used on " $1}')

NGINX_STATUS=$(systemctl is-active nginx 2>/dev/null)
CERTBOT_TIMER=$(systemctl is-active certbot.timer 2>/dev/null)

echo
echo "╔════════════════════════════════════════════════════════╗"
echo "║  Welcome to $APP_NAME ($HOSTNAME)"
echo "║  Managed by UpHill Solutions"
echo "║"
echo "║  User:    $USER"
echo "║  IP:      $IP"
echo "║  Uptime:  $UPTIME"
echo "║  Load:    $LOAD"
echo "║  Disk:    $DISK"
echo "║"
echo "║  NGINX:   ${NGINX_STATUS^^}     Certbot Timer: ${CERTBOT_TIMER^^}"
echo "╚════════════════════════════════════════════════════════╝"
echo
EOF

# Replace placeholder with real app name
sed -i "s/__APP_NAME__/$APP_NAME/" /etc/profile.d/motd.sh
chmod +x /etc/profile.d/motd.sh

chmod +x /etc/profile.d/motd.sh

if [[ -n "$GIT_NAME" && -n "$GIT_EMAIL" ]]; then
  echo "Configuring Git identity..."
  git config --global user.name "$GIT_NAME"
  git config --global user.email "$GIT_EMAIL"
fi

echo "Bootstrap complete. Server is ready."
