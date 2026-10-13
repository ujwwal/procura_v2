-- Procura Stage 2: synthetic invoice fixtures. Prepared 2026-10-08. Loaded and verified on Neon in this session.
-- Review and run the entire file in one connection with stop-on-error enabled.
-- Do not run selected fragments. Reruns fail on collisions; existing rows are never replaced.
-- Expected answers are the literal handoff manifest, not inferred from the views.
-- Pause other writers (including direct sequence callers) during this one-time load.
-- Revised with user approval: 5003 is a separate expected-rejection test.
-- This batch loads 11 invoices, 9 POs/PO lines and 9 receipts.
-- See invoice-exceptions-itest-expected-failures.sql.
-- Dates: 2030-01-01 through 2030-11-27; unrelated invoices >=30 days apart.
-- 5008/5009 alone share a PO and are two days apart. Receipt checks are per line, not cumulative.
-- Partial quantities and duplicate similarity are review signals, not proven violations.

BEGIN;
SET LOCAL TIME ZONE 'UTC';
SET LOCAL search_path = public, pg_catalog;
SET LOCAL lock_timeout = '10s';
LOCK TABLE public.purchase_orders, public.purchase_order_lines, public.goods_receipts, public.invoices, public.invoice_lines, public.suppliers IN SHARE ROW EXCLUSIVE MODE;

DO $preflight$
BEGIN
  IF EXISTS (SELECT 1 FROM public.purchase_orders WHERE id BETWEEN 5000 AND 5009 OR po_no LIKE 'PROCURA-ITEST-%') THEN
    RAISE EXCEPTION 'purchase_orders: fixture ID/document namespace collision; no rows loaded';
  END IF;
  IF pg_get_serial_sequence('public.purchase_orders', 'id') IS NULL THEN
    RAISE EXCEPTION 'purchase_orders: expected SERIAL sequence missing';
  END IF;
  IF EXISTS (SELECT 1 FROM public.purchase_order_lines WHERE id BETWEEN 5000 AND 5009) THEN
    RAISE EXCEPTION 'purchase_order_lines: fixture ID/document namespace collision; no rows loaded';
  END IF;
  IF pg_get_serial_sequence('public.purchase_order_lines', 'id') IS NULL THEN
    RAISE EXCEPTION 'purchase_order_lines: expected SERIAL sequence missing';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='purchase_order_lines' AND column_name='line_total' AND is_generated='ALWAYS') THEN
    RAISE EXCEPTION 'purchase_order_lines.line_total must be generated';
  END IF;
  IF EXISTS (SELECT 1 FROM public.goods_receipts WHERE id BETWEEN 5000 AND 5009 OR receipt_no LIKE 'PROCURA-ITEST-%') THEN
    RAISE EXCEPTION 'goods_receipts: fixture ID/document namespace collision; no rows loaded';
  END IF;
  IF pg_get_serial_sequence('public.goods_receipts', 'id') IS NULL THEN
    RAISE EXCEPTION 'goods_receipts: expected SERIAL sequence missing';
  END IF;
  IF EXISTS (SELECT 1 FROM public.invoices WHERE id BETWEEN 5000 AND 5011 OR invoice_no LIKE 'PROCURA-ITEST-%') THEN
    RAISE EXCEPTION 'invoices: fixture ID/document namespace collision; no rows loaded';
  END IF;
  IF pg_get_serial_sequence('public.invoices', 'id') IS NULL THEN
    RAISE EXCEPTION 'invoices: expected SERIAL sequence missing';
  END IF;
  IF EXISTS (SELECT 1 FROM public.invoice_lines WHERE id BETWEEN 5000 AND 5011) THEN
    RAISE EXCEPTION 'invoice_lines: fixture ID/document namespace collision; no rows loaded';
  END IF;
  IF pg_get_serial_sequence('public.invoice_lines', 'id') IS NULL THEN
    RAISE EXCEPTION 'invoice_lines: expected SERIAL sequence missing';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='invoice_lines' AND column_name='line_total' AND is_generated='ALWAYS') THEN
    RAISE EXCEPTION 'invoice_lines.line_total must be generated';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.suppliers WHERE id=1 AND name='Northstar Parts') THEN
    RAISE EXCEPTION 'Reference supplier 1 Northstar Parts changed or missing';
  END IF;
  IF EXISTS (SELECT 1 FROM public.invoices WHERE created_at BETWEEN TIMESTAMPTZ '2029-12-27 00:00:00+00' AND TIMESTAMPTZ '2030-12-02 00:00:00+00') THEN
    RAISE EXCEPTION 'Existing invoice dates overlap isolated synthetic date window';
  END IF;
END;
$preflight$;

INSERT INTO public.purchase_orders (id, po_no, title, supplier_id, amount, status, order_date, created_at, requisition_id, contract_id, currency) VALUES
  (5000, 'PROCURA-ITEST-PO-5000', 'Synthetic invoice scenario 5000', 1, 50000, 'Open', '2030-01-01', '2030-01-01T00:00:00Z', NULL, NULL, 'INR'),
  (5001, 'PROCURA-ITEST-PO-5001', 'Synthetic invoice scenario 5001', 1, 50000, 'Open', '2030-01-31', '2030-01-31T00:00:00Z', NULL, NULL, 'INR'),
  (5002, 'PROCURA-ITEST-PO-5002', 'Synthetic invoice scenario 5002', 1, 50000, 'Open', '2030-03-02', '2030-03-02T00:00:00Z', NULL, NULL, 'INR'),
  (5004, 'PROCURA-ITEST-PO-5004', 'Synthetic invoice scenario 5004', 1, 50000, 'Open', '2030-05-01', '2030-05-01T00:00:00Z', NULL, NULL, 'INR'),
  (5005, 'PROCURA-ITEST-PO-5005', 'Synthetic invoice scenario 5005', 1, 50000, 'Open', '2030-05-31', '2030-05-31T00:00:00Z', NULL, NULL, 'INR'),
  (5006, 'PROCURA-ITEST-PO-5006', 'Synthetic invoice scenario 5006', 1, 50000, 'Open', '2030-07-01', '2030-07-01T00:00:00Z', NULL, NULL, 'INR'),
  (5007, 'PROCURA-ITEST-PO-5007', 'Synthetic invoice scenario 5008', 1, 50000, 'Open', '2030-08-29', '2030-08-29T00:00:00Z', NULL, NULL, 'INR'),
  (5008, 'PROCURA-ITEST-PO-5008', 'Synthetic invoice scenario 5010', 1, 50000, 'Open', '2030-10-28', '2030-10-28T00:00:00Z', NULL, NULL, 'INR'),
  (5009, 'PROCURA-ITEST-PO-5009', 'Synthetic invoice scenario 5011', 1, 50000, 'Open', '2030-11-27', '2030-11-27T00:00:00Z', NULL, NULL, 'INR');

INSERT INTO public.purchase_order_lines (id, po_id, line_no, requisition_line_id, description, quantity, unit, unit_price, created_at) VALUES
  (5000, 5000, 1, NULL, 'Synthetic monitor for invoice 5000', 5, 'each', 10000, '2030-01-01T00:00:00Z'),
  (5001, 5001, 1, NULL, 'Synthetic monitor for invoice 5001', 5, 'each', 10000, '2030-01-31T00:00:00Z'),
  (5002, 5002, 1, NULL, 'Synthetic monitor for invoice 5002', 5, 'each', 10000, '2030-03-02T00:00:00Z'),
  (5004, 5004, 1, NULL, 'Synthetic monitor for invoice 5004', 5, 'each', 10000, '2030-05-01T00:00:00Z'),
  (5005, 5005, 1, NULL, 'Synthetic monitor for invoice 5005', 5, 'each', 10000, '2030-05-31T00:00:00Z'),
  (5006, 5006, 1, NULL, 'Synthetic monitor for invoice 5006', 5, 'each', 10000, '2030-07-01T00:00:00Z'),
  (5007, 5007, 1, NULL, 'Synthetic monitor for invoice 5008', 5, 'each', 10000, '2030-08-29T00:00:00Z'),
  (5008, 5008, 1, NULL, 'Synthetic monitor for invoice 5010', 5, 'each', 10000, '2030-10-28T00:00:00Z'),
  (5009, 5009, 1, NULL, 'Synthetic monitor for invoice 5011', 5, 'each', 10000, '2030-11-27T00:00:00Z');

INSERT INTO public.goods_receipts (id, receipt_no, po_line_id, quantity, received_by, received_at, notes, created_at) VALUES
  (5000, 'PROCURA-ITEST-GR-5000', 5000, 5, 'Procura Test Receiver', '2030-01-01', 'Fictional Stage 2 fixture; receipt-date filtering is not part of invoice_flags.', '2030-01-01T00:00:00Z'),
  (5001, 'PROCURA-ITEST-GR-5001', 5001, 5, 'Procura Test Receiver', '2030-01-31', 'Fictional Stage 2 fixture; receipt-date filtering is not part of invoice_flags.', '2030-01-31T00:00:00Z'),
  (5002, 'PROCURA-ITEST-GR-5002', 5002, 5, 'Procura Test Receiver', '2030-03-02', 'Fictional Stage 2 fixture; receipt-date filtering is not part of invoice_flags.', '2030-03-02T00:00:00Z'),
  (5004, 'PROCURA-ITEST-GR-5004', 5005, 3, 'Procura Test Receiver', '2030-05-31', 'Fictional Stage 2 fixture; receipt-date filtering is not part of invoice_flags.', '2030-05-31T00:00:00Z'),
  (5005, 'PROCURA-ITEST-GR-5005', 5006, 5, 'Procura Test Receiver', '2030-07-01', 'Fictional Stage 2 fixture; receipt-date filtering is not part of invoice_flags.', '2030-07-01T00:00:00Z'),
  (5006, 'PROCURA-ITEST-GR-5006', 5007, 5, 'Procura Test Receiver', '2030-08-29', 'Fictional Stage 2 fixture; receipt-date filtering is not part of invoice_flags.', '2030-08-29T00:00:00Z'),
  (5007, 'PROCURA-ITEST-GR-5007', 5008, 3, 'Procura Test Receiver', '2030-10-28', 'Fictional Stage 2 fixture; receipt-date filtering is not part of invoice_flags.', '2030-10-28T00:00:00Z'),
  (5008, 'PROCURA-ITEST-GR-5008', 5009, 2, 'Procura Test Receiver', '2030-11-27', 'Fictional Stage 2 fixture; receipt-date filtering is not part of invoice_flags.', '2030-11-27T00:00:00Z'),
  (5009, 'PROCURA-ITEST-GR-5009', 5009, 3, 'Procura Test Receiver', '2030-11-27', 'Fictional Stage 2 fixture; receipt-date filtering is not part of invoice_flags.', '2030-11-27T00:00:00Z');

INSERT INTO public.invoices (id, invoice_no, supplier_id, po_id, amount, status, due_date, created_at, currency) VALUES
  (5000, 'PROCURA-ITEST-INV-5000', 1, 5000, 50000, 'Received', '2030-01-16', '2030-01-01T00:00:00Z', 'INR'),
  (5001, 'PROCURA-ITEST-INV-5001', 1, 5001, 40000, 'Received', '2030-02-15', '2030-01-31T00:00:00Z', 'INR'),
  (5002, 'PROCURA-ITEST-INV-5002', 1, 5002, 55000, 'Received', '2030-03-17', '2030-03-02T00:00:00Z', 'INR'),
  (5004, 'PROCURA-ITEST-INV-5004', 1, 5004, 50000, 'Received', '2030-05-16', '2030-05-01T00:00:00Z', 'INR'),
  (5005, 'PROCURA-ITEST-INV-5005', 1, 5005, 50000, 'Received', '2030-06-15', '2030-05-31T00:00:00Z', 'INR'),
  (5006, 'PROCURA-ITEST-INV-5006', 1, 5006, 50000, 'Received', '2030-07-15', '2030-06-30T00:00:00Z', 'INR'),
  (5007, 'PROCURA-ITEST-INV-5007', 1, NULL, 50000, 'Received', '2030-08-14', '2030-07-30T00:00:00Z', 'INR'),
  (5008, 'PROCURA-ITEST-INV-5008', 1, 5007, 50000, 'Received', '2030-09-13', '2030-08-29T00:00:00Z', 'INR'),
  (5009, 'PROCURA-ITEST-INV-5009', 1, 5007, 50000, 'Received', '2030-09-15', '2030-08-31T00:00:00Z', 'INR'),
  (5010, 'PROCURA-ITEST-INV-5010', 1, 5008, 66000, 'Received', '2030-11-12', '2030-10-28T00:00:00Z', 'INR'),
  (5011, 'PROCURA-ITEST-INV-5011', 1, 5009, 50000, 'Received', '2030-12-12', '2030-11-27T00:00:00Z', 'INR');

INSERT INTO public.invoice_lines (id, invoice_id, line_no, po_id, po_line_id, description, quantity, unit, unit_price, created_at) VALUES
  (5000, 5000, 1, 5000, 5000, 'Synthetic invoice scenario 5000', 5, 'each', 10000, '2030-01-01T00:00:00Z'),
  (5001, 5001, 1, 5001, 5001, 'Synthetic invoice scenario 5001', 4, 'each', 10000, '2030-01-31T00:00:00Z'),
  (5002, 5002, 1, 5002, 5002, 'Synthetic invoice scenario 5002', 5, 'each', 11000, '2030-03-02T00:00:00Z'),
  (5004, 5004, 1, 5004, 5004, 'Synthetic invoice scenario 5004', 5, 'each', 10000, '2030-05-01T00:00:00Z'),
  (5005, 5005, 1, 5005, 5005, 'Synthetic invoice scenario 5005', 5, 'each', 10000, '2030-05-31T00:00:00Z'),
  (5006, 5006, 1, 5006, 5006, 'Synthetic invoice scenario 5006', 5, 'each', 10000, '2030-06-30T00:00:00Z'),
  (5007, 5007, 1, NULL, NULL, 'Synthetic invoice scenario 5007', 5, 'each', 10000, '2030-07-30T00:00:00Z'),
  (5008, 5008, 1, 5007, 5007, 'Synthetic invoice scenario 5008', 5, 'each', 10000, '2030-08-29T00:00:00Z'),
  (5009, 5009, 1, 5007, 5007, 'Synthetic invoice scenario 5009', 5, 'each', 10000, '2030-08-31T00:00:00Z'),
  (5010, 5010, 1, 5008, 5008, 'Synthetic invoice scenario 5010', 6, 'each', 11000, '2030-10-28T00:00:00Z'),
  (5011, 5011, 1, 5009, 5009, 'Synthetic invoice scenario 5011', 5, 'each', 10000, '2030-11-27T00:00:00Z');

-- Verify every inserted row and relationship, not just aggregate flag counts.
DO $validate$
BEGIN
  IF (SELECT count(*) FROM public.purchase_orders WHERE id BETWEEN 5000 AND 5009) <> 9 THEN
    RAISE EXCEPTION 'purchase_orders: wrong fixture count';
  END IF;
  IF EXISTS (
    WITH expected AS (SELECT * FROM jsonb_populate_recordset(NULL::public.purchase_orders,
      '[{"id":5000,"po_no":"PROCURA-ITEST-PO-5000","title":"Synthetic invoice scenario 5000","supplier_id":1,"amount":50000,"status":"Open","order_date":"2030-01-01","created_at":"2030-01-01T00:00:00Z","requisition_id":null,"contract_id":null,"currency":"INR"},{"id":5001,"po_no":"PROCURA-ITEST-PO-5001","title":"Synthetic invoice scenario 5001","supplier_id":1,"amount":50000,"status":"Open","order_date":"2030-01-31","created_at":"2030-01-31T00:00:00Z","requisition_id":null,"contract_id":null,"currency":"INR"},{"id":5002,"po_no":"PROCURA-ITEST-PO-5002","title":"Synthetic invoice scenario 5002","supplier_id":1,"amount":50000,"status":"Open","order_date":"2030-03-02","created_at":"2030-03-02T00:00:00Z","requisition_id":null,"contract_id":null,"currency":"INR"},{"id":5004,"po_no":"PROCURA-ITEST-PO-5004","title":"Synthetic invoice scenario 5004","supplier_id":1,"amount":50000,"status":"Open","order_date":"2030-05-01","created_at":"2030-05-01T00:00:00Z","requisition_id":null,"contract_id":null,"currency":"INR"},{"id":5005,"po_no":"PROCURA-ITEST-PO-5005","title":"Synthetic invoice scenario 5005","supplier_id":1,"amount":50000,"status":"Open","order_date":"2030-05-31","created_at":"2030-05-31T00:00:00Z","requisition_id":null,"contract_id":null,"currency":"INR"},{"id":5006,"po_no":"PROCURA-ITEST-PO-5006","title":"Synthetic invoice scenario 5006","supplier_id":1,"amount":50000,"status":"Open","order_date":"2030-07-01","created_at":"2030-07-01T00:00:00Z","requisition_id":null,"contract_id":null,"currency":"INR"},{"id":5007,"po_no":"PROCURA-ITEST-PO-5007","title":"Synthetic invoice scenario 5008","supplier_id":1,"amount":50000,"status":"Open","order_date":"2030-08-29","created_at":"2030-08-29T00:00:00Z","requisition_id":null,"contract_id":null,"currency":"INR"},{"id":5008,"po_no":"PROCURA-ITEST-PO-5008","title":"Synthetic invoice scenario 5010","supplier_id":1,"amount":50000,"status":"Open","order_date":"2030-10-28","created_at":"2030-10-28T00:00:00Z","requisition_id":null,"contract_id":null,"currency":"INR"},{"id":5009,"po_no":"PROCURA-ITEST-PO-5009","title":"Synthetic invoice scenario 5011","supplier_id":1,"amount":50000,"status":"Open","order_date":"2030-11-27","created_at":"2030-11-27T00:00:00Z","requisition_id":null,"contract_id":null,"currency":"INR"}]'::jsonb))
    SELECT id, po_no, title, supplier_id, amount, status, order_date, created_at, requisition_id, contract_id, currency FROM expected
    EXCEPT ALL
    SELECT id, po_no, title, supplier_id, amount, status, order_date, created_at, requisition_id, contract_id, currency FROM public.purchase_orders WHERE id BETWEEN 5000 AND 5009
  ) THEN
    RAISE EXCEPTION 'purchase_orders: fixture values or links differ from construction';
  END IF;
  IF (SELECT count(*) FROM public.purchase_order_lines WHERE id BETWEEN 5000 AND 5009) <> 9 THEN
    RAISE EXCEPTION 'purchase_order_lines: wrong fixture count';
  END IF;
  IF EXISTS (
    WITH expected AS (SELECT * FROM jsonb_populate_recordset(NULL::public.purchase_order_lines,
      '[{"id":5000,"po_id":5000,"line_no":1,"requisition_line_id":null,"description":"Synthetic monitor for invoice 5000","quantity":5,"unit":"each","unit_price":10000,"created_at":"2030-01-01T00:00:00Z"},{"id":5001,"po_id":5001,"line_no":1,"requisition_line_id":null,"description":"Synthetic monitor for invoice 5001","quantity":5,"unit":"each","unit_price":10000,"created_at":"2030-01-31T00:00:00Z"},{"id":5002,"po_id":5002,"line_no":1,"requisition_line_id":null,"description":"Synthetic monitor for invoice 5002","quantity":5,"unit":"each","unit_price":10000,"created_at":"2030-03-02T00:00:00Z"},{"id":5004,"po_id":5004,"line_no":1,"requisition_line_id":null,"description":"Synthetic monitor for invoice 5004","quantity":5,"unit":"each","unit_price":10000,"created_at":"2030-05-01T00:00:00Z"},{"id":5005,"po_id":5005,"line_no":1,"requisition_line_id":null,"description":"Synthetic monitor for invoice 5005","quantity":5,"unit":"each","unit_price":10000,"created_at":"2030-05-31T00:00:00Z"},{"id":5006,"po_id":5006,"line_no":1,"requisition_line_id":null,"description":"Synthetic monitor for invoice 5006","quantity":5,"unit":"each","unit_price":10000,"created_at":"2030-07-01T00:00:00Z"},{"id":5007,"po_id":5007,"line_no":1,"requisition_line_id":null,"description":"Synthetic monitor for invoice 5008","quantity":5,"unit":"each","unit_price":10000,"created_at":"2030-08-29T00:00:00Z"},{"id":5008,"po_id":5008,"line_no":1,"requisition_line_id":null,"description":"Synthetic monitor for invoice 5010","quantity":5,"unit":"each","unit_price":10000,"created_at":"2030-10-28T00:00:00Z"},{"id":5009,"po_id":5009,"line_no":1,"requisition_line_id":null,"description":"Synthetic monitor for invoice 5011","quantity":5,"unit":"each","unit_price":10000,"created_at":"2030-11-27T00:00:00Z"}]'::jsonb))
    SELECT id, po_id, line_no, requisition_line_id, description, quantity, unit, unit_price, created_at FROM expected
    EXCEPT ALL
    SELECT id, po_id, line_no, requisition_line_id, description, quantity, unit, unit_price, created_at FROM public.purchase_order_lines WHERE id BETWEEN 5000 AND 5009
  ) THEN
    RAISE EXCEPTION 'purchase_order_lines: fixture values or links differ from construction';
  END IF;
  IF (SELECT count(*) FROM public.goods_receipts WHERE id BETWEEN 5000 AND 5009) <> 9 THEN
    RAISE EXCEPTION 'goods_receipts: wrong fixture count';
  END IF;
  IF EXISTS (
    WITH expected AS (SELECT * FROM jsonb_populate_recordset(NULL::public.goods_receipts,
      '[{"id":5000,"receipt_no":"PROCURA-ITEST-GR-5000","po_line_id":5000,"quantity":5,"received_by":"Procura Test Receiver","received_at":"2030-01-01","notes":"Fictional Stage 2 fixture; receipt-date filtering is not part of invoice_flags.","created_at":"2030-01-01T00:00:00Z"},{"id":5001,"receipt_no":"PROCURA-ITEST-GR-5001","po_line_id":5001,"quantity":5,"received_by":"Procura Test Receiver","received_at":"2030-01-31","notes":"Fictional Stage 2 fixture; receipt-date filtering is not part of invoice_flags.","created_at":"2030-01-31T00:00:00Z"},{"id":5002,"receipt_no":"PROCURA-ITEST-GR-5002","po_line_id":5002,"quantity":5,"received_by":"Procura Test Receiver","received_at":"2030-03-02","notes":"Fictional Stage 2 fixture; receipt-date filtering is not part of invoice_flags.","created_at":"2030-03-02T00:00:00Z"},{"id":5004,"receipt_no":"PROCURA-ITEST-GR-5004","po_line_id":5005,"quantity":3,"received_by":"Procura Test Receiver","received_at":"2030-05-31","notes":"Fictional Stage 2 fixture; receipt-date filtering is not part of invoice_flags.","created_at":"2030-05-31T00:00:00Z"},{"id":5005,"receipt_no":"PROCURA-ITEST-GR-5005","po_line_id":5006,"quantity":5,"received_by":"Procura Test Receiver","received_at":"2030-07-01","notes":"Fictional Stage 2 fixture; receipt-date filtering is not part of invoice_flags.","created_at":"2030-07-01T00:00:00Z"},{"id":5006,"receipt_no":"PROCURA-ITEST-GR-5006","po_line_id":5007,"quantity":5,"received_by":"Procura Test Receiver","received_at":"2030-08-29","notes":"Fictional Stage 2 fixture; receipt-date filtering is not part of invoice_flags.","created_at":"2030-08-29T00:00:00Z"},{"id":5007,"receipt_no":"PROCURA-ITEST-GR-5007","po_line_id":5008,"quantity":3,"received_by":"Procura Test Receiver","received_at":"2030-10-28","notes":"Fictional Stage 2 fixture; receipt-date filtering is not part of invoice_flags.","created_at":"2030-10-28T00:00:00Z"},{"id":5008,"receipt_no":"PROCURA-ITEST-GR-5008","po_line_id":5009,"quantity":2,"received_by":"Procura Test Receiver","received_at":"2030-11-27","notes":"Fictional Stage 2 fixture; receipt-date filtering is not part of invoice_flags.","created_at":"2030-11-27T00:00:00Z"},{"id":5009,"receipt_no":"PROCURA-ITEST-GR-5009","po_line_id":5009,"quantity":3,"received_by":"Procura Test Receiver","received_at":"2030-11-27","notes":"Fictional Stage 2 fixture; receipt-date filtering is not part of invoice_flags.","created_at":"2030-11-27T00:00:00Z"}]'::jsonb))
    SELECT id, receipt_no, po_line_id, quantity, received_by, received_at, notes, created_at FROM expected
    EXCEPT ALL
    SELECT id, receipt_no, po_line_id, quantity, received_by, received_at, notes, created_at FROM public.goods_receipts WHERE id BETWEEN 5000 AND 5009
  ) THEN
    RAISE EXCEPTION 'goods_receipts: fixture values or links differ from construction';
  END IF;
  IF (SELECT count(*) FROM public.invoices WHERE id BETWEEN 5000 AND 5011) <> 11 THEN
    RAISE EXCEPTION 'invoices: wrong fixture count';
  END IF;
  IF EXISTS (
    WITH expected AS (SELECT * FROM jsonb_populate_recordset(NULL::public.invoices,
      '[{"id":5000,"invoice_no":"PROCURA-ITEST-INV-5000","supplier_id":1,"po_id":5000,"amount":50000,"status":"Received","due_date":"2030-01-16","created_at":"2030-01-01T00:00:00Z","currency":"INR"},{"id":5001,"invoice_no":"PROCURA-ITEST-INV-5001","supplier_id":1,"po_id":5001,"amount":40000,"status":"Received","due_date":"2030-02-15","created_at":"2030-01-31T00:00:00Z","currency":"INR"},{"id":5002,"invoice_no":"PROCURA-ITEST-INV-5002","supplier_id":1,"po_id":5002,"amount":55000,"status":"Received","due_date":"2030-03-17","created_at":"2030-03-02T00:00:00Z","currency":"INR"},{"id":5004,"invoice_no":"PROCURA-ITEST-INV-5004","supplier_id":1,"po_id":5004,"amount":50000,"status":"Received","due_date":"2030-05-16","created_at":"2030-05-01T00:00:00Z","currency":"INR"},{"id":5005,"invoice_no":"PROCURA-ITEST-INV-5005","supplier_id":1,"po_id":5005,"amount":50000,"status":"Received","due_date":"2030-06-15","created_at":"2030-05-31T00:00:00Z","currency":"INR"},{"id":5006,"invoice_no":"PROCURA-ITEST-INV-5006","supplier_id":1,"po_id":5006,"amount":50000,"status":"Received","due_date":"2030-07-15","created_at":"2030-06-30T00:00:00Z","currency":"INR"},{"id":5007,"invoice_no":"PROCURA-ITEST-INV-5007","supplier_id":1,"po_id":null,"amount":50000,"status":"Received","due_date":"2030-08-14","created_at":"2030-07-30T00:00:00Z","currency":"INR"},{"id":5008,"invoice_no":"PROCURA-ITEST-INV-5008","supplier_id":1,"po_id":5007,"amount":50000,"status":"Received","due_date":"2030-09-13","created_at":"2030-08-29T00:00:00Z","currency":"INR"},{"id":5009,"invoice_no":"PROCURA-ITEST-INV-5009","supplier_id":1,"po_id":5007,"amount":50000,"status":"Received","due_date":"2030-09-15","created_at":"2030-08-31T00:00:00Z","currency":"INR"},{"id":5010,"invoice_no":"PROCURA-ITEST-INV-5010","supplier_id":1,"po_id":5008,"amount":66000,"status":"Received","due_date":"2030-11-12","created_at":"2030-10-28T00:00:00Z","currency":"INR"},{"id":5011,"invoice_no":"PROCURA-ITEST-INV-5011","supplier_id":1,"po_id":5009,"amount":50000,"status":"Received","due_date":"2030-12-12","created_at":"2030-11-27T00:00:00Z","currency":"INR"}]'::jsonb))
    SELECT id, invoice_no, supplier_id, po_id, amount, status, due_date, created_at, currency FROM expected
    EXCEPT ALL
    SELECT id, invoice_no, supplier_id, po_id, amount, status, due_date, created_at, currency FROM public.invoices WHERE id BETWEEN 5000 AND 5011
  ) THEN
    RAISE EXCEPTION 'invoices: fixture values or links differ from construction';
  END IF;
  IF (SELECT count(*) FROM public.invoice_lines WHERE id BETWEEN 5000 AND 5011) <> 11 THEN
    RAISE EXCEPTION 'invoice_lines: wrong fixture count';
  END IF;
  IF EXISTS (
    WITH expected AS (SELECT * FROM jsonb_populate_recordset(NULL::public.invoice_lines,
      '[{"id":5000,"invoice_id":5000,"line_no":1,"po_id":5000,"po_line_id":5000,"description":"Synthetic invoice scenario 5000","quantity":5,"unit":"each","unit_price":10000,"created_at":"2030-01-01T00:00:00Z"},{"id":5001,"invoice_id":5001,"line_no":1,"po_id":5001,"po_line_id":5001,"description":"Synthetic invoice scenario 5001","quantity":4,"unit":"each","unit_price":10000,"created_at":"2030-01-31T00:00:00Z"},{"id":5002,"invoice_id":5002,"line_no":1,"po_id":5002,"po_line_id":5002,"description":"Synthetic invoice scenario 5002","quantity":5,"unit":"each","unit_price":11000,"created_at":"2030-03-02T00:00:00Z"},{"id":5004,"invoice_id":5004,"line_no":1,"po_id":5004,"po_line_id":5004,"description":"Synthetic invoice scenario 5004","quantity":5,"unit":"each","unit_price":10000,"created_at":"2030-05-01T00:00:00Z"},{"id":5005,"invoice_id":5005,"line_no":1,"po_id":5005,"po_line_id":5005,"description":"Synthetic invoice scenario 5005","quantity":5,"unit":"each","unit_price":10000,"created_at":"2030-05-31T00:00:00Z"},{"id":5006,"invoice_id":5006,"line_no":1,"po_id":5006,"po_line_id":5006,"description":"Synthetic invoice scenario 5006","quantity":5,"unit":"each","unit_price":10000,"created_at":"2030-06-30T00:00:00Z"},{"id":5007,"invoice_id":5007,"line_no":1,"po_id":null,"po_line_id":null,"description":"Synthetic invoice scenario 5007","quantity":5,"unit":"each","unit_price":10000,"created_at":"2030-07-30T00:00:00Z"},{"id":5008,"invoice_id":5008,"line_no":1,"po_id":5007,"po_line_id":5007,"description":"Synthetic invoice scenario 5008","quantity":5,"unit":"each","unit_price":10000,"created_at":"2030-08-29T00:00:00Z"},{"id":5009,"invoice_id":5009,"line_no":1,"po_id":5007,"po_line_id":5007,"description":"Synthetic invoice scenario 5009","quantity":5,"unit":"each","unit_price":10000,"created_at":"2030-08-31T00:00:00Z"},{"id":5010,"invoice_id":5010,"line_no":1,"po_id":5008,"po_line_id":5008,"description":"Synthetic invoice scenario 5010","quantity":6,"unit":"each","unit_price":11000,"created_at":"2030-10-28T00:00:00Z"},{"id":5011,"invoice_id":5011,"line_no":1,"po_id":5009,"po_line_id":5009,"description":"Synthetic invoice scenario 5011","quantity":5,"unit":"each","unit_price":10000,"created_at":"2030-11-27T00:00:00Z"}]'::jsonb))
    SELECT id, invoice_id, line_no, po_id, po_line_id, description, quantity, unit, unit_price, created_at FROM expected
    EXCEPT ALL
    SELECT id, invoice_id, line_no, po_id, po_line_id, description, quantity, unit, unit_price, created_at FROM public.invoice_lines WHERE id BETWEEN 5000 AND 5011
  ) THEN
    RAISE EXCEPTION 'invoice_lines: fixture values or links differ from construction';
  END IF;
  IF EXISTS (SELECT 1 FROM public.invoices h WHERE h.id BETWEEN 5000 AND 5011 AND ((SELECT count(*) FROM public.invoice_lines l WHERE l.invoice_id=h.id) <> 1 OR h.amount IS DISTINCT FROM (SELECT sum(l.line_total) FROM public.invoice_lines l WHERE l.invoice_id=h.id))) THEN
    RAISE EXCEPTION 'invoices: missing/extra lines or incorrect financial total';
  END IF;
  IF EXISTS (SELECT 1 FROM public.invoice_lines WHERE invoice_id BETWEEN 5000 AND 5011 AND line_total IS DISTINCT FROM round(quantity * unit_price,2)) THEN
    RAISE EXCEPTION 'invoice_lines: incorrect generated financial total';
  END IF;
  IF EXISTS (SELECT 1 FROM public.purchase_orders h WHERE h.id BETWEEN 5000 AND 5009 AND ((SELECT count(*) FROM public.purchase_order_lines l WHERE l.po_id=h.id) <> 1 OR h.amount IS DISTINCT FROM (SELECT sum(l.line_total) FROM public.purchase_order_lines l WHERE l.po_id=h.id))) THEN
    RAISE EXCEPTION 'purchase_orders: missing/extra lines or incorrect financial total';
  END IF;
  IF EXISTS (SELECT 1 FROM public.purchase_order_lines WHERE po_id BETWEEN 5000 AND 5009 AND line_total IS DISTINCT FROM round(quantity * unit_price,2)) THEN
    RAISE EXCEPTION 'purchase_order_lines: incorrect generated financial total';
  END IF;
  IF EXISTS (SELECT 1 FROM (
WITH expected(entity_id, expected_flags) AS (
  VALUES
    (5000, ARRAY[]::text[]),
    (5001, ARRAY['quantity_mismatch']::text[]),
    (5002, ARRAY['price_mismatch']::text[]),
    (5004, ARRAY['missing_receipt']::text[]),
    (5005, ARRAY['overbilled_quantity']::text[]),
    (5006, ARRAY['invoice_before_po']::text[]),
    (5007, ARRAY['no_po_link']::text[]),
    (5008, ARRAY[]::text[]),
    (5009, ARRAY['possible_duplicate']::text[]),
    (5010, ARRAY['overbilled_quantity', 'price_mismatch', 'quantity_mismatch']::text[]),
    (5011, ARRAY[]::text[])
), observed AS (
  SELECT invoice_id AS entity_id, array_agg(DISTINCT flag_type ORDER BY flag_type) AS actual_flags
  FROM public.invoice_flags WHERE invoice_id BETWEEN 5000 AND 5011
  GROUP BY invoice_id
)
SELECT e.entity_id, r.id IS NOT NULL AS entity_present, e.expected_flags,
       COALESCE(o.actual_flags, ARRAY[]::text[]) AS actual_flags,
       r.id IS NOT NULL AND e.expected_flags = COALESCE(o.actual_flags, ARRAY[]::text[]) AS matches
FROM expected e LEFT JOIN public.invoices r ON r.id=e.entity_id
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
  seq_name := pg_get_serial_sequence('public.purchase_orders', 'id');
  EXECUTE format('SELECT last_value FROM %s', seq_name::regclass) INTO seq_value;
  SELECT max(id) INTO max_id FROM public.purchase_orders;
  PERFORM setval(seq_name::regclass, GREATEST(seq_value, max_id), true);
  seq_name := pg_get_serial_sequence('public.purchase_order_lines', 'id');
  EXECUTE format('SELECT last_value FROM %s', seq_name::regclass) INTO seq_value;
  SELECT max(id) INTO max_id FROM public.purchase_order_lines;
  PERFORM setval(seq_name::regclass, GREATEST(seq_value, max_id), true);
  seq_name := pg_get_serial_sequence('public.goods_receipts', 'id');
  EXECUTE format('SELECT last_value FROM %s', seq_name::regclass) INTO seq_value;
  SELECT max(id) INTO max_id FROM public.goods_receipts;
  PERFORM setval(seq_name::regclass, GREATEST(seq_value, max_id), true);
  seq_name := pg_get_serial_sequence('public.invoices', 'id');
  EXECUTE format('SELECT last_value FROM %s', seq_name::regclass) INTO seq_value;
  SELECT max(id) INTO max_id FROM public.invoices;
  PERFORM setval(seq_name::regclass, GREATEST(seq_value, max_id), true);
  seq_name := pg_get_serial_sequence('public.invoice_lines', 'id');
  EXECUTE format('SELECT last_value FROM %s', seq_name::regclass) INTO seq_value;
  SELECT max(id) INTO max_id FROM public.invoice_lines;
  PERFORM setval(seq_name::regclass, GREATEST(seq_value, max_id), true);
END;
$sequences$;
COMMIT;

-- Read-only verification after commit; keep timestamp comparisons in UTC.
BEGIN READ ONLY;
SET LOCAL TIME ZONE 'UTC';
SELECT 'purchase_orders' AS table_name, 9 AS expected_count, count(*) AS actual_count FROM public.purchase_orders WHERE id BETWEEN 5000 AND 5009
UNION ALL
SELECT 'purchase_order_lines' AS table_name, 9 AS expected_count, count(*) AS actual_count FROM public.purchase_order_lines WHERE id BETWEEN 5000 AND 5009
UNION ALL
SELECT 'goods_receipts' AS table_name, 9 AS expected_count, count(*) AS actual_count FROM public.goods_receipts WHERE id BETWEEN 5000 AND 5009
UNION ALL
SELECT 'invoices' AS table_name, 11 AS expected_count, count(*) AS actual_count FROM public.invoices WHERE id BETWEEN 5000 AND 5011
UNION ALL
SELECT 'invoice_lines' AS table_name, 11 AS expected_count, count(*) AS actual_count FROM public.invoice_lines WHERE id BETWEEN 5000 AND 5011;

WITH expected(entity_id, expected_flags) AS (
  VALUES
    (5000, ARRAY[]::text[]),
    (5001, ARRAY['quantity_mismatch']::text[]),
    (5002, ARRAY['price_mismatch']::text[]),
    (5004, ARRAY['missing_receipt']::text[]),
    (5005, ARRAY['overbilled_quantity']::text[]),
    (5006, ARRAY['invoice_before_po']::text[]),
    (5007, ARRAY['no_po_link']::text[]),
    (5008, ARRAY[]::text[]),
    (5009, ARRAY['possible_duplicate']::text[]),
    (5010, ARRAY['overbilled_quantity', 'price_mismatch', 'quantity_mismatch']::text[]),
    (5011, ARRAY[]::text[])
), observed AS (
  SELECT invoice_id AS entity_id, array_agg(DISTINCT flag_type ORDER BY flag_type) AS actual_flags
  FROM public.invoice_flags WHERE invoice_id BETWEEN 5000 AND 5011
  GROUP BY invoice_id
)
SELECT e.entity_id, r.id IS NOT NULL AS entity_present, e.expected_flags,
       COALESCE(o.actual_flags, ARRAY[]::text[]) AS actual_flags,
       r.id IS NOT NULL AND e.expected_flags = COALESCE(o.actual_flags, ARRAY[]::text[]) AS matches
FROM expected e LEFT JOIN public.invoices r ON r.id=e.entity_id
LEFT JOIN observed o ON o.entity_id=e.entity_id
ORDER BY e.entity_id;
COMMIT;
