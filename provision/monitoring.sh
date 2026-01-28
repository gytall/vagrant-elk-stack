#!/bin/bash
set -e

echo "=== Monitoring provisioning ==="

# Создаём директории для сервисов
mkdir -p /opt/monitoring
mkdir -p /opt/elk
mkdir -p /opt/prometheus

# ---------- Установка Prometheus ----------
if [ ! -f /usr/local/bin/prometheus ]; then
    PROMETHEUS_VERSION="2.48.0"
    wget https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
    tar xvfz prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
    cp prometheus-${PROMETHEUS_VERSION}.linux-amd64/prometheus /usr/local/bin/
    cp prometheus-${PROMETHEUS_VERSION}.linux-amd64/promtool /usr/local/bin/
    chmod +x /usr/local/bin/prometheus /usr/local/bin/promtool
    rm -rf prometheus-${PROMETHEUS_VERSION}.linux-amd64*
    
    # Создаём пользователя для Prometheus
    useradd --no-create-home --shell /bin/false prometheus || true
    
    # Создаём необходимые директории
    mkdir -p /opt/prometheus/data
    mkdir -p /opt/prometheus/consoles
    mkdir -p /opt/prometheus/console_libraries
    chown -R prometheus:prometheus /opt/prometheus
    
    # Копируем конфигурацию Prometheus
    cp /vagrant/provision/configs/prometheus.yml /opt/prometheus/prometheus.yml
    chown prometheus:prometheus /opt/prometheus/prometheus.yml
    
    # Создаём systemd service для Prometheus
    cat > /etc/systemd/system/prometheus.service <<EOF
[Unit]
Description=Prometheus
After=network.target

[Service]
Type=simple
User=prometheus
ExecStart=/usr/local/bin/prometheus \\
    --config.file=/opt/prometheus/prometheus.yml \\
    --storage.tsdb.path=/opt/prometheus/data \\
    --web.console.templates=/opt/prometheus/consoles \\
    --web.console.libraries=/opt/prometheus/console_libraries \\
    --web.listen-address=0.0.0.0:9090
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable prometheus
    systemctl start prometheus
fi

# ---------- Установка Grafana ----------
if ! command -v grafana-server &> /dev/null; then
    apt-get update
    apt-get install -y libfontconfig1 musl wget
    wget -O /tmp/grafana.deb -q https://dl.grafana.com/oss/release/grafana_10.2.5_amd64.deb
    dpkg -i /tmp/grafana.deb || apt-get install -f -y
    systemctl enable grafana-server
    systemctl start grafana-server
fi



# ---------- Развёртывание ELK через Docker Compose ----------
if [ ! -f /opt/elk/docker-compose.yml ]; then
    cp /vagrant/provision/configs/elk-docker-compose.yml /opt/elk/docker-compose.yml
    cp /vagrant/provision/configs/logstash.conf /opt/elk/logstash.conf
    
    cd /opt/elk
    # Увеличиваем vm.max_map_count для Elasticsearch
    sysctl -w vm.max_map_count=262144
    echo "vm.max_map_count=262144" >> /etc/sysctl.conf
    
    # Запускаем ELK stack
    docker-compose up -d
    
    # Ждём готовности Elasticsearch
    echo "Ожидание готовности Elasticsearch..."
    sleep 30
    for i in {1..30}; do
        if curl -s http://localhost:9200 > /dev/null 2>&1; then
            echo "Elasticsearch готов"
            break
        fi
        sleep 2
    done
fi

echo "=== Monitoring node is ready ==="
