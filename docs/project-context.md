# Context: Procura AI Procurement Project (FDE Prep)

## Background
- I'm an Analyst in Oracle Tech Consulting at EY (Oracle Fusion Procurement/SCM work), based in Delhi. Doing a BCA (finishing July 2026).
- Long-term goal: pivot to a Forward Deployed Engineer (FDE) role within 1-1.5 years, targeting FAANG/top AI companies (Palantir, OpenAI, Anthropic, Scale AI).
- Mentor for this specific project is an FDE at OpenAI (met him at a fireside chat, stayed in touch). He is going to test me on this at the end of the month.
- I built a project called **Procura** — a procurement dashboard similar to Zycus, with supplier management, contracts, and sourcing modules. I'm now trying to add AI to it as an FDE-prep exercise.
- I have some prior AI/ML project experience: QuietCost (Monte Carlo fiscal simulator, top 10/808 teams at USAII hackathon), a RAG-based LinkedIn post generator (LangChain + FAISS), and an AI evaluation layer on a cybersecurity education platform. I'm new to building AI *agents* specifically (tool-calling, orchestration) though.
- Preference: I want to learn by building, not be handed code — want to debug and derive things myself.
- Time budget: ~1hr weekdays, 2-3hrs weekends (~15-25 hrs total over the 20-day window I'm working with).

## The problem as framed so far
My mentor told me to approach this like an FDE would: first understand the problem space and research what already exists ("procurement harnesses"), THEN start building — not jump straight to code.

Two meanings of "harness" surfaced in this conversation:
1. **Agent harness** — the orchestration layer that lets an LLM take real actions in an app (tool/function calling: search_suppliers, create_contract, initiate_sourcing_event, etc.), with guardrails, retries, logging, human-in-loop checks on risky writes.
2. **Eval harness** — a systematic way to test the AI layer's outputs against known-correct scenarios before shipping.

## Research done so far (as of Sept 2026)
Looked into existing AI-native / agentic procurement platforms to understand the current bar:
- **Pactum AI** — full-lifecycle agentic system: picks up requisitions, checks against policy, identifies negotiation opportunities, and executes commercial negotiations with suppliers autonomously; connects natively to SAP Ariba, Coupa, SAP S/4HANA; every action verified/traceable.
- **Levelpath** — AI-native procurement suite built AI-first (not bolted on), unifying intake, sourcing, supplier management, contracts.
- **Sirion** — AI-native Contract Lifecycle Management; agents ingest contracts and auto-extract clauses, obligations, risk into a unified repository.
- **Coupa / Ivalua** — legacy full-suite platforms with AI layered on top (useful contrast case vs. AI-native).
- Industry framing: 2026 is the year platforms shift from AI-for-suggestions to AI-for-execution — agents that act without being prompted each time (monitor, flag, renew, escalate) vs. dashboards that just surface insights.

## Plan / where we left off
1. Study 2 of the platforms above in more depth (what specific action the agent takes end-to-end, what system it reads/writes, what the human checkpoint is before execution) to build a mental template.
2. Map that template onto ONE real Procura workflow (not 3) — e.g., supplier search → contract draft, or sourcing recommendation.
3. Build it as a real agent/tool-calling loop (not a chatbot wrapper): define the workflow as callable tools, get the model reliably calling them, handle failure cases (wrong args, hallucinated IDs), validate before any write action executes.
4. Add a second tool once the first is solid, and get the model chaining them.
5. Build a small eval set (5-15 test scenarios with known-correct answers) so I can demonstrate reliability, not just a demo.
6. Be ready to explain every design decision out loud (why function-calling over prompt-stuffing, why I chose this workflow, what happens on failure) — this is what will actually be tested, not visual polish.

Rough 20-day split discussed: days 1-4 tool-calling basics + first tool wired up; 5-12 make the loop reliable + handle failures; 13-17 second tool + chaining; 18-20 polish + eval cases + rehearse explaining it.

## Open question I hadn't resolved yet
I was about to clarify what "reply: 3" meant (probably pointing back to something in the research/plan above) when this context was exported — worth re-clarifying with whoever picks this up.
