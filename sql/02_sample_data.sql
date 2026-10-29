-- Sample data. Run once, right after 01_create_tables.sql.
-- Account ids are looked up by e-mail, so the script does not depend on
-- the sequence start values.

INSERT INTO customers(customer_id, full_name, email, phone, city)
VALUES (customer_seq.NEXTVAL, 'Aarav Sharma', 'aarav@example.com', '9876500001', 'Delhi');

INSERT INTO customers(customer_id, full_name, email, phone, city)
VALUES (customer_seq.NEXTVAL, 'Priya Verma', 'priya@example.com', '9876500002', 'Mumbai');

INSERT INTO customers(customer_id, full_name, email, phone, city)
VALUES (customer_seq.NEXTVAL, 'Rahul Singh', 'rahul@example.com', '9876500003', 'Pune');

INSERT INTO accounts(account_id, customer_id, account_type, balance)
VALUES (account_seq.NEXTVAL,
        (SELECT customer_id FROM customers WHERE email = 'aarav@example.com'),
        'SAVINGS', 25000);

INSERT INTO accounts(account_id, customer_id, account_type, balance)
VALUES (account_seq.NEXTVAL,
        (SELECT customer_id FROM customers WHERE email = 'priya@example.com'),
        'CURRENT', 50000);

INSERT INTO accounts(account_id, customer_id, account_type, balance)
VALUES (account_seq.NEXTVAL,
        (SELECT customer_id FROM customers WHERE email = 'rahul@example.com'),
        'SAVINGS', 15000);

-- Opening-balance entries so that SUM(ledger) = balance from day one
INSERT INTO bank_transactions(transaction_id, account_id, transaction_type, amount, description)
SELECT transaction_seq.NEXTVAL, account_id, 'DEPOSIT', balance, 'Opening balance'
FROM accounts WHERE balance > 0;

COMMIT;
