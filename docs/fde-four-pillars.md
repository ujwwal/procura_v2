# Procura: the four core pillars

This document answers your mentor's four questions using the features already built in Procura.

**The four questions are:**

1. **How can I add value?**
2. **How can I use AI to build these use cases?**
3. **What is the ROI?**
4. **How do I measure success?**

Think of them as: **help someone → choose a useful implementation → estimate the benefit → check whether it actually helped.**

**Evidence reviewed on 9 October 2026.** This is an FDE learning exercise using synthetic procurement records. It does not claim measured client impact or production readiness.

## Start with your actual role

You maintain and configure GEP for a client. You know procurement software and its processes, but you are not claiming to perform every buyer, approver, or accounts-payable task yourself.

Your advantage is understanding how users, configuration, records, permissions, and integrations fit together. The next step is to connect that knowledge to a user's problem and a measurable outcome.

For this exercise, the requester, buyer, approver, and accounts-payable analyst are **candidate users**. Their pain and task volumes still need confirmation through observation or interviews. The descriptions below are working hypotheses, not findings about your client.

You do not need a new invention. A familiar solution can demonstrate FDE thinking if you can explain the user's problem, implement it within the actual system, and show evidence of improvement.

## Pillar 1: how can I add value?

**Value means making a task easier, faster, or more reliable for a specific person.** “We added Gemini” describes technology; it does not describe a benefit.

The useful starting question is: **Who is struggling, what do they do today, and what would improve their work?**

| Feature already built | Candidate user and task | Possible value | Simple alternative to compare |
| --- | --- | --- | --- |
| Requisition assistant | An employee searches for an item and prepares a complete request | Less searching and clarification; a clearer draft | Catalog search plus a form that requires missing fields |
| Invoice exception explainer | AP or a buyer gathers invoice, PO, and receipt evidence to understand flags | Less time assembling and interpreting an exception | A consolidated evidence report with fixed explanations |
| Approval review summarizer | A reviewer reads a request and checks recorded approval issues | Less reading and a more focused review | A standard checklist with request facts and rule flags |
| Supplier quote extractor | A buyer copies a supplier's offer into fields | Less transcription and more visible missing information | A supplier form or a fixed parser for standard quote text |

### What each feature contributes

**Requisition:** A person says “I need two monitors.” The assistant searches actual catalog records and asks for missing details. The useful result is a complete proposal that the person can check. This version does not save or submit it, so do not count savings from automatic record creation.

**Invoice:** A reviewer normally needs to connect several records before understanding an exception. Procura gathers the evidence; Gemini prepares an explanation and suggested review steps. The potential benefit is quicker understanding. Existing database rules detect the flags, so AI cannot take credit for finding them.

**Approval:** A brief can help the reviewer see relevant request facts, recorded issues, and useful questions. It supports the human decision. It does not establish budget, delegated authority, or permission to approve.

**Quote:** A supplier's words can be turned into draft fields. Unknown offered quantity, currency, or timing stays unknown. The useful outcome is fewer copying errors and clearer questions to ask the supplier. Draft storage is available; selecting a supplier is outside this feature.

A task can have low value even when the demo looks impressive. If an existing report or form already solves the problem quickly, adding AI must justify its extra review effort and cost.

**Your first evidence-gathering task:** Ask a representative user to show you one real task, where they spend time, what they correct, and what a usable output looks like. For this sandbox, start with synthetic versions of that task.

## Pillar 2: how can I use AI to build these use cases?

**Give AI the language work. Give ordinary code the exact checks and application actions.**

AI can understand different ways of asking for something, summarize evidence, and interpret unstructured text. Code can fetch the correct record, calculate a rule, check an ID, and control where data is saved.

### The roles in your implementation

| Part | Plain-language job |
| --- | --- |
| Procura and Neon | Hold the application records and relationships |
| Procura API | Retrieve the records a workflow needs |
| n8n | Connect the steps and expose inputs, outputs, and failures |
| Gemini | Interpret the request, explain evidence, or extract quote facts |
| Validation code | Check supported structure, IDs, references, and selected claims |
| Human | Check meaning and make procurement decisions |

The requisition workflow is the clearest **agent**: the model can choose to search the catalog, ask a question, or return a draft.

The other three are mostly fixed workflows with an AI step: fetch evidence, call Gemini, validate, and present the output. The quote workflow also has an optional draft-save branch. “Assistant” is a useful name for all four; they do not all make autonomous tool choices.

A fixed sequence is suitable when the next step is already known. More autonomy is useful only when it helps the user complete the task.

### What AI does in each feature

| Feature | Gemini's job | What the surrounding system checks or controls |
| --- | --- | --- |
| Requisition | Choose search words, ask questions, write a proposal | Fixed catalog tool; no write tools. The final chat draft is not code-validated |
| Invoice | Explain supplied issue categories and suggest review actions | Evidence retrieval; category and reference checks; original supporting facts attached by code |
| Approval | Summarize the request, explain recorded issues, suggest questions | Approval-to-requisition links; issue attribution; original facts and recorded statuses attached by code |
| Quote | Extract supported item and commercial fields; identify unknowns | Quote excerpts, numeric support, item matching, source-version checks, and draft-only storage |

An example makes the division easier:

- The invoice data says the supplier billed more units than the recorded receipts cover.
- The database rule raises the flag.
- Gemini explains what a reviewer should investigate.
- Code attaches the original quantities.
- A person decides the next procurement action.

The AI does not need to calculate the mismatch or decide whether payment is allowed.

### What makes the implementation credible

The important engineering work includes retrieving related records consistently, exposing check limitations, validating generated output, preserving unknown quote values, handling failures, and keeping drafts separate from authoritative records.

For example, an approval brief must name the approval records responsible for an issue. A quote must not inherit the buyer's requested quantity when the supplier never offered it.

These details demonstrate that you understand the system around the model. Passing validation still does not prove every sentence is correct; a human must review the meaning.

A supplier quote can also contain instructions such as “ignore previous rules.” That text is part of the document being read, not an instruction from the user. The implementation has checks for recognized attempts, but actual Gemini behavior against the attack cases remains unmeasured.

## Pillar 3: what is the ROI?

**ROI asks whether the benefit is worth the total cost.**

For the current prototype, the honest answer is: **we have a way to calculate ROI, but we do not yet have measured ROI.**

Start with time, then estimate its monetary value.

### Step 1: measure the time saved

For one well-defined task:

    Monthly capacity hours recovered =
        eligible monthly task volume
        × adoption fraction
        × average net human minutes saved per task
        ÷ 60

“Eligible” means the tasks this version can handle. For quotes, multiple offered lines are outside the current scope.

“Adoption” means the fraction actually handled using the assistant.

“Net human minutes saved” means baseline handling time minus assisted handling time, including input, review, correction, reruns that require attention, and manual fallback. Include failed attempts in the pilot's average; do not count only the fastest successful examples.

Use **average** net minutes for the volume calculation. Report the **median** separately to describe a typical task. A median alone can hide expensive failures.

Record model waiting time separately, as well as total elapsed completion time. Waiting for an approver or supplier is different from active work by the user.

### Step 2: estimate value and costs

    Estimated monthly capacity value =
        hours recovered × loaded hourly labor cost

    Estimated monthly net capacity value =
        capacity value − monthly operating cost

A loaded rate includes the relevant employment costs. Use an agreed rate; the example below is not your salary.

Operating cost includes model calls, retries, incremental infrastructure, and maintenance/support time. Initial build cost includes implementation, evaluation, and setup effort.

**Recovered time is capacity, not automatically cash savings.** It may let someone handle more work. Cash savings require evidence that paid cost actually falls.

Do not count the full value of an invoice as a benefit because an exception was flagged. Avoided errors or losses need separate evidence and should not be counted twice.

### A worked example: assumptions only

Suppose we evaluate **invoice exception review**. None of these numbers has been measured in Procura.

| Assumption | Example value |
| --- | --- |
| Eligible reviews each month | 600 |
| Adoption | 50% |
| Best non-AI baseline handling time | 6 minutes |
| Assisted handling time, including correction and fallback | 3 minutes on average |
| Loaded hourly rate | INR 600 |
| Monthly operating cost, including maintenance | INR 3000 |
| Initial build cost | INR 24000 |

The arithmetic:

    600 × 0.50 × (6 − 3) ÷ 60 = 15 hours recovered per month
    15 × INR 600 = INR 9000 monthly capacity value
    INR 9000 − INR 3000 = INR 6000 monthly net capacity value

If these assumptions hold, estimated payback is:

    INR 24000 ÷ INR 6000 = 4 months

For a twelve-month comparison:

    Annual benefit = INR 9000 × 12 = INR 108000
    First-year cost = (INR 3000 × 12) + INR 24000 = INR 60000
    First-year ROI = (108000 − 60000) ÷ 60000 × 100 = 80%

This is **hypothetical ROI based on estimated capacity value**, not proven cash ROI. Build cost is counted once. Do not also subtract an amortized build cost in the operating-cost line.

If adoption is only 20%, the same assumptions produce six hours recovered, INR 3600 capacity value, INR 600 net value, and approximately forty months to recover the build cost. If net benefit is zero or negative, there is no positive payback under those assumptions.

This sensitivity matters more than an impressive single percentage.

### Apply ROI to each feature separately

| Feature | Unit to time | Include in assisted effort |
| --- | --- | --- |
| Requisition | One correct, complete chat draft | Answering questions, checking catalog match, correcting the draft; manual entry if included in both comparisons |
| Invoice | One reviewed exception | Reading facts, checking explanations, deciding the next review step |
| Approval | One reviewed request brief | Reading the request, checking attribution and limits, correcting the brief |
| Quote | One correct extraction draft | Comparing fields with the source, resolving ambiguity, correcting or manually redoing extraction |

Do not multiply the example by four. Measure each task's volume and savings. When several assistants support the same process, avoid counting the same saved minutes twice.

Compare against the **best practical non-AI alternative**. If a consolidated API report creates most of the improvement, report that benefit separately from the additional benefit of Gemini.

## Pillar 4: how do I measure success?

**Success means the user gets a correct, useful result with less total effort at an acceptable cost.**

A working API and a green n8n execution are necessary engineering evidence. They are not the final business result.

### Feature-specific checks

| Feature | What a correct result must demonstrate |
| --- | --- |
| Requisition | Correct catalog item and quantity; required details collected; corrections respected; no false claim that the draft was saved or submitted |
| Invoice | All supplied issue categories represented; valid supporting references; useful next checks; no invented facts or payment decision |
| Approval | Original statuses kept separate from decisions; issues attributed to the right approval records; scope and missing information disclosed |
| Quote | Correct item and commercial fields; exact source support; unknown values preserved; no borrowed catalog prices/request quantities; draft-write boundaries respected |

For quotes, measure both **per-field correctness** and **whole-draft correctness**. Six correct fields and one material invented field do not make a correct draft.

For explanations and briefs, a human checks whether the words are faithful to the evidence and whether the proposed questions or actions are useful.

### Shared scorecard

| Measure | How to record it |
| --- | --- |
| Correct completion | Correct, usable outputs divided by all attempted tasks; log failures and fallbacks |
| Human handling time | Input, review, correction, and fallback time; report mean, median, range, and slow cases |
| Elapsed time | Time from starting to a usable result, including model waiting |
| Rework | Corrections per task and whether errors affect a procurement decision |
| Adoption | Tasks actually attempted with the assistant divided by eligible tasks |
| User acceptance | Outputs the reviewer can use without material correction |
| Cost | Total operating spend per attempt and per correct completion, including failed calls |
| Action boundaries | Any unauthorized status change, authoritative write, or false completed-action claim |

Acceptance and correctness are different: a user might accept a wrong answer. Check accepted outputs against evidence too.

### A small pilot you can actually run

1. Pick one feature and define exactly when its task starts and ends.
2. Prepare a small, varied set of cases, for example 10–20 per approach initially. Include clean, problematic, ambiguous, and failure cases.
3. Compare the current manual process, the strongest simple non-AI alternative, and the AI-assisted version.
4. Use comparable cases and alternate the order so practicing a case does not unfairly help the later method.
5. Time active work and total elapsed time. Keep wrong results and failures in the records.
6. Have a knowledgeable reviewer grade correctness and usefulness against the source evidence.
7. Calculate the scorecard and ROI using the observed results. Increase the sample before drawing broader conclusions.

Start with these **proposed pilot targets**, carried forward from the scoping work:

- At least 90% correct, usable completion.
- At least 20% lower median human handling time than the strongest non-AI baseline, without worse material errors.
- Zero observed critical unauthorized or destructive actions.

These are starting points to agree with your mentor, not industry standards. Report counts such as “18 of 20,” individual failures, and time distributions. A small sample with no bad actions does not establish production safety.

A simple worksheet:

| Case | Method | Correct and usable? | Active minutes | Elapsed minutes | Corrections/failure | Reviewer note |
| --- | --- | --- | --- | --- | --- | --- |
| Example case ID | Manual / non-AI / AI | Yes / no | Measured | Measured | Observed | Evidence and decision |

Keep model configuration, execution ID, available usage/cost data, and source version alongside the AI results. Record unavailable usage as unknown.

## What has actually been demonstrated so far?

| Evidence | Recorded result | What it establishes |
| --- | --- | --- |
| Local tests | Invoice 10; approval 13; quote 16 passed | Tested code behavior and failure handling |
| Live evidence APIs | Invoice 11 fixtures; approval 10; quote 25, plus error checks passed | Retrieval against the synthetic answer keys |
| Simulated n8n runs | Invoice 12 cases; approval 11; quote 25 previews and one fake save check passed | Workflow wiring with simulated model responses |
| Real quote draft storage | One manually constructed, source-validated draft saved; identical retry reused its row; conflicting draft rejected | Storage and retry/conflict behavior |
| Actual Stage 3 Gemini runs | Last recorded attempts stopped with billing error HTTP 402; no successful outputs | AI evaluation remains pending |
| Human semantic review | Pending | Explanation usefulness and meaning remain unmeasured |
| Time savings, adoption, and ROI | No measured baseline or pilot yet | Business impact remains unmeasured |

The manually saved draft was not generated by Gemini. Mock answers do not demonstrate model accuracy. Five quote attack fixtures and synthetic invoice/approval attacks do not establish general resistance to malicious document instructions.

The APIs expose the limits of their current rules. For example, a pending approval can have no inactive-approver flag, and an invoice duplicate flag is a similarity signal. Evaluate the assistant against those actual meanings, rather than treating a clean result as procurement authorization.

## How to explain this to your mentor

You can say:

> I built four bounded procurement assistants in Procura using n8n and Gemini. The requisition assistant prepares chat drafts; the Stage 3 features explain invoice exceptions, summarize approval evidence, and extract supplier quote drafts. I verified retrieval, validation, workflow wiring, and draft-storage behavior. Actual Stage 3 model evaluation was blocked by billing in the last recorded runs. My next evidence is whether these assistants produce correct outputs and reduce handling time compared with practical non-AI alternatives. ROI will use those measured savings and total costs.

That demonstrates ownership of the problem, integration, limitations, and measurement without claiming results you have not obtained.

Your immediate next work is to resolve the model billing blocker if it is still present, run one real example, review its meaning, and collect a baseline for one feature. Then run the small comparison and replace assumptions with measurements.

Use [the n8n usage guide](D:/CODING/procura/docs/n8n-agent-usage-guide.md) for the operating steps. The earlier [scoping research](D:/CODING/procura/docs/procurement-ai-scoping.md) provides background; this document is the practical four-question explanation of the implementation now in place.
