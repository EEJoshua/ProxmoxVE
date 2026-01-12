#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: EEJoshua
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/rakshasa/rtorrent

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

# Relax GCC 14 strictness for older codebases (resolves xmlrpc-c detection issues)
export CFLAGS="-Wno-error=implicit-function-declaration -Wno-error=int-conversion -Wno-error=incompatible-pointer-types"
export CXXFLAGS="-Wno-error=implicit-function-declaration -Wno-error=int-conversion -Wno-error=incompatible-pointer-types"

msg_info "Installing Dependencies"
# Ensure non-free is enabled for unrar
if [[ -f /etc/apt/sources.list.d/debian.sources ]]; then
    sed -i -r 's/^Components: .*/& non-free non-free-firmware/g' /etc/apt/sources.list.d/debian.sources
fi
$STD apt-get update
$STD apt-get install -y \
  nginx \
  git \
  unzip \
  tmux \
  ffmpeg \
  mediainfo \
  sox \
  curl \
  dtach \
  build-essential \
  automake \
  libtool \
  pkg-config \
  libcurl4-openssl-dev \
  libncursesw5-dev \
  libsigc++-2.0-dev \
  zlib1g-dev \
  libssl-dev \
  subversion \
  libxml2-dev \
  autoconf-archive \
  python3 \
  python-is-python3 \
  python3-pip \
  irssi \
  libarchive-zip-perl \
  libnet-ssleay-perl \
  libhtml-parser-perl \
  libxml-libxml-perl \
  libdigest-sha-perl \
  libjson-perl \
  libjson-xs-perl \
  libxml-libxslt-perl \
  unrar
msg_ok "Installed Dependencies"

msg_info "Setting up PHP"
PHP_VERSION="8.3"
PHP_FPM="YES" PHP_MODULE="curl,mbstring,cli,xml,zip" setup_php
msg_ok "Setup PHP"

msg_info "Installing Python Libraries"
pip3 install cloudscraper --break-system-packages >/dev/null 2>&1
msg_ok "Installed Python Libraries"

msg_info "Compiling XML-RPC-C"
# Install advanced XML-RPC-C for rTorrent (required for i8 support)
svn checkout -q https://svn.code.sf.net/p/xmlrpc-c/code/advanced xmlrpc-c
cd xmlrpc-c || exit
# Configure
./configure --disable-cplusplus >/dev/null

# FORCE internal-check for i8 (int64) support since configure fails on modern GCC
# MUST insert BEFORE the last line (#endif) otherwise it is ignored
sed -i '$i #define HAVE_INT64 1' xmlrpc_config.h

# Build with suppression flags for make only
make -j$(nproc) CXXFLAGS="-w" CFLAGS="-w" ARFLAGS="rc" >/dev/null
make install >/dev/null
ldconfig
cd ..
rm -rf xmlrpc-c
msg_ok "Compiled XML-RPC-C"

msg_info "Compiling LibTorrent (Rakshasa)"
git clone -q https://github.com/rakshasa/libtorrent.git /opt/libtorrent
cd /opt/libtorrent || exit
autoreconf -fiv >/dev/null 2>&1
./configure --disable-debug --enable-aligned >/dev/null
make -j$(nproc) CXXFLAGS="-w" CFLAGS="-w" >/dev/null
make install >/dev/null
ldconfig
msg_ok "Compiled LibTorrent"

msg_info "Compiling rTorrent (Rakshasa)"
git clone -q https://github.com/rakshasa/rtorrent.git /opt/rtorrent-src
cd /opt/rtorrent-src || exit
autoreconf -fiv >/dev/null 2>&1
./configure --with-xmlrpc-c --disable-debug >/dev/null
make -j$(nproc) CXXFLAGS="-w" CFLAGS="-w" >/dev/null
make install >/dev/null
msg_ok "Compiled rTorrent"

msg_info "Compiling dumptorrent"
git clone -q https://github.com/tomcdj71/dumptorrent.git /opt/dumptorrent
cd /opt/dumptorrent || exit
# Compile manually as Makefile expects files in root but they are in src/
gcc -Wall -o dumptorrent src/*.c -I include >/dev/null 2>&1
cp dumptorrent /usr/local/bin/
chmod +x /usr/local/bin/dumptorrent
cd ..
rm -rf /opt/dumptorrent
msg_ok "Compiled dumptorrent"

msg_info "Configuring rTorrent User"
useradd -u 1000 -U -d /home/rtorrent -s /bin/bash rtorrent
mkdir -p /home/rtorrent/{.session,download,watch}
chown -R rtorrent:rtorrent /home/rtorrent
msg_ok "Configured rTorrent User"

msg_info "Configuring rTorrent Service"
cat <<EOF >/etc/systemd/system/rtorrent.service
[Unit]
Description=rTorrent
After=network.target

[Service]
Type=forking
User=rtorrent
Group=rtorrent
ExecStart=/usr/bin/tmux new-session -s rtorrent -n rtorrent -d '/usr/local/bin/rtorrent'
ExecStop=/usr/bin/tmux kill-session -t rtorrent
WorkingDirectory=/home/rtorrent
RemainAfterExit=yes
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now rtorrent
msg_ok "Created rTorrent Service"

msg_info "Configuring autodl-irssi"
# Download autodl-irssi (full package)
mkdir -p /home/rtorrent/.irssi/scripts/autoload
curl -sL https://github.com/autodl-community/autodl-irssi/archive/master.zip -o /tmp/autodl.zip
unzip -o /tmp/autodl.zip -d /tmp >/dev/null 2>&1
cp -r /tmp/autodl-irssi-master/AutodlIrssi /home/rtorrent/.irssi/scripts/
cp /tmp/autodl-irssi-master/autodl-irssi.pl /home/rtorrent/.irssi/scripts/
ln -sf /home/rtorrent/.irssi/scripts/autodl-irssi.pl /home/rtorrent/.irssi/scripts/autoload/autodl-irssi.pl
rm -f /tmp/autodl.zip && rm -rf /tmp/autodl-irssi-master
# Create config file
mkdir -p /home/rtorrent/.autodl
touch /home/rtorrent/.autodl/autodl.cfg
# Generate password
AUTODL_PORT="51421"
AUTODL_PASS=$(python3 -c "import secrets,string; print(''.join(secrets.choice(string.ascii_letters + string.digits) for i in range(20)))")
echo "[options]" > /home/rtorrent/.autodl/autodl.cfg
echo "gui-server-port = $AUTODL_PORT" >> /home/rtorrent/.autodl/autodl.cfg
echo "gui-server-password = $AUTODL_PASS" >> /home/rtorrent/.autodl/autodl.cfg

chown -R rtorrent:rtorrent /home/rtorrent/.irssi /home/rtorrent/.autodl

# Create service
cat <<EOF >/etc/systemd/system/autodl-irssi.service
[Unit]
Description=autodl-irssi (irssi)
After=network.target

[Service]
Type=forking
User=rtorrent
Group=rtorrent
ExecStart=/usr/bin/tmux new-session -s autodl -n irssi -d '/usr/bin/irssi'
ExecStop=/usr/bin/tmux kill-session -t autodl
WorkingDirectory=/home/rtorrent
RemainAfterExit=yes
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now autodl-irssi
msg_ok "Configured autodl-irssi"

msg_info "Installing ruTorrent"
mkdir -p /var/www
git clone -q https://github.com/Novik/ruTorrent.git /var/www/rutorrent
# Patch settings.php to disable false positive XML-RPC version check (issue with to_kb method)
sed -i 's/public \$badXMLRPCVersion = true;/public \$badXMLRPCVersion = false;/' /var/www/rutorrent/php/settings.php
chown -R www-data:www-data /var/www/rutorrent
chmod -R 775 /var/www/rutorrent
msg_ok "Installed ruTorrent"

# Install autodl-irssi plugin
msg_info "Installing autodl-irssi Plugin"
git clone -q https://github.com/autodl-community/autodl-rutorrent.git /var/www/rutorrent/plugins/autodl-irssi
cp /var/www/rutorrent/plugins/autodl-irssi/_conf.php /var/www/rutorrent/plugins/autodl-irssi/conf.php
sed -i "s/\$autodlPort = 0;/\$autodlPort = \$AUTODL_PORT;/" /var/www/rutorrent/plugins/autodl-irssi/conf.php
sed -i "s/\$autodlPassword = \"\";/\$autodlPassword = \"\$AUTODL_PASS\";/" /var/www/rutorrent/plugins/autodl-irssi/conf.php
chown -R www-data:www-data /var/www/rutorrent/plugins/autodl-irssi
msg_ok "Installed autodl-irssi Plugin"

msg_info "Configuring Nginx"
rm -f /etc/nginx/sites-enabled/default

cat <<EOF >/etc/nginx/sites-available/rutorrent
server {
    listen 80;
    server_name _;
    root /var/www/rutorrent;
    index index.html index.php;

    access_log /var/log/nginx/rutorrent-access.log;
    error_log /var/log/nginx/rutorrent-error.log;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;
    }

    location /RPC2 {
        include scgi_params;
        scgi_pass 127.0.0.1:5000;
    }
}
EOF
ln -s /etc/nginx/sites-available/rutorrent /etc/nginx/sites-enabled/rutorrent

# Configure rTorrent .rtorrent.rc with RPC
cat <<EOF >/home/rtorrent/.rtorrent.rc
# Global settings
directory.default.set = /home/rtorrent/download
session.path.set = /home/rtorrent/.session
protocol.encryption.set = allow_incoming,try_outgoing,enable_retry

# RPC for ruTorrent
network.scgi.open_port = 127.0.0.1:5000
encoding.add = UTF-8

# Watch directory
schedule2 = watch_directory,5,5,load.start=/home/rtorrent/watch/*.torrent
EOF
chown rtorrent:rtorrent /home/rtorrent/.rtorrent.rc

# Restart services
systemctl restart rtorrent
systemctl restart nginx
systemctl restart php"${PHP_VERSION}"-fpm
msg_ok "Configured Web Server"

motd_ssh
customize
cleanup_lxc
