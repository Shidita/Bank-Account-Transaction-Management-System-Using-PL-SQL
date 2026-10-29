-- BANK ACCOUNT & TRANSACTION MANAGEMENT SYSTEM
-- Oracle SQL / PL/SQL Mini Project
-- Run as a normal Oracle user/schema.
-- Re-running? Run 07_reset.sql first, otherwise you get ORA-00955.

CREATE TABLE customers (
    customer_id NUMBER PRIMARY KEY,
    full_name   VARCHAR2(100) NOT NULL,
    email       VARCHAR2(120) NOT NULL,
    phone       VARCHAR2(20),
    city        VARCHAR2(60),
    created_at  DATE DEFAULT SYSDATE NOT NULL,
    CONSTRAINT uq_customer_email UNIQUE (email),
    CONSTRAINT chk_customer_email CHECK (REGEXP_LIKE(email, '^[^@ ]+@[^@ ]+\.[^@ ]+$'))
);

CREATE TABLE accounts (
    account_id   NUMBER PRIMARY KEY,
    customer_id  NUMBER NOT NULL,
    account_type VARCHAR2(20) NOT NULL,
    balance      NUMBER(15,2) DEFAULT 0 NOT NULL,
    status       VARCHAR2(15) DEFAULT 'ACTIVE' NOT NULL,
    opened_at    DATE DEFAULT SYSDATE NOT NULL,
    CONSTRAINT fk_account_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    CONSTRAINT chk_account_type    CHECK (account_type IN ('SAVINGS','CURRENT')),
    CONSTRAINT chk_account_balance CHECK (balance >= 0),
    CONSTRAINT chk_account_status  CHECK (status IN ('ACTIVE','BLOCKED','CLOSED'))
);

CREATE TABLE bank_transactions (
    transaction_id     NUMBER PRIMARY KEY,
    account_id         NUMBER NOT NULL,
    transaction_type   VARCHAR2(20) NOT NULL,
    amount             NUMBER(15,2) NOT NULL,
    transaction_date   TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    description        VARCHAR2(250),
    related_account_id NUMBER,
    CONSTRAINT fk_tx_account FOREIGN KEY (account_id) REFERENCES accounts(account_id),
    CONSTRAINT fk_tx_related FOREIGN KEY (related_account_id) REFERENCES accounts(account_id),
    CONSTRAINT chk_tx_type   CHECK (transaction_type IN ('DEPOSIT','WITHDRAW','TRANSFER_IN','TRANSFER_OUT')),
    CONSTRAINT chk_tx_amount CHECK (amount > 0)
);

CREATE TABLE loans (
    loan_id       NUMBER PRIMARY KEY,
    customer_id   NUMBER NOT NULL,
    principal     NUMBER(15,2) NOT NULL,
    interest_rate NUMBER(5,2) NOT NULL,
    tenure_months NUMBER NOT NULL,
    outstanding   NUMBER(15,2) NOT NULL,
    status        VARCHAR2(15) DEFAULT 'ACTIVE' NOT NULL,
    CONSTRAINT fk_loan_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    CONSTRAINT chk_loan_status    CHECK (status IN ('ACTIVE','PAID','CLOSED')),
    CONSTRAINT chk_loan_principal CHECK (principal > 0),
    CONSTRAINT chk_loan_rate      CHECK (interest_rate >= 0),
    CONSTRAINT chk_loan_tenure    CHECK (tenure_months > 0),
    CONSTRAINT chk_loan_due       CHECK (outstanding >= 0)
);

CREATE TABLE audit_log (
    audit_id    NUMBER PRIMARY KEY,
    account_id  NUMBER,
    action_type VARCHAR2(50),
    old_balance NUMBER(15,2),
    new_balance NUMBER(15,2),
    action_time TIMESTAMP DEFAULT SYSTIMESTAMP,
    details     VARCHAR2(250)
);

-- Indexes on foreign keys / frequent filters
CREATE INDEX idx_accounts_customer ON accounts(customer_id);
CREATE INDEX idx_tx_account_date   ON bank_transactions(account_id, transaction_date);
CREATE INDEX idx_loans_customer    ON loans(customer_id);
CREATE INDEX idx_audit_account     ON audit_log(account_id);

CREATE SEQUENCE customer_seq    START WITH 1001 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE account_seq     START WITH 2001 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE transaction_seq START WITH 5001 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE loan_seq        START WITH 7001 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE audit_seq       START WITH 9001 INCREMENT BY 1 NOCACHE;
