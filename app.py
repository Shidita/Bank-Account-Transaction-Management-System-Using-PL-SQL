"""Bank Account & Transaction Management - web app.
Run:  python app.py        (demo mode)      or set ORACLE_USER / ORACLE_PASSWORD / ORACLE_DSN in .env
"""
import os
import sys
from decimal import Decimal
from pathlib import Path

from flask import Flask, jsonify, request, send_from_directory

from common import BankError, parse_amount, parse_id, sql_lit

HERE = Path(__file__).parent


def load_env():
    f = HERE / ".env"
    if f.exists():
        for line in f.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))


def make_bank():
    load_env()
    user, pwd, dsn = (os.environ.get(k) for k in ("ORACLE_USER", "ORACLE_PASSWORD", "ORACLE_DSN"))
    if os.environ.get("BANK_MODE", "").lower() != "demo" and user and pwd and dsn:
        try:
            from oracle_backend import OracleBank
            return OracleBank(user, pwd, dsn)
        except Exception as e:  # noqa
            sys.exit(f"\n[!] Oracle se connect nahi hua: {e}\n"
                     f"    .env check karo (ORACLE_USER / ORACLE_PASSWORD / ORACLE_DSN), "
                     f"ya demo ke liye BANK_MODE=demo set karo.\n")
    from demo_backend import DemoBank
    return DemoBank()


bank = make_bank()
app = Flask(__name__, static_folder=str(HERE / "static"), static_url_path="")


def body():
    return request.get_json(silent=True) or {}


def run(proc, args, shown):
    """Execute a package procedure; return the call text + DBMS_OUTPUT. Errors become JSON too."""
    call = f"bank_pkg.{proc}(" + ", ".join(sql_lit(a) for a in shown) + ");"
    try:
        out = bank.call(proc, args)
        return {"ok": True, "call": call, "output": out}
    except BankError as e:
        return {"ok": False, "call": call, "code": e.code, "error": e.message, "ora": e.ora}


def respond(res, extra=None):
    if extra and res["ok"]:
        res.update(extra)
    return jsonify(res), (200 if res["ok"] else 400)


def guard(fn):
    """Turn BankError raised during parsing/queries into a JSON error."""
    def wrapper(*a, **k):
        try:
            return fn(*a, **k)
        except BankError as e:
            return jsonify({"ok": False, "code": e.code, "error": e.message, "ora": e.ora, "call": ""}), 400
    wrapper.__name__ = fn.__name__
    return wrapper


# ------------------------------------------------------------------ pages
@app.get("/")
def index():
    return send_from_directory(app.static_folder, "index.html")


@app.get("/api/mode")
def mode():
    return jsonify({"mode": bank.mode, "label": bank.label})


# ------------------------------------------------------------------ reads
@app.get("/api/summary")
@guard
def summary():
    accounts, txs = bank.accounts(), bank.transactions(limit=100000)
    rec = bank.reconciliation()
    by_type = {}
    for a in accounts:
        by_type[a["account_type"]] = by_type.get(a["account_type"], 0) + a["balance"]
    return jsonify({
        "customers": len(bank.customers()),
        "accounts": len(accounts),
        "active_accounts": sum(1 for a in accounts if a["status"] == "ACTIVE"),
        "total_balance": round(sum(a["balance"] for a in accounts), 2),
        "transactions": len(txs),
        "mismatches": sum(1 for r in rec if round(r["balance"] - r["ledger_total"], 2) != 0),
        "by_type": by_type,
        "recent": txs[:6],
        "accounts_list": accounts,
    })


@app.get("/api/customers")
@guard
def customers():
    return jsonify(bank.customers())


@app.get("/api/accounts")
@guard
def accounts():
    return jsonify(bank.accounts())


@app.get("/api/transactions")
@guard
def transactions():
    acc = parse_id(request.args.get("account_id"))
    return jsonify(bank.transactions(acc, int(request.args.get("limit", 300))))


@app.get("/api/audit")
@guard
def audit():
    return jsonify(bank.audit())


@app.get("/api/reconciliation")
@guard
def reconciliation():
    rows = bank.reconciliation()
    for r in rows:
        r["difference"] = round(r["balance"] - r["ledger_total"], 2)
    return jsonify(rows)


@app.get("/api/balance/<acc>")
@guard
def balance(acc):
    a = parse_id(acc)
    v = bank.get_balance(a)
    call = f"bank_pkg.get_balance({sql_lit(a)})"
    if v is None:
        return jsonify({"ok": False, "call": call, "error": "Account not found (function returned NULL).", "code": 0}), 404
    return jsonify({"ok": True, "call": call, "balance": v})


@app.get("/api/interest")
@guard
def interest():
    a, rate = parse_id(request.args.get("account_id")), parse_amount(request.args.get("rate"))
    call = f"bank_pkg.calculate_interest({sql_lit(a)}, {sql_lit(rate)})"
    v = bank.calculate_interest(a, rate)
    if v is None and rate is not None:
        return jsonify({"ok": False, "call": call, "error": "Account not found (function returned NULL).", "code": 0}), 404
    return jsonify({"ok": True, "call": call, "interest": v, "balance": bank.get_balance(a)})


# ------------------------------------------------------------------ operations (call bank_pkg)
@app.post("/api/customers")
@guard
def create_customer():
    b = body()
    args = [b.get("name"), b.get("email"), b.get("phone") or None, b.get("city") or None]
    res = run("create_customer", args, args)
    extra = {}
    if res["ok"]:
        em = (b.get("email") or "").strip().lower()
        extra["customer_id"] = next((c["customer_id"] for c in bank.customers() if c["email"] == em), None)
    return respond(res, extra)


@app.post("/api/accounts")
@guard
def create_account():
    b = body()
    cid, amt = parse_id(b.get("customer_id")), parse_amount(b.get("initial_deposit"))
    args = [cid, b.get("account_type"), amt if amt is not None else Decimal(0)]
    return respond(run("create_account", args, args))


@app.post("/api/accounts/<acc>/status")
@guard
def change_status(acc):
    args = [parse_id(acc), body().get("status")]
    return respond(run("change_account_status", args, args))


@app.post("/api/deposit")
@guard
def deposit():
    b = body()
    args = [parse_id(b.get("account_id")), parse_amount(b.get("amount")), b.get("description") or "Cash deposit"]
    return respond(run("deposit", args, args))


@app.post("/api/withdraw")
@guard
def withdraw():
    b = body()
    args = [parse_id(b.get("account_id")), parse_amount(b.get("amount")), b.get("description") or "Cash withdrawal"]
    return respond(run("withdraw", args, args))


@app.post("/api/transfer")
@guard
def transfer():
    b = body()
    args = [parse_id(b.get("from_account")), parse_id(b.get("to_account")), parse_amount(b.get("amount"))]
    return respond(run("transfer", args, args))


@app.post("/api/reset")
@guard
def reset():
    bank.reset()
    return jsonify({"ok": True, "call": "-- demo data reset", "output": ["Demo data restored."]})


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    print(f"\n  Bank app running ->  http://localhost:{port}   [{bank.label}]\n")
    app.run(host="127.0.0.1", port=port, debug=False, threaded=True)
