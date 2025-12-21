#!/bin/bash
set -eux

NODE_EXPORTER_VERSION="1.7.0"
USER="node_exporter"

# Create user if not exists
id -u $USER &>/dev/null || useradd --no-create-home --shell /usr/sbin/nologin $USER

# Download Node Exporter
cd /tmp
curl -LO https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz

# Install binary
tar xzf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
cp node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /usr/local/bin/
chown $USER:$USER /usr/local/bin/node_exporter
chmod 755 /usr/local/bin/node_exporter

# Create systemd service
cat <<EOF >/etc/systemd/system/node_exporter.service
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
User=$USER
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

# Start service
systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter

