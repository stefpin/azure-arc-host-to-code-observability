SET VERIFY OFF
-- MiniBank ledger table + 30 seed rows. Run as SYSTEM connected to FREEPDB1 (after 01-minibank-user.sql). No parameters.
--   sudo podman cp db/oracle/02-minibank-tables.sql minibank-oracle:/tmp/02-minibank-tables.sql
--   read -rsp 'SYSTEM password: ' SYS_PW; echo
--   printf 'CONNECT system/"%s"@FREEPDB1\n@/tmp/02-minibank-tables.sql\nEXIT\n' "$SYS_PW" | sudo podman exec -i minibank-oracle sqlplus -s /nolog
--   unset SYS_PW
-- Never create a table called LEDGER_MISSING: scenario fail-oracle depends on it NOT existing (ORA-00942).
WHENEVER SQLERROR EXIT SQL.SQLCODE

CREATE TABLE IF NOT EXISTS MINIBANK.LEDGER_ENTRY (
  ID           NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  REFERENCE_NO VARCHAR2(20)  NOT NULL,
  ACCOUNT_NO   VARCHAR2(10)  NOT NULL,
  COUNTERPARTY VARCHAR2(60),
  AMOUNT       NUMBER(18,2)  NOT NULL,
  DIRECTION    CHAR(1)       NOT NULL CHECK (DIRECTION IN ('D', 'C')),   -- D = debit, C = credit
  CHANNEL      VARCHAR2(10)  NOT NULL,                                   -- TRANSFER, QRIS, PAYROLL
  CREATED_AT   TIMESTAMP     DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,   -- UTC
  TRACE_ID     VARCHAR2(32)
);
CREATE INDEX IF NOT EXISTS MINIBANK.LEDGER_ENTRY_ACCT_IX ON MINIBANK.LEDGER_ENTRY (ACCOUNT_NO, CREATED_AT);

-- seed rows (synthetic), spread over the last 30 days; re-running replaces them
DELETE FROM MINIBANK.LEDGER_ENTRY WHERE REFERENCE_NO LIKE 'SEED-%';
INSERT INTO MINIBANK.LEDGER_ENTRY (REFERENCE_NO, ACCOUNT_NO, COUNTERPARTY, AMOUNT, DIRECTION, CHANNEL, CREATED_AT)
SELECT s.ref, s.acct, s.cp, s.amt, s.dir, s.chan, SYS_EXTRACT_UTC(SYSTIMESTAMP) - NUMTODSINTERVAL(s.hrs, 'HOUR')
FROM (
  SELECT 'SEED-001' ref, '9901000011' acct, 'PT Sejahtera Demo (gaji)' cp, 15000000 amt, 'C' dir, 'PAYROLL' chan, 672 hrs FROM dual UNION ALL
  SELECT 'SEED-002', '9901000021', 'PT Sejahtera Demo (gaji)', 12500000, 'C', 'PAYROLL', 671 FROM dual UNION ALL
  SELECT 'SEED-003', '9901000031', 'PT Sejahtera Demo (gaji)', 18000000, 'C', 'PAYROLL', 670 FROM dual UNION ALL
  SELECT 'SEED-004', '9901000011', 'Kopi Senja (Demo)',            45000, 'D', 'QRIS',     624 FROM dual UNION ALL
  SELECT 'SEED-005', '9901000011', '9901000021',                 1500000, 'D', 'TRANSFER', 600 FROM dual UNION ALL
  SELECT 'SEED-005', '9901000021', '9901000011',                 1500000, 'C', 'TRANSFER', 600 FROM dual UNION ALL
  SELECT 'SEED-006', '9901000021', 'Warung Nusantara (Demo)',      120000, 'D', 'QRIS',     576 FROM dual UNION ALL
  SELECT 'SEED-007', '9901000031', '9901000032',                 5000000, 'D', 'TRANSFER', 528 FROM dual UNION ALL
  SELECT 'SEED-007', '9901000032', '9901000031',                 5000000, 'C', 'TRANSFER', 528 FROM dual UNION ALL
  SELECT 'SEED-008', '9901000031', 'Apotek Sehat (Demo)',           89000, 'D', 'QRIS',     504 FROM dual UNION ALL
  SELECT 'SEED-009', '9901000022', '9901000012',                  750000, 'D', 'TRANSFER', 456 FROM dual UNION ALL
  SELECT 'SEED-009', '9901000012', '9901000022',                  750000, 'C', 'TRANSFER', 456 FROM dual UNION ALL
  SELECT 'SEED-010', '9901000012', 'Toko Buku Pelangi (Demo)',     210000, 'D', 'QRIS',     408 FROM dual UNION ALL
  SELECT 'SEED-011', '9901000032', 'Bakmi Lestari (Demo)',          65000, 'D', 'QRIS',     384 FROM dual UNION ALL
  SELECT 'SEED-012', '9901000021', '9901000031',                 2000000, 'D', 'TRANSFER', 336 FROM dual UNION ALL
  SELECT 'SEED-012', '9901000031', '9901000021',                 2000000, 'C', 'TRANSFER', 336 FROM dual UNION ALL
  SELECT 'SEED-013', '9901000022', 'Kopi Senja (Demo)',             37500, 'D', 'QRIS',     288 FROM dual UNION ALL
  SELECT 'SEED-014', '9901000012', '9901000011',                  300000, 'D', 'TRANSFER', 240 FROM dual UNION ALL
  SELECT 'SEED-014', '9901000011', '9901000012',                  300000, 'C', 'TRANSFER', 240 FROM dual UNION ALL
  SELECT 'SEED-015', '9901000011', 'Bakmi Lestari (Demo)',         155000, 'D', 'QRIS',     192 FROM dual UNION ALL
  SELECT 'SEED-016', '9901000031', 'Kopi Senja (Demo)',             49000, 'D', 'QRIS',     168 FROM dual UNION ALL
  SELECT 'SEED-017', '9901000032', '9901000022',                 1250000, 'D', 'TRANSFER', 144 FROM dual UNION ALL
  SELECT 'SEED-017', '9901000022', '9901000032',                 1250000, 'C', 'TRANSFER', 144 FROM dual UNION ALL
  SELECT 'SEED-018', '9901000021', 'Apotek Sehat (Demo)',           98000, 'D', 'QRIS',     120 FROM dual UNION ALL
  SELECT 'SEED-019', '9901000012', 'Warung Nusantara (Demo)',       27000, 'D', 'QRIS',      96 FROM dual UNION ALL
  SELECT 'SEED-020', '9901000011', '9901000032',                  500000, 'D', 'TRANSFER',  72 FROM dual UNION ALL
  SELECT 'SEED-020', '9901000032', '9901000011',                  500000, 'C', 'TRANSFER',  72 FROM dual UNION ALL
  SELECT 'SEED-021', '9901000022', 'Toko Buku Pelangi (Demo)',      76000, 'D', 'QRIS',      48 FROM dual UNION ALL
  SELECT 'SEED-022', '9901000031', 'Warung Nusantara (Demo)',      132000, 'D', 'QRIS',      24 FROM dual UNION ALL
  SELECT 'SEED-023', '9901000032', 'Kopi Senja (Demo)',             18000, 'D', 'QRIS',      12 FROM dual
) s;
COMMIT;

SELECT ACCOUNT_NO, COUNT(*) AS ENTRIES FROM MINIBANK.LEDGER_ENTRY GROUP BY ACCOUNT_NO ORDER BY ACCOUNT_NO;
