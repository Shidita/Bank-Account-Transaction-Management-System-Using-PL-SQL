# Bank Account and Transaction Management System Using Oracle PL/SQL

A database-driven banking application developed using **Python, Flask, Oracle PL/SQL, HTML, CSS, and JavaScript**. The system provides a user-friendly interface for managing bank accounts and performing common banking operations, with database-level transaction processing and auditing.

## Overview

The Bank Account and Transaction Management System demonstrates how a web application can integrate a frontend, a Python backend, and an Oracle database. It uses PL/SQL packages, stored procedures, triggers, and database queries to support banking operations and maintain transaction records.

The project also includes a demo mode for testing the application without requiring an Oracle database connection.

## Key Features

- **Customer Management:** Create and manage customer information.
- **Account Management:** Manage bank accounts and account details.
- **Deposit Operations:** Deposit money into an account.
- **Withdrawal Operations:** Withdraw money with appropriate balance validation.
- **Fund Transfers:** Transfer money between accounts.
- **Balance Inquiry:** Retrieve account balances.
- **Transaction History:** View transaction records and account activity.
- **Interest Calculation:** Demonstrate interest calculation for accounts.
- **Audit Logging:** Maintain records of relevant database operations.
- **Reports and Summaries:** Access account summaries and transaction reports.
- **Demo Mode:** Test supported functionality using a SQLite backend.

## Technologies Used

| Technology | Purpose |
|---|---|
| Python | Backend application logic |
| Flask | Web application framework |
| Oracle Database | Primary database |
| PL/SQL | Stored procedures, packages, and database operations |
| HTML | Webpage structure |
| CSS | User interface styling |
| JavaScript | Frontend interactions |
| SQLite | Optional demo database |
| python-oracledb | Python-to-Oracle connectivity |

## Project Structure

```text
Bank-Account-Transaction-Management-System/
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

*Note: This structure illustrates the expected project layout. Some filenames or folders may differ in your uploaded repository.*

## Getting Started

### Prerequisites

Before running the project, install or prepare:

- Python 3.10 or a compatible version supported by the project dependencies
- pip package manager
- Oracle Database and SQL*Plus for Oracle mode
- A modern web browser

Oracle Database is not required if you use the optional demo mode.

### 1. Clone the Repository

```bash
git clone https://github.com/YOUR-USERNAME/YOUR-REPOSITORY.git
cd YOUR-REPOSITORY
```

Replace `YOUR-USERNAME` and `YOUR-REPOSITORY` with your GitHub username and repository name.

### 2. Install Dependencies

```bash
pip install -r requirements.txt
```

For a cleaner Python environment, you can create and activate a virtual environment before installing the dependencies.

### 3. Configure Oracle Database

To use the Oracle backend:

1. Start your Oracle Database service.
2. Open SQL*Plus and connect using an account with the necessary database privileges.
3. Execute the SQL scripts in the order required by the project. If `sql/00_run_all.sql` is configured to execute the setup scripts, you can use it as the main setup script.
4. Create a local `.env` file using `.env.example` as a reference.
5. Add your Oracle connection details to the local `.env` file.

Example configuration:

```env
ORACLE_USER=your_username
ORACLE_PASSWORD=your_password
ORACLE_DSN=localhost:1521/XEPDB1
```

Replace these example values with the credentials and service name configured for your Oracle installation. Ensure that the application is configured to use the Oracle backend.

### 4. Run the Application

Start the Flask application:

```bash
python app.py
```

Open your browser and visit:

**http://127.0.0.1:5000**

The application should be accessible locally if the server starts successfully.

## Database Design

The Oracle database component demonstrates the use of:

- Relational database tables
- Primary and foreign key relationships
- PL/SQL packages and stored procedures
- Database triggers
- Views and reporting queries
- Transaction handling and validation
- Audit logging

The SQL scripts are provided to help create and populate the database objects required by the application.

## Demo Mode

The project includes an optional SQLite-based demo backend. This mode is useful for demonstrations and testing when Oracle Database is unavailable.

Run the application using the project's supported demo configuration. Refer to `app.py`, `demo_backend.py`, and `.env.example` for the configuration options implemented in the repository.

**Note:** Demo mode and Oracle mode may differ in database features and behavior.

## Security Considerations

- Never commit database passwords, API keys, or private credentials.
- Keep the local `.env` file out of version control.
- Use `.env.example` to document required configuration variables without exposing real secrets.
- Validate user inputs and verify account balances before processing transactions.
- Test database transactions and error handling before using the application beyond an academic demonstration.

## Learning Outcomes

This project demonstrates practical knowledge of:

- Web application development with Flask
- Frontend and backend integration
- Oracle database connectivity using Python
- PL/SQL packages, procedures, and triggers
- Banking transaction workflows
- Database reporting and audit logging

## Future Enhancements

Potential improvements include:

- Secure user authentication and role-based access control
- Password hashing and session management
- Enhanced transaction validation and rollback handling
- PDF account statements
- Improved reporting dashboards
- Automated database and application tests

## Author

**Shidita Tiwari**

## Disclaimer

This project is intended for educational and demonstration purposes. It is not a production banking system and should not be used to process real financial transactions.

## License

No license has been specified. All rights remain with the respective author unless a license is added to the repository.
