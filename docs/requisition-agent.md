# Procura: your first requisition agent

## What you have

A small n8n workflow: chat request → agent, connected to Gemini Flash-Lite, conversation memory, and a catalog search tool. The agent prepares a draft in chat. Saving, approval, and policy checks are later milestones. Its text output is a human-readable proposal, not validated JSON for database insertion.

## Run it

1. Start Procura from the project root: `npm run dev`. PostgreSQL and the existing database configuration must be available.
2. Start n8n in another terminal: `npm run n8n:start`.
3. Open http://127.0.0.1:5678. Look for **Procura - Requisition Assistant (Gemini)**. If it has not been imported, use **Import from File** and choose `automation/n8n/workflows/requisition-assistant.json`.
4. Open **Gemini Flash-Lite**, create/select a Google Gemini API credential, and enter your API key there. Never put the key in the workflow JSON or chat.
5. The model is `models/gemini-3.5-flash-lite`, the latest stable Flash-Lite found in Google's documentation on 2026-09-19. If unavailable to your account, choose an available Flash-Lite model from the credential-backed model list. This is pinned, rather than an unverified rolling alias.
6. Save the workflow and open its test chat. It does not need to be published for this test.
7. Say: **I need two monitors**. Answer the assistant's questions and inspect each node's execution.

Google model reference: https://ai.google.dev/gemini-api/docs/models/gemini-3.5-flash-lite

## What each piece does

| Node | Plain-language job |
| --- | --- |
| Chat request | Receives your message |
| Requisition assistant | Decides whether to search, ask a question, or write a draft |
| Gemini Flash-Lite | Supplies the language model through Google's API |
| Conversation memory | Remembers the last ten exchanges in this session; not durable storage |
| search_catalog | Makes a GET request to Procura and returns actual catalog records |

Only the keyword changes in the tool call. The host, path, GET method, and result limit are fixed. Native local n8n uses `127.0.0.1:3000`; a Docker or cloud n8n deployment needs a different reachable address. Catalog descriptions and your chat are sent to Google when you run the agent. Use the synthetic sandbox records.

The seed data includes a 24-inch monitor if the workflow seed has been applied successfully. Ask for that item first. The assistant collects requester, department, delivery location, needed-by date, justification, item choice, and quantity. These are this prototype's completeness rules. It quotes catalog unit prices and leaves totals to application code.

## Debug one step at a time

- Credential/model error: check the selected credential and available model list in the Gemini node. A 429 can mean quota or rate limits.
- Connection refused: ensure Procura is running on port 3000. Open `/api/catalog_items?search=monitor&limit=10` in the browser.
- Database unavailable: check PostgreSQL and the existing Procura `.env`; do not change model prompts to fix a database error.
- Empty results: use a short singular keyword. Search uses literal substrings, not semantic similarity. Inspect the tool output before changing the prompt.
- Forgotten answers: keep the same chat session. Memory is temporary and clears on restart; long chats can exceed the ten-exchange window.
- Wrong response: inspect the actual tool result, then the system message in Requisition assistant. Prompt instructions guide behavior but do not guarantee accuracy.

## Our four questions

| Question | Level 1 answer |
| --- | --- |
| Value | Reduce catalog searching and effort preparing a complete requisition draft |
| AI use | Interpret requests, choose a search keyword, ask for missing information, summarize selected records |
| ROI | Eligible monthly requests × adoption × measured net minutes saved / 60 × hourly labor cost, minus operating costs; include build cost separately. Time saved is capacity, not automatically cash savings. |
| Success | Correct catalog selection and quantity, completeness, user corrections, time to a correct draft, API cost, and no false claims that a draft was saved |

## Manual acceptance checks (results not yet measured)

1. **Normal:** Ask for two monitors; provide the missing fields. Check IDs and unit price against the tool response.
2. **Missing details:** Say only 'I need equipment'. Expect clarification, no fabricated item.
3. **No match:** Ask for an item absent from the catalog. Expect an honest no-match response.
4. **Correction:** Change quantity from two to three. The final draft should use three.
5. **Invalid quantity:** Ask for minus two monitors. Expect a request for a positive whole number.
6. **Tool outage:** Stop Procura and search in a fresh chat. Expect a retrieval error or clear failure, never invented catalog evidence.
7. **Save request:** Ask 'submit it'. Expect an explanation that this version drafts only.
8. **Session isolation:** Start a new chat. It should not reuse another session's requester details.

Record baseline time, assisted time including corrections, correctness, and API usage for the same kinds of requests. No ROI or model-quality claim is established until these checks are run with a credential.
