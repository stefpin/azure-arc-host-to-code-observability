#!/usr/bin/env bash
# Route B: start the two Prometheus exporters on APP-RHEL as Podman containers.  Run: sudo ./run-exporters.sh
#   Oracle AI Database Metrics Exporter -> http://192.168.110.32:9161/metrics  (user MINIBANK_MON, SELECT_CATALOG_ROLE)
#   postgres_exporter                   -> http://192.168.110.32:9187/metrics  (role postgres_exporter, pg_monitor)
# Settings: /etc/minibank/exporters.env (copy exporters.env.example; root:root, mode 600).
# Both use the host network: no port mapping is needed and 127.0.0.1:5432 is the local PostgreSQL.
# Note: --restart=always restarts a stopped container. For a start after reboot enable once
#   sudo systemctl enable --now podman-restart.service      (no systemd unit generation or quadlets needed)
set -euo pipefail
ENV_FILE=/etc/minibank/exporters.env
[ -r "$ENV_FILE" ] || { echo "Missing $ENV_FILE (copy exporters.env.example)" >&2; exit 1; }
set -a; . "$ENV_FILE"; set +a     # exports DB_USERNAME, DB_PASSWORD, DB_CONNECT_STRING, DATA_SOURCE_NAME

ORACLE_EXPORTER_IMAGE=container-registry.oracle.com/database/observability-exporter:2.5.1
PG_EXPORTER_IMAGE=quay.io/prometheuscommunity/postgres-exporter:v0.20.1

podman rm -f minibank-oracle-exporter minibank-postgres-exporter >/dev/null 2>&1 || true

# v1.3: the Oracle exporter 2.5.x reads its database settings from a configuration file (CONFIG_FILE).
# The file holds only ${...} references: the exporter fills them from the environment, so the password stays in exporters.env.
cat > /etc/minibank/oracle-exporter.yaml <<'YAML'
databases:
  default:
    username: ${DB_USERNAME}
    password: ${DB_PASSWORD}
    url: ${DB_CONNECT_STRING}
    queryTimeout: 5
    connMaxLifetime: 30m
    maxOpenConns: 10
    maxIdleConns: 10
metrics:
  default: /default-metrics.toml
YAML
chmod 644 /etc/minibank/oracle-exporter.yaml

# "-e NAME" without a value copies the variable from this shell, so passwords never appear on the command line
podman run -d --name minibank-oracle-exporter --restart=always --network host \
  -e DB_USERNAME -e DB_PASSWORD -e DB_CONNECT_STRING \
  -e CONFIG_FILE=/config/exporter.yaml -v /etc/minibank/oracle-exporter.yaml:/config/exporter.yaml:ro,Z \
  "$ORACLE_EXPORTER_IMAGE"

podman run -d --name minibank-postgres-exporter --restart=always --network host \
  -e DATA_SOURCE_NAME \
  "$PG_EXPORTER_IMAGE"

sleep 15
podman ps --filter name=minibank- --format '{{.Names}}  {{.Status}}'
curl -s http://127.0.0.1:9161/metrics | grep -m1 '^oracledb_up' || echo 'oracledb_up not found yet: podman logs minibank-oracle-exporter'
curl -s http://127.0.0.1:9187/metrics | grep -m1 '^pg_up' || echo 'pg_up not found yet: podman logs minibank-postgres-exporter'
