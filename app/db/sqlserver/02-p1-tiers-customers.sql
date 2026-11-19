/* MiniBank v1.4 (P1 build, feature D - business impact in IDR): customer tiers and 30 more synthetic customers.
   Run on APP-SQL AFTER 01-minibank-db.sql, in PowerShell as Administrator with the Invoke-SqlFile helper from runbook Chapter 14.1:
     Invoke-SqlFile C:\Build\minibank\db\sqlserver\02-p1-tiers-customers.sql
   (or, if sqlcmd is installed: sqlcmd -S localhost -E -b -i C:\Build\minibank\db\sqlserver\02-p1-tiers-customers.sql)
   Safe to run again: the column Tier, its check constraint, customers and accounts are added only when missing, the view
   dbo.DemoBalanceTargets is re-created and the tiers are set to the values below. Balances of accounts that already exist
   are never changed here (scripts\topup-demo-balances.sql does that); new accounts start at their tier balance.
   Result: 33 customers (Reguler 24, Prioritas 7, Solitaire 2) with 2 accounts each (Tabungan Demo + Giro Demo) = 66 accounts.
   Account number = 990100 + 3-digit customer number + 1 (Tabungan) or 2 (Giro): customer 1 keeps 9901000011/12,
   customer 33 gets 9901000331/32. Every customer uses the documented demo password and PIN (checked by the API, not stored).
   The Oracle ledger and PostgreSQL need no rows for the new accounts: a new account has an empty statement until its first
   payment (LEDGER_ENTRY has no account master and no foreign key). */
USE MiniBankDemo;
GO
/* 1. Tier of every customer: Reguler (default), Prioritas or Solitaire */
IF COL_LENGTH(N'dbo.Customers', N'Tier') IS NULL
    ALTER TABLE dbo.Customers ADD Tier varchar(10) NOT NULL CONSTRAINT DF_Customers_Tier DEFAULT ('Reguler');
GO
IF OBJECT_ID(N'dbo.CK_Customers_Tier', N'C') IS NULL
    ALTER TABLE dbo.Customers ADD CONSTRAINT CK_Customers_Tier CHECK (Tier IN ('Reguler', 'Prioritas', 'Solitaire'));
GO
/* 2. Target balance of every demo account by tier, used by scripts\topup-demo-balances.sql (every 6 hours) and
      scripts\reset-demo-balances.sql. Tabungan (savings, suffix 1) carries the tier level, Giro (current account, suffix 2)
      is an everyday account. The spread inside each band comes from the customer number, so every account gets a fixed,
      realistic-looking value:
        Reguler   Tabungan IDR 35-75 million       Giro IDR 25-46 million
        Prioritas Tabungan IDR 0.9-1.2 billion     Giro IDR 15-46 million
        Solitaire Tabungan IDR 9-12.2 billion      Giro IDR 50-101 million
      The Giro of ANDI, SITI and BUDI must stay well below IDR 475 million: the traffic generator's business declines pay
      IDR 10-25 million more than the smaller account holds, and the API accepts at most IDR 500 million per payment. */
CREATE OR ALTER VIEW dbo.DemoBalanceTargets
AS
SELECT a.AccountNo, c.CustomerId, c.UserId, c.Tier, a.ProductName,
       CAST(CASE
            WHEN c.Tier = 'Solitaire' AND a.ProductName LIKE N'Tabungan%'
                THEN 9000000000.00 + (c.CustomerId * 7 % 31) * 100000000.00 + (c.CustomerId * 37 % 100) * 1250000.00
            WHEN c.Tier = 'Solitaire'
                THEN 50000000.00 + (c.CustomerId * 11 % 51) * 1000000.00 + (c.CustomerId * 13 % 20) * 50000.00
            WHEN c.Tier = 'Prioritas' AND a.ProductName LIKE N'Tabungan%'
                THEN 900000000.00 + (c.CustomerId * 7 % 31) * 10000000.00 + (c.CustomerId * 37 % 100) * 125000.00
            WHEN c.Tier = 'Prioritas'
                THEN 15000000.00 + (c.CustomerId * 11 % 31) * 1000000.00 + (c.CustomerId * 13 % 20) * 50000.00
            WHEN a.ProductName LIKE N'Tabungan%'
                THEN 35000000.00 + (c.CustomerId * 7 % 40) * 1000000.00 + (c.CustomerId * 37 % 20) * 50000.00
            ELSE 25000000.00 + (c.CustomerId * 11 % 21) * 1000000.00 + (c.CustomerId * 13 % 20) * 50000.00
       END AS decimal(18,2)) AS TargetBalance
FROM dbo.Accounts a
JOIN dbo.Customers c ON c.CustomerId = a.CustomerId;
GO
/* 3. The 3 original customers get their tier, 30 synthetic customers are added (fictional Indonesian names).
      Tiers: the 3 original customers are Prioritas because the continuous traffic generator (ANDI, SITI, BUDI) pays about
      IDR 100 million per customer per hour once its transfer list holds all 66 accounts: a Prioritas balance lasts about
      10 hours between the 6-hourly top-ups, a Reguler balance would run out within the hour.
      Robot: every customer except ANDI.WIJAYA (presenter, reserved); the list is robot\customers.json. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @customers TABLE (CustomerId int NOT NULL PRIMARY KEY, UserId varchar(30) NOT NULL UNIQUE,
                          FullName nvarchar(100) NOT NULL, Tier varchar(10) NOT NULL);
INSERT INTO @customers (CustomerId, UserId, FullName, Tier) VALUES
    ( 1, 'ANDI.WIJAYA',       N'Andi Wijaya',       'Prioritas'),   -- presenter (reserved, never used by the robot); traffic generator
    ( 2, 'SITI.RAHAYU',       N'Siti Rahayu',       'Prioritas'),   -- traffic generator; robot
    ( 3, 'BUDI.SANTOSO',      N'Budi Santoso',      'Prioritas'),   -- traffic generator and probe; robot
    ( 4, 'AGUS.SETIAWAN',     N'Agus Setiawan',     'Reguler'),
    ( 5, 'RINA.KURNIAWATI',   N'Rina Kurniawati',   'Reguler'),
    ( 6, 'DEDI.SUPRIADI',     N'Dedi Supriadi',     'Reguler'),
    ( 7, 'KEVIN.HALIM',       N'Kevin Halim',       'Prioritas'),
    ( 8, 'PUTRI.ANGGRAINI',   N'Putri Anggraini',   'Reguler'),
    ( 9, 'HENDRA.SAPUTRA',    N'Hendra Saputra',    'Reguler'),
    (10, 'YULIANA.SARI',      N'Yuliana Sari',      'Reguler'),
    (11, 'BAMBANG.SUTRISNO',  N'Bambang Sutrisno',  'Reguler'),
    (12, 'HARYANTO.TJAHJADI', N'Haryanto Tjahjadi', 'Solitaire'),
    (13, 'NURUL.HIDAYAH',     N'Nurul Hidayah',     'Reguler'),
    (14, 'IWAN.KURNIAWAN',    N'Iwan Kurniawan',    'Reguler'),
    (15, 'MELINDA.KUSNADI',   N'Melinda Kusnadi',   'Prioritas'),
    (16, 'FITRI.HANDAYANI',   N'Fitri Handayani',   'Reguler'),
    (17, 'FAJAR.NUGROHO',     N'Fajar Nugroho',     'Reguler'),
    (18, 'MAYA.PUSPITASARI',  N'Maya Puspitasari',  'Reguler'),
    (19, 'ASEP.SURYANA',      N'Asep Suryana',      'Reguler'),
    (20, 'ANISA.RAHMAWATI',   N'Anisa Rahmawati',   'Reguler'),
    (21, 'DANIEL.SIREGAR',    N'Daniel Siregar',    'Prioritas'),
    (22, 'YOGA.PRATAMA',      N'Yoga Pratama',      'Reguler'),
    (23, 'INDAH.WULANDARI',   N'Indah Wulandari',   'Reguler'),
    (24, 'RIZKY.FIRMANSYAH',  N'Rizky Firmansyah',  'Reguler'),
    (25, 'MARIA.SITUMORANG',  N'Maria Situmorang',  'Reguler'),
    (26, 'LIDIA.SOETANTO',    N'Lidia Soetanto',    'Solitaire'),
    (27, 'MADE.SUDARSANA',    N'Made Sudarsana',    'Reguler'),
    (28, 'WIDYA.ASTUTI',      N'Widya Astuti',      'Reguler'),
    (29, 'RIZAL.CHANIAGO',    N'Rizal Chaniago',    'Reguler'),
    (30, 'RATNA.KOMALASARI',  N'Ratna Komalasari',  'Prioritas'),
    (31, 'GRACE.PANGEMANAN',  N'Grace Pangemanan',  'Reguler'),
    (32, 'TEGUH.WIBOWO',      N'Teguh Wibowo',      'Reguler'),
    (33, 'DIAN.PRATIWI',      N'Dian Pratiwi',      'Reguler');

-- Stop without any change if a customer number or User ID of this list already belongs to another customer.
IF EXISTS (SELECT 1 FROM dbo.Customers c JOIN @customers s
           ON (c.CustomerId = s.CustomerId AND c.UserId <> s.UserId) OR (c.UserId = s.UserId AND c.CustomerId <> s.CustomerId))
    THROW 50001, 'A customer number or User ID of 02-p1-tiers-customers.sql is already used by another customer: nothing was changed.', 1;

DECLARE @newAccounts TABLE (AccountNo char(10) NOT NULL PRIMARY KEY);
BEGIN TRANSACTION;
MERGE dbo.Customers AS t
USING @customers AS s
ON t.CustomerId = s.CustomerId
WHEN MATCHED AND t.Tier <> s.Tier THEN UPDATE SET Tier = s.Tier
WHEN NOT MATCHED THEN INSERT (CustomerId, UserId, FullName, Tier) VALUES (s.CustomerId, s.UserId, s.FullName, s.Tier);

-- 2 accounts per customer; existing account numbers are kept as they are
MERGE dbo.Accounts AS t
USING (SELECT '990100' + RIGHT('00' + CAST(c.CustomerId AS varchar(3)), 3) + p.Suffix AS AccountNo, c.CustomerId, p.ProductName
       FROM @customers c
       CROSS JOIN (VALUES ('1', N'Tabungan Demo'), ('2', N'Giro Demo')) AS p (Suffix, ProductName)) AS s
ON t.AccountNo = s.AccountNo
WHEN NOT MATCHED THEN INSERT (AccountNo, CustomerId, ProductName, Balance) VALUES (s.AccountNo, s.CustomerId, s.ProductName, 0)
OUTPUT inserted.AccountNo INTO @newAccounts (AccountNo);

-- new accounts start at their tier balance
UPDATE a SET a.Balance = v.TargetBalance
FROM dbo.Accounts AS a
JOIN @newAccounts AS n ON n.AccountNo = a.AccountNo
JOIN dbo.DemoBalanceTargets AS v ON v.AccountNo = a.AccountNo;
COMMIT TRANSACTION;
GO
/* 4. Check (sqlcmd prints it; with Invoke-SqlFile run the check query of P1-DC-DEPLOY.md): Reguler 24 / 48 accounts,
      Prioritas 7 / 14 accounts, Solitaire 2 / 4 accounts */
SELECT c.Tier, COUNT(DISTINCT c.CustomerId) AS Customers, COUNT(a.AccountNo) AS Accounts
FROM dbo.Customers c LEFT JOIN dbo.Accounts a ON a.CustomerId = c.CustomerId
GROUP BY c.Tier ORDER BY c.Tier;
GO
