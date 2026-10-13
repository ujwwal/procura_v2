-- Expected failures for the quote-extraction batch.
-- Run each statement on its own, after db/quote-extraction-qtest.sql has committed.
-- These statements are not part of that load and are not wrapped in its transaction.
-- A successful run of any statement below means the constraint did not fire.

-- 1. Duplicate event/supplier pair. Bid 4000 already uses event 4000 and supplier 1.
--    Expected: unique_violation on supplier_bids_event_id_supplier_id_key.
INSERT INTO supplier_bids (id, bid_no, event_id, supplier_id, freight, tax_amount, status)
VALUES (4090, 'PROCURA-QTEST-BID-FAIL-DUP', 4000, 1, 0, 0, 'Draft');

-- 2. Bid line event differs from its parent bid.
--    Bid 4000 belongs to event 4000. Item 4001 belongs to event 4001, so only the bid/event key should fail.
--    Expected: foreign_key_violation on bid_lines (bid_id, event_id) -> supplier_bids (id, event_id).
INSERT INTO bid_lines (id, bid_id, event_id, sourcing_item_id, quantity, unit_price, offered_specification)
VALUES (4091, 4000, 4001, 4001, 5, 9000.00, 'IPS panel, HDMI, three-year warranty');

-- 3. Bid line sourcing item belongs to another event.
--    Bid 4000 and event 4000 are a valid pair. Item 4001 belongs to event 4001.
--    Expected: foreign_key_violation on bid_lines (sourcing_item_id, event_id) -> sourcing_items (id, event_id).
INSERT INTO bid_lines (id, bid_id, event_id, sourcing_item_id, quantity, unit_price, offered_specification)
VALUES (4092, 4000, 4000, 4001, 5, 9000.00, 'IPS panel, HDMI, three-year warranty');

-- 4. Zero quantity. Bid 4018 has no complete line, so the quantity check is the failing constraint.
--    Expected: check_violation on bid_lines_quantity_check.
INSERT INTO bid_lines (id, bid_id, event_id, sourcing_item_id, quantity, unit_price, offered_specification)
VALUES (4093, 4018, 4005, 4005, 0, 9000.00, 'IPS panel, HDMI, three-year warranty');

-- 5. Negative unit price. Bid 4019 has no complete line, so the price check is the failing constraint.
--    Expected: check_violation on bid_lines_unit_price_check.
INSERT INTO bid_lines (id, bid_id, event_id, sourcing_item_id, quantity, unit_price, offered_specification)
VALUES (4094, 4019, 4005, 4005, 5, -1.00, 'IPS panel, HDMI, three-year warranty');
