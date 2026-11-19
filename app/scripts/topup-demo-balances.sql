/* MiniBank v1.4: top up ALL demo accounts to their tier balance (view dbo.DemoBalanceTargets, created by
   db\sqlserver\02-p1-tiers-customers.sql: Reguler accounts IDR 25-75 million, Prioritas Tabungan about IDR 1 billion,
   Solitaire Tabungan about IDR 10 billion; Giro accounts IDR 15-101 million). v1.3 listed the 6 accounts of the 3 original
   customers; v1.4 covers all 66 accounts of the 33 customers by tier. Run by the scheduled task minibank-topup on APP-SQL every
   6 hours (00:00, 06:00, 12:00 and 18:00 WIB) and by hand before a demo (Chapter 20.1). It only sets dbo.Accounts.Balance:
   Transfers rows and the Oracle ledger are not touched, so a top-up does not appear in the transaction history.
   The continuous load generator (ANDI, SITI, BUDI, all Prioritas) pays about IDR 100 million per customer per hour to the
   other customers and to QRIS merchants once its transfer list holds all 66 accounts, so their balance lasts about 10 hours.
   The last result set (AccountNo, Balance, Tier) is read by topup-demo-balances.ps1 for its log line. */
SET NOCOUNT ON;
UPDATE a SET a.Balance = v.TargetBalance
FROM dbo.Accounts AS a
JOIN dbo.DemoBalanceTargets AS v ON v.AccountNo = a.AccountNo;
SELECT a.AccountNo, a.Balance, c.Tier
FROM dbo.Accounts AS a JOIN dbo.Customers AS c ON c.CustomerId = a.CustomerId
ORDER BY a.AccountNo;
