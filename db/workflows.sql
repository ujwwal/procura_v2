-- Applied once by db/setup.js, inside its transaction.
ALTER TABLE requisitions ADD COLUMN currency CHAR(3) NOT NULL DEFAULT 'INR',
  ADD COLUMN delivery_location TEXT, ADD COLUMN needed_by DATE,
  ADD COLUMN justification TEXT;
ALTER TABLE purchase_orders ADD COLUMN requisition_id INTEGER REFERENCES requisitions(id),
  ADD COLUMN contract_id INTEGER REFERENCES contracts(id),
  ADD COLUMN currency CHAR(3) NOT NULL DEFAULT 'INR';
ALTER TABLE invoices ADD COLUMN currency CHAR(3) NOT NULL DEFAULT 'INR';
ALTER TABLE contracts ADD COLUMN currency CHAR(3) NOT NULL DEFAULT 'INR', ADD COLUMN document_text TEXT;
ALTER TABLE sourcing_events ADD COLUMN currency CHAR(3) NOT NULL DEFAULT 'INR';

CREATE TABLE catalog_items (
  id SERIAL PRIMARY KEY, sku TEXT UNIQUE NOT NULL, description TEXT NOT NULL,
  supplier_id INTEGER NOT NULL REFERENCES suppliers(id), category TEXT NOT NULL,
  unit TEXT NOT NULL DEFAULT 'each', unit_price NUMERIC(14,2) NOT NULL CHECK (unit_price >= 0),
  currency CHAR(3) NOT NULL DEFAULT 'INR', status TEXT NOT NULL DEFAULT 'Active'
    CHECK (status IN ('Active','Inactive')), created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE procurement_policies (
  id SERIAL PRIMARY KEY, code TEXT UNIQUE NOT NULL, title TEXT NOT NULL,
  category TEXT NOT NULL, department TEXT NOT NULL DEFAULT 'All',
  preferred_supplier_id INTEGER REFERENCES suppliers(id),
  approval_threshold NUMERIC(14,2) CHECK (approval_threshold >= 0),
  invoice_tolerance_percent NUMERIC(6,3) NOT NULL DEFAULT 0 CHECK (invoice_tolerance_percent BETWEEN 0 AND 100),
  currency CHAR(3) NOT NULL DEFAULT 'INR', rules_text TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'Draft' CHECK (status IN ('Draft','Published','Retired')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE requisition_lines (
  id SERIAL PRIMARY KEY, requisition_id INTEGER NOT NULL REFERENCES requisitions(id),
  line_no INTEGER NOT NULL CHECK (line_no > 0), catalog_item_id INTEGER REFERENCES catalog_items(id),
  supplier_id INTEGER REFERENCES suppliers(id), description TEXT NOT NULL,
  quantity NUMERIC(14,3) NOT NULL CHECK (quantity > 0), unit TEXT NOT NULL DEFAULT 'each',
  unit_price NUMERIC(14,2) NOT NULL CHECK (unit_price >= 0),
  line_total NUMERIC(14,2) GENERATED ALWAYS AS (ROUND(quantity * unit_price, 2)) STORED,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), UNIQUE(requisition_id,line_no)
);
CREATE TABLE purchase_order_lines (
  id SERIAL PRIMARY KEY, po_id INTEGER NOT NULL REFERENCES purchase_orders(id),
  line_no INTEGER NOT NULL CHECK (line_no > 0), requisition_line_id INTEGER REFERENCES requisition_lines(id),
  description TEXT NOT NULL, quantity NUMERIC(14,3) NOT NULL CHECK (quantity > 0),
  unit TEXT NOT NULL DEFAULT 'each', unit_price NUMERIC(14,2) NOT NULL CHECK (unit_price >= 0),
  line_total NUMERIC(14,2) GENERATED ALWAYS AS (ROUND(quantity * unit_price, 2)) STORED,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), UNIQUE(po_id,line_no), UNIQUE(id,po_id)
);
CREATE UNIQUE INDEX invoices_id_po_idx ON invoices(id,po_id);
CREATE TABLE invoice_lines (
  id SERIAL PRIMARY KEY, invoice_id INTEGER NOT NULL REFERENCES invoices(id),
  line_no INTEGER NOT NULL CHECK (line_no > 0), po_id INTEGER, po_line_id INTEGER,
  description TEXT NOT NULL, quantity NUMERIC(14,3) NOT NULL CHECK (quantity > 0),
  unit TEXT NOT NULL DEFAULT 'each', unit_price NUMERIC(14,2) NOT NULL CHECK (unit_price >= 0),
  line_total NUMERIC(14,2) GENERATED ALWAYS AS (ROUND(quantity * unit_price, 2)) STORED,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), UNIQUE(invoice_id,line_no),
  CHECK ((po_id IS NULL) = (po_line_id IS NULL)),
  FOREIGN KEY (po_line_id,po_id) REFERENCES purchase_order_lines(id,po_id),
  FOREIGN KEY (invoice_id,po_id) REFERENCES invoices(id,po_id)
);
CREATE TABLE goods_receipts (
  id SERIAL PRIMARY KEY, receipt_no TEXT UNIQUE NOT NULL,
  po_line_id INTEGER NOT NULL REFERENCES purchase_order_lines(id),
  quantity NUMERIC(14,3) NOT NULL CHECK (quantity > 0),
  received_by TEXT NOT NULL, received_at DATE NOT NULL DEFAULT CURRENT_DATE, notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE invoice_holds (
  id SERIAL PRIMARY KEY, hold_no TEXT UNIQUE NOT NULL,
  invoice_id INTEGER NOT NULL REFERENCES invoices(id),
  policy_id INTEGER REFERENCES procurement_policies(id), reason TEXT NOT NULL,
  evidence TEXT NOT NULL, owner TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'Open' CHECK (status IN ('Open','Resolved')),
  resolution_note TEXT,
  CHECK (status <> 'Resolved' OR LENGTH(TRIM(COALESCE(resolution_note,''))) > 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE sourcing_items (
  id SERIAL PRIMARY KEY, event_id INTEGER NOT NULL REFERENCES sourcing_events(id),
  line_no INTEGER NOT NULL CHECK (line_no > 0), description TEXT NOT NULL, specification TEXT NOT NULL,
  quantity NUMERIC(14,3) NOT NULL CHECK (quantity > 0), unit TEXT NOT NULL DEFAULT 'each',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), UNIQUE(event_id,line_no), UNIQUE(id,event_id)
);
CREATE TABLE supplier_bids (
  id SERIAL PRIMARY KEY, bid_no TEXT UNIQUE NOT NULL,
  event_id INTEGER NOT NULL REFERENCES sourcing_events(id), supplier_id INTEGER NOT NULL REFERENCES suppliers(id),
  freight NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (freight >= 0),
  tax_amount NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (tax_amount >= 0),
  delivery_days INTEGER CHECK (delivery_days >= 0), payment_terms TEXT, exclusions TEXT,
  status TEXT NOT NULL DEFAULT 'Draft' CHECK (status IN ('Draft','Submitted','Withdrawn')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), UNIQUE(event_id,supplier_id), UNIQUE(id,event_id)
);
CREATE TABLE bid_lines (
  id SERIAL PRIMARY KEY, bid_id INTEGER NOT NULL REFERENCES supplier_bids(id),
  event_id INTEGER NOT NULL, sourcing_item_id INTEGER NOT NULL,
  quantity NUMERIC(14,3) NOT NULL CHECK (quantity > 0), unit_price NUMERIC(14,2) NOT NULL CHECK (unit_price >= 0),
  offered_specification TEXT NOT NULL,
  line_total NUMERIC(14,2) GENERATED ALWAYS AS (ROUND(quantity * unit_price, 2)) STORED,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), UNIQUE(bid_id,sourcing_item_id),
  FOREIGN KEY(bid_id,event_id) REFERENCES supplier_bids(id,event_id),
  FOREIGN KEY(sourcing_item_id,event_id) REFERENCES sourcing_items(id,event_id)
);
CREATE TABLE evaluation_criteria (
  id SERIAL PRIMARY KEY, event_id INTEGER NOT NULL REFERENCES sourcing_events(id),
  name TEXT NOT NULL, weight NUMERIC(5,2) NOT NULL CHECK(weight > 0 AND weight <= 100),
  rubric TEXT NOT NULL, created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), UNIQUE(event_id,name)
);

-- Preserve historical header values as explicit opening lines. No amounts are discarded.
INSERT INTO requisition_lines(requisition_id,line_no,description,quantity,unit_price)
  SELECT id,1,title,1,amount FROM requisitions;
INSERT INTO purchase_order_lines(po_id,line_no,description,quantity,unit_price)
  SELECT id,1,title,1,amount FROM purchase_orders;
INSERT INTO invoice_lines(invoice_id,line_no,po_id,po_line_id,description,quantity,unit_price)
  SELECT i.id,1,i.po_id,p.id,i.invoice_no,1,i.amount FROM invoices i
  LEFT JOIN purchase_order_lines p ON p.po_id=i.po_id AND p.line_no=1;

-- Totals change atomically with line edits. Lock the parent BEFORE a line mutation
-- to serialize concurrent edits under READ COMMITTED.
CREATE FUNCTION lock_line_parent() RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE parent_key INTEGER;
BEGIN
  IF TG_OP = 'UPDATE' AND (to_jsonb(NEW)->>TG_ARGV[1]) IS DISTINCT FROM (to_jsonb(OLD)->>TG_ARGV[1]) THEN
    RAISE EXCEPTION 'Move lines by deleting and recreating them' USING ERRCODE='23514';
  END IF;
  parent_key := (CASE WHEN TG_OP='DELETE' THEN to_jsonb(OLD) ELSE to_jsonb(NEW) END ->> TG_ARGV[1])::INTEGER;
  EXECUTE format('SELECT id FROM %I WHERE id=$1 FOR UPDATE', TG_ARGV[0]) USING parent_key;
  IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
END $$;
CREATE FUNCTION refresh_line_total() RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE parent_key INTEGER;
BEGIN
  parent_key := (CASE WHEN TG_OP='DELETE' THEN to_jsonb(OLD) ELSE to_jsonb(NEW) END ->> TG_ARGV[1])::INTEGER;
  EXECUTE format('UPDATE %I SET amount=(SELECT COALESCE(SUM(line_total),0) FROM %I WHERE %I=$1) WHERE id=$1', TG_ARGV[0],TG_TABLE_NAME,TG_ARGV[1]) USING parent_key;
  RETURN NULL;
END $$;
CREATE TRIGGER req_line_lock BEFORE INSERT OR UPDATE OR DELETE ON requisition_lines FOR EACH ROW EXECUTE FUNCTION lock_line_parent('requisitions','requisition_id');
CREATE TRIGGER req_line_total AFTER INSERT OR UPDATE OR DELETE ON requisition_lines FOR EACH ROW EXECUTE FUNCTION refresh_line_total('requisitions','requisition_id');
CREATE TRIGGER po_line_lock BEFORE INSERT OR UPDATE OR DELETE ON purchase_order_lines FOR EACH ROW EXECUTE FUNCTION lock_line_parent('purchase_orders','po_id');
CREATE TRIGGER po_line_total AFTER INSERT OR UPDATE OR DELETE ON purchase_order_lines FOR EACH ROW EXECUTE FUNCTION refresh_line_total('purchase_orders','po_id');
CREATE TRIGGER inv_line_lock BEFORE INSERT OR UPDATE OR DELETE ON invoice_lines FOR EACH ROW EXECUTE FUNCTION lock_line_parent('invoices','invoice_id');
CREATE TRIGGER inv_line_total AFTER INSERT OR UPDATE OR DELETE ON invoice_lines FOR EACH ROW EXECUTE FUNCTION refresh_line_total('invoices','invoice_id');

CREATE INDEX receipts_po_line_idx ON goods_receipts(po_line_id);
CREATE INDEX holds_invoice_idx ON invoice_holds(invoice_id);
CREATE INDEX req_lines_catalog_idx ON requisition_lines(catalog_item_id);
CREATE INDEX po_lines_req_idx ON purchase_order_lines(requisition_line_id);

-- Check the affected record and its dependents, including parent edits.
-- Existing inconsistent legacy records are preserved; edits to them require repair.
CREATE FUNCTION validate_workflow_links() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF EXISTS(SELECT 1 FROM invoices i JOIN purchase_orders p ON p.id=i.po_id
    WHERE (i.supplier_id IS DISTINCT FROM p.supplier_id OR i.currency<>p.currency)
    AND ((TG_TABLE_NAME='invoices' AND i.id=NEW.id) OR (TG_TABLE_NAME='purchase_orders' AND p.id=NEW.id))) THEN
    RAISE EXCEPTION 'Invoice supplier and currency must match its PO' USING ERRCODE='23514';
  END IF;
  IF EXISTS(SELECT 1 FROM purchase_orders p JOIN contracts c ON c.id=p.contract_id
    WHERE (p.supplier_id IS DISTINCT FROM c.supplier_id OR p.currency<>c.currency)
    AND ((TG_TABLE_NAME='purchase_orders' AND p.id=NEW.id) OR (TG_TABLE_NAME='contracts' AND c.id=NEW.id))) THEN
    RAISE EXCEPTION 'PO supplier and currency must match its contract' USING ERRCODE='23514';
  END IF;
  IF EXISTS(SELECT 1 FROM purchase_orders p JOIN requisitions r ON r.id=p.requisition_id WHERE p.currency<>r.currency
    AND ((TG_TABLE_NAME='purchase_orders' AND p.id=NEW.id) OR (TG_TABLE_NAME='requisitions' AND r.id=NEW.id))) THEN
    RAISE EXCEPTION 'PO currency must match its requisition' USING ERRCODE='23514';
  END IF;
  IF EXISTS(SELECT 1 FROM requisition_lines l JOIN catalog_items c ON c.id=l.catalog_item_id JOIN requisitions r ON r.id=l.requisition_id
    WHERE (l.supplier_id IS DISTINCT FROM c.supplier_id OR r.currency<>c.currency OR l.unit<>c.unit)
    AND ((TG_TABLE_NAME='requisition_lines' AND l.id=NEW.id) OR (TG_TABLE_NAME='catalog_items' AND c.id=NEW.id) OR (TG_TABLE_NAME='requisitions' AND r.id=NEW.id))) THEN
    RAISE EXCEPTION 'Catalog line supplier, currency and unit must match the catalog item' USING ERRCODE='23514';
  END IF;
  IF EXISTS(SELECT 1 FROM purchase_order_lines l JOIN requisition_lines r ON r.id=l.requisition_line_id JOIN purchase_orders p ON p.id=l.po_id
    WHERE (p.requisition_id IS DISTINCT FROM r.requisition_id OR (r.supplier_id IS NOT NULL AND p.supplier_id IS DISTINCT FROM r.supplier_id) OR l.unit<>r.unit)
    AND ((TG_TABLE_NAME='purchase_order_lines' AND l.id=NEW.id) OR (TG_TABLE_NAME='requisition_lines' AND r.id=NEW.id) OR (TG_TABLE_NAME='purchase_orders' AND p.id=NEW.id))) THEN
    RAISE EXCEPTION 'PO line must reference its source requisition and supplier with matching units' USING ERRCODE='23514';
  END IF;
  IF EXISTS(SELECT 1 FROM invoice_lines l JOIN purchase_order_lines p ON p.id=l.po_line_id WHERE l.unit<>p.unit
    AND ((TG_TABLE_NAME='invoice_lines' AND l.id=NEW.id) OR (TG_TABLE_NAME='purchase_order_lines' AND p.id=NEW.id))) THEN
    RAISE EXCEPTION 'Matched invoice and PO lines must use the same unit' USING ERRCODE='23514';
  END IF;
  IF (to_jsonb(NEW)->>'currency') !~ '^[A-Z]{3}$' THEN
    RAISE EXCEPTION 'Currency must be a three-letter uppercase code' USING ERRCODE='23514';
  END IF;
  RETURN NULL;
END $$;
DO $$ DECLARE t TEXT; BEGIN
  FOREACH t IN ARRAY ARRAY['invoices','purchase_orders','contracts','requisitions','requisition_lines','purchase_order_lines','invoice_lines','catalog_items','sourcing_events','procurement_policies'] LOOP
    EXECUTE format('CREATE TRIGGER workflow_links AFTER INSERT OR UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION validate_workflow_links()',t);
  END LOOP;
END $$;
