#!/usr/bin/env bash
# Swizzin Seedbox – Proxmox Helper‑Script (CT)
source <(curl -fsSL https://raw.githubusercontent.com/EEJoshua/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021‑2025 tteck | MIT

APP="Swizzin"                        # Display name in the wizard
var_tags="${var_tags:-seedbox}"      # Tag shown on helper‑scripts.com
var_cpu="${var_cpu:-2}"              # Default vCPU cores
var_ram="${var_ram:-4096}"           # Default RAM (MiB)
var_disk="${var_disk:-20}"           # Default disk (GiB)
var_os="${var_os:-debian}"           # Base template family
var_version="${var_version:-12}"     # Template release (Bookworm)
var_unprivileged="${var_unprivileged:-1}"   # Unprivileged container

header_info   "$APP"
variables     # sets NSAPP & var_install automatically (=> swizzin-install)
color
catch_errors

function update_script() {
    header_info
    check_container_storage
    check_container_resources
    if ! sudo command -v box >/dev/null 2>&1; then
        msg_error "No ${APP} installation found!"
        exit
    fi
    msg_info "Running 'box update' inside the container"
    box update
    msg_ok "Update finished"
    exit
}

start               # shell / PVE sanity checks
build_container     # launches the interactive wizard
description         # writes a nice HTML note into the CT config

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW}Attach with:${CL}  pct console ${CTID}"
echo -e "${INFO}${YW}Then complete Swizzin’s menu, or run:${CL}  box"
