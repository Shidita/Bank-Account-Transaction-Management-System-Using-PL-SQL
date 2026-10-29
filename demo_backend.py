"""Demo backend: SQLite re-implementation of bank_pkg (same rules, same ORA-200xx codes).
Lets the whole app run without Oracle. The real Oracle backend is oracle_backend.py."""
import re
import sqlite3
import threading
from contextlib import contextmanager
from datetime import datetime
from decimal import Decimal

from common import BankError

EMAIL_RE = re.compile(r"^[^@ ]+@[^@ ]+\.[^@ ]+$")

SCHEMA = """
CREATE TABLE customers(customer_id INTEGER PRIMARY KEY, full_name TEXT NOT NULL, email TEXT NOT NULL UNIQUE,
  phone TEXT, city TEXT, created_at TEXT NOT NULL);
CREATE TABLE accounts(account_id INTEGER PRIMARY KEY, customer_id INTEGER NOT NULL REFERENCES customers,
  account_type TEXT NOT NULL CHECK(account_type IN ('SAVINGS','CURRENT')),
  balance INTEGER NOT NULL DEFAULT 0 CHECK(balance>=0),
  status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK(status IN ('ACTIVE','BLOCKED','CLOSED')), opened_at TEXT NOT NULL);
CREATE TABLE bank_transactions(transaction_id INTEGER PRIMARY KEY, account_id INTEGER NOT NULL REFERENCES accounts,
  transaction_type TEXT NOT NULL, amount INTEGER NOT NULL CHECK(amount>0), transaction_date TEXT NOT NULL,
  description TEXT, related_account_id INTEGER);
CREATE TABLE audit_log(audit_id INTEGER PRIMARY KEY, account_id INTEGER, action_type TEXT, old_balance INTEGER,
  new_balance INTEGER, action_time TEXT, details TEXT);
"""


def now():
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")


def paise(d):
    return int(d * 100)


def rupees(p):
    return None if p is None else p / 100


class DemoBank:
    mode = "demo"
    label = "Demo mode (SQLite, no Oracle needed)"

    def __init__(self):
        self.db = sqlite3.connect(":memory:", check_same_thread=False, isolation_level=None)
        self.db.row_factory = sqlite3.Row
        self.lock = threading.RLock()
        self.seq = {"customer": 1001, "account": 2001, "tx": 5001, "audit": 9001}
        self.db.executescript(SCHEMA)
        self._seed()

    # ---- helpers -----------------------------------------------------
    def nextval(self, name):
        v = self.seq[name]
        self.seq[name] += 1
        return v

    @contextmanager
    def tx(self):
        with self.lock:
            self.db.execute("BEGIN")
            try:
                yield self.db
                self.db.execute("COMMIT")
            except BaseException:
                self.db.execute("ROLLBACK")
                raise

    def _audit(self, acc, action, old, new, details):
        self.db.execute("INSERT INTO audit_log VALUES(?,?,?,?,?,?,?)",
                        (self.nextval("audit"), acc, action, old, new, now(), details))

    def _insert_tx(self, acc, typ, amt_p, desc, related=None):
        self.db.execute("INSERT INTO bank_transactions VALUES(?,?,?,?,?,?,?)",
                        (self.nextval("tx"), acc, typ, amt_p, now(), desc, related))

    def _set_balance(self, acc, old_p, new_p):
        """UPDATE accounts SET balance + trg_account_audit."""
        self.db.execute("UPDATE accounts SET balance=? WHERE account_id=?", (new_p, acc))
        if old_p != new_p:
            self._audit(acc, "BALANCE_CHANGE", old_p, new_p, "Automatic balance audit")

    def _seed(self):
        self.call("create_customer", ["Aarav Sharma", "aarav@example.com", "9876500001", "Delhi"])
        self.call("create_customer", ["Priya Verma", "priya@example.com", "9876500002", "Mumbai"])
        self.call("create_customer", ["Rahul Singh", "rahul@example.com", "9876500003", "Pune"])
        self.call("create_account", [1001, "SAVINGS", Decimal(25000)])
        self.call("create_account", [1002, "CURRENT", Decimal(50000)])
        self.call("create_account", [1003, "SAVINGS", Decimal(15000)])

    @staticmethod
    def _check_amount(amount, code, label):
        if amount is None or amount <= 0:
            raise BankError(code, f"{label} amount must be greater than zero.")
        if amount != amount.quantize(Decimal("0.01")):
            raise BankError(-20017, "Amount can have at most 2 decimal places.")

    # ---- procedures (mirror of bank_pkg) -------------------------------
    def call(self, name, a):
        return getattr(self, "p_" + name)(*a)

    def p_create_customer(self, name, email, phone, city):
        email = (email or "").strip().lower()
        if not (name or "").strip() or not email:
            raise BankError(-20019, "Customer name and e-mail are required.")
        with self.tx() as db:
            if db.execute("SELECT 1 FROM customers WHERE email=?", (email,)).fetchone():
                raise BankError(-20001, "Email already exists.")
            if not EMAIL_RE.match(email):
                raise BankError(-2290, "ORA-02290: check constraint (CHK_CUSTOMER_EMAIL) violated")
            cid = self.nextval("customer")
            db.execute("INSERT INTO customers VALUES(?,?,?,?,?,?)",
                       (cid, name.strip(), email, phone or None, city or None, now()))
        return ["Customer created successfully."]

    def p_create_account(self, cid, typ, initial):
        initial = initial if initial is not None else Decimal(0)
        with self.tx() as db:
            if not db.execute("SELECT 1 FROM customers WHERE customer_id=?", (cid,)).fetchone():
                raise BankError(-20002, "Customer does not exist.")
            typ = (typ or "").strip().upper()
            if typ not in ("SAVINGS", "CURRENT"):
                raise BankError(-20003, "Account type must be SAVINGS or CURRENT.")
            if initial < 0:
                raise BankError(-20004, "Initial deposit cannot be negative.")
            if initial != initial.quantize(Decimal("0.01")):
                raise BankError(-20017, "Amount can have at most 2 decimal places.")
            aid = self.nextval("account")
            p = paise(initial)
            db.execute("INSERT INTO accounts VALUES(?,?,?,?,?,?)", (aid, cid, typ, p, "ACTIVE", now()))
            self._audit(aid, "ACCOUNT_OPENED", None, p, "Account opened")
            if p > 0:
                self._insert_tx(aid, "DEPOSIT", p, "Opening balance")
        return [f"Account {aid} created successfully."]

    def p_deposit(self, acc, amount, desc="Cash deposit"):
        self._check_amount(amount, -20005, "Deposit")
        with self.tx() as db:
            r = db.execute("SELECT balance,status FROM accounts WHERE account_id=?", (acc,)).fetchone()
            if not r:
                raise BankError(-20007, "Account not found.")
            if r["status"] != "ACTIVE":
                raise BankError(-20006, "Account is not active.")
            p = paise(amount)
            self._set_balance(acc, r["balance"], r["balance"] + p)
            self._insert_tx(acc, "DEPOSIT", p, desc)
        return ["Deposit successful."]

    def p_withdraw(self, acc, amount, desc="Cash withdrawal"):
        self._check_amount(amount, -20008, "Withdrawal")
        with self.tx() as db:
            r = db.execute("SELECT balance,status FROM accounts WHERE account_id=?", (acc,)).fetchone()
            if not r:
                raise BankError(-20011, "Account not found.")
            if r["status"] != "ACTIVE":
                raise BankError(-20009, "Account is not active.")
            p = paise(amount)
            if r["balance"] < p:
                raise BankError(-20010, "Insufficient balance.")
            self._set_balance(acc, r["balance"], r["balance"] - p)
            self._insert_tx(acc, "WITHDRAW", p, desc)
        return ["Withdrawal successful."]

    def p_transfer(self, src, dst, amount):
        if src == dst:
            raise BankError(-20012, "Source and destination accounts must differ.")
        self._check_amount(amount, -20013, "Transfer")
        with self.tx() as db:
            rows = {r["account_id"]: r for r in db.execute(
                "SELECT account_id,balance,status FROM accounts WHERE account_id IN (?,?)", (src, dst))}
            if src not in rows:
                raise BankError(-20018, "Source account not found.")
            if rows[src]["status"] != "ACTIVE":
                raise BankError(-20014, "Source account is not active.")
            if dst not in rows or rows[dst]["status"] != "ACTIVE":
                raise BankError(-20016, "Destination account not found or inactive.")
            p = paise(amount)
            if rows[src]["balance"] < p:
                raise BankError(-20015, "Insufficient balance for transfer.")
            self._set_balance(src, rows[src]["balance"], rows[src]["balance"] - p)
            self._set_balance(dst, rows[dst]["balance"], rows[dst]["balance"] + p)
            self._insert_tx(src, "TRANSFER_OUT", p, f"Transfer to account {dst}", dst)
            self._insert_tx(dst, "TRANSFER_IN", p, f"Transfer from account {src}", src)
        return ["Transfer successful."]

    def p_change_account_status(self, acc, status):
        status = (status or "").strip().upper()
        if status not in ("ACTIVE", "BLOCKED", "CLOSED"):
            raise BankError(-20021, "Status must be ACTIVE, BLOCKED or CLOSED.")
        with self.tx() as db:
            r = db.execute("SELECT balance FROM accounts WHERE account_id=?", (acc,)).fetchone()
            if not r:
                raise BankError(-20022, "Account not found.")
            if status == "CLOSED" and r["balance"] > 0:
                raise BankError(-20023, "Withdraw the remaining balance before closing the account.")
            db.execute("UPDATE accounts SET status=? WHERE account_id=?", (status, acc))
        return [f"Account {acc} is now {status}."]

    # ---- functions -----------------------------------------------------
    def get_balance(self, acc):
        with self.lock:
            r = self.db.execute("SELECT balance FROM accounts WHERE account_id=?", (acc,)).fetchone()
        return rupees(r["balance"]) if r else None

    def calculate_interest(self, acc, rate):
        if rate is None or rate < 0:
            raise BankError(-20020, "Interest rate must be zero or more.")
        bal = self.get_balance(acc)
        if bal is None:
            return None
        return float(round(Decimal(str(bal)) * rate / 100, 2))

    # ---- queries -------------------------------------------------------
    def _rows(self, sql, params=()):
        with self.lock:
            return [dict(r) for r in self.db.execute(sql, params)]

    @staticmethod
    def _money(rows, *cols):
        for r in rows:
            for c in cols:
                r[c] = rupees(r[c])
        return rows

    def customers(self):
        return self._money(self._rows("""
            SELECT c.customer_id, c.full_name, c.email, c.phone, c.city, c.created_at,
                   COUNT(a.account_id) AS accounts, COALESCE(SUM(a.balance),0) AS total_balance
            FROM customers c LEFT JOIN accounts a ON a.customer_id=c.customer_id
            GROUP BY c.customer_id ORDER BY c.customer_id"""), "total_balance")

    def accounts(self):
        return self._money(self._rows("""
            SELECT a.account_id, c.customer_id, c.full_name, c.email, a.account_type, a.balance, a.status, a.opened_at
            FROM accounts a JOIN customers c ON a.customer_id=c.customer_id ORDER BY a.account_id"""), "balance")

    def transactions(self, account_id=None, limit=300):
        where, p = ("WHERE t.account_id=?", [account_id]) if account_id else ("", [])
        return self._money(self._rows(f"""
            SELECT t.transaction_id, t.account_id, c.full_name, t.transaction_type, t.amount,
                   t.transaction_date, t.description, t.related_account_id
            FROM bank_transactions t JOIN accounts a ON t.account_id=a.account_id
            JOIN customers c ON a.customer_id=c.customer_id {where}
            ORDER BY t.transaction_date DESC, t.transaction_id DESC LIMIT ?""", p + [limit]), "amount")

    def audit(self, limit=300):
        return self._money(self._rows(
            "SELECT * FROM audit_log ORDER BY audit_id DESC LIMIT ?", (limit,)), "old_balance", "new_balance")

    def reconciliation(self):
        return self._money(self._rows("""
            SELECT a.account_id, a.balance,
              COALESCE(SUM(CASE WHEN t.transaction_type IN ('DEPOSIT','TRANSFER_IN') THEN t.amount
                                WHEN t.transaction_type IN ('WITHDRAW','TRANSFER_OUT') THEN -t.amount END),0) AS ledger_total
            FROM accounts a LEFT JOIN bank_transactions t ON t.account_id=a.account_id
            GROUP BY a.account_id, a.balance ORDER BY a.account_id"""), "balance", "ledger_total")

    def reset(self):
        with self.lock:
            self.__init__()
