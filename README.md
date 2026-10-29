# Bank Account & Transaction Management System using PL/SQL – web frontend

Yeh app aapke Oracle `bank_pkg` package ke upar chalta hai. Har button seedha aapki procedure call karta hai
(`deposit`, `withdraw`, `transfer`, `create_customer`, `create_account`, `change_account_status`,
`get_balance`, `calculate_interest`) aur screen ke right side wale **PL/SQL console** me call, DBMS_OUTPUT
aur `ORA-200xx` error dikhata hai – viva/demo ke liye perfect.

## Screens
Overview · Customers · Accounts · Move money (+ error-case buttons) · Transactions / statement · Reports
(balance vs transactions, interest calculator) · Audit log (trigger ka output)

## Option A – Oracle ke saath (asli use)
1. Pehle apne schema me SQL scripts chala lo (`sql/00_run_all.sql` ya 01–05). Package + tables + views zaroori hain.
2. `pip install -r requirements.txt`  (python-oracledb "thin" mode use karta hai – Oracle Client install nahi chahiye)
3. `.env.example` ko copy karke `.env` banao aur apna login bharo:
   ```
   ORACLE_USER=system
   ORACLE_PASSWORD=...
   ORACLE_DSN=localhost:1521/XE        # XE 18c/21c ke liye: localhost:1521/XEPDB1
   ```
4. `python app.py` → browser me http://localhost:5000

Note: transactions/audit list me `FETCH FIRST n ROWS ONLY` use hua hai, isliye Oracle **12c ya upar** chahiye
(11g XE me yeh query badalni padegi – bata dena).

## Option B – Demo mode (Oracle ke bina)
`.env` bina banaye `python app.py` chalao. Ek SQLite copy chalti hai jisme same rules aur same ORA-200xx codes hain.
Sidebar me "Reset demo data" se data wapas original ho jata hai.

## Files
```
app.py              Flask routes (JSON API)
oracle_backend.py   bank_pkg ko call karta hai (python-oracledb)
demo_backend.py     Oracle ke bina chalne wala SQLite version
static/             index.html, style.css, app.js  (frontend)
sql/ report/        aapka original project (unchanged)
```
