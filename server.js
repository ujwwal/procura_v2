const express = require("express");
const path = require("node:path");
const { Pool } = require("pg");
require("dotenv").config();

const app = express();
const port = Number(process.env.PORT || 3000);
const pool = new Pool(process.env.DATABASE_URL ? { connectionString: process.env.DATABASE_URL } : {});

const resources = {
  suppliers: {
    table: "suppliers",
    fields: ["code", "name", "category", "email", "status", "risk_score"],
    search: ["code", "name", "category", "email", "status"],
    label: "Suppliers"
  },
  contracts: {
    table: "contracts",
    fields: ["contract_no", "title", "supplier_id", "status", "start_date", "end_date", "value"],
    search: ["contract_no", "title", "status"],
    label: "Contracts"
  },
  sourcing_events: {
    table: "sourcing_events",
    fields: ["event_no", "title", "category", "status", "closes_at"],
    search: ["event_no", "title", "category", "status"],
    label: "Sourcing events"
  },
  requisitions: {
    table: "requisitions",
    fields: ["req_no", "title", "requester", "department", "amount", "status"],
    search: ["req_no", "title", "requester", "department", "status"],
    label: "Requisitions"
  },
  purchase_orders: {
    table: "purchase_orders",
    fields: ["po_no", "title", "supplier_id", "amount", "status", "order_date"],
    search: ["po_no", "title", "status"],
    label: "Purchase orders"
  },
  invoices: {
    table: "invoices",
    fields: ["invoice_no", "supplier_id", "po_id", "amount", "status", "due_date"],
    search: ["invoice_no", "status"],
    label: "Invoices"
  },
  risk_assessments: {
    table: "risk_assessments",
    fields: ["assessment_no", "supplier_id", "score", "level", "status", "assessed_at"],
    search: ["assessment_no", "level", "status"],
    label: "Risk assessments"
  },
  approvals: {
    table: "approvals",
    fields: ["entity_type", "entity_id", "action", "approver", "status", "comment"],
    search: ["entity_type", "action", "approver", "status"],
    label: "Approvals"
  },
  activities: {
    table: "activities",
    fields: ["entity_type", "entity_id", "message", "actor"],
    search: ["entity_type", "message", "actor"],
    label: "Activity"
  }
};

const workflowConfig = require('./workflow-config');
for (const [name, info] of Object.entries(workflowConfig.resources)) {
  resources[name] = {table:name, label:info.label, fields:info.fields.map(f=>f[0]),
    search:info.fields.filter(f=>['text','textarea','select'].includes(f[2])).map(f=>f[0])};
}
for (const [name, fields] of Object.entries(workflowConfig.additions)) resources[name].fields.push(...fields.map(f=>f[0]));
// Header totals are derived from lines. Clients must edit the lines instead.
for (const name of ['requisitions','purchase_orders','invoices']) resources[name].fields = resources[name].fields.filter(f=>f!=='amount');

function sendDatabaseError(res, error) {
  const validation = ['23502','23503','23505','23514','22P02','22003','22007','22008','22001'].includes(error.code);
  res.status(validation ? 400 : 503).json({error: validation ? error.message : 'Database unavailable'});
}

app.use(express.json({ limit: "1mb" }));
// Serve only public assets; database scripts and research notes are not web assets.
for (const file of ['index.html','app.js','styles.css','workflow-config.js']) {
  app.get(`/${file}`, (req,res)=>res.sendFile(path.join(__dirname,file)));
}

function getResource(name) {
  return Object.hasOwn(resources, name) ? resources[name] : null;
}

function cleanPayload(resource, payload) {
  return resource.fields.reduce((result, field) => {
    if (Object.hasOwn(payload, field)) result[field] = payload[field] === "" ? null : payload[field];
    return result;
  }, {});
}

async function recordActivity(entityType, entityId, message) {
  try {
    await pool.query(
      "INSERT INTO activities (entity_type, entity_id, message, actor) VALUES ($1, $2, $3, $4)",
      [entityType, entityId, message, "Sandbox user"]
    );
  } catch (error) {
    // Activity is supplementary and should not make a successful write fail.
    console.warn("Activity log unavailable:", error.message);
  }
}

app.get("/api/invoices/:id/flags", require("./lib/invoice-context").invoiceFlagsHandler(pool));
app.get("/api/approvals/:id/review", require("./lib/approval-context").approvalReviewHandler(pool));
app.get("/api/supplier_bids/:id/quote-context", require("./lib/quote-context").quoteHandler(pool));
app.post("/api/supplier_bids/:id/extracted-lines", require("./lib/quote-context").draftHandler(pool));

app.get("/api/summary", async (req, res) => {
  try {
    const [invoices, suppliers, contracts, risks, approvals] = await Promise.all([
      pool.query("SELECT COUNT(*)::int AS count FROM invoices WHERE status <> 'Paid'"),
      pool.query("SELECT COUNT(*)::int AS count FROM suppliers WHERE status = 'Active'"),
      pool.query("SELECT COUNT(*)::int AS count FROM contracts WHERE end_date BETWEEN CURRENT_DATE AND CURRENT_DATE + 30"),
      pool.query("SELECT COUNT(*)::int AS count FROM risk_assessments WHERE status NOT IN ('Complete', 'Closed')"),
      pool.query("SELECT COUNT(*)::int AS count FROM approvals WHERE status = 'Pending'")
    ]);
    res.json({
      invoices: invoices.rows[0].count,
      suppliers: suppliers.rows[0].count,
      contracts: contracts.rows[0].count,
      risks: risks.rows[0].count,
      approvals: approvals.rows[0].count
    });
  } catch (error) {
    res.status(503).json({ error: "Database unavailable", detail: error.message });
  }
});

app.get("/api/:resource", async (req, res) => {
  const resource = getResource(req.params.resource);
  if (!resource) return res.status(404).json({ error: "Unknown resource" });
  const values = [];
  const clauses = [];
  if (req.query.search) {
    values.push(`%${req.query.search}%`);
    clauses.push(`(${resource.search.map((field) => `CAST(${field} AS TEXT) ILIKE $1`).join(" OR ")})`);
  }
  for (const field of resource.fields.filter(f=>f.endsWith('_id'))) {
    if (req.query[field] !== undefined) {
      if (!/^\d+$/.test(req.query[field])) return res.status(400).json({error:`Invalid ${field}`});
      values.push(req.query[field]);
      clauses.push(`${field}=$${values.length}`);
    }
  }
  const limit = Math.min(Math.max(Math.floor(Number(req.query.limit)) || 100, 1), 500);
  const offset = Math.max(Math.floor(Number(req.query.offset)) || 0, 0);
  if (!Number.isFinite(offset)) return res.status(400).json({error:'Invalid offset'});
  try {
    const result = await pool.query(
      `SELECT * FROM ${resource.table} ${clauses.length ? `WHERE ${clauses.join(" AND ")}` : ""} ORDER BY created_at DESC, id DESC LIMIT ${limit} OFFSET ${offset}`,
      values
    );
    res.json(result.rows);
  } catch (error) {
    res.status(503).json({ error: "Database unavailable", detail: error.message });
  }
});

app.get("/api/:resource/:id", async (req, res) => {
  const resource = getResource(req.params.resource);
  if (!resource || !/^\d+$/.test(req.params.id)) return res.status(404).json({ error: "Record not found" });
  try {
    const result = await pool.query(`SELECT * FROM ${resource.table} WHERE id = $1`, [req.params.id]);
    if (!result.rowCount) return res.status(404).json({ error: "Record not found" });
    res.json(result.rows[0]);
  } catch (error) {
    res.status(503).json({ error: "Database unavailable", detail: error.message });
  }
});

app.post("/api/:resource", async (req, res) => {
  const resource = getResource(req.params.resource);
  if (!resource || req.params.resource === "activities") return res.status(404).json({ error: "Resource cannot be created" });
  if (['requisitions','purchase_orders','invoices'].includes(req.params.resource) && Object.hasOwn(req.body || {},'amount')) return res.status(400).json({error:'Amount is derived. Create or edit line items.'});
  const payload = cleanPayload(resource, req.body || {});
  const fields = Object.keys(payload);
  if (!fields.length) return res.status(400).json({ error: "At least one field is required" });
  const values = fields.map((field) => payload[field]);
  try {
    const result = await pool.query(
      `INSERT INTO ${resource.table} (${fields.join(", ")}) VALUES (${fields.map((_, i) => `$${i + 1}`).join(", ")}) RETURNING *`,
      values
    );
    const row = result.rows[0];
    await recordActivity(req.params.resource, row.id, `Created ${resource.label.toLowerCase()} record`);
    res.status(201).json(row);
  } catch (error) {
    sendDatabaseError(res,error);
  }
});

app.put("/api/:resource/:id", async (req, res) => {
  const resource = getResource(req.params.resource);
  if (!resource || req.params.resource === "activities" || !/^\d+$/.test(req.params.id)) return res.status(404).json({ error: "Record not found" });
  if (['requisitions','purchase_orders','invoices'].includes(req.params.resource) && Object.hasOwn(req.body || {},'amount')) return res.status(400).json({error:'Amount is derived. Edit line items.'});
  const payload = cleanPayload(resource, req.body || {});
  const fields = Object.keys(payload);
  if (!fields.length) return res.status(400).json({ error: "At least one field is required" });
  try {
    const result = await pool.query(
      `UPDATE ${resource.table} SET ${fields.map((field, i) => `${field} = $${i + 1}`).join(", ")} WHERE id = $${fields.length + 1} RETURNING *`,
      [...fields.map((field) => payload[field]), req.params.id]
    );
    if (!result.rowCount) return res.status(404).json({ error: "Record not found" });
    await recordActivity(req.params.resource, req.params.id, `Updated ${resource.label.toLowerCase()} record`);
    res.json(result.rows[0]);
  } catch (error) {
    sendDatabaseError(res,error);
  }
});

app.delete("/api/:resource/:id", async (req, res) => {
  const resource = getResource(req.params.resource);
  if (!resource || req.params.resource === "activities" || !/^\d+$/.test(req.params.id)) return res.status(404).json({ error: "Record not found" });
  try {
    const result = await pool.query(`DELETE FROM ${resource.table} WHERE id = $1 RETURNING id`, [req.params.id]);
    if (!result.rowCount) return res.status(404).json({ error: "Record not found" });
    await recordActivity(req.params.resource, req.params.id, `Deleted ${resource.label.toLowerCase()} record`);
    res.status(204).end();
  } catch (error) {
    sendDatabaseError(res,error);
  }
});

app.use('/api', (req,res)=>res.status(404).json({error:'Unknown API route'}));
app.get("/", (req, res) => res.sendFile(path.join(__dirname, "index.html")));

if (require.main === module) app.listen(port, () => {
  console.log(`Procura sandbox running at http://localhost:${port}`);
  if (!process.env.DATABASE_URL) console.warn("DATABASE_URL is not set; API requests will return a database error.");
});
module.exports = {app,pool};
