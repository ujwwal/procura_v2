# Local n8n setup for Procura

## What this gives you

n8n is the visual workflow builder. Procura remains the procurement application and data source. An n8n workflow can receive a user request, ask an AI model what to do, call Procura API routes as tools, and pause before a human approves a write.

The two applications run side by side:

- Procura: <http://127.0.0.1:3000>
- n8n: <http://127.0.0.1:5678>

n8n has its own local data under `automation/n8n/.data/`. It does not use Procura's PostgreSQL database as its internal database. The directory is ignored by Git because it contains the local owner account, credentials, encryption material, and workflow execution history.

## Start it

In one terminal, start Procura:

```powershell
npm run dev
```

In a second terminal, start n8n:

```powershell
npm run n8n:start
```

Open <http://127.0.0.1:5678>. The first screen asks you to create the local n8n owner account. This account exists only in your local n8n data directory.

If the n8n runtime ever needs to be restored, run:

```powershell
npm run n8n:setup
```

The setup downloads the official Node.js 24 LTS Windows archive, verifies its SHA-256 checksum, and installs n8n inside `automation/n8n/`. It does not replace the computer's Node installation.

## Where the AI agent fits

The first workflow should stay small and reviewable:

```text
Chat message
  -> AI Agent
     -> catalog search tool (GET Procura /api/catalog_items?search=...)
     -> policy lookup tool (GET Procura /api/procurement_policies)
  -> structured requisition proposal
  -> human approval
  -> create requisition through a dedicated Procura agent endpoint
```

The model is the decision maker. The n8n workflow is the coordinator. Procura API routes are the tools. PostgreSQL is the source of truth. A human remains responsible for approving a purchase.

Add an OpenAI credential in n8n's **Credentials** screen when we build the AI Agent node. Credentials saved there are encrypted in n8n's local data and are not committed to Git.

## Optional settings

Copy `automation/n8n/.env.example` to `automation/n8n/.env` only if you want to change the port, timezone, or Procura base URL. The local `.env` file is ignored by Git.

## Useful commands

| Command | Purpose |
| --- | --- |
| `npm run n8n:setup` | Restore the supported Node runtime and n8n packages |
| `npm run n8n:start` | Start the local n8n editor |
| `npm run n8n:version` | Print the installed n8n version |
| `npm run dev` | Start Procura on port 3000 |
