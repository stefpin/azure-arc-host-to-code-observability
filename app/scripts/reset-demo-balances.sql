/* Optional: restore the seed balances of ALL demo accounts (Transfers rows and the Oracle ledger are not touched).
   v1.4: the seed balance of every account is its tier balance (view dbo.DemoBalanceTargets, created by
   db\sqlserver\02-p1-tiers-customers.sql), so this sets the same values as topup-demo-balances.sql for all 66 accounts of
   the 33 customers. The v1.2 seed values of the 3 original customers are no longer used: they are Prioritas customers now and
   the traffic generator needs their larger balance.
   Run on APP-SQL: Invoke-SqlFile C:\Build\minibank\scripts\reset-demo-balances.sql -Database MiniBankDemo (helper from runbook Chapter 14.1),
   or sqlcmd -S localhost -E -b -d MiniBankDemo -i C:\Build\minibank\scripts\reset-demo-balances.sql */
SET NOCOUNT ON;
USE MiniBankDemo;
UPDATE a SET a.Balance = v.TargetBalance
FROM dbo.Accounts AS a
JOIN dbo.DemoBalanceTargets AS v ON v.AccountNo = a.AccountNo;
SELECT c.Tier, COUNT(*) AS Accounts, SUM(a.Balance) AS TotalBalance
FROM dbo.Accounts AS a JOIN dbo.Customers AS c ON c.CustomerId = a.CustomerId
GROUP BY c.Tier ORDER BY c.Tier;
