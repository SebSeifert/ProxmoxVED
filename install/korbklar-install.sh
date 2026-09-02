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
# KorbKlar configuration. Same variables as .env.example in the upstream
# repository, with the paths of this container. Empty values mean the
# built-in default. Restart with: systemctl restart korbklar

# Optional instance-wide defaults for the start page, e.g. 26123 and
# REWE,Lidl,Kaufland,dm. Personal browser values take precedence.
SUPERMARKT_DEFAULT_POSTAL_CODE=${var_postal_code:-}
SUPERMARKT_DEFAULT_RETAILERS=${var_retailers:-}

# Optional bearer token for the REST API and the Android app pairing.
# Empty keeps them open; the browser interface has no login either way.
SUPERMARKT_API_KEY=${var_api_key:-}

# Runtime data. Lives outside /opt/korbklar so an update never touches it.
SUPERMARKT_DATA_DIR=/opt/korbklar_data
SUPERMARKT_CACHE_DB=/opt/korbklar_data/supermarkt-cache.sqlite3
SUPERMARKT_SIGNING_SECRET_FILE=/opt/korbklar_data/.signing-secret
SUPERMARKT_ACCESS_TOKENS_FILE=/opt/korbklar_data/access-tokens.json
# Leave empty so a persistent key is generated on first start.
SUPERMARKT_SIGNING_SECRET=
SUPERMARKT_IMAGE_CACHE_DIR=/opt/korbklar_data/supermarkt-images
SUPERMARKT_KAUFLAND_CACHE_DIR=/opt/korbklar_data/kaufland
SUPERMARKT_REWE_CACHE_DIR=/opt/korbklar_data/rewe

# Offer snapshot cache.
SUPERMARKT_CACHE_TTL_MINUTES=30
SUPERMARKT_CACHE_MAX_SNAPSHOTS=100
SUPERMARKT_RESULT_RETENTION_HOURS=168

# Network and parallelism. Empty user agent means korb-klar/<version>.
SUPERMARKT_TIMEOUT_SECONDS=25
SUPERMARKT_MARKTGURU_PAGE_SIZE=500
SUPERMARKT_MAX_WORKERS=8
SUPERMARKT_USER_AGENT=

# Headless browser for the retailer pages that need JavaScript
# (ALDI Sued, Kaufland, REWE).
SUPERMARKT_CHROMIUM=/usr/bin/chromium

# Store mappings. The offer data itself stays fresh.
SUPERMARKT_KAUFLAND_STORE_CACHE_TTL_SECONDS=86400
SUPERMARKT_REWE_STORE_CACHE_TTL_SECONDS=86400

# Image cache.
SUPERMARKT_IMAGE_CACHE_TTL_SECONDS=604800
SUPERMARKT_IMAGE_CACHE_MAX_BYTES=536870912
SUPERMARKT_IMAGE_MAX_FILE_BYTES=4194304
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
