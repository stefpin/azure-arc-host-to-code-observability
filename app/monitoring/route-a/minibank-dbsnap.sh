#!/usr/bin/env bash
# minibank-dbsnap.sh - Route A database snapshot for the MiniBank demo (APP-RHEL, /opt/minibank/dbsnap/).
# Run every 60 s as root by minibank-dbsnap.timer. Appends JSON lines (UTF-8, one object per line) to
# /var/log/minibank/dbsnap.json. The Azure Monitor Agent sends them to the custom table MiniBankDbSnap_CL
# and adds Computer and FilePath itself, so the lines do NOT contain them.
# Fields: TimeGenerated (UTC ISO 8601), DbEngine (Oracle|PostgreSQL), SnapshotType (sessions|waits|topsql|locks|errors),
#         Name, Value (number), Detail (string, max 300 characters)
# Value: sessions = count | waits = Oracle cumulative seconds waited, PostgreSQL current sessions per wait_event_type
#        topsql = average ms per execution | locks = blocked sessions | errors = ORA- lines in the alert log, last minute
# Test by hand: sudo /opt/minibank/dbsnap/minibank-dbsnap.sh && sudo tail -n 5 /var/log/minibank/dbsnap.json
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${DBSNAP_ENV:-/etc/minibank/dbsnap.env}"   # passwords live only in this root-only file
if [ ! -r "$ENV_FILE" ]; then echo "minibank-dbsnap: cannot read $ENV_FILE" >&2; exit 1; fi
set -a; . "$ENV_FILE"; set +a

ORACLE_CONTAINER="${ORACLE_CONTAINER:-minibank-oracle}"
ORACLE_ALERT_LOG="${ORACLE_ALERT_LOG:-/opt/oracle/diag/rdbms/free/FREE/trace/alert_FREE.log}"
OUT="${DBSNAP_FILE:-/var/log/minibank/dbsnap.json}"
MAX_BYTES=$((50 * 1024 * 1024))
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"                # one timestamp for the whole snapshot
rc=0

mkdir -p "$(dirname "$OUT")" && chmod 755 "$(dirname "$OUT")"
# rotate when the file is larger than 50 MB (the agent continues with the new file)
if [ -f "$OUT" ] && [ "$(stat -c %s "$OUT")" -gt "$MAX_BYTES" ]; then mv -f "$OUT" "$OUT.1"; fi

# --- Oracle: sqlplus inside the container; user/password go on stdin, never on a command line ---
ORA_SQL='@/snap/oracle-snap.sql'
if ! podman exec "$ORACLE_CONTAINER" test -r /snap/oracle-snap.sql 2>/dev/null; then
  ORA_SQL="$(cat "$SCRIPT_DIR/oracle-snap.sql")"    # /snap not mounted: send the file content instead
fi
ORA_OUT="$(printf 'CONNECT %s/"%s"@FREEPDB1\n%s\nEXIT\n' "${ORACLE_MON_USER:-MINIBANK_MON}" "$ORACLE_MON_PASSWORD" "$ORA_SQL" \
  | timeout 30 podman exec -i "$ORACLE_CONTAINER" sqlplus -s /nolog 2>&1)" || rc=1

# --- Oracle alert log: keep only timestamp lines and ORA- lines (Python counts the last minute) ---
if ALERT_RAW="$(timeout 15 podman exec "$ORACLE_CONTAINER" tail -n 5000 "$ORACLE_ALERT_LOG" 2>/dev/null)"; then
  ALERT_OK=1
  ALERT_OUT="$(printf '%s\n' "$ALERT_RAW" | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}T|ORA-' | tail -n 400 || true)"
else
  ALERT_OK=0; ALERT_OUT=""; rc=1
  echo "minibank-dbsnap: cannot read the Oracle alert log $ORACLE_ALERT_LOG" >&2
fi

# --- PostgreSQL: psql as postgres_exporter (password in PGPASSWORD, not on the command line) ---
PG_OUT="$(PGPASSWORD="$PG_MON_PASSWORD" PGCONNECT_TIMEOUT=10 timeout 30 psql -X -q -A -t -F '|' \
  -h "${PG_HOST:-127.0.0.1}" -p "${PG_PORT:-5432}" -U "${PG_MON_USER:-postgres_exporter}" -d "${PG_DB:-minibank}" \
  -f "$SCRIPT_DIR/pg-snap.sql" 2>&1)" || rc=1

# --- convert to JSON lines (python3 is part of RHEL 9; json.dumps escapes everything safely) ---
export NOW ORA_OUT ALERT_OUT ALERT_OK PG_OUT
python3 - >> "$OUT" <<'PY' || rc=1
import json, os, re, sys
from datetime import datetime, timedelta, timezone

now = os.environ["NOW"]
cutoff = datetime.now(timezone.utc) - timedelta(seconds=60)
TYPES = {"sessions", "waits", "topsql", "locks"}
problems = []

def emit(engine, stype, name, value, detail):
    print(json.dumps({"TimeGenerated": now, "DbEngine": engine, "SnapshotType": stype,
                      "Name": name[:128], "Value": value, "Detail": detail[:300]}))

for engine, text in (("Oracle", os.environ.get("ORA_OUT", "")), ("PostgreSQL", os.environ.get("PG_OUT", ""))):
    rows = 0
    for line in text.splitlines():
        parts = line.strip().split("|", 3)          # SnapshotType|Name|Value|Detail (Detail may contain '|')
        if len(parts) == 4 and parts[0] in TYPES:
            try:
                value = float(parts[2])
            except ValueError:
                continue
            emit(engine, parts[0], parts[1].strip(), value, parts[3].strip())
            rows += 1
    if rows == 0:
        problems.append(engine + ": " + " ".join(text.split())[:300])

if os.environ.get("ALERT_OK") == "1":               # errors = ORA- lines written in the last minute
    count, last, stamp = 0, "", None
    for line in os.environ.get("ALERT_OUT", "").splitlines():
        if re.match(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}", line):
            try:
                stamp = datetime.fromisoformat(line.split()[0])
                if stamp.tzinfo is None:
                    stamp = stamp.replace(tzinfo=timezone.utc)
            except ValueError:
                stamp = None
        elif "ORA-" in line and stamp is not None and stamp >= cutoff:
            count += 1
            last = line.strip()
    emit("Oracle", "errors", "alert_log_ORA", float(count), last)

for problem in problems:
    print("minibank-dbsnap: no data from " + problem, file=sys.stderr)
sys.exit(2 if problems else 0)
PY
chmod 644 "$OUT"
exit $rc
