# Procura Procurement Sandbox

A local procurement MVP with an enterprise-style workspace, an Express server, and PostgreSQL persistence. It has no AI endpoints or developer/API surface in the UI.

## Quick start

Requirements: Node.js 18+ and PostgreSQL 14+.

```bash
npm install
export DATABASE_URL=postgres://postgres:your-password@localhost:5432/procura
npm run db:setup
npm run dev
```

Open <http://localhost:3000>. On Windows, set `DATABASE_URL` in the shell before running `npm run db:setup`.

`npm run db:setup` applies the base schema, one-time workflow migrations, and idempotent synthetic data. Set `PORT` to change the web port.

## Launch scripts

After PostgreSQL is running and `DATABASE_URL` is set:

- Linux/macOS: `./launch-linux.sh`
- Windows PowerShell: `.\launch-windows.ps1`
- Windows Command Prompt: `launch-windows.bat`

See [setup and architecture](./docs/setup-and-architecture.md) for the full setup, architecture, and troubleshooting guide. The [documentation index](./docs/README.md) links the project research, context, and AI implementation plan.

## n8n workflow builder

n8n is installed as an isolated local automation service. It uses a supported Node.js 24 runtime inside `.tools/`, so it does not change the machine's Node installation or mix n8n's internal data with Procura's PostgreSQL data.

```powershell
npm run n8n:start
```

Open <http://127.0.0.1:5678>. See [local n8n setup](./docs/n8n-local-setup.md) for the file locations, recovery command, and the first procurement agent workflow.

## Included application routes

The GUI uses JSON routes for list, detail, create, update, and delete operations:

`/api/suppliers`, `/api/contracts`, `/api/sourcing_events`, `/api/requisitions`, `/api/purchase_orders`, `/api/invoices`, `/api/risk_assessments`, and `/api/approvals`.

`/api/summary` powers dashboard counts and `/api/activities` powers the activity feed. Add `?search=term` to list routes.

These are application routes for the local GUI, not AI service endpoints.

## Connected workflow data

The sandbox now models the records needed to study three AI-assisted workflows:

- Guided purchasing: catalogs and policies connect to requisition lines, purchase orders, and approvals.
- Invoice investigation: PO lines connect to receipts, invoice lines, and invoice holds.
- Sourcing analysis: sourcing items connect to supplier bids, bid lines, and evaluation criteria.

Header amounts for requisitions, purchase orders, and invoices are calculated from their lines. The database rejects mismatched supplier, currency, event, and document relationships. Run `npm run db:setup` after pulling schema changes.

The additional CRUD routes are `/api/catalog_items`, `/api/procurement_policies`, `/api/requisition_lines`, `/api/purchase_order_lines`, `/api/invoice_lines`, `/api/goods_receipts`, `/api/invoice_holds`, `/api/sourcing_items`, `/api/supplier_bids`, `/api/bid_lines`, and `/api/evaluation_criteria`. List routes accept parent filters such as `?invoice_id=12` or `?event_id=3`.

All supplied data is synthetic. `REQ-LAB-01` provides a linked requisition-to-invoice example and `SRC-LAB-01` provides a linked bid-comparison example.
