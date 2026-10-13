-- Synthetic cases; separate identifiers avoid changing the original sample records.
INSERT INTO procurement_policies(code,title,category,department,approval_threshold,invoice_tolerance_percent,rules_text,status)
VALUES ('POL-IT-01','IT equipment purchasing','IT hardware','All',50000,0,
 'Use an active catalog supplier. Requests above INR 50,000 require review. Confirm delivery location. Receipts must support billed quantities; an expected delivery is not a receipt.','Published') ON CONFLICT(code) DO NOTHING;
INSERT INTO catalog_items(sku,description,supplier_id,category,unit_price)
SELECT 'MON-24','24-inch IPS monitor',id,'IT hardware',10000 FROM suppliers WHERE code='SUP-1092' ON CONFLICT(sku) DO NOTHING;
INSERT INTO requisitions(req_no,title,requester,department,status,delivery_location,justification)
VALUES ('REQ-LAB-01','Two monitors for new joiners','Maya Shah','IT','Draft','Delhi office','New starter equipment') ON CONFLICT(req_no) DO NOTHING;
INSERT INTO requisition_lines(requisition_id,line_no,catalog_item_id,supplier_id,description,quantity,unit_price)
SELECT r.id,1,c.id,c.supplier_id,c.description,2,c.unit_price FROM requisitions r,catalog_items c
WHERE r.req_no='REQ-LAB-01' AND c.sku='MON-24' ON CONFLICT(requisition_id,line_no) DO NOTHING;
INSERT INTO purchase_orders(po_no,title,supplier_id,requisition_id)
SELECT 'PO-LAB-01','Monitor order',s.id,r.id FROM suppliers s,requisitions r WHERE s.code='SUP-1092' AND r.req_no='REQ-LAB-01' ON CONFLICT(po_no) DO NOTHING;
INSERT INTO purchase_order_lines(po_id,line_no,requisition_line_id,description,quantity,unit_price)
SELECT p.id,1,l.id,l.description,l.quantity,l.unit_price FROM purchase_orders p JOIN requisition_lines l ON l.requisition_id=p.requisition_id WHERE p.po_no='PO-LAB-01' ON CONFLICT(po_id,line_no) DO NOTHING;
INSERT INTO invoices(invoice_no,supplier_id,po_id,status,due_date)
SELECT 'INV-LAB-01',supplier_id,id,'Exception review',CURRENT_DATE+14 FROM purchase_orders WHERE po_no='PO-LAB-01' ON CONFLICT(invoice_no) DO NOTHING;
INSERT INTO invoice_lines(invoice_id,line_no,po_id,po_line_id,description,quantity,unit_price)
SELECT i.id,1,i.po_id,l.id,l.description,l.quantity,l.unit_price FROM invoices i JOIN purchase_order_lines l ON l.po_id=i.po_id WHERE i.invoice_no='INV-LAB-01' ON CONFLICT(invoice_id,line_no) DO NOTHING;
INSERT INTO goods_receipts(receipt_no,po_line_id,quantity,received_by,notes)
SELECT 'GR-LAB-01',l.id,1,'Asha Mehta','One monitor received. Second delivery is expected, not yet confirmed.' FROM purchase_order_lines l JOIN purchase_orders p ON p.id=l.po_id WHERE p.po_no='PO-LAB-01' ON CONFLICT(receipt_no) DO NOTHING;
INSERT INTO invoice_holds(hold_no,invoice_id,policy_id,reason,evidence,owner)
SELECT 'HOLD-LAB-01',i.id,p.id,'Receipt shortfall','Invoice bills two monitors; GR-LAB-01 confirms one. Ask the receiver to verify the remaining delivery.','AP analyst' FROM invoices i,procurement_policies p WHERE i.invoice_no='INV-LAB-01' AND p.code='POL-IT-01' ON CONFLICT(hold_no) DO NOTHING;
INSERT INTO sourcing_events(event_no,title,category,status) VALUES ('SRC-LAB-01','Monitor quotation comparison','IT hardware','Evaluation') ON CONFLICT(event_no) DO NOTHING;
INSERT INTO sourcing_items(event_id,line_no,description,specification,quantity)
SELECT id,1,'24-inch monitor','IPS panel, HDMI, three-year warranty',5 FROM sourcing_events WHERE event_no='SRC-LAB-01' ON CONFLICT(event_id,line_no) DO NOTHING;
INSERT INTO supplier_bids(bid_no,event_id,supplier_id,freight,tax_amount,delivery_days,payment_terms,status)
SELECT 'BID-LAB-A',e.id,s.id,5000,0,7,'Net 30; synthetic prices exclude tax','Submitted' FROM sourcing_events e,suppliers s WHERE e.event_no='SRC-LAB-01' AND s.code='SUP-1092' ON CONFLICT(bid_no) DO NOTHING;
INSERT INTO supplier_bids(bid_no,event_id,supplier_id,freight,tax_amount,delivery_days,payment_terms,status)
SELECT 'BID-LAB-B',e.id,s.id,0,0,10,'Net 30; synthetic prices exclude tax','Submitted' FROM sourcing_events e,suppliers s WHERE e.event_no='SRC-LAB-01' AND s.code='SUP-1074' ON CONFLICT(bid_no) DO NOTHING;
INSERT INTO bid_lines(bid_id,event_id,sourcing_item_id,quantity,unit_price,offered_specification)
SELECT b.id,b.event_id,i.id,5,CASE WHEN b.bid_no='BID-LAB-A' THEN 10000 ELSE 10600 END,'IPS panel, HDMI, three-year warranty' FROM supplier_bids b JOIN sourcing_items i ON i.event_id=b.event_id WHERE b.bid_no IN ('BID-LAB-A','BID-LAB-B') ON CONFLICT(bid_id,sourcing_item_id) DO NOTHING;
INSERT INTO evaluation_criteria(event_id,name,weight,rubric)
SELECT id,'Delivered cost',70,'Compare line totals plus freight and tax in the event currency; lower is better.' FROM sourcing_events WHERE event_no='SRC-LAB-01' ON CONFLICT(event_id,name) DO NOTHING;
INSERT INTO evaluation_criteria(event_id,name,weight,rubric)
SELECT id,'Delivery',30,'Compare confirmed delivery days; fewer is better. Check specification separately.' FROM sourcing_events WHERE event_no='SRC-LAB-01' ON CONFLICT(event_id,name) DO NOTHING;
