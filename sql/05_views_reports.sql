CREATE OR REPLACE VIEW account_summary AS
SELECT a.account_id, c.customer_id, c.full_name, c.email,
       a.account_type, a.balance, a.status, a.opened_at
FROM accounts a JOIN customers c ON a.customer_id = c.customer_id;

CREATE OR REPLACE VIEW transaction_report AS
SELECT t.transaction_id, t.account_id, c.full_name, t.transaction_type,
       t.amount, t.transaction_date, t.description, t.related_account_id
FROM bank_transactions t
JOIN accounts a  ON t.account_id = a.account_id
JOIN customers c ON a.customer_id = c.customer_id;

-- Does every balance equal the sum of its ledger entries?  difference must be 0.
CREATE OR REPLACE VIEW balance_reconciliation AS
SELECT a.account_id, a.balance,
       NVL(SUM(CASE WHEN t.transaction_type IN ('DEPOSIT','TRANSFER_IN')  THEN  t.amount
                    WHEN t.transaction_type IN ('WITHDRAW','TRANSFER_OUT') THEN -t.amount
               END), 0) AS ledger_total,
       a.balance - NVL(SUM(CASE WHEN t.transaction_type IN ('DEPOSIT','TRANSFER_IN')  THEN  t.amount
                                WHEN t.transaction_type IN ('WITHDRAW','TRANSFER_OUT') THEN -t.amount
                           END), 0) AS difference
FROM accounts a
LEFT JOIN bank_transactions t ON t.account_id = a.account_id
GROUP BY a.account_id, a.balance;

-- Useful reports:
-- SELECT * FROM account_summary ORDER BY account_id;
-- SELECT * FROM transaction_report ORDER BY transaction_date DESC, transaction_id DESC;
-- SELECT account_type, COUNT(*), SUM(balance) FROM accounts GROUP BY account_type;
-- SELECT * FROM balance_reconciliation WHERE difference <> 0;   -- expect no rows
-- SELECT * FROM audit_log ORDER BY audit_id;
