#!/bin/bash
set -e

echo "=== Web provisioning ==="

apt update
apt install -y nginx apache2 wget curl docker-compose

# ================= Apache =================
a2enmod status
a2dissite 000-default.conf || true

# Apache НЕ слушает 80 (его слушает nginx)
sed -i 's/^Listen 80/#Listen 80/' /etc/apache2/ports.conf || true

cp /vagrant/provision/configs/apache-backend.conf /etc/apache2/sites-available/backend.conf
a2ensite backend.conf

mkdir -p /var/www/html{1,2,3}
echo "Server 1" > /var/www/html1/index.html
echo "Server 2" > /var/www/html2/index.html
echo "Server 3" > /var/www/html3/index.html

systemctl restart apache2
systemctl enable apache2

# ================= Nginx =================
rm -f /etc/nginx/sites-enabled/default
cp /vagrant/provision/configs/nginx.conf /etc/nginx/sites-available/load-balancer.conf
ln -sf /etc/nginx/sites-available/load-balancer.conf /etc/nginx/sites-enabled/

nginx -t
systemctl restart nginx
systemctl enable nginx

# ================= Node Exporter =================
NODE_EXPORTER_VERSION="1.7.0"
if [ ! -f /usr/local/bin/node_exporter ]; then
    wget https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
    tar xvfz node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
    cp node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /usr/local/bin/
    chmod +x /usr/local/bin/node_exporter
    rm -rf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64*
fi

cat > /etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
ExecStart=/usr/local/bin/node_exporter
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# ================= Nginx Exporter =================
NGINX_EXPORTER_VERSION="0.11.0"
if [ ! -f /usr/local/bin/nginx-prometheus-exporter ]; then
    wget https://github.com/nginxinc/nginx-prometheus-exporter/releases/download/v${NGINX_EXPORTER_VERSION}/nginx-prometheus-exporter_${NGINX_EXPORTER_VERSION}_linux_amd64.tar.gz
    tar xvfz nginx-prometheus-exporter_${NGINX_EXPORTER_VERSION}_linux_amd64.tar.gz
    mv nginx-prometheus-exporter /usr/local/bin/
    chmod +x /usr/local/bin/nginx-prometheus-exporter
    rm -f nginx-prometheus-exporter_${NGINX_EXPORTER_VERSION}_linux_amd64.tar.gz
fi

cat > /etc/systemd/system/nginx-prometheus-exporter.service <<EOF
[Unit]
Description=Nginx Prometheus Exporter
After=nginx.service
Requires=nginx.service

[Service]
ExecStart=/usr/local/bin/nginx-prometheus-exporter \
  --nginx.scrape-uri=http://localhost/stub_status
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# ================= Apache Exporter (FIXED) =================
APACHE_EXPORTER_VERSION="0.13.0"
if [ ! -f /usr/local/bin/apache_exporter ]; then
    wget https://github.com/Lusitaniae/apache_exporter/releases/download/v${APACHE_EXPORTER_VERSION}/apache_exporter-${APACHE_EXPORTER_VERSION}.linux-amd64.tar.gz
    tar xvfz apache_exporter-${APACHE_EXPORTER_VERSION}.linux-amd64.tar.gz
    mv apache_exporter-${APACHE_EXPORTER_VERSION}.linux-amd64/apache_exporter /usr/local/bin/
    chmod +x /usr/local/bin/apache_exporter
    rm -rf apache_exporter-${APACHE_EXPORTER_VERSION}.linux-amd64*
fi

cat > /etc/systemd/system/apache_exporter.service <<EOF
[Unit]
Description=Apache Exporter
After=apache2.service
Requires=apache2.service

[Service]
ExecStart=/usr/local/bin/apache_exporter \
  --scrape_uri=http://localhost/server-status?auto \
  --telemetry.address=:9117
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# ================= Enable & Start =================
systemctl daemon-reload
systemctl enable node_exporter nginx-prometheus-exporter apache_exporter
systemctl restart node_exporter nginx-prometheus-exporter apache_exporter

echo "=== Web node READY ==="
