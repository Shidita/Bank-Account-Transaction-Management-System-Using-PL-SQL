-- Run only if you want to remove ALL project objects (then start again at 01).
-- Only "object does not exist" errors are ignored; anything else is shown.

DECLARE
    PROCEDURE drop_it(p_sql VARCHAR2) IS
    BEGIN
        EXECUTE IMMEDIATE p_sql;
    EXCEPTION
        WHEN OTHERS THEN
            -- 942 table/view, 4043 object, 2289 sequence, 4080 trigger: already gone
            IF SQLCODE NOT IN (-942, -4043, -2289, -4080) THEN
                DBMS_OUTPUT.PUT_LINE('Could not run: ' || p_sql || ' -> ' || SQLERRM);
            END IF;
    END drop_it;
BEGIN
    drop_it('DROP VIEW balance_reconciliation');
    drop_it('DROP VIEW transaction_report');
    drop_it('DROP VIEW account_summary');
    drop_it('DROP TRIGGER trg_transaction_validate');
    drop_it('DROP TRIGGER trg_account_audit');
    drop_it('DROP PACKAGE bank_pkg');
    drop_it('DROP TABLE audit_log CASCADE CONSTRAINTS');
    drop_it('DROP TABLE bank_transactions CASCADE CONSTRAINTS');
    drop_it('DROP TABLE loans CASCADE CONSTRAINTS');
    drop_it('DROP TABLE accounts CASCADE CONSTRAINTS');
    drop_it('DROP TABLE customers CASCADE CONSTRAINTS');
    drop_it('DROP SEQUENCE audit_seq');
    drop_it('DROP SEQUENCE loan_seq');
    drop_it('DROP SEQUENCE transaction_seq');
    drop_it('DROP SEQUENCE account_seq');
    drop_it('DROP SEQUENCE customer_seq');
    DBMS_OUTPUT.PUT_LINE('Reset complete.');
END;
/
