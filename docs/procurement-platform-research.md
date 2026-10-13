# Procurement Sandbox Research & Product Brief

## 1. Purpose

This document captures the available research and reference observations for a lightweight procurement sandbox. The sandbox is intended to provide a realistic UI and synthetic data surface for implementing and testing AI capabilities. It is not intended to reproduce Zycus source code, proprietary assets, private workflows, or production behavior.

The working product name is **Procura**. It is an original name chosen for this sandbox and should not be presented as an official Zycus product.

## 2. Scope decision

The requested product is a **barebones UI shell**, not a complete source-to-pay implementation. Features are represented as navigable screens and sample records only. Business rules, persistence, integrations, payments, supplier communications, and AI behavior will be added separately by the AI implementer.

### In scope for the UI shell

- Home dashboard with global task search
- Persistent module navigation
- Contextual sub-navigation for each procurement domain
- Dashboard cards and recent activity using synthetic data
- Lightweight list/detail views for the most important record types
- Approval and task states that can be used as AI input/output surfaces
- Original visual identity inspired by enterprise procurement software
- Responsive layout for desktop and tablet widths

### Explicitly out of scope

- Real supplier, employee, banking, tax, or ERP data
- Real transactions, invoices, payments, or legal execution
- Authentication and production authorization
- ERP, SSO, email, e-signature, tax, or risk-provider integrations
- Workflow execution engines
- AI models, prompts, agents, or automated decisions
- Pixel-perfect copying of Zycus branding, icons, screens, or proprietary UX

## 3. Public research summary

Public Zycus materials describe **DewDrops** as a next-generation interface for integrated procurement work. The public product family is presented across sourcing, procurement, supplier management, contract lifecycle management, spend analysis, invoicing, and risk management. Zycus also publicly describes **Merlin** as its newer agentic AI platform, with specialized agents for intake, sourcing, supplier onboarding, accounts payable, and analytics.

Public pages reviewed:

- [DewDrops UI overview](https://www.zycus.com/videos/product/dew-drops-the-next-generation-user-interface-by-zycus)
- [What is Zycus DewDrops](https://www.zycus.com/videos/product/what-is-zycus-dewdrops)
- [Merlin Agentic AI platform](https://www.zycus.com/solution/merlin-agentic-ai-platform)
- [DewDrops eProc portal](https://dewdrops.zycus.com/eproc/)

The authenticated portal cannot be used to verify every internal screen. The supplied screenshots are therefore the primary visual and navigation reference for this sandbox.

## 4. Reference image observations

The `zycus sample images` folder contains ten supplied screenshots/photos. Together they show:

- A dark blue top bar with a compact product logo, global links, notifications, and a user area.
- A left navigation rail with Home, My Desk, My Approvals, and product modules.
- A blue selected state and chevron affordances for modules with a secondary menu.
- A two-panel navigation pattern: module selection on the left and contextual destinations on the right.
- A home page asking “What would you like to do today?” with a prominent search field.
- Frequently accessed actions such as creating a recurring contract, viewing KPIs, authoring a contract, and creating a requisition.
- Shortcut tiles for suppliers, sourcing events, invoices, requisitions, purchase orders, spend analysis, contracts, performance events, and requests.
- eProc destinations including requisitions, PO requester, catalog approvals, all approvals, buyer desk, upcoming requisitions, PO buyer, and central receiving.
- eInvoice/AP destinations including invoices, credit memos, check requests, eInvoice mailbox, approvals, all requests, delegation settings, PO, recurring contracts, reconciliation, and setup.
- iAnalyze destinations including spend dashboard, spend overview, crosswalk, guided browsing, alerts, spend miner, offline exports, data enrichment, settings, and admin.
- iSource destinations including QuickSource, iLogix, managing users and suppliers, offline exports, approvals/reviews, and settings.
- iContract destinations including authoring contracts, repository contracts, shared contracts, clauses, templates, reports/dashboards, approvals/reviews, contracting-party management, settings, and all approvals.
- iManage destinations including programs, projects, phases, tasks, resource-management dashboards, templates, assigned tasks, approvals/reviews, settings, and admin.
- iRisk destinations including a 360-degree risk dashboard, alerts/reminders, key indicators, scorecards, assessments, review queues, events, scoring, quick surveys, supplier analysis, and supplier segmentation.
- iSupplier destinations including requests, approvals, all requests, activity, logs, suppliers, pre-qualification, alerts, contact-registration status, forums, and company data export.
- A multi-step “Create Invoice” form with supplier information, basic details, attachments, billing/cost booking, eForms, items, taxes, and submit/save-as-draft actions.

## 5. Domain map for Procura

| Domain | Sandbox destinations | Representative records |
| --- | --- | --- |
| eProc | Requisitions, Purchase Orders, Receiving, Approvals | Requisition, PO, receipt |
| eInvoice | Invoices, Credit Memos, Reconciliation, Mailbox | Invoice, credit memo, match |
| iAnalyze | Spend Dashboard, Spend Overview, Alerts, Data Enrichment | Spend category, transaction |
| iSource | QuickSource, Sourcing Events, Bids, Reviews | Event, supplier bid, award |
| iContract | Authoring, Repository, Clauses, Templates, Renewals | Contract, clause, obligation |
| iSupplier | Suppliers, Onboarding, Pre-qualification, Activity | Supplier, questionnaire, document |
| iRisk | Risk Dashboard, Assessments, Scorecards, Alerts | Assessment, score, mitigation |
| iManage | Programs, Projects, Phases, Tasks | Program, project, task |
| iRequest | My Requests, Approvals, Activity, Logs | Request, approval, event |

## 6. AI integration seams

The UI should make it straightforward to add AI without coupling the shell to a specific model:

1. **Global search/intake**: accept a natural-language request and route to a domain.
2. **Supplier cards**: show extracted profile facts, missing documents, and risk summaries.
3. **Sourcing events**: compare bids, explain outliers, and draft an award recommendation.
4. **Contracts**: upload a document, extract clauses, identify obligations, and flag renewal/risk language.
5. **Invoices**: extract fields from an attachment, suggest PO matches, and explain exceptions.
6. **Spend analytics**: classify transactions, identify anomalies, and answer questions over spend.
7. **Approvals**: summarize the record, show policy evidence, and preserve a human approval checkpoint.
8. **Activity timeline**: provide traceable inputs, outputs, decisions, and confidence/evidence links.

Recommended API boundary for later work:

```text
GET  /api/dashboard
GET  /api/modules/:module
GET  /api/records/:type
POST /api/ai/intake
POST /api/ai/extract
POST /api/ai/summarize
POST /api/ai/recommend
```

These endpoints are conceptual only; the current UI uses local synthetic data.

## 7. Synthetic data model

The first sandbox dataset can contain:

- 12 suppliers across direct, indirect, services, and technology categories
- 8 sourcing events with RFQ/RFP status and bid counts
- 20 contracts with renewal dates, owners, categories, and risk flags
- 40 requisitions and purchase orders with approval states
- 50 invoices with matched, exception, and draft states
- 15 risk assessments with scorecards and remediation tasks
- Spend transactions grouped by category, business unit, supplier, and month

All names, amounts, dates, and identifiers must remain fictional.

## 8. UX principles

- Keep the module rail persistent and predictable.
- Use a contextual second level rather than exposing every destination at once.
- Make “what needs attention” more prominent than raw navigation.
- Use restrained blue, teal, amber, and red states for enterprise readability.
- Make cards and table rows useful as future AI insertion points.
- Prefer clear empty/loading/error states over silent behavior.
- Keep the visual language original: no Zycus logo, wordmark, or copied proprietary assets.

## 9. Implementation phases

### Phase 1: UI shell (current)

- Original Procura branding
- Navigation and module menu
- Dashboard and representative list views
- Local synthetic data
- Responsive CSS

### Phase 2: AI-ready backend

- Persistent entities and seeded fixtures
- File/document storage
- Search index
- Permission-aware API
- Activity and audit events

### Phase 3: AI experiments

- Extraction, classification, summarization, recommendations
- Prompt/version tracking
- Evaluation datasets and human feedback
- Evidence and confidence presentation

### Phase 4: Optional workflow depth

- Configurable approvals
- Supplier collaboration
- Contract obligations
- Three-way invoice matching
- Risk remediation workflows

## 10. Acceptance criteria for the current sandbox

- A user can open the app locally without external services.
- The home screen communicates that this is an AI experimentation sandbox.
- All domains observed in the references are reachable from navigation.
- Selecting a domain updates the contextual menu and main content.
- Dashboard cards and records are clearly synthetic.
- The shell is usable on a smaller viewport.
- No Zycus trademarks or proprietary assets are used in the implementation.

