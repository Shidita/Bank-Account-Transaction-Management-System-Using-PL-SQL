# PL/SQL Viva Questions & Short Answers

1. What is PL/SQL?
   PL/SQL is Oracle's procedural extension to SQL.

2. What is a procedure?
   A stored PL/SQL program that performs an operation and may accept parameters.

3. What is a function?
   A stored PL/SQL program that returns a value.

4. Procedure vs function?
   A function must return a value; a procedure does not have to.

5. What is a cursor?
   A cursor lets PL/SQL process query results row by row.

6. What is a trigger?
   A trigger automatically executes in response to a database event.

7. Why use a package?
   A package groups related procedures and functions and exposes a controlled
   specification. Private helpers such as `check_amount` stay hidden in the body.

8. Why use COMMIT?
   It permanently saves a successful transaction.

9. Why use ROLLBACK?
   It undoes uncommitted changes after an error and releases row locks.

10. What is FOR UPDATE?
    It locks selected rows so concurrent transactions cannot modify them until
    the current transaction is completed.

11. Why use sequences?
    To generate unique numeric identifiers.

12. What is RAISE_APPLICATION_ERROR?
    It raises a user-defined Oracle error with a number between -20000 and -20999.

13. What is exception handling?
    It handles runtime errors without abruptly terminating the program.

14. Why use a trigger for audit?
    It automatically records changes without requiring every caller to remember
    to insert an audit record.

15. What is the role of a primary key?
    It uniquely identifies each row.

16. Why does `IF p_amount <= 0` not catch a NULL amount?
    Any comparison with NULL is neither TRUE nor FALSE, so the IF branch is skipped.
    Test `p_amount IS NULL OR p_amount <= 0`.

17. How does the transfer avoid a deadlock?
    Both account rows are locked together in ascending `account_id` order, so two
    opposite transfers wait for each other in a line instead of in a circle.

18. How do you know balances and the ledger agree?
    The view `balance_reconciliation` shows `balance - SUM(ledger)`; every row must be 0.

19. Why store e-mail in lower case?
    So `A@x.com` and `a@x.com` cannot become two customers.

20. Why is the audit trigger `AFTER` and `FOR EACH ROW`?
    It must see the final :OLD and :NEW values of every changed row and it
    rolls back together with the transaction if the transfer fails.
