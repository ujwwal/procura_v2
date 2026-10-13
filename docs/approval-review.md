# Approval review summarizer

This feature prepares a brief for a human reviewing a requisition. The human makes the decision.

## What each part does

- **Procura API** fetches the original approval, linked requisition, line items, employee matches, department matches, and recorded flags.
- **n8n** passes this information through a small sequence of nodes.
- **Gemini** writes a short summary, explains each supplied issue, and suggests questions or checks.
- **Validation code** rejects wrong IDs, missing or extra issue categories, invented references, malformed JSON, and selected unsafe claims. It copies original facts into the final brief.

Think of it as gathering the paperwork and preparing a review note. It does not change statuses, route approvals, or create POs.

## Open and run it

From the project folder, start Procura:

    npm run dev

In another terminal, start n8n:

    npm run n8n:start

Open [local n8n](http://127.0.0.1:5678). Select **Procura - Approval Review Summarizer (Gemini)**.

If it has not been imported, use **Import from File**:

    automation/n8n/workflows/approval-review.json

Open **Gemini model**, select your saved Google Gemini credential, and check the model setting. The export contains no credential secret. Its model configuration was reused from the existing invoice workflow; the evaluator uses the saved local configuration.

Open **Choose approval**. The default is **6004**, which has two recorded issues. Change the ID, click **Execute Workflow**, and inspect **Validate review brief**.

For a clean pending example, use **6007**. Its recorded employee is inactive, but the existing view does not flag inactive employees for pending approvals. A clean result therefore does not establish that the request can be approved.

This is a manual workflow. It needs no publishing or public webhook.

## Read the result

The brief contains a summary, recorded statuses, original request facts, issues with supporting facts, human review questions, missing information, and limitations.

The model does not write numbers or status labels in prose. Code attaches amounts, dates, identifiers, and historical statuses directly from the retrieved records. This keeps a recorded status separate from an AI decision.

Read the generated words alongside the supporting facts. Structural validation cannot prove every sentence is true or every recommendation useful.

## A detail that matters

The API takes an **approval ID**, but the existing approval_flags view reports issues for the **whole requisition**.

If a requisition has multiple approvals, the brief includes their relevant evidence. Each issue names its source approval IDs in the supporting facts. The selected approval is not automatically the source of every issue.

The CSV answer key uses **requisition IDs**. In the ten fixtures, approval IDs happen to be the same numbers. The evaluator verifies both identities.

| Recorded flag | Existing meaning |
| --- | --- |
| over_limit | A recorded status normalizes to approved, and a matched employee's numeric limit is strictly below the requisition amount. Equality is not flagged. |
| inactive_approver | A recorded status normalizes to approved, and a matched employee is currently inactive. |
| unresolved_approver | The approver's exact name matches no employee, regardless of approval status. |

Entity type and status use PostgreSQL lower(trim(...)). Employee names use exact matching. Multiple employee matches are disclosed as ambiguous.

The view does not establish budget availability, departmental or delegated authority, historical employee state, or currency conversion. There is no currency field for employee limits. Missing links and values are disclosed separately; they do not create extra view flags.

## API

    GET /api/approvals/:id/review

Example: [approval 6004 evidence](http://127.0.0.1:3000/api/approvals/6004/review).

It reads one consistent snapshot in a read-only transaction. Numeric values remain decimal strings.

Responses: 400 invalid ID, 404 missing approval, 409 missing linked requisition, 422 unsupported entity type, 503 unavailable or inconsistent evidence. Failures never become a clean brief.

## Tests and evaluation

Local validation and failure tests:

    npm run test:approval

Live API against the independent CSV:

    npm run approval:eval

Actual n8n wiring with simulated responses:

    npm run approval:eval -- --mock

Actual Gemini fixture evaluation:

    npm run approval:eval -- --llm

The evaluator covers all ten fixtures and four invalid/missing-ID cases. Workflow modes add an instruction attack to an in-memory approval comment; they do not edit database records.

Mock mode verifies wiring only. LLM mode checks generated output, but a human must still assess summary meaning, issue attribution, useful questions, and unsupported claims. A single attack case does not demonstrate general injection resistance.

Private reports and logs are saved under:

    automation/n8n/.data/approval-evaluations/<run-time>/

Reports separate API results, simulated wiring, actual AI results, and pending human review. They record model configuration, times, latency, and token usage when returned. No estimated cost is presented.

## Inspect a failure

Open the failed execution in n8n and select its red node.

- **Fetch approval evidence**: check that Procura is running and open the example API URL.
- **Summarize with Gemini**: inspect the provider error; check the saved credential, project billing, and model setting.
- **Validate review brief**: compare the raw model output with the API evidence. Its error identifies the rejected structure or claim.
- **Evaluation**: open report.json in that run's private folder. Unexecuted cases are not passes.

Do not paste API keys into chat or exported workflow files.

## Changed files

- server.js and lib/approval-context.js: route, snapshot retrieval, and evidence attribution.
- lib/approval-review.js: prompt and response validation.
- automation/n8n/build-approval-workflow.js and automation/n8n/workflows/approval-review.json: workflow generator and import.
- scripts/evaluate-approval-review.js: independent fixture and workflow evaluation.
- tests/approval-review.test.js: validation, attribution, and failure tests.
- package.json: approval commands.
- docs/approval-review.md and docs/README.md: guide and index.

No Neon schema or business records were modified.

## Results from this implementation

- **Local tests:** thirteen approval tests passed; the ten existing invoice tests also passed.
- **Live API:** all ten approval fixtures and four invalid/missing-ID checks passed.
- **n8n wiring:** ten fixture briefs plus one in-memory attack case passed with simulated outputs. This does not measure Gemini quality or attack resistance.
- **Actual Gemini:** one attempted model call failed with HTTP 402 because Google project prepaid credits were depleted. No actual briefs were generated. Real-model injection handling and semantic quality remain untested.
- **Model configuration:** models/gemini-3.5-flash-lite, reused from the saved invoice workflow.
- **Usage:** token usage was unavailable; no cost was estimated.

Actual-model report:

    automation/n8n/.data/approval-evaluations/2026-10-09T16-16-41-007Z/report.json

Simulated wiring report:

    automation/n8n/.data/approval-evaluations/2026-10-09T16-15-18-430Z/report.json

After resolving billing in the Google project, rerun:

    npm run approval:eval -- --llm

A passing deterministic evaluation still requires human review of the generated words.
