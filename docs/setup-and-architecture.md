# Procura Procurement Sandbox: Foundation Guide

This guide explains what the sandbox is, how to launch it, how its pieces fit together, and where to start when building your own research and AI work around it.

## 1. What you have

Procura is a local procurement application with:

- A browser-based graphical interface
- A Node.js application server
- An Express web framework
- A PostgreSQL relational database
- Synthetic procurement records
- Create, read, update, and delete (CRUD) operations
- No AI endpoints
- No production integrations
- No developer tools exposed in the user interface

It is an original procurement sandbox using original branding and implementation rather than Zycus code, logos, or proprietary assets.

## 2. Architecture in plain English

```text
Your browser
    |
    | HTTP requests for pages and data
    v
Node.js + Express server
    |
    | SQL queries through the pg database driver
    v
PostgreSQL database
```

### Browser (frontend)

The browser displays navigation, dashboards, forms, tables, and record details.

- [index.html](../index.html) contains the page structure.
- [styles.css](../styles.css) contains the visual design and responsive layout.
- [app.js](../app.js) contains navigation, rendering, form submission, and browser-to-server requests.

The frontend does not own permanent data. When you create a supplier, it sends the form values to the server. This prevents data from being dependent on one browser tab.

### Node.js (runtime)

Node.js runs JavaScript outside the browser. It starts the local process and hosts the application server. It is the runtime, not the database.

### Express (web framework)

Express receives browser requests and chooses what to do. For example:

1. The browser sends `POST /api/suppliers`.
2. Express parses the JSON body.
3. The server keeps only allowed fields.
4. The server executes an `INSERT` query in PostgreSQL.
5. The server returns the saved supplier as JSON.

The server entry point is [server.js](../server.js).

### PostgreSQL (database)

PostgreSQL stores structured records permanently. Tables represent suppliers, contracts, invoices, requisitions, and other domains. Foreign keys connect related records, such as a contract referring to a supplier.

The database definition is [db/schema.sql](../db/schema.sql), and fictional sample records are in [db/seed.sql](../db/seed.sql).

### `pg` (database driver)

The `pg` package allows Node.js to communicate with PostgreSQL. It sends parameterized SQL queries and returns database rows to the server.

### dotenv (configuration loader)

The `dotenv` package loads local environment values when a `.env` file is used. The important setting is `DATABASE_URL`. Never commit real passwords or company credentials.

## 3. Requirements

Install:

1. Node.js 18 or newer, which includes npm.
2. PostgreSQL 14 or newer.
3. A PostgreSQL database named `procura`.

Check Node.js and npm:

```bash
node --version
npm --version
```

Check PostgreSQL:

```bash
psql --version
```

PostgreSQL must be running before setup. On Windows, use the PostgreSQL service or pgAdmin. On Linux, it is commonly managed with `systemctl`.

## 4. Create the database

The application creates tables, but it does not create the PostgreSQL database itself. Create it once:

```bash
createdb -U postgres procura
```

Alternatively:

```bash
psql -U postgres -c "CREATE DATABASE procura;"
```

If it already exists, that is safe.

## 5. Configure the connection

`DATABASE_URL` tells the server where PostgreSQL is located:

```text
postgres://USERNAME:PASSWORD@HOST:PORT/DATABASE
```

Example:

```text
postgres://postgres:your-password@localhost:5432/procura
```

Linux/macOS:

```bash
export DATABASE_URL=postgres://postgres:your-password@localhost:5432/procura
```

Windows PowerShell:

```powershell
$env:DATABASE_URL = "postgres://postgres:your-password@localhost:5432/procura"
```

The variable applies to the current terminal session. Set it again in a new terminal. Do not commit a `.env` file containing a real password.

## 6. Launch the application

From the project folder:

### Linux/macOS

```bash
chmod +x launch-linux.sh
./launch-linux.sh
```

### Windows PowerShell

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\launch-windows.ps1
```

### Windows Command Prompt

```bat
set DATABASE_URL=postgres://postgres:your-password@localhost:5432/procura
launch-windows.bat
```

Each script installs dependencies if needed, applies the schema and seed data, and starts the development server. Open <http://localhost:3000>.

Use another port if 3000 is busy:

```bash
PORT=3001 npm run dev
```

PowerShell:

```powershell
$env:PORT = "3001"
npm run dev
```

## 7. What database setup does

`npm run db:setup` runs [db/setup.js](../db/setup.js). It connects using `DATABASE_URL`, applies the base schema and seed, applies one-time migrations from `db/workflows.sql`, loads connected synthetic cases from `db/workflow-seed.sql`, and closes the connection.

The seed is idempotent: running setup again does not intentionally duplicate records with the same unique identifiers.

## 8. What you can do in the GUI

- **Request:** requests, approvals, activity, and logs
- **Sourcing:** sourcing events and supplier bid workspaces
- **Contracts:** contracts, clauses, templates, renewals
- **Suppliers:** supplier profiles, onboarding, and pre-qualification
- **Procurement:** requisitions, purchase orders, receiving, approvals
- **Invoice:** invoices, credit memos, mailbox, reconciliation
- **Risk:** risk assessments, scorecards, alerts, and segmentation
- **Analytics:** spend dashboards and data exploration

Supported record screens let you create, view, edit, delete, search, and refresh records. The data remains in PostgreSQL after the browser closes.

## 9. How supplier creation works

1. Select **Suppliers** and then **Suppliers**.
2. Select **Create new**.
3. Enter supplier details and submit.
4. The browser sends JSON to `server.js`.
5. Express performs a parameterized SQL `INSERT`.
6. PostgreSQL returns the saved row.
7. An activity record is written.
8. The browser reloads the list and dashboard metrics.

This is the stable application foundation. AI is intentionally outside the current application boundary.

## 10. Application routes

The browser uses internal JSON routes for CRUD. These are not AI routes:

- `/api/suppliers`
- `/api/contracts`
- `/api/sourcing_events`
- `/api/requisitions`
- `/api/purchase_orders`
- `/api/invoices`
- `/api/risk_assessments`
- `/api/approvals`
- `/api/activities`
- `/api/summary`

Resource routes support list, detail, create, update, and delete operations where appropriate. The GUI is the intended user surface; there is no API documentation page or developer console.

## 11. Common problems

### `DATABASE_URL is required`

Set the variable in the same terminal that launches the app.

### `Database unavailable`

Check that PostgreSQL is running, `procura` exists, credentials are correct, and the terminal still has `DATABASE_URL`.

### Port 3000 is already in use

Set `PORT=3001` and start again.

### PowerShell blocks the script

Use the process-only policy change shown above. It does not permanently change the machine policy.

### The dashboard is empty

Run `npm run db:setup` again. Dashboard counts and activity are read from PostgreSQL.

## 12. Foundation-building roadmap

Recommended extension order:

1. Add field-level validation and friendly errors.
2. Add supplier addresses, contacts, documents, and questionnaires.
3. Add explicit status transitions and approval history.
4. Add document metadata and local file storage.
5. Add automated CRUD tests.
6. Add simulated roles if research requires different personas.
7. Add reporting and export behavior.
8. Integrate your own AI experiments outside this application boundary.
