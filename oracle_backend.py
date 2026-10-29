"""Oracle backend: calls YOUR bank_pkg procedures/functions and reads YOUR tables/views.
Uses python-oracledb in 'thin' mode, so no Oracle Client install is needed."""
import re
from datetime import datetime
from decimal import Decimal

import oracledb

from common import BankError

ORA_RE = re.compile(r"ORA-(\d{5}):\s*(.*)")


def _clean(v):
    if isinstance(v, datetime):
        return v.strftime("%Y-%m-%d %H:%M:%S")
    if isinstance(v, Decimal):
        return float(v)
    return v


def _to_bank_error(exc):
    msg = str(exc.args[0].message if exc.args and hasattr(exc.args[0], "message") else exc)
    m = ORA_RE.search(msg)
    if m:
        num = int(m.group(1))
        text = m.group(2).splitlines()[0].strip()
        if 20000 <= num <= 20999:
            return BankError(-num, text)           # our RAISE_APPLICATION_ERROR codes
        return BankError(-num, f"ORA-{m.group(1)}: {text}")
    return BankError(-1, msg.strip())


class OracleBank:
    mode = "oracle"

    def __init__(self, user, password, dsn):
        self.label = f"Oracle · {user}@{dsn}"
        self.pool = oracledb.create_pool(user=user, password=password, dsn=dsn, min=1, max=4, increment=1)
        with self.pool.acquire() as c:        # fail fast if package is missing
            cur = c.cursor()
            cur.execute("SELECT COUNT(*) FROM user_objects WHERE object_name='BANK_PKG' AND object_type='PACKAGE BODY'")
            if cur.fetchone()[0] == 0:
                raise RuntimeError("bank_pkg not found in this schema. Run sql/00_run_all.sql (or 01-05) first.")

    # ---- plumbing --------------------------------------------------------
    def _rows(self, sql, params=None):
        with self.pool.acquire() as c:
            cur = c.cursor()
            cur.execute(sql, params or {})
            cols = [d[0].lower() for d in cur.description]
            return [{k: _clean(v) for k, v in zip(cols, r)} for r in cur.fetchall()]

    def call(self, name, args):
        """Run bank_pkg.<name>(args) and return the DBMS_OUTPUT lines."""
        with self.pool.acquire() as c:
            cur = c.cursor()
            try:
                cur.callproc("dbms_output.enable", [None])
                cur.callproc(f"bank_pkg.{name}", list(args))
                return self._output(cur)
            except oracledb.DatabaseError as e:
                raise _to_bank_error(e)

    @staticmethod
    def _output(cur):
        lines, line, status = [], cur.var(str), cur.var(int)
        while True:
            cur.callproc("dbms_output.get_line", (line, status))
            if status.getvalue() != 0:
                break
            lines.append(line.getvalue())
        return lines

    # ---- functions ---------------------------------------------------------
    def get_balance(self, acc):
        with self.pool.acquire() as c:
            v = c.cursor().callfunc("bank_pkg.get_balance", float, [acc])
        return v

    def calculate_interest(self, acc, rate):
        with self.pool.acquire() as c:
            try:
                return c.cursor().callfunc("bank_pkg.calculate_interest", float, [acc, rate])
            except oracledb.DatabaseError as e:
                raise _to_bank_error(e)

    # ---- queries -----------------------------------------------------------
    def customers(self):
        return self._rows("""
            SELECT c.customer_id, c.full_name, c.email, c.phone, c.city, c.created_at,
                   COUNT(a.account_id) AS accounts, NVL(SUM(a.balance),0) AS total_balance
            FROM customers c LEFT JOIN accounts a ON a.customer_id = c.customer_id
            GROUP BY c.customer_id, c.full_name, c.email, c.phone, c.city, c.created_at
            ORDER BY c.customer_id""")

    def accounts(self):
        return self._rows("SELECT * FROM account_summary ORDER BY account_id")

    def transactions(self, account_id=None, limit=300):
        where = "WHERE account_id = :a" if account_id else ""
        p = {"a": account_id, "n": limit} if account_id else {"n": limit}
        return self._rows(f"""SELECT * FROM transaction_report {where}
                              ORDER BY transaction_date DESC, transaction_id DESC
                              FETCH FIRST :n ROWS ONLY""", p)

    def audit(self, limit=300):
        return self._rows("SELECT * FROM audit_log ORDER BY audit_id DESC FETCH FIRST :n ROWS ONLY", {"n": limit})

    def reconciliation(self):
        return self._rows("SELECT account_id, balance, ledger_total FROM balance_reconciliation ORDER BY account_id")

    def reset(self):
        raise BankError(-1, "Reset is only available in demo mode. Run sql/07_reset.sql for Oracle.")
