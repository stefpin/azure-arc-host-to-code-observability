/* MiniBank SQL Server database (APP-SQL, SQL Server 2022 Developer, default instance).
   Run on APP-SQL in PowerShell as Administrator with the Invoke-SqlFile helper from runbook Chapter 14.1:
     Invoke-SqlFile C:\Build\minibank\db\sqlserver\01-minibank-db.sql
   (or, if sqlcmd is installed: sqlcmd -S localhost -E -b -i C:\Build\minibank\db\sqlserver\01-minibank-db.sql)
   Prerequisite: local Windows account APP-SQL\minibank-svc with the SAME password as minibank-svc on APP-WIN
   (mirrored account; the IIS app pool of minibank-api runs as minibank-svc). Safe to run again. */
IF DB_ID(N'MiniBankDemo') IS NULL CREATE DATABASE MiniBankDemo;
GO
USE MiniBankDemo;
GO
IF OBJECT_ID(N'dbo.Customers') IS NULL
CREATE TABLE dbo.Customers (
    CustomerId int           NOT NULL PRIMARY KEY,
    UserId      varchar(30)   NOT NULL UNIQUE,
    FullName   nvarchar(100) NOT NULL);
IF OBJECT_ID(N'dbo.Accounts') IS NULL
CREATE TABLE dbo.Accounts (
    AccountNo   char(10)      NOT NULL PRIMARY KEY,
    CustomerId  int           NOT NULL REFERENCES dbo.Customers (CustomerId),
    ProductName nvarchar(50)  NOT NULL,
    Balance     decimal(18,2) NOT NULL);
IF OBJECT_ID(N'dbo.Transfers') IS NULL
CREATE TABLE dbo.Transfers (
    Id          bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
    ReferenceNo varchar(20)   NOT NULL UNIQUE,      -- MB + yyMMddHHmmss (WIB) + 4 random digits
    FromAccount char(10)      NOT NULL,
    ToAccount   char(10)      NULL,                 -- Transfer only
    MerchantId  varchar(20)   NULL,                 -- QRIS only
    Amount      decimal(18,2) NOT NULL,
    Channel     varchar(10)   NOT NULL,             -- TRANSFER or QRIS
    Scenario    varchar(20)   NOT NULL,
    Status      varchar(10)   NOT NULL,             -- PENDING, SUCCESS or FAILED
    CreatedAt   datetime2(3)  NOT NULL DEFAULT SYSUTCDATETIME(),
    TraceId     varchar(32)   NULL);                -- W3C trace ID = Application Insights operation ID
GO
/* 3 synthetic customers with 2 accounts each (demo password Demo123! is checked by the API, not stored here) */
MERGE dbo.Customers AS t
USING (VALUES (1, 'ANDI.WIJAYA',  N'Andi Wijaya'),
              (2, 'SITI.RAHAYU',  N'Siti Rahayu'),
              (3, 'BUDI.SANTOSO', N'Budi Santoso')) AS s (CustomerId, UserId, FullName)
ON t.CustomerId = s.CustomerId
WHEN NOT MATCHED THEN INSERT (CustomerId, UserId, FullName) VALUES (s.CustomerId, s.UserId, s.FullName);
MERGE dbo.Accounts AS t
USING (VALUES ('9901000011', 1, N'Tabungan Demo', 125750000.00),
              ('9901000012', 1, N'Giro Demo',      15250000.00),
              ('9901000021', 2, N'Tabungan Demo',  87500000.00),
              ('9901000022', 2, N'Giro Demo',       7800000.00),
              ('9901000031', 3, N'Tabungan Demo', 210000000.00),
              ('9901000032', 3, N'Giro Demo',      32400000.00)) AS s (AccountNo, CustomerId, ProductName, Balance)
ON t.AccountNo = s.AccountNo
WHEN NOT MATCHED THEN INSERT (AccountNo, CustomerId, ProductName, Balance)
                      VALUES (s.AccountNo, s.CustomerId, s.ProductName, s.Balance);
GO
/* Windows login for the mirrored local account (NOT APP-WIN\minibank-svc) */
USE master;
IF SUSER_ID(N'APP-SQL\minibank-svc') IS NULL
    CREATE LOGIN [APP-SQL\minibank-svc] FROM WINDOWS WITH DEFAULT_DATABASE = MiniBankDemo;
GO
USE MiniBankDemo;
IF USER_ID(N'minibank-svc') IS NULL
    CREATE USER [minibank-svc] FOR LOGIN [APP-SQL\minibank-svc];
ALTER ROLE db_datareader ADD MEMBER [minibank-svc];
ALTER ROLE db_datawriter ADD MEMBER [minibank-svc];
GO
SELECT c.UserId, a.AccountNo, a.ProductName, a.Balance
FROM dbo.Accounts a JOIN dbo.Customers c ON c.CustomerId = a.CustomerId ORDER BY a.AccountNo;
GO
