# BANK ACCOUNT & TRANSACTION MANAGEMENT SYSTEM USING PL/SQL

## Abstract
The Bank Account & Transaction Management System is an Oracle database
mini-project developed to demonstrate SQL and PL/SQL programming. The system
stores customer, account and transaction information and provides controlled
operations for deposits, withdrawals, transfers, balance enquiries and
transaction reporting. An interactive web dashboard runs the same rules in a
browser so the system can be demonstrated and tested visually.

## 1. Introduction
Manual banking records are difficult to maintain and can lead to inconsistent
balances and transaction records. This project demonstrates how an Oracle
database can automate common banking operations using PL/SQL.

## 2. Objectives
- Maintain customer records.
- Create and manage bank accounts (active, blocked, closed).
- Perform deposits and withdrawals.
- Transfer money between accounts safely.
- Display current balance.
- Calculate simple interest.
- Maintain transaction history.
- Audit balance changes automatically.
- Keep every balance equal to the sum of its ledger entries.
- Demonstrate exception handling and transaction control.

## 3. Software Requirements
Oracle Database, Oracle SQL Developer/SQL*Plus/Oracle Live SQL. A web browser
for the dashboard (`web/index.html`).

## 4. Database Tables
### CUSTOMERS
Stores customer identity and contact details. E-mail is unique and format checked.

### ACCOUNTS
Stores account number, customer, account type, balance and status.

### BANK_TRANSACTIONS
Stores deposits, withdrawals and transfer entries. `related_account_id` points
to the other side of a transfer.

### LOANS
Reserved for the loan extension module.

### AUDIT_LOG
Stores automatic account-opening and balance-change records.

See `ER_Diagram.svg` for the relationships.

## 5. PL/SQL Objects
### Procedures
- create_customer
- create_account
- deposit
- withdraw
- transfer
- change_account_status
- print_transaction_history
- print_customer_summary

### Functions
- get_balance
- calculate_interest

### Package
BANK_PKG groups the banking operations into one reusable interface. A private
helper, `check_amount`, validates every money amount in one place.

### Cursors
Cursor FOR loops are used for transaction history, customer summaries and for
locking both rows of a transfer.

### Triggers
- TRG_ACCOUNT_AUDIT records account opening and every real balance change.
- TRG_TRANSACTION_VALIDATE validates transaction amounts.

### Views
- ACCOUNT_SUMMARY, TRANSACTION_REPORT
- BALANCE_RECONCILIATION (balance minus ledger total; must be zero)

## 6. Transaction Handling
Deposit, withdrawal and transfer use COMMIT after success and ROLLBACK on every
error path, which also releases row locks. A transfer locks both accounts in
ascending `account_id` order, so two opposite transfers cannot deadlock, and
either both sides are written or neither.

## 7. Exception Handling
Errors use RAISE_APPLICATION_ERROR with fixed codes:

| Code | Meaning |
|------|---------|
| -20001 | E-mail already exists |
| -20002 | Customer does not exist |
| -20003 | Invalid account type |
| -20004 | Negative initial deposit |
| -20005 / -20008 / -20013 | Deposit / withdrawal / transfer amount invalid (NULL, zero, negative) |
| -20006 / -20009 / -20014 | Account not active |
| -20007 / -20011 / -20018 | Account / source account not found |
| -20010 / -20015 | Insufficient balance |
| -20012 | Source and destination are the same |
| -20016 | Destination not found or inactive |
| -20017 | More than 2 decimal places |
| -20019 | Customer name or e-mail missing |
| -20020 | Invalid interest rate |
| -20021 / -20022 / -20023 | Invalid status / account not found / cannot close with balance |

## 8. Web Dashboard
`web/index.html` (Bank Ledger Console) shows accounts, a form for each
procedure, the generated PL/SQL call, a console that prints DBMS_OUTPUT text
and ORA errors, the transaction ledger, the audit log and a live check that
balances match the ledger. Ten "viva scenario" buttons run the test cases.

## 9. Testing
Test cases:
1. Valid deposit -> balance increases.
2. Valid withdrawal -> balance decreases.
3. Withdrawal greater than balance -> rejected (-20010).
4. Valid transfer -> source decreases and destination increases.
5. Transfer to inactive/nonexistent account -> rolled back (-20016).
6. Transfer from a nonexistent account -> -20018.
7. Negative or NULL amount -> rejected (-20005 / -20008 / -20013).
8. Amount with 3 decimals -> rejected (-20017).
9. Duplicate customer e-mail, in any letter case -> rejected (-20001).
10. Blocked account -> deposit rejected (-20006).
11. Balance update -> audit record generated.
12. `balance_reconciliation` returns no rows with a difference.

## 10. Future Scope
- Secure user authentication.
- Password hashing.
- Interest posting by scheduled job.
- Loan repayment module.
- ATM integration.
- Connecting the dashboard to Oracle through a REST layer (Oracle REST Data Services).
- Role-based access control.
- More detailed compliance/audit reporting.

## 11. Conclusion
The project demonstrates how SQL and PL/SQL can be combined to build a reliable
database-centric banking transaction system. It covers procedures, functions,
cursors, packages, triggers, exception handling, constraints, locking and
transaction control, and adds a visual dashboard for demonstration.
