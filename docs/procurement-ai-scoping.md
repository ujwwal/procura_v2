# Procura: procurement AI research and scoping

Research date: 9 September 2026. Status: preliminary desk research; no workflow selected for implementation.

## Decision to make

Which procurement task should we improve, why would AI help, and what evidence would justify continuing beyond a sandbox demo?

The sandbox permits API, GUI, and hybrid implementations. Choose access methods after choosing the task. The working learning budget is 15–25 hours from the shared project context. This brief proposes experiments, not changes to an employer's systems.

## Evidence and its limits

Official implementation documentation establishes product behavior. Vendor product pages establish advertised capabilities, not independently verified effectiveness. The workflow pain points below are hypotheses until validated against actual practice. We have not measured task volumes, handling times, rework rates, or commercial savings.

### A. Creating a complete purchase request

**User:** employee requesting goods, with a procurement analyst checking completeness.

**Problem hypothesis:** interpreting an informal request, finding an appropriate item, and applying policy causes clarification and correction work.

**Existing process:** Oracle documents catalog search, selection, cart editing, delivery details, and submission, including noncatalog options. This provides an established manual baseline rather than assuming the process is entirely email-based. [Oracle requisition creation](https://docs.oracle.com/en/cloud/saas/procurement/26b/oaprc/create-a-requisition.html)

**Existing AI:** Oracle's 26C documentation describes policy-aware search and clarification. Levelpath advertises structured intake and routing across procurement workflows. These demonstrate solution patterns; neither establishes our likely improvement. [Oracle AI guide](https://docs.oracle.com/en/cloud/saas/readiness/scm/26c/ssproc26c/26C-ssproc-wn-f43319.htm), [Levelpath intake](https://www.levelpath.com/capabilities/intake-orchestration)

**Proposed boundary:** informal request to a complete, policy-checked draft for one category. Approval, ordering, and delivery are separate outcomes.

**AI contribution:** interpret language, identify missing information, retrieve relevant guidance, and explain suitable choices. Code validates identifiers, required fields, arithmetic, allowed transitions, and enforceable policy conditions.

**What might invalidate the idea:** a clear catalog and conditional form already get users to the same result faster and with fewer errors.

### B. Investigating an invoice exception

**User:** AP analyst working with a buyer or receiver.

**Problem hypothesis:** assembling evidence and choosing the next resolution step takes longer than detecting the exception.

**Existing process:** Oracle already supports automatic/manual holds and release through UI and APIs. Some holds require fixing the underlying condition rather than manual release. Its tolerance checks are an ordinary validation baseline. [Oracle holds](https://docs.oracle.com/en/cloud/saas/financials/26b/fappp/how-invoice-holds-work.html), [Oracle tolerances](https://docs.oracle.com/en/cloud/saas/financials/25d/fappp/invoice-tolerances.html)

**Proposed boundary:** invoice plus hold and supporting records to an evidence-linked investigation note and proposed owner/action. No automatic hold release or payment.

**AI contribution:** interpret notes and assemble a supported explanation; code performs matching and variance calculations. Without unstructured evidence or branching investigation needs, a joined report may be sufficient.

**What might invalidate the idea:** existing hold codes and a consolidated record view already identify the next action without substantial interpretation.

### C. Comparing supplier quotations

**User:** buyer evaluating responses to a sourcing event.

**Problem hypothesis:** quotations express price, delivery, and exclusions differently, requiring normalization before comparison.

**Existing process and AI:** SAP documents conventional bid comparison and analysis, including filters and scenarios. SAP also advertises an AI sourcing assistant. The incremental opportunity is understanding inconsistent quotation content, not replacing a weighted calculation with an LLM. [SAP bid analysis](https://help.sap.com/docs/strategic-sourcing/event-management/bid-analysis), [SAP sourcing assistant](https://www.sap.com/uk/use-cases/joule-assistant/sourcing-assistant)

**Proposed boundary:** three synthetic quotes for one item specification to a sourced comparison and recommendation under explicit buyer criteria. No award execution.

**AI contribution:** extract and explain terms and omissions. Code normalizes comparable amounts and applies agreed scoring. Missing freight, currency, or specification data must remain unresolved rather than be guessed.

**What might invalidate the idea:** suppliers already enter standardized bids and existing comparison tables meet the buyer's needs.

## Worked examples for discovery

All names, amounts, policies, and conditions in these examples are invented for the sandbox.

| Candidate | Input and evidence | Expected outcome | Deliberate uncertainty |
| --- | --- | --- | --- |
| Request draft | Employee asks for two monitors; published policy specifies approved models; catalog has prices | Ask for missing required delivery/budget information, identify permitted choices, prepare a reviewed draft | Do not assume urgency proves stock availability or delivery feasibility |
| Invoice investigation | Invoice bills 10 units, PO orders 10, receipt records 8; note says remaining delivery is expected | Identify receipt shortfall and propose verification with receiver, citing the actual records | Expected delivery is not proof of receipt; do not assert the supplier overbilled |
| Quote comparison | A quotes 50,000 plus 5,000 freight; B quotes 53,000 delivered; both otherwise meet stated requirements | Calculate comparable totals and explain B's lower delivered price under these assumptions | If tax treatment or specifications differ, pause the ranking until comparable |

For each example, document what a human reads, what decision they make, and what artifact they produce. These become evaluation cases only after the expected behavior is reviewed.

## Fit with the current application

The relationship work identified during initial scoping has now been implemented. The base schema is extended by `db/workflows.sql`, with connected synthetic cases in `db/workflow-seed.sql`.

| Candidate | Current foundation | Remaining work before AI | Preliminary fit |
| --- | --- | --- | --- |
| Request draft | Catalog, policies, requisition lines, supplier links, delivery fields | AI tools, proposal review, run logging, and eval cases | Strong if confined to one category |
| Invoice investigation | PO/invoice lines, receipts, holds, policies, and supporting notes | Investigation tools, evidence contract, and richer held-out cases | Strong second workflow |
| Quote comparison | Sourcing items, supplier bids, commercial terms, and evaluation criteria | Comparison tools, scoring rules, and held-out cases | Plausible third workflow; document parsing adds scope |

These are engineering judgments, not effort measurements. The new database relationships enforce record consistency, but the AI proposal and approval workflow has not been implemented.

## How to demonstrate improvement

Compare three approaches on equivalent starting data:

1. Manual work in the sandbox, using a clear written procedure.
2. A simple non-AI baseline: conditional form, consolidated report, or normalized comparison table.
3. The AI-assisted approach, including review and correction time.

Use separate development and held-out cases. A small initial design is six development cases and six held-out cases per selected workflow, with three AI runs per held-out case to expose variation. This is a pilot, not statistical proof. Counterbalance manual/AI order or use equivalent case variants to reduce practice effects. Freeze policy and data versions, and reset state between runs.

| Metric | Definition |
| --- | --- |
| Valid task completion | Output and resulting state satisfy the case's required facts and actions |
| Active handling time | Human input, review, and correction time; record model waiting separately |
| Rework | Number and severity of corrections needed before accepting the result |
| Evidence accuracy | Material factual claims supported by the cited record or policy |
| Appropriate clarification | Required missing information requested without unnecessary questions |
| Execution failures | Invalid IDs, duplicate writes, incorrect transitions, or unapproved actions |
| Operating cost | Measured model/tool usage per attempted and per successful task |

**Proposed pilot decision rule:** zero critical unauthorized or destructive actions in observed runs; at least 90% valid completion; at least 20% lower median human handling time than the strongest non-AI baseline without worse material error rates. These are negotiation starting points, not industry benchmarks. Report raw counts, individual failures, and ranges; passing a small sample does not establish production safety.

**Value calculation:** monthly capacity hours recovered = task volume × adoption fraction × net human minutes saved per task ÷ 60. Net time includes expected correction effort. Separately subtract model, maintenance, and amortized implementation costs when estimating monetary value. Recovered capacity is not automatically cash savings. Do not assume shorter handling time eliminates approval or supplier waiting time.

## Preliminary recommendation and unresolved questions

Investigate request drafting first because it has a documented comparator and a bounded output. This is a provisional research priority, not authorization to implement or a conclusion that it has the highest business ROI. Invoice investigation may be better if actual cases reveal substantial evidence-gathering work. Quote comparison may be closer to the user's auctions/contracts responsibilities.

The decision still needs:

- Which of these tasks the user performs or observes directly, and how often.
- One anonymized example of the actual sequence and output, reconstructed in plain language.
- Whether effort is spent interpreting information, entering it, correcting it, or waiting on someone else.
- What existing platform features already solve and why people do not use them, if applicable.
- Which mistakes matter most and what the smallest acceptable output would be.

Next learning session: walk through the most familiar task, record a rough baseline, and revise this brief before selecting implementation. The research can inform this conversation; it cannot substitute for it.
