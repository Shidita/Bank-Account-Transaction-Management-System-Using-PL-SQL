"""Shared helpers: error type and input parsing."""
from decimal import Decimal, InvalidOperation


class BankError(Exception):
    """An error raised by the bank package (ORA-200xx) or by input validation."""

    def __init__(self, code, message):
        super().__init__(message)
        self.code = code          # e.g. -20010
        self.message = message

    @property
    def ora(self):
        if self.message.startswith("ORA-") or not self.code:
            return self.message
        return f"ORA-{abs(self.code):05d}: {self.message}"


def parse_amount(raw):
    """Empty -> None (the package then raises -20005/-20008/-20013 itself).
    Keeps the exact decimals so 10.005 reaches the package and is rejected (-20017)."""
    if raw is None:
        return None
    s = str(raw).strip()
    if s == "":
        return None
    try:
        d = Decimal(s)
    except InvalidOperation:
        raise BankError(-1722, "ORA-01722: invalid number - enter digits only, e.g. 2500 or 2500.50")
    if not d.is_finite():
        raise BankError(-1722, "ORA-01722: invalid number")
    return d


def parse_id(raw):
    if raw is None or str(raw).strip() == "":
        return None
    try:
        return int(str(raw).strip())
    except ValueError:
        raise BankError(-1722, "ORA-01722: ids must be whole numbers")


def sql_lit(v):
    """Render a value the way it would be typed in the PL/SQL call shown in the console."""
    if v is None:
        return "NULL"
    if isinstance(v, (int, Decimal, float)):
        return str(v)
    return "'" + str(v).replace("'", "''") + "'"
