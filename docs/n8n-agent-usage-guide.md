# Procura: how to use your n8n assistants

This is your everyday usage guide. Start with one workflow and one record. You do not need to understand all the code to run it.

**Guide checked against the repository and saved workflows on 9 October 2026.**

## 1. What you have

Think of the system as four parts:

- **Procura** is the application holding the procurement records.
- **Neon** holds its database.
- **n8n** moves information through steps. Each box on its canvas is a node.
- **Gemini** reads the information and writes an answer. It needs a working Google API credential and billing.

An **API** is a doorway that lets n8n ask Procura for records. An **execution** is one run of a workflow. A **fixture** is a made-up record we use to check the result.

| Workflow in n8n | What you give it | What you get | Does it save procurement data? |
| --- | --- | --- | --- |
| Procura - Requisition Assistant (Gemini) | A chat request | A requisition draft in chat | No |
| Procura - Invoice Exception Explainer (Gemini) | An invoice ID | An explanation of existing flags and review steps | No |
| Procura - Approval Review Summarizer (Gemini) | An approval ID | A brief for a human reviewer | No |
| Procura - Supplier Quote Extractor (Gemini) | A supplier bid ID | Quote facts, unknowns, and questions | Only an extraction draft when you enable saving |

These run in the **n8n editor**. There are no new AI buttons or human approval tabs inside Procura for these features. None submits a requisition, approves a request, creates a PO, selects a supplier, or pays an invoice.

## 2. Start the two applications

If both pages already open successfully, skip these commands.

In a PowerShell terminal:

    cd D:\CODING\procura
    npm run dev

In a second PowerShell terminal:

    cd D:\CODING\procura
    npm run n8n:start

Keep both terminals running. Open:

- [Procura](http://127.0.0.1:3000)
- [n8n](http://127.0.0.1:5678)

The numbers 3000 and 5678 are different doors on your computer. Procura and n8n each need their own running service. Starting Procura alone does not start n8n.

If you see an “address already in use” error, check the existing page first; another instance may already be running. To stop a service you started in a terminal, press **Ctrl+C** in that terminal.

## 3. Check Gemini once

Open the workflow you want to use. Open **Gemini Flash-Lite** in the requisition workflow, or **Gemini model** in the other three.

Select your saved Google Gemini credential. If you need to create one, enter the API key in n8n's credential form. Keep keys out of chat, prompts, and exported workflow files. Save the workflow.

The current saved configuration uses **models/gemini-3.5-flash-lite**. This records what is configured; it does not prove that the model is available to your account. Check the node's available model list if necessary.

**Last recorded Stage 3 Gemini evaluations stopped with HTTP 402 because the Google project's prepaid credits were depleted.** They produced no successful model outputs. If billing has since been fixed, run one example before starting a full evaluation.

The workflows are currently unpublished. **You can run these manual workflows and the test chat without publishing them.** Publishing does not fix credentials or billing.

When you run Gemini, the chat and retrieved sandbox evidence go to Google. Use the synthetic records for this exercise.

## 4. Requisition assistant: “help me ask for something”

Open **Procura - Requisition Assistant (Gemini)**.

1. Open the workflow's test chat.
2. Send: **I need two monitors.**
3. Let it search the catalog and ask questions.
4. Choose an item from the returned catalog results.
5. Give the missing details.
6. Read the completed draft and correct anything wrong.

For example, you can supply these fictional details in the same chat:

> Requester: Maya Shah. Department: IT. Delivery location: Delhi office. Needed by: 2026-11-15. Justification: equipment for two new joiners. Quantity: two. Use the monitor we selected from the catalog.

Choose a needed-by date appropriate to your test. The prototype collects requester, department, delivery location, needed-by date, justification, catalog item, and a positive whole-number quantity.

**What happens:** Gemini chooses a search keyword, uses **search_catalog**, asks for missing details, and writes a draft. The catalog search uses literal text, so “monitor” is a better test keyword than a long sentence.

**Check:** Is the selected item actually in the tool result? Does its unit price match the catalog? Did the draft preserve your quantity and answers?

**Where to inspect:** Open **search_catalog** to see the records returned to the model. Open **Requisition assistant** to inspect its response.

The answer is a readable chat proposal, not a saved requisition or code-validated submission. If you want an application record, you still need to enter and review it through the existing Procura process.

**Conversation memory** remembers the last ten exchanges in that session. Start a fresh session for a separate request.

## 5. Invoice explainer: “help me understand this exception”

Open **Procura - Invoice Exception Explainer (Gemini)**.

1. Open **Choose invoice**.
2. Set its code to:

       return [{ json: { invoice_id: 5010 } }];

3. Save the change and click **Execute Workflow**.
4. Open **Fetch invoice evidence** to see the original records.
5. Open **Validate explanation** to read the final result.

The fixture answer key expects invoice **5010** to have quantity mismatch, price mismatch, and overbilled quantity flags. This is the expected answer, not a previously successful Gemini answer.

Try these afterwards:

| Invoice ID | Expected fixture behavior |
| --- | --- |
| 5000 | No flags from the supplied checks |
| 5004 | Missing receipt |
| 5009 | Possible duplicate of lower-ID invoice 5008 |
| 5010 | Three issues to explain |
| 5011 | Clean example with two receipts contributing to the received quantity |

Use IDs 5000–5011 **except 5003**. Case 5003 is an intentional database rejection test and has no stored invoice.

Read the explanation alongside its **supporting facts**, suggested owner, and review action. The database rules find the flags; Gemini explains them. Validation checks the response and attaches the original amounts and other facts.

“No exceptions detected” means only these checks found nothing. Partial billing can trigger a quantity mismatch, received quantity includes receipts regardless of date, and duplicate similarity requires investigation. Read [the detailed invoice guide](D:/CODING/procura/docs/invoice-explainer.md) for the complete limits. The output is not permission to pay.

Evidence without an LLM: [invoice 5010 API](http://127.0.0.1:3000/api/invoices/5010/flags).

## 6. Approval summarizer: “help a person review this request”

Open **Procura - Approval Review Summarizer (Gemini)**.

1. Open **Choose approval**.
2. Set its code to:

       return [{ json: { approval_id: 6004 } }];

3. Save and click **Execute Workflow**.
4. Compare **Fetch approval evidence** with **Validate review brief**.

The answer key expects **6004** to show over-limit and inactive-approver issues. The final brief includes original request facts, recorded statuses, issues, questions, and limitations.

Useful comparisons:

| Approval ID | Expected fixture behavior |
| --- | --- |
| 6001 | Amount equals the recorded limit; no over-limit flag |
| 6004 | Over-limit and inactive-approver flags |
| 6005 | Recorded Approved, but the approver cannot be matched |
| 6007 | Pending and inactive, but no flags under the current rules |
| 6008 | Pending with an unresolved approver; flagged |

**Give an approval ID, not a requisition ID.** The fixture numbers happen to match, but that is not a general rule.

The flags cover the **whole linked requisition**. When several approval records are involved, check the source approval IDs in the supporting facts.

The current rules flag inactive or over-limit approvers only for recorded Approved statuses. Therefore 6007's clean result does not establish permission to approve. Budget, delegation, historical employee state, and currency conversion are outside these checks.

Human review means a person reads the brief and follows the existing approval process. Gemini does not make or record that decision.

Evidence without an LLM: [approval 6004 API](http://127.0.0.1:3000/api/approvals/6004/review).

## 7. Quote extractor: “turn the supplier's words into fields”

Open **Procura - Supplier Quote Extractor (Gemini)**.

1. Open **Choose quote**.
2. Start with:

       return [{ json: { bid_id: 4022, save_draft: false } }];

3. Save and click **Execute Workflow**.
4. Read the supplier text in **Fetch quote**.
5. Read **Validate extraction**, then **Preview only**.

The answer key for **4022** expects an identified monitor, unit price INR 10400, fourteen calendar days, and **unknown offered quantity**. The quote also contains an instruction attempt that should be reported. These are expected results for comparison.

**Null means “we do not know,” not zero.** The assistant must not borrow a requested quantity or a catalog price to fill a missing supplier offer.

| Bid ID | What to practice checking |
| --- | --- |
| 4000 | Complete offer: quantity 5, INR 9800, seven calendar days |
| 4019 | Amount 210 is present; currency and calendar lead time remain unknown |
| 4022 | Price and lead time are present; offered quantity remains unknown |
| 4024 | Incomplete quote; missing commercial fields remain unknown |

For 4019, “$” does not uniquely identify a currency, and “10 business days” is not ten calendar days.

Check each value against its exact quote excerpt. Catalog records help identify the item; the **supplier text** supplies the commercial offer. The prototype supports one offered line and one sourcing item per event.

### Optional: save an extraction draft

Once previewing makes sense, you can set:

    return [{ json: { bid_id: 4022, save_draft: true } }];

Run the workflow. The true branch goes to **Save draft lines**.

**This reruns Gemini and creates a new extraction. It does not simply save the previous preview.** Review the newly generated result and stored draft.

Only the extraction draft table is written. Authoritative bid lines and supplier decisions are not changed.

- 201: a new draft was stored.
- 200: an identical draft already exists; its row was reused.
- 409: source records changed or a different draft already exists. Investigate before retrying; the workflow does not overwrite it.

The draft table does not retain the full evidence, warnings, or model details. Keep the final execution output alongside the draft.

Evidence without an LLM: [quote 4022 API](http://127.0.0.1:3000/api/supplier_bids/4022/quote-context).

## 8. Debug by finding the first failed step

Open the failed execution and click the first red node. Read its **Input**, **Output**, and error. The input tells you what it received; the output tells you what it produced.

| Failure | Your next step |
| --- | --- |
| Fetch node: connection refused | Start Procura; check the matching API link above |
| Gemini: 402 | Check Google project billing and prepaid credits |
| Gemini: 401/403 | Check the credential and account permissions |
| Gemini: 429 | Inspect the provider message for quota or rate limits |
| API: 400 or 404 | Check the ID and whether the record exists |
| API: 409 or 422 | Read the relationship/context error; the record may not fit this workflow |
| API: 503 | Check Procura's terminal and database availability |
| Validation node rejects output | Compare raw model output with fetched evidence and the validation error |

A green execution means the configured steps completed. It does not prove every explanation is true. Correctness still needs comparison with the original evidence.

Do not edit a prompt to fix a server, credential, or billing failure. Change one relevant thing and rerun one case.

## 9. Understand the three kinds of evaluation

You do not need these commands for everyday manual use. They help you check changes.

| Check | Example command | What it establishes |
| --- | --- | --- |
| Local code tests | npm run test:invoice | Tested validation and failure behavior |
| Live API and answer key | npm run invoice:eval | Retrieval and fixture correctness |
| Simulated n8n run | npm run invoice:eval -- --mock | Workflow wiring with pretend model answers |
| Actual Gemini run | npm run invoice:eval -- --llm | Generated results to inspect and evaluate |

Replace **invoice** with **approval** or **quote** for their corresponding commands.

Mock mode does not measure AI quality. The normal quote evaluation previews results; its mock save check uses a fake storage service. A separate storage-only mode that writes a manual fixture draft is described in [the quote guide](D:/CODING/procura/docs/quote-extractor.md).

Actual Gemini evaluation can incur API charges. It still needs human review of meaning, not only automated checks. The requisition assistant currently has manual acceptance checks in [its guide](D:/CODING/procura/docs/requisition-agent.md), rather than an equivalent automated evaluator.

Evaluation runs create separate temporary workflows. Those can be archived after debugging. Keep the four main workflows listed at the top for daily use.

Private reports are stored in these folders:

    D:\CODING\procura\automation\n8n\.data\invoice-evaluations\
    D:\CODING\procura\automation\n8n\.data\approval-evaluations\
    D:\CODING\procura\automation\n8n\.data\quote-evaluations\

Each run has a dated folder containing report.json. Treat reports and execution logs as private.

## 10. Your first practice session

Try one chat request, invoice 5010, approval 6004, and quote 4022 in preview mode. Then try one clean case and one incomplete case.

For each, explain aloud: **“Here is the original information. Here is what AI did. Here is what code checked. Here is what a human still has to decide.”**

If Gemini is blocked, you can inspect API evidence and run mock checks, but describe those as integration demonstrations.

For the business explanation, continue with [Procura's four core pillars](D:/CODING/procura/docs/fde-four-pillars.md).
