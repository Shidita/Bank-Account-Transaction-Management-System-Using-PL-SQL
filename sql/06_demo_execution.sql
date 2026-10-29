SET SERVEROUTPUT ON;

PROMPT === 1. Normal operations ===
BEGIN
    bank_pkg.deposit(2001, 5000, 'Monthly savings');
    bank_pkg.withdraw(2002, 2500, 'ATM withdrawal');
    bank_pkg.transfer(2001, 2002, 3000);
END;
/

PROMPT === 2. Error handling (each block must print an expected error) ===
BEGIN
    bank_pkg.withdraw(2003, 999999, 'Too much');
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Expected: ' || SQLERRM);
END;
/
BEGIN
    bank_pkg.deposit(2001, NULL);
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Expected: ' || SQLERRM);
END;
/
BEGIN
    bank_pkg.deposit(2001, -50);
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Expected: ' || SQLERRM);
END;
/
BEGIN
    bank_pkg.deposit(2001, 10.005);
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Expected: ' || SQLERRM);
END;
/
BEGIN
    bank_pkg.transfer(2001, 9999, 100);      -- unknown destination
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Expected: ' || SQLERRM);
END;
/
BEGIN
    bank_pkg.transfer(9999, 2001, 100);      -- unknown source
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Expected: ' || SQLERRM);
END;
/
BEGIN
    bank_pkg.create_customer('Duplicate', 'AARAV@example.com', '1', 'X');   -- same e-mail, other case
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Expected: ' || SQLERRM);
END;
/

PROMPT === 3. Blocked account cannot be used ===
BEGIN
    bank_pkg.change_account_status(2003, 'BLOCKED');
    bank_pkg.deposit(2003, 100);
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Expected: ' || SQLERRM);
END;
/
BEGIN
    bank_pkg.change_account_status(2003, 'ACTIVE');
END;
/

PROMPT === 4. New customer with an account ===
BEGIN
    bank_pkg.create_customer('Neha Kapoor', 'neha@example.com', '9876500004', 'Jaipur');
    bank_pkg.create_account(customer_seq.CURRVAL, 'SAVINGS', 10000);
END;
/

PROMPT === 5. Reports ===
SELECT account_id, full_name, account_type, balance, status
FROM account_summary
ORDER BY account_id;

SELECT * FROM transaction_report ORDER BY transaction_date DESC, transaction_id DESC;

SELECT * FROM balance_reconciliation WHERE difference <> 0;   -- expect: no rows selected

SELECT * FROM audit_log ORDER BY audit_id;

BEGIN
    DBMS_OUTPUT.PUT_LINE('Balance of 2001 = ' || bank_pkg.get_balance(2001));
    DBMS_OUTPUT.PUT_LINE('5% interest on 2001 = ' || bank_pkg.calculate_interest(2001, 5));
    bank_pkg.print_transaction_history(2001);
    bank_pkg.print_customer_summary(1001);
END;
/
