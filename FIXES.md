# Bugs found and fixed

| # | Where | Problem | Fix |
|---|-------|---------|-----|
| 1 | deposit / withdraw / transfer | `IF p_amount <= 0` is not true for `NULL`, so a NULL amount passed validation and failed later with a raw `ORA-01407`. | Private `check_amount` rejects NULL, zero and negative values (-20005 / -20008 / -20013). |
| 2 | all amount inputs | `10.005` was accepted; the column rounds it but the balance arithmetic did not match. | More than 2 decimals is rejected with -20017. |
| 3 | transfer | `WHEN NO_DATA_FOUND` caught a missing **source** account and reported "Destination account not found". | Both rows are read once; separate errors -20018 (source) and -20016 (destination). |
| 4 | transfer | Source row was locked first, destination second. Two opposite transfers (A to B and B to A) could deadlock (ORA-00060). | Both rows are locked together, ordered by `account_id`. |
| 5 | deposit / withdraw | After an error the `FOR UPDATE` lock stayed until the caller ended the transaction. | `WHEN OTHERS THEN ROLLBACK; RAISE;` releases the lock. |
| 6 | create_account | The initial deposit changed the balance but no `DEPOSIT` row was written, so balance and ledger disagreed. | An "Opening balance" transaction is inserted. Sample data does the same. |
| 7 | create_account | `NULL` initial deposit slipped through (`NULL < 0` is not true). | `NVL(p_initial_deposit, 0)`; parameter now defaults to 0. |
| 8 | create_customer | `Aarav@Example.com` and `aarav@example.com` were treated as different customers. Blank name/e-mail gave raw ORA-01400. | E-mail is trimmed and lower-cased; name/e-mail required (-20019). |
| 9 | INSERT statements | `INSERT INTO bank_transactions VALUES (...)` relied on column order. | Explicit column lists. |
| 10 | trg_account_audit | Fired for updates that changed nothing, and never recorded a new account. | Logs `ACCOUNT_OPENED` on insert; logs `BALANCE_CHANGE` only if the balance really changed. |
| 11 | sample data | Hard-coded customer ids 1001-1003; breaks if sequences differ. | Customer ids are looked up by e-mail. |
| 12 | 01_create_tables | `loans.status` was nullable; no checks on principal, rate, tenure; no e-mail format check; no indexes; `related_account_id` had no foreign key; sequences cached (gaps after restart). | Constraints, indexes and `NOCACHE` added. |
| 13 | print_transaction_history | Ordered by timestamp only, so same-second rows (the two sides of a transfer) could swap. `TO_CHAR` format overflowed to `####` above 9,999,999.99. | `ORDER BY transaction_date, transaction_id`; wider format with thousands separators. |
| 14 | 07_reset | `WHEN OTHERS THEN NULL` hid every error, even real ones. | Only "object does not exist" errors are ignored; others are printed. |
| 15 | calculate_interest | A negative or NULL rate returned nonsense. | Rejected with -20020. |
| 16 | 06_demo | A failing call stopped the whole demo script. | Error demos are wrapped so each prints "Expected: ORA-..." and the script continues. |

## Added
- `bank_pkg.change_account_status` (ACTIVE / BLOCKED / CLOSED; cannot close with balance > 0).
- View `balance_reconciliation` (balance minus ledger total, must be 0).
- `sql/00_run_all.sql`.
- `web/index.html`, the interactive dashboard.
- Redrawn `report/ER_Diagram.svg` showing all five tables and their relationships.

## Not tested
The Oracle scripts were reviewed line by line but could not be executed here
(no Oracle database in the workspace). Run `00_run_all.sql` once on your
schema; every "Expected:" line in the demo output should appear and
`SELECT * FROM balance_reconciliation WHERE difference <> 0` should return no rows.
The dashboard logic was run in a browser against all scenarios.
