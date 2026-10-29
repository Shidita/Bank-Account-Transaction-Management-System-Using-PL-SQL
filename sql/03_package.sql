-- BANK_PKG : all banking operations in one package.
-- Error codes used by RAISE_APPLICATION_ERROR:
--   -20001 email exists            -20012 same source/destination
--   -20002 customer not found      -20013 transfer amount invalid
--   -20003 bad account type        -20014 source not active
--   -20004 negative initial dep.   -20015 insufficient balance (transfer)
--   -20005 deposit amount invalid  -20016 destination not found / inactive
--   -20006 deposit: not active     -20017 more than 2 decimal places
--   -20007 deposit: not found      -20018 transfer: source not found
--   -20008 withdraw amt invalid    -20019 name / e-mail required
--   -20009 withdraw: not active    -20020 invalid interest rate
--   -20010 insufficient balance    -20021 invalid status
--   -20011 withdraw: not found     -20022 status change: account not found
--                                  -20023 cannot close, balance > 0

CREATE OR REPLACE PACKAGE bank_pkg AS
    PROCEDURE create_customer(
        p_name VARCHAR2, p_email VARCHAR2, p_phone VARCHAR2, p_city VARCHAR2
    );

    PROCEDURE create_account(
        p_customer_id NUMBER, p_account_type VARCHAR2, p_initial_deposit NUMBER DEFAULT 0
    );

    PROCEDURE deposit(
        p_account_id NUMBER, p_amount NUMBER, p_description VARCHAR2 DEFAULT 'Cash deposit'
    );

    PROCEDURE withdraw(
        p_account_id NUMBER, p_amount NUMBER, p_description VARCHAR2 DEFAULT 'Cash withdrawal'
    );

    PROCEDURE transfer(
        p_from_account NUMBER, p_to_account NUMBER, p_amount NUMBER
    );

    PROCEDURE change_account_status(p_account_id NUMBER, p_status VARCHAR2);

    FUNCTION get_balance(p_account_id NUMBER) RETURN NUMBER;
    FUNCTION calculate_interest(p_account_id NUMBER, p_rate NUMBER) RETURN NUMBER;

    PROCEDURE print_transaction_history(p_account_id NUMBER);
    PROCEDURE print_customer_summary(p_customer_id NUMBER);
END bank_pkg;
/

CREATE OR REPLACE PACKAGE BODY bank_pkg AS

    -- Private helper: rejects NULL, zero, negative and >2-decimal amounts.
    -- (A plain "p_amount <= 0" test lets NULL slip through, because
    --  NULL <= 0 is neither TRUE nor FALSE.)
    PROCEDURE check_amount(p_amount NUMBER, p_code NUMBER, p_label VARCHAR2) IS
    BEGIN
        IF p_amount IS NULL OR p_amount <= 0 THEN
            RAISE_APPLICATION_ERROR(p_code, p_label || ' amount must be greater than zero.');
        END IF;
        IF p_amount <> ROUND(p_amount, 2) THEN
            RAISE_APPLICATION_ERROR(-20017, 'Amount can have at most 2 decimal places.');
        END IF;
    END check_amount;

    PROCEDURE create_customer(
        p_name VARCHAR2, p_email VARCHAR2, p_phone VARCHAR2, p_city VARCHAR2
    ) IS
        v_email customers.email%TYPE := LOWER(TRIM(p_email));
    BEGIN
        IF TRIM(p_name) IS NULL OR v_email IS NULL THEN
            RAISE_APPLICATION_ERROR(-20019, 'Customer name and e-mail are required.');
        END IF;

        INSERT INTO customers(customer_id, full_name, email, phone, city)
        VALUES (customer_seq.NEXTVAL, TRIM(p_name), v_email, p_phone, p_city);
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Customer created successfully.');
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20001, 'Email already exists.');
    END create_customer;

    PROCEDURE create_account(
        p_customer_id NUMBER, p_account_type VARCHAR2, p_initial_deposit NUMBER DEFAULT 0
    ) IS
        v_count      NUMBER;
        v_account_id accounts.account_id%TYPE;
        v_deposit    NUMBER := NVL(p_initial_deposit, 0);
    BEGIN
        SELECT COUNT(*) INTO v_count FROM customers WHERE customer_id = p_customer_id;
        IF v_count = 0 THEN
            RAISE_APPLICATION_ERROR(-20002, 'Customer does not exist.');
        END IF;

        IF UPPER(TRIM(p_account_type)) IS NULL
           OR UPPER(TRIM(p_account_type)) NOT IN ('SAVINGS','CURRENT') THEN
            RAISE_APPLICATION_ERROR(-20003, 'Account type must be SAVINGS or CURRENT.');
        END IF;

        IF v_deposit < 0 THEN
            RAISE_APPLICATION_ERROR(-20004, 'Initial deposit cannot be negative.');
        END IF;
        IF v_deposit <> ROUND(v_deposit, 2) THEN
            RAISE_APPLICATION_ERROR(-20017, 'Amount can have at most 2 decimal places.');
        END IF;

        INSERT INTO accounts(account_id, customer_id, account_type, balance)
        VALUES (account_seq.NEXTVAL, p_customer_id, UPPER(TRIM(p_account_type)), v_deposit)
        RETURNING account_id INTO v_account_id;

        -- The opening balance must appear in the ledger too.
        IF v_deposit > 0 THEN
            INSERT INTO bank_transactions(transaction_id, account_id, transaction_type,
                                          amount, transaction_date, description)
            VALUES (transaction_seq.NEXTVAL, v_account_id, 'DEPOSIT',
                    v_deposit, SYSTIMESTAMP, 'Opening balance');
        END IF;

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Account ' || v_account_id || ' created successfully.');
    END create_account;

    PROCEDURE deposit(
        p_account_id NUMBER, p_amount NUMBER, p_description VARCHAR2 DEFAULT 'Cash deposit'
    ) IS
        v_status accounts.status%TYPE;
    BEGIN
        check_amount(p_amount, -20005, 'Deposit');

        SELECT status INTO v_status FROM accounts
        WHERE account_id = p_account_id FOR UPDATE;

        IF v_status <> 'ACTIVE' THEN
            RAISE_APPLICATION_ERROR(-20006, 'Account is not active.');
        END IF;

        UPDATE accounts SET balance = balance + p_amount WHERE account_id = p_account_id;

        INSERT INTO bank_transactions(transaction_id, account_id, transaction_type,
                                      amount, transaction_date, description, related_account_id)
        VALUES (transaction_seq.NEXTVAL, p_account_id, 'DEPOSIT',
                p_amount, SYSTIMESTAMP, p_description, NULL);

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Deposit successful.');
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20007, 'Account not found.');
        WHEN OTHERS THEN
            ROLLBACK;          -- release the row lock
            RAISE;
    END deposit;

    PROCEDURE withdraw(
        p_account_id NUMBER, p_amount NUMBER, p_description VARCHAR2 DEFAULT 'Cash withdrawal'
    ) IS
        v_balance accounts.balance%TYPE;
        v_status  accounts.status%TYPE;
    BEGIN
        check_amount(p_amount, -20008, 'Withdrawal');

        SELECT balance, status INTO v_balance, v_status
        FROM accounts WHERE account_id = p_account_id FOR UPDATE;

        IF v_status <> 'ACTIVE' THEN
            RAISE_APPLICATION_ERROR(-20009, 'Account is not active.');
        END IF;

        IF v_balance < p_amount THEN
            RAISE_APPLICATION_ERROR(-20010, 'Insufficient balance.');
        END IF;

        UPDATE accounts SET balance = balance - p_amount WHERE account_id = p_account_id;

        INSERT INTO bank_transactions(transaction_id, account_id, transaction_type,
                                      amount, transaction_date, description, related_account_id)
        VALUES (transaction_seq.NEXTVAL, p_account_id, 'WITHDRAW',
                p_amount, SYSTIMESTAMP, p_description, NULL);

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Withdrawal successful.');
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20011, 'Account not found.');
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END withdraw;

    PROCEDURE transfer(
        p_from_account NUMBER, p_to_account NUMBER, p_amount NUMBER
    ) IS
        v_from_found  BOOLEAN := FALSE;
        v_to_found    BOOLEAN := FALSE;
        v_from_bal    accounts.balance%TYPE;
        v_from_status accounts.status%TYPE;
        v_to_status   accounts.status%TYPE;
    BEGIN
        IF p_from_account = p_to_account THEN
            RAISE_APPLICATION_ERROR(-20012, 'Source and destination accounts must differ.');
        END IF;

        check_amount(p_amount, -20013, 'Transfer');

        -- Lock BOTH rows in ascending account_id order. Two opposite transfers
        -- (A->B and B->A) therefore queue up instead of deadlocking.
        FOR r IN (SELECT account_id, balance, status
                  FROM accounts
                  WHERE account_id IN (p_from_account, p_to_account)
                  ORDER BY account_id
                  FOR UPDATE) LOOP
            IF r.account_id = p_from_account THEN
                v_from_found  := TRUE;
                v_from_bal    := r.balance;
                v_from_status := r.status;
            ELSE
                v_to_found  := TRUE;
                v_to_status := r.status;
            END IF;
        END LOOP;

        -- Each failure now has its own, correct message.
        IF NOT v_from_found THEN
            RAISE_APPLICATION_ERROR(-20018, 'Source account not found.');
        END IF;
        IF v_from_status <> 'ACTIVE' THEN
            RAISE_APPLICATION_ERROR(-20014, 'Source account is not active.');
        END IF;
        IF NOT v_to_found OR v_to_status <> 'ACTIVE' THEN
            RAISE_APPLICATION_ERROR(-20016, 'Destination account not found or inactive.');
        END IF;
        IF v_from_bal < p_amount THEN
            RAISE_APPLICATION_ERROR(-20015, 'Insufficient balance for transfer.');
        END IF;

        UPDATE accounts SET balance = balance - p_amount WHERE account_id = p_from_account;
        UPDATE accounts SET balance = balance + p_amount WHERE account_id = p_to_account;

        INSERT INTO bank_transactions(transaction_id, account_id, transaction_type,
                                      amount, transaction_date, description, related_account_id)
        VALUES (transaction_seq.NEXTVAL, p_from_account, 'TRANSFER_OUT', p_amount, SYSTIMESTAMP,
                'Transfer to account ' || p_to_account, p_to_account);

        INSERT INTO bank_transactions(transaction_id, account_id, transaction_type,
                                      amount, transaction_date, description, related_account_id)
        VALUES (transaction_seq.NEXTVAL, p_to_account, 'TRANSFER_IN', p_amount, SYSTIMESTAMP,
                'Transfer from account ' || p_from_account, p_from_account);

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Transfer successful.');
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;          -- all-or-nothing: no half transfer is ever kept
            RAISE;
    END transfer;

    PROCEDURE change_account_status(p_account_id NUMBER, p_status VARCHAR2) IS
        v_status  VARCHAR2(15) := UPPER(TRIM(p_status));
        v_balance accounts.balance%TYPE;
    BEGIN
        IF v_status IS NULL OR v_status NOT IN ('ACTIVE','BLOCKED','CLOSED') THEN
            RAISE_APPLICATION_ERROR(-20021, 'Status must be ACTIVE, BLOCKED or CLOSED.');
        END IF;

        SELECT balance INTO v_balance FROM accounts
        WHERE account_id = p_account_id FOR UPDATE;

        IF v_status = 'CLOSED' AND v_balance > 0 THEN
            RAISE_APPLICATION_ERROR(-20023, 'Withdraw the remaining balance before closing the account.');
        END IF;

        UPDATE accounts SET status = v_status WHERE account_id = p_account_id;
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Account ' || p_account_id || ' is now ' || v_status || '.');
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20022, 'Account not found.');
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END change_account_status;

    FUNCTION get_balance(p_account_id NUMBER) RETURN NUMBER IS
        v_balance NUMBER;
    BEGIN
        SELECT balance INTO v_balance FROM accounts WHERE account_id = p_account_id;
        RETURN v_balance;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END get_balance;

    -- Simple interest for ONE year: balance * rate / 100
    FUNCTION calculate_interest(p_account_id NUMBER, p_rate NUMBER) RETURN NUMBER IS
        v_balance NUMBER;
    BEGIN
        IF p_rate IS NULL OR p_rate < 0 THEN
            RAISE_APPLICATION_ERROR(-20020, 'Interest rate must be zero or more.');
        END IF;
        v_balance := get_balance(p_account_id);
        IF v_balance IS NULL THEN
            RETURN NULL;
        END IF;
        RETURN ROUND(v_balance * p_rate / 100, 2);
    END calculate_interest;

    PROCEDURE print_transaction_history(p_account_id NUMBER) IS
        CURSOR c_tx IS
            SELECT transaction_id, transaction_type, amount, transaction_date, description
            FROM bank_transactions
            WHERE account_id = p_account_id
            ORDER BY transaction_date, transaction_id;
        v_found BOOLEAN := FALSE;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('--- Transaction History: ' || p_account_id || ' ---');
        FOR r IN c_tx LOOP
            v_found := TRUE;
            DBMS_OUTPUT.PUT_LINE(
                r.transaction_id || ' | ' || RPAD(r.transaction_type, 12) || ' | ' ||
                LPAD(TO_CHAR(r.amount, 'FM999,999,999,999,990.00'), 16) || ' | ' ||
                TO_CHAR(r.transaction_date, 'DD-MON-YYYY HH24:MI') || ' | ' ||
                NVL(r.description, '-')
            );
        END LOOP;
        IF NOT v_found THEN
            DBMS_OUTPUT.PUT_LINE('No transactions found.');
        END IF;
    END print_transaction_history;

    PROCEDURE print_customer_summary(p_customer_id NUMBER) IS
        CURSOR c_accounts IS
            SELECT account_id, account_type, balance, status
            FROM accounts WHERE customer_id = p_customer_id ORDER BY account_id;
        v_name  customers.full_name%TYPE;
        v_total NUMBER := 0;
        v_found BOOLEAN := FALSE;
    BEGIN
        SELECT full_name INTO v_name FROM customers WHERE customer_id = p_customer_id;
        DBMS_OUTPUT.PUT_LINE('Customer: ' || v_name);
        DBMS_OUTPUT.PUT_LINE('--------------------------------');
        FOR r IN c_accounts LOOP
            v_found := TRUE;
            v_total := v_total + r.balance;
            DBMS_OUTPUT.PUT_LINE(
                r.account_id || ' | ' || RPAD(r.account_type, 7) || ' | Balance: ' ||
                TO_CHAR(r.balance, 'FM999,999,999,999,990.00') || ' | ' || r.status
            );
        END LOOP;
        IF v_found THEN
            DBMS_OUTPUT.PUT_LINE('Total balance: ' || TO_CHAR(v_total, 'FM999,999,999,999,990.00'));
        ELSE
            DBMS_OUTPUT.PUT_LINE('This customer has no accounts yet.');
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Customer not found.');
    END print_customer_summary;
END bank_pkg;
/
