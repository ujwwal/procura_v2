-- Case 5003: expected database rejection, NOT a stored invoice flag.
-- Run after the invoice batch. All test work is rolled back; no sequence is advanced.
BEGIN;
SET LOCAL TIME ZONE 'UTC';
DO $test$
DECLARE rejected boolean := false; msg text;
BEGIN
  IF EXISTS (SELECT 1 FROM public.invoices WHERE id=5003 OR invoice_no='PROCURA-ITEST-INV-5003') THEN
    RAISE EXCEPTION 'Case 5003 ID/document collision';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.purchase_orders WHERE id=5000 AND supplier_id=1 AND currency='INR') THEN
    RAISE EXCEPTION 'Expected INR fixture PO 5000 missing';
  END IF;
  BEGIN
    INSERT INTO public.invoices (id,invoice_no,supplier_id,po_id,amount,status,created_at,currency)
    VALUES (5003,'PROCURA-ITEST-INV-5003',1,5000,50000,'Received','2030-04-01T00:00:00Z','USD');
  EXCEPTION WHEN check_violation THEN
    GET STACKED DIAGNOSTICS msg = MESSAGE_TEXT;
    IF msg <> 'Invoice supplier and currency must match its PO' THEN
      RAISE EXCEPTION 'Unexpected constraint rejection: %', msg;
    END IF;
    rejected := true;
  END;
  IF NOT rejected THEN
    RAISE EXCEPTION 'FAIL: currency mismatch was accepted';
  END IF;
  IF EXISTS (SELECT 1 FROM public.invoices WHERE id=5003) THEN
    RAISE EXCEPTION 'Rejected invoice unexpectedly persisted';
  END IF;
  RAISE NOTICE 'PASS case 5003: SQLSTATE 23514; currency protection intact';
END;
$test$;
ROLLBACK;
