-- oracle-snap.sql - Route A snapshot queries for Oracle (run by minibank-dbsnap.sh as MINIBANK_MON in FREEPDB1).
-- Mounted read-only in the container as /snap/oracle-snap.sql. Output: one line per value  SnapshotType|Name|Value|Detail
SET PAGESIZE 0 FEEDBACK OFF HEADING OFF VERIFY OFF ECHO OFF TRIMOUT ON TRIMSPOOL ON TAB OFF LINESIZE 1000
ALTER SESSION SET NLS_NUMERIC_CHARACTERS = '.,';

-- sessions: number of MINIBANK sessions (TOTAL and per status)
SELECT 'sessions|TOTAL|' || COUNT(*) || '|username=MINIBANK' FROM v$session WHERE username = 'MINIBANK';
SELECT 'sessions|' || status || '|' || COUNT(*) || '|username=MINIBANK' FROM v$session WHERE username = 'MINIBANK' GROUP BY status;

-- waits: cumulative seconds waited (time_waited_micro / 1e6): top 5 non-Idle events ...
SELECT 'waits|' || event || '|' || TO_CHAR(ROUND(time_waited_micro / 1000000, 3), 'FM999999999990.000')
       || '|wait_class=' || wait_class || ' total_waits=' || total_waits
FROM (SELECT event, wait_class, time_waited_micro, total_waits FROM v$system_event
      WHERE wait_class <> 'Idle' ORDER BY time_waited_micro DESC FETCH FIRST 5 ROWS ONLY);
-- ... plus 'PL/SQL lock timer' (Idle class, but this is where DBMS_SESSION.SLEEP of scenario slow-oracle waits)
SELECT 'waits|PL/SQL lock timer|' || TO_CHAR(NVL(MAX(ROUND(time_waited_micro / 1000000, 3)), 0), 'FM999999999990.000')
       || '|wait_class=Idle total_waits=' || NVL(MAX(total_waits), 0)
FROM v$system_event WHERE event = 'PL/SQL lock timer';

-- topsql: average elapsed milliseconds per execution, top 5 statements parsed by MINIBANK
SELECT 'topsql|' || sql_id || '|' || TO_CHAR(ROUND(SUM(elapsed_time) / 1000 / SUM(executions), 3), 'FM999999999990.000')
       || '|' || REPLACE(REPLACE(MAX(SUBSTR(sql_text, 1, 200)), CHR(10), ' '), CHR(13), ' ') || ' | execs=' || SUM(executions)
FROM v$sql
WHERE parsing_schema_name = 'MINIBANK' AND executions > 0
GROUP BY sql_id
ORDER BY SUM(elapsed_time) / SUM(executions) DESC FETCH FIRST 5 ROWS ONLY;

-- locks: number of blocked sessions
SELECT 'locks|blocked_sessions|' || COUNT(*) || '|v$session.blocking_session is set' FROM v$session WHERE blocking_session IS NOT NULL;
EXIT
