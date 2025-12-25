#!/bin/bash
set -ux

NODE_VERSION="1.8.2"
NODE_USER="node_exporter"

# -----------------------------
# Create user
# -----------------------------
id ${NODE_USER} &>/dev/null || useradd --no-create-home --shell /sbin/nologin ${NODE_USER}

# -----------------------------
# Download Node Exporter
# -----------------------------
cd /tmp
curl -LO https://github.com/prometheus/node_exporter/releases/download/v${NODE_VERSION}/node_exporter-${NODE_VERSION}.linux-amd64.tar.gz
tar -xzf node_exporter-${NODE_VERSION}.linux-amd64.tar.gz

# -----------------------------
# Install binary
# -----------------------------
mv node_exporter-${NODE_VERSION}.linux-amd64/node_exporter /usr/local/bin/
chown ${NODE_USER}:${NODE_USER} /usr/local/bin/node_exporter
chmod 755 /usr/local/bin/node_exporter

# -----------------------------
# Create systemd service
# -----------------------------
cat <<EOF >/etc/systemd/system/node-exporter.service
[Unit]
Description=Prometheus Node Exporter
After=network-online.target
Wants=network-online.target

[Service]
User=${NODE_USER}
Group=${NODE_USER}
Type=simple
ExecStart=/usr/local/bin/node_exporter

Restart=always

[Install]
WantedBy=multi-user.target
EOF

# -----------------------------
# Enable & start service
# -----------------------------
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable node-exporter
systemctl start node-exporter
