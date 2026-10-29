-- Audit trigger: logs account opening and every real balance change.
CREATE OR REPLACE TRIGGER trg_account_audit
AFTER INSERT OR UPDATE OF balance ON accounts
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        INSERT INTO audit_log(audit_id, account_id, action_type, old_balance, new_balance, details)
        VALUES (audit_seq.NEXTVAL, :NEW.account_id, 'ACCOUNT_OPENED',
                NULL, :NEW.balance, 'Account opened');
    ELSIF :OLD.balance <> :NEW.balance THEN      -- skip updates that change nothing
        INSERT INTO audit_log(audit_id, account_id, action_type, old_balance, new_balance, details)
        VALUES (audit_seq.NEXTVAL, :NEW.account_id, 'BALANCE_CHANGE',
                :OLD.balance, :NEW.balance, 'Automatic balance audit');
    END IF;
END;
/

-- Safety net in addition to CHK_TX_AMOUNT; gives a friendlier message.
CREATE OR REPLACE TRIGGER trg_transaction_validate
BEFORE INSERT ON bank_transactions
FOR EACH ROW
BEGIN
    IF :NEW.amount IS NULL OR :NEW.amount <= 0 THEN
        RAISE_APPLICATION_ERROR(-20100, 'Transaction amount must be positive.');
    END IF;
END;
/
