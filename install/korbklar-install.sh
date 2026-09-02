#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: Sebastian Seifert (SebSeifert)
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/lesecuritae/KorbKlar

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt install -y chromium
msg_ok "Installed Dependencies"

setup_uv

fetch_and_deploy_gh_release "korbklar" "lesecuritae/KorbKlar" "tarball"

msg_info "Setting up Python Environment"
cd /opt/korbklar
$STD uv venv --python 3.13 /opt/korbklar/.venv
$STD uv pip install --python /opt/korbklar/.venv /opt/korbklar
msg_ok "Set up Python Environment"

msg_info "Configuring KorbKlar"
mkdir -p /opt/korbklar_data
cat <<EOF >/opt/korbklar.env
# Runtime data lives outside /opt/korbklar so an update never touches it.
SUPERMARKT_DATA_DIR=/opt/korbklar_data
SUPERMARKT_CACHE_DB=/opt/korbklar_data/supermarkt-cache.sqlite3
SUPERMARKT_SIGNING_SECRET_FILE=/opt/korbklar_data/.signing-secret
SUPERMARKT_ACCESS_TOKENS_FILE=/opt/korbklar_data/access-tokens.json
SUPERMARKT_IMAGE_CACHE_DIR=/opt/korbklar_data/supermarkt-images
SUPERMARKT_KAUFLAND_CACHE_DIR=/opt/korbklar_data/kaufland
SUPERMARKT_REWE_CACHE_DIR=/opt/korbklar_data/rewe
# Headless browser for the retailer pages that need JavaScript (ALDI Sued, Kaufland, REWE).
SUPERMARKT_CHROMIUM=/usr/bin/chromium
# Optional bearer token for the REST API and the Android app pairing. Empty keeps them open.
SUPERMARKT_API_KEY=${var_api_key:-}
# Optional instance-wide defaults for the start page, e.g. 26123 and REWE,Lidl,Kaufland.
SUPERMARKT_DEFAULT_POSTAL_CODE=${var_postal_code:-}
SUPERMARKT_DEFAULT_RETAILERS=${var_retailers:-}
EOF
chmod 600 /opt/korbklar.env
msg_ok "Configured KorbKlar"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/korbklar.service
[Unit]
Description=KorbKlar
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/korbklar
EnvironmentFile=/opt/korbklar.env
ExecStart=/opt/korbklar/.venv/bin/uvicorn supermarkt.asgi:app --host 0.0.0.0 --port 8000
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now korbklar
msg_ok "Created Service"

motd_ssh
customize
cleanup_lxc
