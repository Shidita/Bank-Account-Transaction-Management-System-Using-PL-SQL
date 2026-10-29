# Bank Account & Transaction Management System Using PL/SQL

A web-based banking application developed using **Python, Flask, Oracle PL/SQL, HTML, CSS, and JavaScript**. It provides banking operations through an interactive frontend connected to a database backend.

## Features

- **Customer Management:** Create and manage customer records.
- **Account Management:** Create accounts and change account status.
- **Deposit & Withdrawal:** Perform banking transactions.
- **Fund Transfer:** Transfer money between accounts.
- **Balance Inquiry:** Check account balances.
- **Transaction History:** View transactions and account statements.
- **Interest Calculator:** Calculate account interest.
- **Audit Logging:** Track database operations using triggers.
- **PL/SQL Console:** View procedure calls, database output, and errors.
- **Demo Mode:** Run the application without an Oracle database using SQLite.

## Technologies Used

- **Frontend:** HTML, CSS, JavaScript
- **Backend:** Python, Flask
- **Database:** Oracle Database, PL/SQL
- **Oracle Connectivity:** python-oracledb
- **Demo Database:** SQLite

## Project Structure

```text
Bank_Account_Transaction_Management_System/
├── app.py
├── common.py
├── oracle_backend.py
├── demo_backend.py
├── requirements.txt
├── .env.example
├── static/
│   ├── index.html
│   ├── style.css
│   └── app.js
├── sql/
│   ├── 00_run_all.sql
│   ├── 01_create_tables.sql
│   ├── 02_sample_data.sql
│   ├── 03_package.sql
│   ├── 04_triggers.sql
│   ├── 05_views_reports.sql
│   ├── 06_demo_execution.sql
│   └── 07_reset.sql
└── report/
    ├── ER_Diagram.svg
    ├── Project_Report.md
    └── Viva_Questions.md
```

## Installation and Setup

### 1. Clone the Repository

```bash
git clone https://github.com/YOUR-USERNAME/YOUR-REPOSITORY.git
cd YOUR-REPOSITORY
```

Replace `YOUR-USERNAME` and `YOUR-REPOSITORY` with your actual GitHub details.

### 2. Install Dependencies

```bash
pip install -r requirements.txt
```

### 3. Run in Demo Mode

To run the application without Oracle Database configuration:

```bash
python app.py
```

Open your browser and visit:

`http://localhost:5000`

### 4. Run with Oracle Database

1. Install and start Oracle Database.
2. Execute the SQL scripts in the `sql/` directory in the required order, or use `sql/00_run_all.sql` in SQL*Plus.
3. Create a `.env` file based on `.env.example`.
4. Configure your Oracle database credentials:

```env
ORACLE_USER=your_username
ORACLE_PASSWORD=your_password
ORACLE_DSN=localhost:1521/XEPDB1
```

Use the correct service name and credentials for your Oracle installation.

5. Start the application:

```bash
python app.py
```

**Important:** Never upload your actual `.env` file or database passwords to GitHub.

## Database Concepts Demonstrated

- PL/SQL packages and stored procedures
- Database tables and relationships
- Triggers and audit logs
- Views and reporting queries
- Transaction processing
- Error handling and validation

## Project Purpose

This project demonstrates the integration of a web-based frontend with Python backend logic and Oracle PL/SQL database operations. It is designed for academic learning, database management practice, and banking transaction demonstrations.

## Author

**Shidita Tiwari**

## License

No license has been specified yet.
