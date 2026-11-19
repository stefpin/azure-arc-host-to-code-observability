SET VERIFY OFF
-- MiniBank Oracle users. Run as SYSTEM connected to FREEPDB1 (container minibank-oracle on APP-RHEL).
-- Parameters: &1 = new password of MINIBANK (application), &2 = new password of MINIBANK_MON (monitoring).
-- Run on APP-RHEL (bash). The passwords are typed hidden and passed on stdin, never on a command line:
--   sudo podman cp db/oracle/01-minibank-user.sql minibank-oracle:/tmp/01-minibank-user.sql
--   read -rsp 'SYSTEM password: ' SYS_PW; echo; read -rsp 'New MINIBANK password: ' APP_PW; echo; read -rsp 'New MINIBANK_MON password: ' MON_PW; echo
--   printf 'CONNECT system/"%s"@FREEPDB1\n@/tmp/01-minibank-user.sql %s %s\nEXIT\n' "$SYS_PW" "$APP_PW" "$MON_PW" | sudo podman exec -i minibank-oracle sqlplus -s /nolog
--   unset SYS_PW APP_PW MON_PW
-- Use only letters and digits in passwords (start with a letter). Safe to run again (it resets the passwords).
-- Check the result: echo $? must print 0, and the last query must list MINIBANK and MINIBANK_MON as OPEN.
WHENEVER SQLERROR EXIT SQL.SQLCODE

-- v1.3: the "latest-lite" Oracle AI Database Free image has no USERS tablespace in FREEPDB1. Without it the
-- CREATE USER below fails with ORA-00959 and the script stops. Create USERS next to the SYSTEM datafile if missing.
DECLARE
  n   NUMBER;
  dir VARCHAR2(512);
BEGIN
  SELECT COUNT(*) INTO n FROM dba_tablespaces WHERE tablespace_name = 'USERS';
  IF n = 0 THEN
    SELECT SUBSTR(file_name, 1, INSTR(file_name, '/', -1)) INTO dir
      FROM dba_data_files WHERE tablespace_name = 'SYSTEM' AND ROWNUM = 1;
    EXECUTE IMMEDIATE 'CREATE TABLESPACE USERS DATAFILE ''' || dir || 'users01.dbf'' SIZE 100M AUTOEXTEND ON NEXT 50M MAXSIZE 4G';
  END IF;
END;
/

-- application user (minibank-transfer)
CREATE USER IF NOT EXISTS MINIBANK IDENTIFIED BY "&1" DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS;
ALTER USER MINIBANK IDENTIFIED BY "&1" ACCOUNT UNLOCK;
GRANT CREATE SESSION, CREATE TABLE, CREATE SEQUENCE TO MINIBANK;
GRANT EXECUTE ON SYS.DBMS_SESSION TO MINIBANK;   -- scenario slow-oracle uses DBMS_SESSION.SLEEP

-- monitoring user (Oracle exporter, Route B, and minibank-dbsnap.sh, Route A)
CREATE USER IF NOT EXISTS MINIBANK_MON IDENTIFIED BY "&2" DEFAULT TABLESPACE USERS;
ALTER USER MINIBANK_MON IDENTIFIED BY "&2" ACCOUNT UNLOCK;
GRANT CREATE SESSION, SELECT_CATALOG_ROLE TO MINIBANK_MON;

SELECT username, account_status FROM dba_users WHERE username IN ('MINIBANK', 'MINIBANK_MON') ORDER BY username;
