const modules = [
  { id: "home", label: "Home", icon: "HM", description: "A focused overview of your procurement workspace.", menu: [["Overview", null], ["My Desk", "approvals"], ["My Approvals", "approvals"]] },
  { id: "iRequest", label: "Request", icon: "RQ", description: "A request intake and approval workspace.", menu: [["My Requests", "requisitions"], ["Approvals", "approvals"], ["Activity", "activities"]] },
  { id: "iSource", label: "Sourcing", icon: "SO", description: "Sourcing events and supplier bid comparison.", menu: [["QuickSource", "sourcing_events"], ["Sourcing Events", "sourcing_events"], ["Suppliers", "suppliers"]] },
  { id: "iContract", label: "Contracts", icon: "CO", description: "Contract authoring, repository, clauses, and renewals.", menu: [["Authoring Contracts", "contracts"], ["Repository Contracts", "contracts"], ["Approvals and Reviews", "approvals"]] },
  { id: "iSupplier", label: "Suppliers", icon: "SU", description: "Supplier profiles, onboarding, and pre-qualification.", menu: [["My Requests", "suppliers"], ["Suppliers", "suppliers"], ["Activity", "activities"]] },
  { id: "eProc", label: "Procurement", icon: "EP", description: "Requisitions, purchase orders, receiving, and approvals.", menu: [["Requisitions", "requisitions"], ["Purchase Orders", "purchase_orders"], ["My Approvals", "approvals"]] },
  { id: "eInvoice", label: "Invoice", icon: "EI", description: "Invoice intake and reconciliation.", menu: [["Invoices", "invoices"], ["Reconciliation", "invoices"]] },
  { id: "iRisk", label: "Risk", icon: "RI", description: "Risk assessments, scorecards, alerts, and segmentation.", menu: [["360 Risk Dashboard", "risk_assessments"], ["Risk Assessments", "risk_assessments"], ["Alerts & Reminders", "risk_assessments"]] },
  { id: "iAnalyze", label: "Analytics", icon: "AN", description: "Spend visibility and data exploration surfaces.", menu: [["Spend Dashboard", "purchase_orders"], ["Spend Overview", "invoices"]] }
];

const resourceInfo = {
  suppliers: { label: "Suppliers", icon: "SU", id: "code", title: "name", fields: [
    ["code", "Supplier code", "text", true], ["name", "Company name", "text", true], ["category", "Category", "text", true],
    ["email", "Contact email", "email"], ["status", "Status", "select", false, ["Active", "Review", "Inactive"]], ["risk_score", "Risk score", "number"]
  ] },
  contracts: { label: "Contracts", icon: "CO", id: "contract_no", title: "title", fields: [
    ["contract_no", "Contract number", "text", true], ["title", "Title", "text", true], ["supplier_id", "Supplier ID", "number"],
    ["status", "Status", "select", false, ["Draft", "Authoring", "Active", "Expired"]], ["start_date", "Start date", "date"], ["end_date", "End date", "date"], ["value", "Value", "number"]
  ] },
  sourcing_events: { label: "Sourcing events", icon: "SO", id: "event_no", title: "title", fields: [
    ["event_no", "Event number", "text", true], ["title", "Title", "text", true], ["category", "Category", "text", true],
    ["status", "Status", "select", false, ["Draft", "Open", "Evaluation", "Closed"]], ["closes_at", "Closing date", "date"]
  ] },
  requisitions: { label: "Requisitions", icon: "RQ", id: "req_no", title: "title", fields: [
    ["req_no", "Requisition number", "text", true], ["title", "Title", "text", true], ["requester", "Requester", "text", true],
    ["department", "Department", "text", true], ["amount", "Amount", "number"], ["status", "Status", "select", false, ["Draft", "Pending approval", "Approved", "Rejected"]]
  ] },
  purchase_orders: { label: "Purchase orders", icon: "PO", id: "po_no", title: "title", fields: [
    ["po_no", "PO number", "text", true], ["title", "Title", "text", true], ["supplier_id", "Supplier ID", "number"],
    ["amount", "Amount", "number"], ["status", "Status", "select", false, ["Open", "Received", "Closed", "Cancelled"]], ["order_date", "Order date", "date"]
  ] },
  invoices: { label: "Invoices", icon: "IN", id: "invoice_no", title: "invoice_no", fields: [
    ["invoice_no", "Invoice number", "text", true], ["supplier_id", "Supplier ID", "number"], ["po_id", "PO ID", "number"],
    ["amount", "Amount", "number"], ["status", "Status", "select", false, ["Received", "Open", "Exception review", "Paid"]], ["due_date", "Due date", "date"]
  ] },
  risk_assessments: { label: "Risk assessments", icon: "RI", id: "assessment_no", title: "assessment_no", fields: [
    ["assessment_no", "Assessment number", "text", true], ["supplier_id", "Supplier ID", "number"], ["score", "Score", "number"],
    ["level", "Level", "select", false, ["Low", "Medium", "High"]], ["status", "Status", "select", false, ["Open", "Complete", "Closed"]], ["assessed_at", "Assessment date", "date"]
  ] },
  approvals: { label: "Approvals", icon: "AP", id: "id", title: "action", fields: [
    ["entity_type", "Entity type", "text", true], ["entity_id", "Entity ID", "number", true], ["action", "Action", "text", true],
    ["approver", "Approver", "text", true], ["status", "Status", "select", false, ["Pending", "Approved", "Rejected"]], ["comment", "Comment", "textarea"]
  ] },
  activities: { label: "Activity", icon: "AC", id: "id", title: "message", fields: [] }
};

Object.assign(resourceInfo, workflowConfig.resources);
for (const [name, fields] of Object.entries(workflowConfig.additions)) resourceInfo[name].fields.push(...fields);
for (const [name, info] of Object.entries(resourceInfo)) {
  info.fields = info.fields.map(f => workflowConfig.references[f[0]] && f[2] === 'number'
    ? [f[0], f[1].replace(' ID',''), 'reference', f[3], workflowConfig.references[f[0]]] : f);
  if (['requisitions','purchase_orders','invoices'].includes(name)) info.fields = info.fields.filter(f=>f[0]!=='amount');
}
modules.find(m=>m.id==='eProc').menu.push(['Catalog','catalog_items'],['Policies','procurement_policies'],['Requisition lines','requisition_lines'],['PO lines','purchase_order_lines'],['Goods receipts','goods_receipts']);
modules.find(m=>m.id==='eInvoice').menu.push(['Invoice lines','invoice_lines'],['Invoice holds','invoice_holds']);
modules.find(m=>m.id==='iSource').menu.push(['Requested items','sourcing_items'],['Supplier bids','supplier_bids'],['Bid lines','bid_lines'],['Evaluation criteria','evaluation_criteria']);

async function allRecords(resource, query='') {
  const rows=[];
  for (let offset=0;;offset+=500) {
    const page=await api(`/api/${resource}?limit=500&offset=${offset}${query ? '&'+query : ''}`);
    rows.push(...page);
    if (page.length<500) return rows;
  }
}
function referenceLabel(resource,row) {
  const info=resourceInfo[resource];
  const parent=row.requisition_id || row.po_id || row.invoice_id || row.event_id || row.bid_id;
  return `${row[info.id] ?? row.id} · ${row[info.title] ?? ''}${parent ? ' (parent #'+parent+')' : ''} [#${row.id}]`;
}

const primaryNav = document.querySelector("#primary-nav");
const dashboard = document.querySelector("#dashboard-view");
const moduleView = document.querySelector("#module-view");
const pageTitle = document.querySelector("#page-title");
const breadcrumb = document.querySelector("#breadcrumb-current");
const search = document.querySelector("#global-search");
const modal = document.querySelector("#record-modal");
let currentModule = modules[0];
let currentResource = null;
let currentRows = [];

const escapeHtml = (value) => String(value ?? "").replace(/[&<>"']/g, (char) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[char]));
const statusClass = (value) => {
  const status = String(value || "").toLowerCase();
  if (["open", "active", "complete", "approved", "paid"].some(word => status.includes(word))) return "success";
  if (["due", "high", "exception", "reject"].some(word => status.includes(word))) return "warning";
  return "pending";
};

async function api(url, options) {
  const response = await fetch(url, options);
  const data = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(data.error || "Request failed");
  return data;
}

function renderNav() {
  primaryNav.innerHTML = modules.map((module, index) => `<button class="nav-item ${index === 0 ? "active" : ""}" data-module="${module.id}"><span class="nav-icon">${module.icon}</span><span>${module.label}</span>${module.id !== "home" ? '<span class="nav-chevron">-&gt;</span>' : ""}</button>`).join("");
}

function renderPriority() {
  const rows = [
    ["Invoice", "INV-8821", "Accounts Payable", "Invoice", "Exception review", "review"],
    ["Contract", "CTR-1044", "Legal Ops", "Contracts", "Renewal soon", "due"],
    ["Request", "REQ-1048", "Maya Shah", "Procurement", "Pending approval", "review"],
    ["Supplier", "SUP-1074", "Supplier Ops", "Suppliers", "Missing document", "due"]
  ];
  const query = search ? search.value.trim().toLowerCase() : "";
  const filtered = query ? rows.filter((r) => r.some((cell) => String(cell).toLowerCase().includes(query))) : rows;
  document.querySelector("#priority-table").innerHTML = filtered.length
    ? filtered.map((row) => `<tr><td>${row[0]} ${row[1]}</td><td>${row[2]}</td><td>${row[3]}</td><td>Recently</td><td><span class="status ${row[5]}">${row[4]}</span></td></tr>`).join("")
    : '<tr><td colspan="5" style="text-align:center;color:var(--muted);padding:18px;">No matching priority items found.</td></tr>';
}

async function loadSummary() {
  try {
    const summary = await api("/api/summary");
    ["invoices", "suppliers", "contracts", "risks"].forEach((key) => { document.querySelector(`#metric-${key}`).textContent = summary[key]; });
    const activity = await api("/api/activities?limit=4");
    document.querySelector("#activity-list").innerHTML = activity.length ? activity.map((item, index) => `<div class="activity"><span class="activity-avatar ${index % 2 ? "teal" : "purple"}">${escapeHtml((item.actor || "SU").slice(0, 2).toUpperCase())}</span><span><strong>${escapeHtml(item.message)}</strong><small>${escapeHtml(item.entity_type)} &middot; ${new Date(item.created_at).toLocaleString()}</small></span><b class="tag success">Logged</b></div>`).join("") : '<div class="empty-state">No activity yet.</div>';
  } catch (error) {
    document.querySelector("#activity-list").innerHTML = `<div class="empty-state">${escapeHtml(error.message)}. Run db:setup first.</div>`;
  }
}

function renderMenu() {
  document.querySelector("#context-menu").innerHTML = currentModule.menu.map(([label, resource], index) => `<button class="context-link ${index === 0 ? "active" : ""}" data-resource="${resource || ""}"><span>${label}</span><span>-&gt;</span></button>`).join("");
}

function recordSummary(row) {
  const info = resourceInfo[currentResource];
  const identifier = row[info.id] ?? row.id;
  const title = row[info.title] ?? row.message ?? "Record";
  const status = row.status || row.level || "Saved";
  return { identifier, title, status };
}

function renderRecords(rows) {
  currentRows = rows;
  const info = resourceInfo[currentResource];
  const list = document.querySelector("#record-list");
  if (!rows.length) {
    list.innerHTML = '<div class="empty-state">No records found. Create the first one.</div>';
    return;
  }
  list.innerHTML = rows.map((row) => {
    const summary = recordSummary(row);
    return `<div class="record-row" data-id="${row.id}"><span class="record-icon">${info.icon}</span><span><strong>${escapeHtml(summary.identifier)} · ${escapeHtml(summary.title)}</strong><small>${escapeHtml(row.requester || row.category || row.actor || row.entity_type || "Procurement record")} · ${escapeHtml(summary.status)}</small></span><span class="tag ${statusClass(summary.status)}">${escapeHtml(summary.status)}</span><button class="row-action" data-action="view" data-id="${row.id}">View</button></div>`;
  }).join("");
}

async function loadRecords(resource) {
  currentResource = resource;
  const list = document.querySelector("#record-list");
  list.innerHTML = '<div class="empty-state">Loading records…</div>';
  document.querySelector("#records-title").textContent = resourceInfo[resource].label;
  try {
    renderRecords(await api(`/api/${resource}?search=${encodeURIComponent(search.value.trim())}`));
  } catch (error) {
    list.innerHTML = `<div class="empty-state">${escapeHtml(error.message)}. Check PostgreSQL and DATABASE_URL.</div>`;
  }
}

function selectModule(id) {
  currentModule = modules.find((item) => item.id === id) || modules[0];
  document.querySelectorAll(".nav-item").forEach((item) => item.classList.toggle("active", item.dataset.module === currentModule.id));
  breadcrumb.textContent = currentModule.label;
  if (id === "home") {
    dashboard.classList.remove("hidden");
    moduleView.classList.add("hidden");
    pageTitle.textContent = "What would you like to do today?";
    loadSummary();
    return;
  }
  dashboard.classList.add("hidden");
  moduleView.classList.remove("hidden");
  document.querySelector("#module-eyebrow").textContent = `${currentModule.label} WORKSPACE`;
  document.querySelector("#module-title").textContent = currentModule.label;
  document.querySelector("#module-description").textContent = currentModule.description;
  document.querySelector("#menu-title").textContent = `${currentModule.label} destinations`;
  renderMenu();
  const firstResource = currentModule.menu.find((entry) => entry[1])?.[1];
  document.querySelector("#create-record").style.display = firstResource === "activities" ? "none" : "";
  if (firstResource) loadRecords(firstResource);
}

let modalVersion = 0;
async function openModal(resource, row = null, defaults = {}) {
  const version=++modalVersion;
  const info = resourceInfo[resource];
  const isEdit = Boolean(row);
  modal.classList.remove('hidden');
  document.querySelector('#modal-body').innerHTML='<p class="empty-state">Loading form…</p>';
  const lookups={};
  try {
    await Promise.all([...new Set(info.fields.filter(f=>f[2]==='reference').map(f=>f[4]))].map(async target=>{lookups[target]=await allRecords(target);}));
  } catch(error) {
    if(version===modalVersion) document.querySelector('#modal-body').innerHTML=`<p class="form-error">${escapeHtml(error.message)}</p>`;
    return;
  }
  if(version!==modalVersion) return;
  document.querySelector("#modal-eyebrow").textContent = isEdit ? `EDIT ${info.label.toUpperCase()}` : `NEW ${info.label.toUpperCase()}`;
  document.querySelector("#modal-title").textContent = isEdit ? `Edit ${info.label.slice(0, -1)}` : `Create ${info.label.slice(0, -1)}`;
  const fields = info.fields.map(([name, label, type, required, options]) => {
    const rawValue = row?.[name] ?? defaults[name] ?? ({currency:'INR',unit:'each',quantity:1,line_no:1,freight:0,tax_amount:0,invoice_tolerance_percent:0,department:'All',received_at:new Date().toISOString().slice(0,10)}[name] ?? "");
    const value = type === "date" && rawValue ? String(rawValue).slice(0, 10) : rawValue;
    const requiredMark = required ? " required" : "";
    if (type === 'reference') return `<label>${escapeHtml(label)}<select name="${name}"${requiredMark}><option value="">Select ${escapeHtml(label.toLowerCase())}</option>${lookups[options].map(item=>`<option value="${item.id}" ${String(value)===String(item.id)?'selected':''}>${escapeHtml(referenceLabel(options,item))}</option>`).join('')}</select></label>`;
    if (type === "select") return `<label>${label}<select name="${name}"${requiredMark}>${options.map((option) => `<option ${String(value) === option ? "selected" : ""}>${option}</option>`).join("")}</select></label>`;
    if(type==='textarea') return `<label>${label}<textarea name="${name}"${requiredMark}>${escapeHtml(value)}</textarea></label>`;
    return `<label>${label}<input name="${name}" type="${type}" value="${escapeHtml(value)}"${type==='number'?' step="any" min="0"':''}${requiredMark}></label>`;
  }).join("");
  document.querySelector("#modal-body").innerHTML = `<form id="record-form" data-resource="${resource}" data-id="${row?.id || ""}"><div class="form-grid">${fields}</div><div class="modal-actions"><button type="button" class="outline-button modal-cancel">Cancel</button><button class="primary-button" type="submit">${isEdit ? "Save changes" : "Create record"}</button></div></form>`;
  modal.classList.remove("hidden");
  const form=document.querySelector('#record-form');
  form.addEventListener('change',event=>{
    const set=(name,value)=>{if(form.elements[name]) form.elements[name].value=value ?? '';};
    const id=Number(event.target.value);
    if(event.target.name==='catalog_item_id' && id) {
      const item=lookups.catalog_items.find(r=>r.id===id);
      for(const name of ['supplier_id','description','unit','unit_price']) set(name,item[name]);
    }
    if(event.target.name==='invoice_id' && id) set('po_id',lookups.invoices.find(r=>r.id===id).po_id);
    if(event.target.name==='po_line_id' && id && lookups.purchase_order_lines) {
      const item=lookups.purchase_order_lines.find(r=>r.id===id);
      set('po_id',item.po_id);
      for(const name of ['description','unit','unit_price']) set(name,item[name]);
    }
    if(event.target.name==='bid_id' && id) set('event_id',lookups.supplier_bids.find(r=>r.id===id).event_id);
  });
}

function closeModal() { ++modalVersion; modal.classList.add("hidden"); }

document.addEventListener("click", (event) => {
  const nav = event.target.closest(".nav-item");
  if (nav) return selectModule(nav.dataset.module);
  const menu = event.target.closest(".context-link");
  if (menu && menu.dataset.resource) {
    document.querySelectorAll(".context-link").forEach((item) => item.classList.remove("active"));
    menu.classList.add("active");
    document.querySelector("#create-record").style.display = menu.dataset.resource === "activities" ? "none" : "";
    return loadRecords(menu.dataset.resource);
  }
  const shortcut = event.target.closest("[data-open-resource]");
  if (shortcut) return openModal(shortcut.dataset.openResource);
  if (event.target.closest("#create-record")) return currentResource && openModal(currentResource);
  if (event.target.closest("#refresh-records")) return currentResource && loadRecords(currentResource);
  const view = event.target.closest("[data-action='view']");
  if (view) {
    const row = currentRows.find((item) => String(item.id) === view.dataset.id);
    if (row) openDetail(currentResource, row);
  }
  if (event.target.closest(".modal-close") || event.target.closest(".modal-cancel") || event.target === modal) closeModal();
});

async function openDetail(resource, row) {
  const version=++modalVersion;
  const info = resourceInfo[resource];
  modal.classList.remove('hidden');
  document.querySelector('#modal-body').innerHTML='<p class="empty-state">Loading linked records…</p>';
  let links=[], parents={};
  try {
    row=await api(`/api/${resource}/${row.id}`);
    await Promise.all(info.fields.filter(f=>f[2]==='reference' && row[f[0]]).map(async f=>{parents[f[0]]=await api(`/api/${f[4]}/${row[f[0]]}`);}));
    links=await Promise.all((workflowConfig.children[resource] || []).map(async ([target,key])=>({target,key,rows:await allRecords(target,`${key}=${row.id}`)})));
  } catch(error) {
    if(version===modalVersion) document.querySelector('#modal-body').innerHTML=`<p class="form-error">${escapeHtml(error.message)}</p>`;
    return;
  }
  if(version!==modalVersion) return;
  const detail = info.fields.length ? info.fields.map(([name, label,type,,target]) => `<div class="detail-item"><small>${label}</small>${parents[name]?`<button class="text-button parent-record" data-field="${name}">${escapeHtml(referenceLabel(target,parents[name]))}</button>`:`<strong>${escapeHtml(row[name] ?? "—")}</strong>`}</div>`).join("") : `<div class="detail-item wide"><small>Message</small><strong>${escapeHtml(row.message)}</strong></div>`;
  const totals=['amount','line_total'].filter(k=>row[k]!==undefined).map(k=>`<p><strong>${k==='amount'?'Total from lines':'Line total'}: ${escapeHtml(row[k])} ${escapeHtml(row.currency || '(parent currency)')}</strong></p>`).join('');
  const related=links.map(({target,rows},index)=>`<section class="related-records"><h3>${escapeHtml(resourceInfo[target].label)} (${rows.length})</h3>${rows.map((r,j)=>`<p><button class="text-button related-record" data-group="${index}" data-row="${j}">${escapeHtml(referenceLabel(target,r))}</button>${r.line_total!==undefined?' · '+escapeHtml(r.line_total):''}</p>`).join('')}<button class="outline-button related-create" data-group="${index}">Add ${escapeHtml(resourceInfo[target].label.toLowerCase())}</button></section>`).join('');
  let bidTotal='';
  if(resource==='supplier_bids') {
    const lines=links.find(l=>l.target==='bid_lines').rows;
    const cents=v=>Math.round(Number(v)*100);
    bidTotal=`<p><strong>Quoted total including freight and tax: ${((lines.reduce((sum,l)=>sum+cents(l.line_total),0)+cents(row.freight)+cents(row.tax_amount))/100).toFixed(2)} ${escapeHtml(parents.event_id?.currency || '')}</strong></p>`;
  }
  document.querySelector("#modal-eyebrow").textContent = `${info.label.toUpperCase()} DETAIL`;
  document.querySelector("#modal-title").textContent = row[info.title] || row.message || info.label;
  document.querySelector("#modal-body").innerHTML = `<div class="detail-grid">${detail}</div>${totals}${bidTotal}${related}<div class="modal-actions"><button class="outline-button modal-cancel">Close</button>${resource !== "activities" ? `<button class="outline-button detail-delete" data-resource="${resource}" data-id="${row.id}">Delete</button><button class="primary-button detail-edit" data-resource="${resource}" data-id="${row.id}">Edit record</button>` : ""}</div>`;
  document.querySelectorAll('.parent-record').forEach(button=>button.addEventListener('click',()=>{const f=info.fields.find(f=>f[0]===button.dataset.field);openDetail(f[4],parents[f[0]]);}));
  document.querySelectorAll('.related-record').forEach(button=>button.addEventListener('click',()=>{const link=links[button.dataset.group];openDetail(link.target,link.rows[button.dataset.row]);}));
  document.querySelectorAll('.related-create').forEach(button=>button.addEventListener('click',()=>{
    const link=links[button.dataset.group];
    const defaults={[link.key]:row.id,line_no:Math.max(0,...link.rows.map(r=>r.line_no || 0))+1};
    if(link.target==='invoice_lines') defaults.po_id=row.po_id;
    if(link.target==='bid_lines') defaults.event_id=row.event_id;
    if(link.target==='purchase_orders') defaults.currency=row.currency;
    if(link.target==='invoices') {defaults.supplier_id=row.supplier_id; defaults.currency=row.currency;}
    openModal(link.target,null,defaults);
  }));
  modal.classList.remove("hidden");
  const edit = document.querySelector(".detail-edit");
  if (edit) edit.addEventListener("click", () => openModal(resource, row));
  const remove = document.querySelector(".detail-delete");
  if (remove) remove.addEventListener("click", async () => {
    if (!window.confirm("Delete this record?")) return;
    try {
      await api(`/api/${resource}/${row.id}`, { method: "DELETE" });
      closeModal();
      if(currentResource) loadRecords(currentResource);
      loadSummary();
    } catch (error) {
      document.querySelector("#modal-body").insertAdjacentHTML("afterbegin", `<p class="form-error">${escapeHtml(error.message)}</p>`);
    }
  });
}

document.querySelector("#record-modal").addEventListener("submit", async (event) => {
  if (!event.target.matches("#record-form")) return;
  event.preventDefault();
  const form = event.target;
  const body = Object.fromEntries(new FormData(form).entries());
  try {
    await api(`/api/${form.dataset.resource}${form.dataset.id ? `/${form.dataset.id}` : ""}`, { method: form.dataset.id ? "PUT" : "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) });
    closeModal();
    if (currentResource) loadRecords(currentResource);
    loadSummary();
  } catch (error) {
    const actions = form.querySelector(".modal-actions");
    form.querySelectorAll(".form-error").forEach((el) => el.remove());
    actions.insertAdjacentHTML("beforebegin", `<p class="form-error">${escapeHtml(error.message)}</p>`);
  }
});

search.addEventListener("input", () => {
  if (moduleView.classList.contains("hidden")) renderPriority();
  else if (currentResource) loadRecords(currentResource);
});
document.addEventListener("keydown", (event) => {
  if (event.key === "/" && document.activeElement !== search) { event.preventDefault(); search.focus(); }
  if (event.key === "Escape") closeModal();
});

renderNav();
renderPriority();
selectModule("home");
