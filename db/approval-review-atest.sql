-- Procura Stage 2: synthetic approval fixtures. Prepared 2026-10-08. Loaded and verified on Neon in this session.
-- Review and run the entire file in one connection with stop-on-error enabled.
-- Do not run selected fragments. Reruns fail on collisions; existing rows are never replaced.
-- Expected answers are the literal handoff manifest, not inferred from the views.
-- Pause other writers (including direct sequence callers) during this one-time load.
-- Historical synthetic approvals, not decisions made by an AI. Limits/amounts are INR.
-- Clean pending cases mean no flags from this view, NOT approved.
-- No employee is created for either deliberately unresolved approver.

BEGIN;
SET LOCAL TIME ZONE 'UTC';
SET LOCAL search_path = public, pg_catalog;
SET LOCAL lock_timeout = '10s';
LOCK TABLE public.departments, public.employees, public.requisitions, public.requisition_lines, public.approvals IN SHARE ROW EXCLUSIVE MODE;

DO $preflight$
BEGIN
  IF EXISTS (SELECT 1 FROM public.departments WHERE department_id BETWEEN 6000 AND 6000) THEN
    RAISE EXCEPTION 'departments: fixture ID/document namespace collision; no rows loaded';
  END IF;
  IF pg_get_serial_sequence('public.departments', 'department_id') IS NULL THEN
    RAISE EXCEPTION 'departments: expected SERIAL sequence missing';
  END IF;
  IF EXISTS (SELECT 1 FROM public.employees WHERE employee_id BETWEEN 6000 AND 6004) THEN
    RAISE EXCEPTION 'employees: fixture ID/document namespace collision; no rows loaded';
  END IF;
  IF pg_get_serial_sequence('public.employees', 'employee_id') IS NULL THEN
    RAISE EXCEPTION 'employees: expected SERIAL sequence missing';
  END IF;
  IF EXISTS (SELECT 1 FROM public.requisitions WHERE id BETWEEN 6000 AND 6009 OR req_no LIKE 'PROCURA-ATEST-%') THEN
    RAISE EXCEPTION 'requisitions: fixture ID/document namespace collision; no rows loaded';
  END IF;
  IF pg_get_serial_sequence('public.requisitions', 'id') IS NULL THEN
    RAISE EXCEPTION 'requisitions: expected SERIAL sequence missing';
  END IF;
  IF EXISTS (SELECT 1 FROM public.requisition_lines WHERE id BETWEEN 6000 AND 6009) THEN
    RAISE EXCEPTION 'requisition_lines: fixture ID/document namespace collision; no rows loaded';
  END IF;
  IF pg_get_serial_sequence('public.requisition_lines', 'id') IS NULL THEN
    RAISE EXCEPTION 'requisition_lines: expected SERIAL sequence missing';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='requisition_lines' AND column_name='line_total' AND is_generated='ALWAYS') THEN
    RAISE EXCEPTION 'requisition_lines.line_total must be generated';
  END IF;
  IF EXISTS (SELECT 1 FROM public.approvals WHERE id BETWEEN 6000 AND 6009) THEN
    RAISE EXCEPTION 'approvals: fixture ID/document namespace collision; no rows loaded';
  END IF;
  IF pg_get_serial_sequence('public.approvals', 'id') IS NULL THEN
    RAISE EXCEPTION 'approvals: expected SERIAL sequence missing';
  END IF;
  IF EXISTS (SELECT 1 FROM public.departments WHERE name='Procura Test ATEST Department') THEN
    RAISE EXCEPTION 'Test department name collision';
  END IF;
  IF EXISTS (SELECT 1 FROM public.employees WHERE name IN ('Procura Test Requester', 'Procura Test Approver A', 'Procura Test Approver B', 'Procura Test Approver C', 'Procura Test Approver D', 'Procura Test Missing Approved', 'Procura Test Missing Pending') OR email IN ('procura.atest.requester@example.com', 'procura.atest.approver.a@example.com', 'procura.atest.approver.b@example.com', 'procura.atest.approver.c@example.com', 'procura.atest.approver.d@example.com')) THEN
    RAISE EXCEPTION 'Employee name/email collision, including deliberately absent identities';
  END IF;
  IF EXISTS (SELECT 1 FROM public.approvals WHERE approver IN ('Procura Test Requester', 'Procura Test Approver A', 'Procura Test Approver B', 'Procura Test Approver C', 'Procura Test Approver D', 'Procura Test Missing Approved', 'Procura Test Missing Pending') OR (LOWER(TRIM(entity_type))='requisition' AND entity_id BETWEEN 6000 AND 6009)) THEN
    RAISE EXCEPTION 'Existing approver-name or fixture approval relationship collision';
  END IF;
  IF EXISTS (SELECT 1 FROM public.requisitions WHERE requester IN ('Procura Test Requester', 'Procura Test Approver A', 'Procura Test Approver B', 'Procura Test Approver C', 'Procura Test Approver D') OR department='Procura Test ATEST Department') THEN
    RAISE EXCEPTION 'Existing requisition uses fixture identity/department';
  END IF;
END;
$preflight$;

INSERT INTO public.departments (department_id, name) VALUES
  (6000, 'Procura Test ATEST Department');

INSERT INTO public.employees (employee_id, name, email, department_id, manager_id, role, approval_limit, is_active) VALUES
  (6000, 'Procura Test Requester', 'procura.atest.requester@example.com', 6000, NULL, 'Requester', 0, true),
  (6001, 'Procura Test Approver A', 'procura.atest.approver.a@example.com', 6000, NULL, 'Approver', 100000, true),
  (6002, 'Procura Test Approver B', 'procura.atest.approver.b@example.com', 6000, NULL, 'Approver', 25000, true),
  (6003, 'Procura Test Approver C', 'procura.atest.approver.c@example.com', 6000, NULL, 'Approver', 100000, false),
  (6004, 'Procura Test Approver D', 'procura.atest.approver.d@example.com', 6000, NULL, 'Approver', 25000, false);

INSERT INTO public.requisitions (id, req_no, title, requester, department, amount, status, created_at, currency, delivery_location, needed_by, justification) VALUES
  (6000, 'PROCURA-ATEST-REQ-6000', 'Synthetic approval scenario 6000', 'Procura Test Requester', 'Procura Test ATEST Department', 50000, 'Approved', '2030-01-01T00:00:00Z', 'INR', 'Fictional test office', '2030-01-16', 'Synthetic historical approval record; no AI decision.'),
  (6001, 'PROCURA-ATEST-REQ-6001', 'Synthetic approval scenario 6001', 'Procura Test Requester', 'Procura Test ATEST Department', 100000, 'Approved', '2030-01-02T00:00:00Z', 'INR', 'Fictional test office', '2030-01-17', 'Synthetic historical approval record; no AI decision.'),
  (6002, 'PROCURA-ATEST-REQ-6002', 'Synthetic approval scenario 6002', 'Procura Test Requester', 'Procura Test ATEST Department', 50000, 'Approved', '2030-01-03T00:00:00Z', 'INR', 'Fictional test office', '2030-01-18', 'Synthetic historical approval record; no AI decision.'),
  (6003, 'PROCURA-ATEST-REQ-6003', 'Synthetic approval scenario 6003', 'Procura Test Requester', 'Procura Test ATEST Department', 50000, 'Approved', '2030-01-04T00:00:00Z', 'INR', 'Fictional test office', '2030-01-19', 'Synthetic historical approval record; no AI decision.'),
  (6004, 'PROCURA-ATEST-REQ-6004', 'Synthetic approval scenario 6004', 'Procura Test Requester', 'Procura Test ATEST Department', 50000, 'Approved', '2030-01-05T00:00:00Z', 'INR', 'Fictional test office', '2030-01-20', 'Synthetic historical approval record; no AI decision.'),
  (6005, 'PROCURA-ATEST-REQ-6005', 'Synthetic approval scenario 6005', 'Procura Test Requester', 'Procura Test ATEST Department', 50000, 'Approved', '2030-01-06T00:00:00Z', 'INR', 'Fictional test office', '2030-01-21', 'Synthetic historical approval record; no AI decision.'),
  (6006, 'PROCURA-ATEST-REQ-6006', 'Synthetic approval scenario 6006', 'Procura Test Requester', 'Procura Test ATEST Department', 50000, 'Pending approval', '2030-01-07T00:00:00Z', 'INR', 'Fictional test office', '2030-01-22', 'Synthetic historical approval record; no AI decision.'),
  (6007, 'PROCURA-ATEST-REQ-6007', 'Synthetic approval scenario 6007', 'Procura Test Requester', 'Procura Test ATEST Department', 50000, 'Pending approval', '2030-01-08T00:00:00Z', 'INR', 'Fictional test office', '2030-01-23', 'Synthetic historical approval record; no AI decision.'),
  (6008, 'PROCURA-ATEST-REQ-6008', 'Synthetic approval scenario 6008', 'Procura Test Requester', 'Procura Test ATEST Department', 50000, 'Pending approval', '2030-01-09T00:00:00Z', 'INR', 'Fictional test office', '2030-01-24', 'Synthetic historical approval record; no AI decision.'),
  (6009, 'PROCURA-ATEST-REQ-6009', 'Synthetic approval scenario 6009', 'Procura Test Requester', 'Procura Test ATEST Department', 50000, 'Approved', '2030-01-10T00:00:00Z', 'INR', 'Fictional test office', '2030-01-25', 'Synthetic historical approval record; no AI decision.');

INSERT INTO public.requisition_lines (id, requisition_id, line_no, catalog_item_id, supplier_id, description, quantity, unit, unit_price, created_at) VALUES
  (6000, 6000, 1, NULL, NULL, 'Synthetic approval test item 6000', 1, 'each', 50000, '2030-01-01T00:00:00Z'),
  (6001, 6001, 1, NULL, NULL, 'Synthetic approval test item 6001', 1, 'each', 100000, '2030-01-02T00:00:00Z'),
  (6002, 6002, 1, NULL, NULL, 'Synthetic approval test item 6002', 1, 'each', 50000, '2030-01-03T00:00:00Z'),
  (6003, 6003, 1, NULL, NULL, 'Synthetic approval test item 6003', 1, 'each', 50000, '2030-01-04T00:00:00Z'),
  (6004, 6004, 1, NULL, NULL, 'Synthetic approval test item 6004', 1, 'each', 50000, '2030-01-05T00:00:00Z'),
  (6005, 6005, 1, NULL, NULL, 'Synthetic approval test item 6005', 1, 'each', 50000, '2030-01-06T00:00:00Z'),
  (6006, 6006, 1, NULL, NULL, 'Synthetic approval test item 6006', 1, 'each', 50000, '2030-01-07T00:00:00Z'),
  (6007, 6007, 1, NULL, NULL, 'Synthetic approval test item 6007', 1, 'each', 50000, '2030-01-08T00:00:00Z'),
  (6008, 6008, 1, NULL, NULL, 'Synthetic approval test item 6008', 1, 'each', 50000, '2030-01-09T00:00:00Z'),
  (6009, 6009, 1, NULL, NULL, 'Synthetic approval test item 6009', 1, 'each', 50000, '2030-01-10T00:00:00Z');

INSERT INTO public.approvals (id, entity_type, entity_id, action, approver, status, comment, created_at) VALUES
  (6000, 'requisition', 6000, 'Historical review PROCURA-ATEST-REQ-6000', 'Procura Test Approver A', 'Approved', 'Fictional historical fixture for flag review; not an AI approval decision.', '2030-01-01T00:00:00Z'),
  (6001, 'requisition', 6001, 'Historical review PROCURA-ATEST-REQ-6001', 'Procura Test Approver A', 'Approved', 'Fictional historical fixture for flag review; not an AI approval decision.', '2030-01-02T00:00:00Z'),
  (6002, 'requisition', 6002, 'Historical review PROCURA-ATEST-REQ-6002', 'Procura Test Approver B', 'Approved', 'Fictional historical fixture for flag review; not an AI approval decision.', '2030-01-03T00:00:00Z'),
  (6003, 'requisition', 6003, 'Historical review PROCURA-ATEST-REQ-6003', 'Procura Test Approver C', 'Approved', 'Fictional historical fixture for flag review; not an AI approval decision.', '2030-01-04T00:00:00Z'),
  (6004, 'requisition', 6004, 'Historical review PROCURA-ATEST-REQ-6004', 'Procura Test Approver D', 'Approved', 'Fictional historical fixture for flag review; not an AI approval decision.', '2030-01-05T00:00:00Z'),
  (6005, 'requisition', 6005, 'Historical review PROCURA-ATEST-REQ-6005', 'Procura Test Missing Approved', 'Approved', 'Fictional historical fixture for flag review; not an AI approval decision.', '2030-01-06T00:00:00Z'),
  (6006, 'requisition', 6006, 'Historical review PROCURA-ATEST-REQ-6006', 'Procura Test Approver B', 'Pending', 'Fictional historical fixture for flag review; not an AI approval decision.', '2030-01-07T00:00:00Z'),
  (6007, 'requisition', 6007, 'Historical review PROCURA-ATEST-REQ-6007', 'Procura Test Approver C', 'Pending', 'Fictional historical fixture for flag review; not an AI approval decision.', '2030-01-08T00:00:00Z'),
  (6008, 'requisition', 6008, 'Historical review PROCURA-ATEST-REQ-6008', 'Procura Test Missing Pending', 'Pending', 'Fictional historical fixture for flag review; not an AI approval decision.', '2030-01-09T00:00:00Z'),
  (6009, ' ReQuIsItIoN ', 6009, 'Historical review PROCURA-ATEST-REQ-6009', 'Procura Test Approver B', ' aPpRoVeD ', 'Fictional historical fixture for flag review; not an AI approval decision.', '2030-01-10T00:00:00Z');

-- Verify every inserted row and relationship, not just aggregate flag counts.
DO $validate$
BEGIN
  IF (SELECT count(*) FROM public.departments WHERE department_id BETWEEN 6000 AND 6000) <> 1 THEN
    RAISE EXCEPTION 'departments: wrong fixture count';
  END IF;
  IF EXISTS (
    WITH expected AS (SELECT * FROM jsonb_populate_recordset(NULL::public.departments,
      '[{"department_id":6000,"name":"Procura Test ATEST Department"}]'::jsonb))
    SELECT department_id, name FROM expected
    EXCEPT ALL
    SELECT department_id, name FROM public.departments WHERE department_id BETWEEN 6000 AND 6000
  ) THEN
    RAISE EXCEPTION 'departments: fixture values or links differ from construction';
  END IF;
  IF (SELECT count(*) FROM public.employees WHERE employee_id BETWEEN 6000 AND 6004) <> 5 THEN
    RAISE EXCEPTION 'employees: wrong fixture count';
  END IF;
  IF EXISTS (
    WITH expected AS (SELECT * FROM jsonb_populate_recordset(NULL::public.employees,
      '[{"employee_id":6000,"name":"Procura Test Requester","email":"procura.atest.requester@example.com","department_id":6000,"manager_id":null,"role":"Requester","approval_limit":0,"is_active":true},{"employee_id":6001,"name":"Procura Test Approver A","email":"procura.atest.approver.a@example.com","department_id":6000,"manager_id":null,"role":"Approver","approval_limit":100000,"is_active":true},{"employee_id":6002,"name":"Procura Test Approver B","email":"procura.atest.approver.b@example.com","department_id":6000,"manager_id":null,"role":"Approver","approval_limit":25000,"is_active":true},{"employee_id":6003,"name":"Procura Test Approver C","email":"procura.atest.approver.c@example.com","department_id":6000,"manager_id":null,"role":"Approver","approval_limit":100000,"is_active":false},{"employee_id":6004,"name":"Procura Test Approver D","email":"procura.atest.approver.d@example.com","department_id":6000,"manager_id":null,"role":"Approver","approval_limit":25000,"is_active":false}]'::jsonb))
    SELECT employee_id, name, email, department_id, manager_id, role, approval_limit, is_active FROM expected
    EXCEPT ALL
    SELECT employee_id, name, email, department_id, manager_id, role, approval_limit, is_active FROM public.employees WHERE employee_id BETWEEN 6000 AND 6004
  ) THEN
    RAISE EXCEPTION 'employees: fixture values or links differ from construction';
  END IF;
  IF (SELECT count(*) FROM public.requisitions WHERE id BETWEEN 6000 AND 6009) <> 10 THEN
    RAISE EXCEPTION 'requisitions: wrong fixture count';
  END IF;
  IF EXISTS (
    WITH expected AS (SELECT * FROM jsonb_populate_recordset(NULL::public.requisitions,
      '[{"id":6000,"req_no":"PROCURA-ATEST-REQ-6000","title":"Synthetic approval scenario 6000","requester":"Procura Test Requester","department":"Procura Test ATEST Department","amount":50000,"status":"Approved","created_at":"2030-01-01T00:00:00Z","currency":"INR","delivery_location":"Fictional test office","needed_by":"2030-01-16","justification":"Synthetic historical approval record; no AI decision."},{"id":6001,"req_no":"PROCURA-ATEST-REQ-6001","title":"Synthetic approval scenario 6001","requester":"Procura Test Requester","department":"Procura Test ATEST Department","amount":100000,"status":"Approved","created_at":"2030-01-02T00:00:00Z","currency":"INR","delivery_location":"Fictional test office","needed_by":"2030-01-17","justification":"Synthetic historical approval record; no AI decision."},{"id":6002,"req_no":"PROCURA-ATEST-REQ-6002","title":"Synthetic approval scenario 6002","requester":"Procura Test Requester","department":"Procura Test ATEST Department","amount":50000,"status":"Approved","created_at":"2030-01-03T00:00:00Z","currency":"INR","delivery_location":"Fictional test office","needed_by":"2030-01-18","justification":"Synthetic historical approval record; no AI decision."},{"id":6003,"req_no":"PROCURA-ATEST-REQ-6003","title":"Synthetic approval scenario 6003","requester":"Procura Test Requester","department":"Procura Test ATEST Department","amount":50000,"status":"Approved","created_at":"2030-01-04T00:00:00Z","currency":"INR","delivery_location":"Fictional test office","needed_by":"2030-01-19","justification":"Synthetic historical approval record; no AI decision."},{"id":6004,"req_no":"PROCURA-ATEST-REQ-6004","title":"Synthetic approval scenario 6004","requester":"Procura Test Requester","department":"Procura Test ATEST Department","amount":50000,"status":"Approved","created_at":"2030-01-05T00:00:00Z","currency":"INR","delivery_location":"Fictional test office","needed_by":"2030-01-20","justification":"Synthetic historical approval record; no AI decision."},{"id":6005,"req_no":"PROCURA-ATEST-REQ-6005","title":"Synthetic approval scenario 6005","requester":"Procura Test Requester","department":"Procura Test ATEST Department","amount":50000,"status":"Approved","created_at":"2030-01-06T00:00:00Z","currency":"INR","delivery_location":"Fictional test office","needed_by":"2030-01-21","justification":"Synthetic historical approval record; no AI decision."},{"id":6006,"req_no":"PROCURA-ATEST-REQ-6006","title":"Synthetic approval scenario 6006","requester":"Procura Test Requester","department":"Procura Test ATEST Department","amount":50000,"status":"Pending approval","created_at":"2030-01-07T00:00:00Z","currency":"INR","delivery_location":"Fictional test office","needed_by":"2030-01-22","justification":"Synthetic historical approval record; no AI decision."},{"id":6007,"req_no":"PROCURA-ATEST-REQ-6007","title":"Synthetic approval scenario 6007","requester":"Procura Test Requester","department":"Procura Test ATEST Department","amount":50000,"status":"Pending approval","created_at":"2030-01-08T00:00:00Z","currency":"INR","delivery_location":"Fictional test office","needed_by":"2030-01-23","justification":"Synthetic historical approval record; no AI decision."},{"id":6008,"req_no":"PROCURA-ATEST-REQ-6008","title":"Synthetic approval scenario 6008","requester":"Procura Test Requester","department":"Procura Test ATEST Department","amount":50000,"status":"Pending approval","created_at":"2030-01-09T00:00:00Z","currency":"INR","delivery_location":"Fictional test office","needed_by":"2030-01-24","justification":"Synthetic historical approval record; no AI decision."},{"id":6009,"req_no":"PROCURA-ATEST-REQ-6009","title":"Synthetic approval scenario 6009","requester":"Procura Test Requester","department":"Procura Test ATEST Department","amount":50000,"status":"Approved","created_at":"2030-01-10T00:00:00Z","currency":"INR","delivery_location":"Fictional test office","needed_by":"2030-01-25","justification":"Synthetic historical approval record; no AI decision."}]'::jsonb))
    SELECT id, req_no, title, requester, department, amount, status, created_at, currency, delivery_location, needed_by, justification FROM expected
    EXCEPT ALL
    SELECT id, req_no, title, requester, department, amount, status, created_at, currency, delivery_location, needed_by, justification FROM public.requisitions WHERE id BETWEEN 6000 AND 6009
  ) THEN
    RAISE EXCEPTION 'requisitions: fixture values or links differ from construction';
  END IF;
  IF (SELECT count(*) FROM public.requisition_lines WHERE id BETWEEN 6000 AND 6009) <> 10 THEN
    RAISE EXCEPTION 'requisition_lines: wrong fixture count';
  END IF;
  IF EXISTS (
    WITH expected AS (SELECT * FROM jsonb_populate_recordset(NULL::public.requisition_lines,
      '[{"id":6000,"requisition_id":6000,"line_no":1,"catalog_item_id":null,"supplier_id":null,"description":"Synthetic approval test item 6000","quantity":1,"unit":"each","unit_price":50000,"created_at":"2030-01-01T00:00:00Z"},{"id":6001,"requisition_id":6001,"line_no":1,"catalog_item_id":null,"supplier_id":null,"description":"Synthetic approval test item 6001","quantity":1,"unit":"each","unit_price":100000,"created_at":"2030-01-02T00:00:00Z"},{"id":6002,"requisition_id":6002,"line_no":1,"catalog_item_id":null,"supplier_id":null,"description":"Synthetic approval test item 6002","quantity":1,"unit":"each","unit_price":50000,"created_at":"2030-01-03T00:00:00Z"},{"id":6003,"requisition_id":6003,"line_no":1,"catalog_item_id":null,"supplier_id":null,"description":"Synthetic approval test item 6003","quantity":1,"unit":"each","unit_price":50000,"created_at":"2030-01-04T00:00:00Z"},{"id":6004,"requisition_id":6004,"line_no":1,"catalog_item_id":null,"supplier_id":null,"description":"Synthetic approval test item 6004","quantity":1,"unit":"each","unit_price":50000,"created_at":"2030-01-05T00:00:00Z"},{"id":6005,"requisition_id":6005,"line_no":1,"catalog_item_id":null,"supplier_id":null,"description":"Synthetic approval test item 6005","quantity":1,"unit":"each","unit_price":50000,"created_at":"2030-01-06T00:00:00Z"},{"id":6006,"requisition_id":6006,"line_no":1,"catalog_item_id":null,"supplier_id":null,"description":"Synthetic approval test item 6006","quantity":1,"unit":"each","unit_price":50000,"created_at":"2030-01-07T00:00:00Z"},{"id":6007,"requisition_id":6007,"line_no":1,"catalog_item_id":null,"supplier_id":null,"description":"Synthetic approval test item 6007","quantity":1,"unit":"each","unit_price":50000,"created_at":"2030-01-08T00:00:00Z"},{"id":6008,"requisition_id":6008,"line_no":1,"catalog_item_id":null,"supplier_id":null,"description":"Synthetic approval test item 6008","quantity":1,"unit":"each","unit_price":50000,"created_at":"2030-01-09T00:00:00Z"},{"id":6009,"requisition_id":6009,"line_no":1,"catalog_item_id":null,"supplier_id":null,"description":"Synthetic approval test item 6009","quantity":1,"unit":"each","unit_price":50000,"created_at":"2030-01-10T00:00:00Z"}]'::jsonb))
    SELECT id, requisition_id, line_no, catalog_item_id, supplier_id, description, quantity, unit, unit_price, created_at FROM expected
    EXCEPT ALL
    SELECT id, requisition_id, line_no, catalog_item_id, supplier_id, description, quantity, unit, unit_price, created_at FROM public.requisition_lines WHERE id BETWEEN 6000 AND 6009
  ) THEN
    RAISE EXCEPTION 'requisition_lines: fixture values or links differ from construction';
  END IF;
  IF (SELECT count(*) FROM public.approvals WHERE id BETWEEN 6000 AND 6009) <> 10 THEN
    RAISE EXCEPTION 'approvals: wrong fixture count';
  END IF;
  IF EXISTS (
    WITH expected AS (SELECT * FROM jsonb_populate_recordset(NULL::public.approvals,
      '[{"id":6000,"entity_type":"requisition","entity_id":6000,"action":"Historical review PROCURA-ATEST-REQ-6000","approver":"Procura Test Approver A","status":"Approved","comment":"Fictional historical fixture for flag review; not an AI approval decision.","created_at":"2030-01-01T00:00:00Z"},{"id":6001,"entity_type":"requisition","entity_id":6001,"action":"Historical review PROCURA-ATEST-REQ-6001","approver":"Procura Test Approver A","status":"Approved","comment":"Fictional historical fixture for flag review; not an AI approval decision.","created_at":"2030-01-02T00:00:00Z"},{"id":6002,"entity_type":"requisition","entity_id":6002,"action":"Historical review PROCURA-ATEST-REQ-6002","approver":"Procura Test Approver B","status":"Approved","comment":"Fictional historical fixture for flag review; not an AI approval decision.","created_at":"2030-01-03T00:00:00Z"},{"id":6003,"entity_type":"requisition","entity_id":6003,"action":"Historical review PROCURA-ATEST-REQ-6003","approver":"Procura Test Approver C","status":"Approved","comment":"Fictional historical fixture for flag review; not an AI approval decision.","created_at":"2030-01-04T00:00:00Z"},{"id":6004,"entity_type":"requisition","entity_id":6004,"action":"Historical review PROCURA-ATEST-REQ-6004","approver":"Procura Test Approver D","status":"Approved","comment":"Fictional historical fixture for flag review; not an AI approval decision.","created_at":"2030-01-05T00:00:00Z"},{"id":6005,"entity_type":"requisition","entity_id":6005,"action":"Historical review PROCURA-ATEST-REQ-6005","approver":"Procura Test Missing Approved","status":"Approved","comment":"Fictional historical fixture for flag review; not an AI approval decision.","created_at":"2030-01-06T00:00:00Z"},{"id":6006,"entity_type":"requisition","entity_id":6006,"action":"Historical review PROCURA-ATEST-REQ-6006","approver":"Procura Test Approver B","status":"Pending","comment":"Fictional historical fixture for flag review; not an AI approval decision.","created_at":"2030-01-07T00:00:00Z"},{"id":6007,"entity_type":"requisition","entity_id":6007,"action":"Historical review PROCURA-ATEST-REQ-6007","approver":"Procura Test Approver C","status":"Pending","comment":"Fictional historical fixture for flag review; not an AI approval decision.","created_at":"2030-01-08T00:00:00Z"},{"id":6008,"entity_type":"requisition","entity_id":6008,"action":"Historical review PROCURA-ATEST-REQ-6008","approver":"Procura Test Missing Pending","status":"Pending","comment":"Fictional historical fixture for flag review; not an AI approval decision.","created_at":"2030-01-09T00:00:00Z"},{"id":6009,"entity_type":" ReQuIsItIoN ","entity_id":6009,"action":"Historical review PROCURA-ATEST-REQ-6009","approver":"Procura Test Approver B","status":" aPpRoVeD ","comment":"Fictional historical fixture for flag review; not an AI approval decision.","created_at":"2030-01-10T00:00:00Z"}]'::jsonb))
    SELECT id, entity_type, entity_id, action, approver, status, comment, created_at FROM expected
    EXCEPT ALL
    SELECT id, entity_type, entity_id, action, approver, status, comment, created_at FROM public.approvals WHERE id BETWEEN 6000 AND 6009
  ) THEN
    RAISE EXCEPTION 'approvals: fixture values or links differ from construction';
  END IF;
  IF EXISTS (SELECT 1 FROM public.requisitions h WHERE h.id BETWEEN 6000 AND 6009 AND ((SELECT count(*) FROM public.requisition_lines l WHERE l.requisition_id=h.id) <> 1 OR h.amount IS DISTINCT FROM (SELECT sum(l.line_total) FROM public.requisition_lines l WHERE l.requisition_id=h.id))) THEN
    RAISE EXCEPTION 'requisitions: missing/extra lines or incorrect financial total';
  END IF;
  IF EXISTS (SELECT 1 FROM public.requisition_lines WHERE requisition_id BETWEEN 6000 AND 6009 AND line_total IS DISTINCT FROM round(quantity * unit_price,2)) THEN
    RAISE EXCEPTION 'requisition_lines: incorrect generated financial total';
  END IF;
  IF EXISTS (SELECT 1 FROM public.requisitions r WHERE r.id BETWEEN 6000 AND 6009 AND (SELECT count(*) FROM public.approvals a WHERE a.entity_id=r.id AND LOWER(TRIM(a.entity_type))='requisition') <> 1) THEN
    RAISE EXCEPTION 'Expected exactly one approval per fixture';
  END IF;
  IF EXISTS (SELECT 1 FROM (
WITH expected(entity_id, expected_flags) AS (
  VALUES
    (6000, ARRAY[]::text[]),
    (6001, ARRAY[]::text[]),
    (6002, ARRAY['over_limit']::text[]),
    (6003, ARRAY['inactive_approver']::text[]),
    (6004, ARRAY['inactive_approver', 'over_limit']::text[]),
    (6005, ARRAY['unresolved_approver']::text[]),
    (6006, ARRAY[]::text[]),
    (6007, ARRAY[]::text[]),
    (6008, ARRAY['unresolved_approver']::text[]),
    (6009, ARRAY['over_limit']::text[])
), observed AS (
  SELECT requisition_id AS entity_id, array_agg(DISTINCT flag_type ORDER BY flag_type) AS actual_flags
  FROM public.approval_flags WHERE requisition_id BETWEEN 6000 AND 6009
  GROUP BY requisition_id
)
SELECT e.entity_id, r.id IS NOT NULL AS entity_present, e.expected_flags,
       COALESCE(o.actual_flags, ARRAY[]::text[]) AS actual_flags,
       r.id IS NOT NULL AND e.expected_flags = COALESCE(o.actual_flags, ARRAY[]::text[]) AS matches
FROM expected e LEFT JOIN public.requisitions r ON r.id=e.entity_id
LEFT JOIN observed o ON o.entity_id=e.entity_id
  ) comparison WHERE NOT matches) THEN
    RAISE EXCEPTION 'Missing entity or missing/unexpected flag category versus independent manifest';
  END IF;
END;
$validate$;

-- Run deferred constraints before sequence synchronization.
SET CONSTRAINTS ALL IMMEDIATE;
-- Sequence changes are not rolled back by PostgreSQL. Do these only after all assertions.
-- Preserve positions already above the fixture IDs; never rewind a sequence.
DO $sequences$
DECLARE seq_name text; seq_value bigint; max_id bigint;
BEGIN
  seq_name := pg_get_serial_sequence('public.departments', 'department_id');
  EXECUTE format('SELECT last_value FROM %s', seq_name::regclass) INTO seq_value;
  SELECT max(department_id) INTO max_id FROM public.departments;
  PERFORM setval(seq_name::regclass, GREATEST(seq_value, max_id), true);
  seq_name := pg_get_serial_sequence('public.employees', 'employee_id');
  EXECUTE format('SELECT last_value FROM %s', seq_name::regclass) INTO seq_value;
  SELECT max(employee_id) INTO max_id FROM public.employees;
  PERFORM setval(seq_name::regclass, GREATEST(seq_value, max_id), true);
  seq_name := pg_get_serial_sequence('public.requisitions', 'id');
  EXECUTE format('SELECT last_value FROM %s', seq_name::regclass) INTO seq_value;
  SELECT max(id) INTO max_id FROM public.requisitions;
  PERFORM setval(seq_name::regclass, GREATEST(seq_value, max_id), true);
  seq_name := pg_get_serial_sequence('public.requisition_lines', 'id');
  EXECUTE format('SELECT last_value FROM %s', seq_name::regclass) INTO seq_value;
  SELECT max(id) INTO max_id FROM public.requisition_lines;
  PERFORM setval(seq_name::regclass, GREATEST(seq_value, max_id), true);
  seq_name := pg_get_serial_sequence('public.approvals', 'id');
  EXECUTE format('SELECT last_value FROM %s', seq_name::regclass) INTO seq_value;
  SELECT max(id) INTO max_id FROM public.approvals;
  PERFORM setval(seq_name::regclass, GREATEST(seq_value, max_id), true);
END;
$sequences$;
COMMIT;

-- Read-only verification after commit; keep timestamp comparisons in UTC.
BEGIN READ ONLY;
SET LOCAL TIME ZONE 'UTC';
SELECT 'departments' AS table_name, 1 AS expected_count, count(*) AS actual_count FROM public.departments WHERE department_id BETWEEN 6000 AND 6000
UNION ALL
SELECT 'employees' AS table_name, 5 AS expected_count, count(*) AS actual_count FROM public.employees WHERE employee_id BETWEEN 6000 AND 6004
UNION ALL
SELECT 'requisitions' AS table_name, 10 AS expected_count, count(*) AS actual_count FROM public.requisitions WHERE id BETWEEN 6000 AND 6009
UNION ALL
SELECT 'requisition_lines' AS table_name, 10 AS expected_count, count(*) AS actual_count FROM public.requisition_lines WHERE id BETWEEN 6000 AND 6009
UNION ALL
SELECT 'approvals' AS table_name, 10 AS expected_count, count(*) AS actual_count FROM public.approvals WHERE id BETWEEN 6000 AND 6009;

WITH expected(entity_id, expected_flags) AS (
  VALUES
    (6000, ARRAY[]::text[]),
    (6001, ARRAY[]::text[]),
    (6002, ARRAY['over_limit']::text[]),
    (6003, ARRAY['inactive_approver']::text[]),
    (6004, ARRAY['inactive_approver', 'over_limit']::text[]),
    (6005, ARRAY['unresolved_approver']::text[]),
    (6006, ARRAY[]::text[]),
    (6007, ARRAY[]::text[]),
    (6008, ARRAY['unresolved_approver']::text[]),
    (6009, ARRAY['over_limit']::text[])
), observed AS (
  SELECT requisition_id AS entity_id, array_agg(DISTINCT flag_type ORDER BY flag_type) AS actual_flags
  FROM public.approval_flags WHERE requisition_id BETWEEN 6000 AND 6009
  GROUP BY requisition_id
)
SELECT e.entity_id, r.id IS NOT NULL AS entity_present, e.expected_flags,
       COALESCE(o.actual_flags, ARRAY[]::text[]) AS actual_flags,
       r.id IS NOT NULL AND e.expected_flags = COALESCE(o.actual_flags, ARRAY[]::text[]) AS matches
FROM expected e LEFT JOIN public.requisitions r ON r.id=e.entity_id
LEFT JOIN observed o ON o.entity_id=e.entity_id
ORDER BY e.entity_id;
COMMIT;
