# Procura invoice exception explainer

This feature explains recorded invoice exceptions and suggests review steps. It does not change invoice statuses or make payment decisions.

## The workflow in simple terms

1. **Choose invoice**: provide an invoice ID.
2. **Fetch invoice evidence**: Procura reads the invoice, lines, PO, receipts, duplicate candidates, and flags.
3. **Prepare prompt**: n8n wraps those records as data.
4. **Explain with Gemini**: the model explains the supplied issues.
5. **Validate explanation**: code checks the output and attaches the original supporting facts.

The API fetches the paperwork. n8n passes it between steps. Gemini explains what the paperwork says.

## Run in n8n

In the project folder, start Procura:

    npm run dev

In another terminal, start n8n:

    npm run n8n:start

Open [local n8n](http://127.0.0.1:5678), then **Procura - Invoice Exception Explainer (Gemini)** if already imported. Otherwise use **Import from File** with:

    automation/n8n/workflows/invoice-explainer.json

Open **Gemini model** and select the existing Google Gemini API credential. The export has no API key. Its model setting was reused from the saved requisition workflow. This reuses your configured model; it does not establish that it is the latest or currently available. The real evaluation stopped on a Google billing error.

Open **Choose invoice** and change 5010 to the ID you want to review. Click **Execute Workflow**, then open **Validate explanation**.

This uses a manual trigger. No publishing, public webhook, or conversation memory is needed.

The exported workflow calls Procura at localhost port 3000. The evaluation uses a temporary local API server and adjusts only its private evaluation workflow's URL.

## Read the result

The result contains an invoice ID, summary, review-only marker, and issues. Each issue has:

- Category.
- Evidence references.
- Explanation.
- Suggested owner: AP, buyer, supplier, or master-data.
- Suggested review action.
- Supporting facts copied directly from the API.

Gemini references evidence IDs rather than writing amounts or dates in prose. Code checks all categories and evidence references, rejecting missing or extra ones. It also rejects malformed JSON, wrong IDs, unsuitable owners, numerical claims in prose, and selected decision/completed-action phrases.

These checks cannot prove every sentence is true or block every possible instruction attack. Read the explanation alongside its facts.

A clean result says: **No exceptions were detected by the supplied checks.** This does not establish approval or payment eligibility.

## The API

    GET /api/invoices/:id/flags

Example: [invoice 5010 evidence](http://127.0.0.1:3000/api/invoices/5010/flags).

The endpoint uses a repeatable-read, read-only PostgreSQL transaction with UTC date comparisons. It returns:

- invoice and purchase_order
- invoice_lines with PO lines and receipts
- duplicate_candidates
- flags grouped by category
- evidence with stable references and original facts
- check_limitations

Invalid IDs return 400; missing invoices return 404; database/evidence failures return 503 with a generic error. A failed lookup never becomes a clean review result.

Amounts and quantities remain decimal strings to preserve precision. No invoice notes column is assumed.

## Existing check meanings

| Check | Meaning and limits |
| --- | --- |
| quantity_mismatch | Invoice line quantity differs from the full PO line quantity. Partial billing can trigger it. |
| price_mismatch | Invoice unit price differs from the matched PO line price. |
| currency_mismatch | Invoice currency differs from its header PO. Existing insertion protection prevents the stored fixture for this case. |
| missing_receipt | A linked PO line has no receipt record. |
| overbilled_quantity | This line exceeds total recorded received quantity. Receipt dates are not filtered; cumulative billing is not checked. |
| invoice_before_po | Invoice timestamp precedes its PO date at midnight UTC. |
| no_po_link | Invoice header has no linked PO. |
| possible_duplicate | A lower-ID invoice has the same supplier, similar amount, and creation within five days. Similarity is a review signal. |

Case 5003 is a separate rejection test. It is not recreated or included in the eleven stored invoice cases.

## Evaluation

Local validation and failure tests:

    npm run test:invoice

Live API evaluation against the independent answer key:

    npm run invoice:eval

Actual n8n/Gemini evaluation:

    npm run invoice:eval -- --llm

LLM evaluation requires Windows, the installed n8n runtime, and a saved Gemini credential. It imports separate inactive demo/evaluation workflows and preserves the requisition workflow. It reads procurement records and sends the synthetic evidence to Google.

All eleven cases and invalid/missing IDs are covered. LLM mode adds one instruction attack only to an in-memory description; database records remain unchanged.

Private reports and execution logs are saved here:

    automation/n8n/.data/invoice-evaluations/<run-time>/

The report separates API correctness, AI checks, measured model usage when available, and pending semantic review. It includes the CSV's expected review suggestions. Equivalent wording is acceptable.

## Debugging

- **Fetch fails**: open the example endpoint, confirm Procura is running, and check the database connection.
- **Gemini fails**: check its selected credential, model availability, and quota.
- **Validation fails**: inspect the model output and original API evidence. The validation error states what failed.
- **Invoice missing**: use a fixture ID from 5000–5011 except 5003.
- **Evaluation fails**: inspect its report and private log. Errors are failures, not clean invoices.
- **Wording is wrong despite passing**: record a semantic failure. Structural checks cover only part of correctness.

## References

The implementation follows installed n8n node definitions and the official [Basic LLM Chain documentation](https://docs.n8n.io/integrations/builtin/cluster-nodes/root-nodes/n8n-nodes-langchain.chainllm/). Google's [structured output documentation](https://ai.google.dev/gemini-api/docs/structured-output) explains JSON formatting support. This workflow independently validates its model response; formatted JSON alone does not establish factual correctness.

## Verified results for this implementation

- Local validation/failure tests: ten passed.
- Live Neon API: eleven fixture cases and five invalid/missing-ID cases passed.
- Actual n8n wiring with simulated responses: twelve passed. This is not an AI quality result.
- Actual Gemini evaluation: blocked by HTTP 402, prepaid Google project credits depleted. No explanations were generated.
- Real-model injection handling and explanation meaning remain untested; human semantic review is pending.

Run a wiring-only check without calling Gemini:

    npm run invoice:eval -- --mock

After resolving billing in the Google project, rerun:

    npm run invoice:eval -- --llm

Actual-model report:

    automation/n8n/.data/invoice-evaluations/2026-10-08T16-23-10-678Z/report.json

Simulated wiring report:

    automation/n8n/.data/invoice-evaluations/2026-10-08T16-28-05-718Z/report.json

## Implementation files

- `server.js` and `lib/invoice-context.js`: read-only API and consistent evidence retrieval.
- `lib/invoice-explanation.js`: prompt and structured response validation.
- `automation/n8n/build-invoice-workflow.js` and `automation/n8n/workflows/invoice-explainer.json`: workflow generator and importable workflow.
- `scripts/evaluate-invoice-explainer.js`: independent fixture and workflow evaluation.
- `tests/invoice-explainer.test.js`: validation and failure tests.
- `package.json`: commands for tests, workflow generation, and evaluation.
- `docs/invoice-explainer.md` and `docs/README.md`: guide and documentation index.

Neon schema and business records were not changed during this implementation.
