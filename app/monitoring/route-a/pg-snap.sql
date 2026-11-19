-- pg-snap.sql - Route A snapshot queries for PostgreSQL (run by minibank-dbsnap.sh as postgres_exporter in database minibank).
-- psql -A -t -F '|' prints one line per row:  SnapshotType|Name|Value|Detail
-- sessions: number of sessions in database minibank (TOTAL and per state), without this monitoring session
SELECT 'sessions', 'TOTAL', count(*), 'datname=minibank'
FROM pg_stat_activity WHERE datname = 'minibank' AND pid <> pg_backend_pid();
SELECT 'sessions', coalesce(state, 'unknown'), count(*), 'datname=minibank'
FROM pg_stat_activity WHERE datname = 'minibank' AND pid <> pg_backend_pid() GROUP BY state;
-- waits: current number of non-idle sessions per wait_event_type (pg_sleep of slow-postgres shows as Timeout)
SELECT 'waits', coalesce(wait_event_type, 'CPU'), count(*), 'events=' || string_agg(DISTINCT coalesce(wait_event, '-'), ',')
FROM pg_stat_activity
WHERE datname = 'minibank' AND state IS DISTINCT FROM 'idle' AND pid <> pg_backend_pid()
GROUP BY coalesce(wait_event_type, 'CPU');
-- topsql: average elapsed milliseconds per execution (mean_exec_time), top 5 in database minibank
SELECT 'topsql', s.queryid, round(s.mean_exec_time::numeric, 3),
       left(regexp_replace(s.query, '\s+', ' ', 'g'), 200) || ' | execs=' || s.calls
FROM pg_stat_statements s JOIN pg_database d ON d.oid = s.dbid
WHERE d.datname = 'minibank'
ORDER BY s.mean_exec_time DESC LIMIT 5;
-- locks: number of blocked sessions
SELECT 'locks', 'blocked_sessions', count(*), 'pg_blocking_pids() is not empty'
FROM pg_stat_activity WHERE datname = 'minibank' AND cardinality(pg_blocking_pids(pid)) > 0;
