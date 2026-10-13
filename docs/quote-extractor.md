# Supplier quote extractor

The third Stage 3 feature turns supplier quote text into a structured **draft**.

It does not approve a quote, select a winning supplier, or change authoritative bid lines.

## What happens

1. **Choose quote** supplies a bid ID and a save_draft setting.
2. **Fetch quote** reads the supplier's text and sourcing context.
3. **search_catalog** uses the existing Procura catalog search API to find possible item identities.
4. **Gemini** extracts facts and identifies missing or ambiguous information.
5. **Validate extraction** checks the structure, IDs, quoted excerpts, and numeric support.
6. **Preview only** shows the result. When save_draft is true, **Save draft lines** stores the validated values in extracted_bid_lines.

The quote is the supplier's offer. The sourcing item is what the buyer requested. The catalog is a reference list. They must not be mixed up: a requested quantity or catalog price is not evidence of what a supplier offered.

## Open the workflow

Start Procura from the project folder:

    npm run dev

Start n8n in another terminal:

    npm run n8n:start

Open [local n8n](http://127.0.0.1:5678) and select **Procura - Supplier Quote Extractor (Gemini)**.

If needed, use **Import from File** with:

    automation/n8n/workflows/quote-extractor.json

In **Gemini model**, select your saved credential. The model setting follows the existing invoice workflow; no key is exported.

In **Choose quote**, the default is:

    bid_id: 4022
    save_draft: false

Click **Execute Workflow**, then inspect **Validate extraction** and **Preview only**.

The independent answer key expects quote 4022 to offer the identified monitor at INR 10400 with a lead time of fourteen calendar days. Its offered quantity is not stated and must stay null. It also contains an instruction attempt. These are expected fixture answers, not a claim that Gemini has produced them successfully.

To store a generated draft, set save_draft to true and run the workflow. It will generate and validate a new extraction. A human must verify the resulting draft before relying on it.

## What null means

Null means the value remains unknown; it does not mean zero.

- Unexplained **9.8k** does not establish a full price.
- **$210** supports the amount but does not identify an explicit currency code.
- **10 business days** is not converted to calendar days.
- Conflicting or approximate lead times remain unknown.
- **Quantity: see your request** does not establish an offered quantity.
- A generic item mention does not establish a catalog identity.

Unambiguous weeks can be multiplied by seven. Explicit expanded shorthand can be extracted. Each known commercial value requires a short exact excerpt from the quote.

The output includes unknown reasons, clarification questions, and injection warnings. Instructions inside supplier text are data. The workflow flags recognized attempts and continues with supported commercial facts.

## Draft storage

Only extracted_bid_lines is written. The original quote, supplier bid, sourcing records, and authoritative bid_lines are preserved.

The server validates again using current source records. It checks a source hash, locks the bid and requested item during saving, and uses parameterized SQL.

- Changed source: 409; fetch and review again.
- Identical stored draft: 200; reuse the row.
- New draft: 201.
- Different existing draft: 409; it is not overwritten.
- Invalid output: 400; no successful save is reported.

The existing draft table stores bid ID, catalog ID, description, quantity, price, currency, lead time, and extraction date. It has no columns for sourcing item ID, evidence, warnings, or model metadata. Retain the workflow output or evaluation report alongside the draft.

## APIs

The existing GET /api/supplier_bids/:id remains available for normal bid record views.

The richer extraction endpoint is:

    GET /api/supplier_bids/:id/quote-context

Example: [quote 4022 context](http://127.0.0.1:3000/api/supplier_bids/4022/quote-context).

Draft storage uses:

    POST /api/supplier_bids/:id/extracted-lines

Its body has exactly source_hash and extraction, taken from the validated output. IDs, commercial facts, and excerpts are checked again on the server.

Context failures return explicit errors: invalid ID 400, missing bid 404, missing relationships 409, unsupported or missing quote context 422, unavailable data 503.

## Tests and evaluation

    npm run test:quote

API and fixture integrity:

    npm run quote:eval

n8n wiring using simulated model responses:

    npm run quote:eval -- --mock

Actual Gemini extraction:

    npm run quote:eval -- --llm

The independent CSV contains 25 cases, including 18 clean quotes, seven problematic quotes, and five injection cases.

Actual-model evaluation checks item IDs, quantities, prices, currencies, calendar lead times, null expectations, and injection reporting. It does not require exact wording.

Mock mode deliberately constructs responses from the answer key to test wiring. It is not an extraction accuracy result. Its extra save test calls a fake HTTP storage service, never Neon.

Normal evaluations preview results and compare before/after fingerprints of the original quote fixtures and draft rows. Local tests cover positive storage, idempotency, and rollback. A separate storage integration mode deliberately saves or reuses one manually constructed, source-validated draft for synthetic quote 4000, then checks retry and conflict handling. It does not call Gemini or measure AI accuracy.

    npm run quote:eval -- --persist-fixture

This mode writes only to extracted_bid_lines and confirms that the authoritative quote fixtures remain unchanged.

Reports live under:

    automation/n8n/.data/quote-evaluations/<run-time>/

They separate API, simulated wiring, actual AI results, fixture integrity, model latency/usage when available, and pending human semantic review. No estimated cost is reported.

## Limits and debugging

This prototype handles one offered line and one requested item per event. It uses literal catalog search and stops when results require narrowing.

Exact excerpts, numeric checks, and instruction patterns cannot prove every interpretation is correct or detect every possible attack. A human must review item matching and the meaning of each excerpt.

For failures, open the red node in n8n:

- **Fetch quote:** check Procura and the context URL.
- **search_catalog:** check the catalog API; reference data is needed for matching.
- **Extract with Gemini:** inspect the provider error and saved credential, model setting, and project billing.
- **Validate extraction:** compare the rejected value with its actual quote excerpt.
- **Save draft lines:** inspect the status and error; source changes or existing drafts require review.

Do not paste API keys into chat or exported workflow files.

## Changed files

- server.js and lib/quote-context.js: context retrieval and draft-only API.
- lib/quote-extraction.js: prompt and evidence validation.
- automation/n8n/build-quote-workflow.js and automation/n8n/workflows/quote-extractor.json: workflow.
- scripts/evaluate-quote-extractor.js: independent evaluation.
- tests/quote-extractor.test.js and tests/quote-fixtures.js: local tests and clearly simulated responses.
- package.json: quote commands.
- docs/quote-extractor.md and docs/README.md: guide and index.

## Verified implementation results

- **Local tests:** sixteen quote tests passed. The thirteen approval and ten invoice tests also passed during regression testing.
- **API:** all 25 quote contexts, four invalid/missing-ID cases, and three draft-save rejection cases passed.
- **n8n:** all 25 simulated previews and one simulated save branch passed. These are wiring results, not model accuracy.
- **Real Neon draft storage:** one manually constructed, source-validated draft for quote 4000 was saved. Retry reused the same row; a conflicting draft returned 409. Original supplier bids, bid lines, events and sourcing items remained unchanged.
- **Gemini:** one attempted call failed with HTTP 402 because Google project prepaid credits were depleted. No actual extractions were produced. All 25 AI results, including the five injection cases, remain untested.
- **Model configuration:** models/gemini-3.5-flash-lite, reused from the saved invoice workflow.
- **Token usage:** unavailable; no cost estimate was made.

Reports:

    automation/n8n/.data/quote-evaluations/2026-10-09T16-39-34-617Z/report.json
    automation/n8n/.data/quote-evaluations/2026-10-09T16-41-59-195Z/report.json
    automation/n8n/.data/quote-evaluations/2026-10-09T16-45-23-974Z/report.json

These are simulated wiring, actual-model attempt, and manual storage integration results respectively.

After resolving Google project billing, rerun:

    npm run quote:eval -- --llm

Human review of interpretation and item matching remains necessary even when deterministic checks pass.
