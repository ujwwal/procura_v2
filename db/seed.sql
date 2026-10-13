INSERT INTO suppliers (code, name, category, email, status, risk_score) VALUES
  ('SUP-1092', 'Northstar Parts', 'IT hardware', 'hello@northstar.example', 'Active', 72),
  ('SUP-1087', 'BluePeak Logistics', 'Logistics', 'ops@bluepeak.example', 'Active', 22),
  ('SUP-1074', 'Vertex Office Co.', 'Office supplies', 'team@vertex.example', 'Review', 84)
ON CONFLICT (code) DO NOTHING;

INSERT INTO contracts (contract_no, title, supplier_id, status, start_date, end_date, value)
SELECT 'CTR-1044', 'Cloud hosting agreement', id, 'Active', '2025-09-01', '2026-09-17', 180000
FROM suppliers WHERE code = 'SUP-1092'
ON CONFLICT (contract_no) DO NOTHING;

INSERT INTO contracts (contract_no, title, supplier_id, status, start_date, end_date, value)
SELECT 'CTR-1039', 'Northstar master services agreement', id, 'Authoring', '2026-01-01', '2027-01-01', 95000
FROM suppliers WHERE code = 'SUP-1092'
ON CONFLICT (contract_no) DO NOTHING;

INSERT INTO sourcing_events (event_no, title, category, status, closes_at) VALUES
  ('SRC-2207', 'Cloud hosting RFP', 'Technology', 'Open', '2026-09-05'),
  ('SRC-2203', 'Office supplies RFQ', 'Facilities', 'Evaluation', '2026-08-30')
ON CONFLICT (event_no) DO NOTHING;

INSERT INTO requisitions (req_no, title, requester, department, amount, status) VALUES
  ('REQ-1048', 'IT hardware refresh', 'Maya Shah', 'IT', 42000, 'Pending approval'),
  ('REQ-1042', 'Design software renewal', 'Nora Patel', 'Design', 12400, 'Due today')
ON CONFLICT (req_no) DO NOTHING;

INSERT INTO purchase_orders (po_no, title, supplier_id, amount, status, order_date)
SELECT 'PO-3021', 'Facilities supplies', id, 8600, 'Open', '2026-08-18'
FROM suppliers WHERE code = 'SUP-1074'
ON CONFLICT (po_no) DO NOTHING;

INSERT INTO invoices (invoice_no, supplier_id, po_id, amount, status, due_date)
SELECT 'INV-8821', s.id, p.id, 8600, 'Exception review', '2026-09-01'
FROM suppliers s, purchase_orders p WHERE s.code = 'SUP-1074' AND p.po_no = 'PO-3021'
ON CONFLICT (invoice_no) DO NOTHING;

INSERT INTO invoices (invoice_no, supplier_id, amount, status, due_date)
SELECT 'INV-8818', id, 3900, 'Open', '2026-09-12'
FROM suppliers WHERE code = 'SUP-1087'
ON CONFLICT (invoice_no) DO NOTHING;

INSERT INTO risk_assessments (assessment_no, supplier_id, score, level, status)
SELECT 'RSK-0771', id, 72, 'Medium', 'Open' FROM suppliers WHERE code = 'SUP-1092'
ON CONFLICT (assessment_no) DO NOTHING;

INSERT INTO risk_assessments (assessment_no, supplier_id, score, level, status)
SELECT 'RSK-0764', id, 22, 'Low', 'Complete' FROM suppliers WHERE code = 'SUP-1087'
ON CONFLICT (assessment_no) DO NOTHING;

INSERT INTO approvals (entity_type, entity_id, action, approver, status)
SELECT 'requisition', id, 'Approve IT hardware refresh', 'Arjun Rao', 'Pending'
FROM requisitions WHERE req_no = 'REQ-1048'
AND NOT EXISTS (SELECT 1 FROM approvals WHERE entity_type = 'requisition' AND entity_id = requisitions.id);

INSERT INTO activities (entity_type, entity_id, message, actor)
SELECT 'supplier', id, 'Supplier profile seeded for sandbox', 'System'
FROM suppliers WHERE code = 'SUP-1092'
AND NOT EXISTS (SELECT 1 FROM activities WHERE entity_type = 'supplier' AND entity_id = suppliers.id);
