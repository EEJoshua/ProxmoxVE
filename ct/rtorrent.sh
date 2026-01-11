#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/EEJoshua/ProxmoxVE/feature/rtorrent-lxc/misc/build.func)
# Copyright (c) 2021-2026 community-scripts ORG
# Author: EEJoshua
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/rakshasa/rtorrent

APP="rTorrent"
var_tags="${var_tags:-torrent}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-8}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources
  if [[ ! -f /etc/systemd/system/rtorrent.service ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  
  msg_info "Updating rTorrent (Source Compile)"
  systemctl stop rtorrent
  
  # Re-compile libtorrent
  if [[ -d /opt/libtorrent ]]; then
      cd /opt/libtorrent || exit
      git pull
      ./autogen.sh
      ./configure --disable-debug --enable-aligned
      make -j$(nproc)
      make install
      ldconfig
      msg_ok "Updated libtorrent"
  fi

  # Re-compile rTorrent
  if [[ -d /opt/rtorrent-src ]]; then
      cd /opt/rtorrent-src || exit
      git pull
      ./autogen.sh
      ./configure --with-xmlrpc-c --disable-debug
      make -j$(nproc)
      make install
      msg_ok "Updated rTorrent"
  fi
  
  msg_info "Updating ruTorrent"
  if [[ -d /var/www/rutorrent ]]; then
      cd /var/www/rutorrent || exit
      git pull
      chown -R www-data:www-data /var/www/rutorrent
      msg_ok "Updated ruTorrent"
  fi
  
  systemctl start rtorrent
  msg_ok "Updated successfully!"
  exit
}

start
build_container
description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access ruTorrent using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}${CL}"
