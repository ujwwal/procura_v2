const LIMITATIONS = [
  'Flags are review signals. No exceptions detected does not establish approval or payment eligibility.',
  'Quantity mismatch compares each invoice line with the entire PO line quantity; partial billing can trigger it.',
  'Receipt quantities include every recorded receipt for the PO line, without filtering receipt dates.',
  'Overbilled quantity compares each invoice line individually, not cumulative billing across invoices.',
  'Possible duplicate means same supplier, amount within one percent of the lower-ID invoice, and creation within five days. The flag belongs to the higher-ID invoice.'
];

function validInvoiceId(value) {
  return (typeof value === 'number' || typeof value === 'string') &&
    /^[1-9]\d*$/.test(String(value)) && Number(value) <= 2147483647;
}

async function readInvoiceContext(pool, id) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY');
    await client.query("SET LOCAL TIME ZONE 'UTC'");
    const header = await client.query(
      'SELECT id, invoice_no, supplier_id, po_id, amount::text, status, due_date::text, created_at, currency FROM public.invoices WHERE id=$1', [id]);
    if (!header.rows.length) { await client.query('COMMIT'); return null; }
    const invoice = header.rows[0];
    const po = await client.query(
      'SELECT id, po_no, title, supplier_id, amount::text, status, order_date::text, currency FROM public.purchase_orders WHERE id=$1', [invoice.po_id]);
    const lines = await client.query(
      "SELECT il.id, il.line_no, il.description, il.quantity::text, il.unit, il.unit_price::text, il.line_total::text, il.po_id, il.po_line_id, " +
      "CASE WHEN pl.id IS NULL THEN NULL ELSE jsonb_build_object('id',pl.id,'po_id',pl.po_id,'description',pl.description,'quantity',pl.quantity::text,'unit',pl.unit,'unit_price',pl.unit_price::text,'line_total',pl.line_total::text) END AS po_line, " +
      'COALESCE(il.quantity <> pl.quantity,false) AS quantity_mismatch, COALESCE(il.unit_price <> pl.unit_price,false) AS price_mismatch, ' +
      'COALESCE(il.quantity > receipts.received,false) AS overbilled_quantity, receipts.received::text AS received_quantity, ' +
      "COALESCE(receipts.records,'[]'::jsonb) AS receipts " +
      'FROM public.invoice_lines il LEFT JOIN public.purchase_order_lines pl ON pl.id=il.po_line_id ' +
      "LEFT JOIN LATERAL (SELECT sum(gr.quantity) AS received, jsonb_agg(jsonb_build_object('id',gr.id,'receipt_no',gr.receipt_no,'quantity',gr.quantity::text,'received_at',gr.received_at::text) ORDER BY gr.id) AS records FROM public.goods_receipts gr WHERE gr.po_line_id=il.po_line_id) receipts ON true " +
      'WHERE il.invoice_id=$1 ORDER BY il.line_no,il.id', [id]);
    const recorded = await client.query('SELECT flag_type,detail FROM public.invoice_flags WHERE invoice_id=$1 ORDER BY flag_type,detail', [id]);
    const duplicates = await client.query(
      'SELECT candidate.id,candidate.invoice_no,candidate.supplier_id,candidate.amount::text,candidate.currency,candidate.created_at ' +
      'FROM public.invoices candidate JOIN public.invoices target ON target.id=$1 ' +
      'WHERE candidate.id < target.id AND candidate.supplier_id=target.supplier_id ' +
      'AND abs(candidate.amount-target.amount) <= 0.01*candidate.amount ' +
      "AND candidate.created_at-target.created_at BETWEEN INTERVAL '-5 days' AND INTERVAL '5 days' " +
      'AND candidate.invoice_no<>target.invoice_no ORDER BY candidate.id', [id]);
    const categories = [...new Set(recorded.rows.map(r => r.flag_type))];
    const evidence = [];
    const add = (category, suffix, facts) => evidence.push({ evidence_id: category + ':' + suffix, category, facts });
    for (const category of categories) {
      if (['quantity_mismatch','price_mismatch','missing_receipt','overbilled_quantity'].includes(category)) {
        for (const line of lines.rows) {
          const applies = category === 'missing_receipt' ? line.po_line_id !== null && line.receipts.length === 0 : line[category];
          if (applies) add(category, 'line:' + line.id, {
            invoice_line_id: line.id, po_line_id: line.po_line_id, unit: line.unit,
            invoiced_quantity: line.quantity, ordered_quantity: line.po_line?.quantity ?? null,
            invoice_unit_price: line.unit_price, po_unit_price: line.po_line?.unit_price ?? null,
            currency: invoice.currency, received_quantity: line.received_quantity,
            receipt_ids: line.receipts.map(r => r.id)
          });
        }
      } else if (category === 'currency_mismatch') {
        add(category, 'header', { invoice_id: invoice.id, po_id: invoice.po_id, invoice_currency: invoice.currency, po_currency: po.rows[0]?.currency });
      } else if (category === 'invoice_before_po') {
        add(category, 'header', { invoice_id: invoice.id, po_id: invoice.po_id, invoice_created_at: invoice.created_at, po_order_date: po.rows[0]?.order_date, comparison_timezone: 'UTC' });
      } else if (category === 'no_po_link') {
        add(category, 'header', { invoice_id: invoice.id, po_id: invoice.po_id });
      } else if (category === 'possible_duplicate') {
        for (const candidate of duplicates.rows) add(category, 'candidate:' + candidate.id, {
          invoice_id: invoice.id, invoice_no: invoice.invoice_no, supplier_id: invoice.supplier_id,
          invoice_amount: invoice.amount, invoice_currency: invoice.currency, invoice_created_at: invoice.created_at,
          candidate_invoice_id: candidate.id, candidate_invoice_no: candidate.invoice_no,
          candidate_amount: candidate.amount, candidate_currency: candidate.currency, candidate_created_at: candidate.created_at
        });
      } else throw new Error('Unsupported flag category');
      if (!evidence.some(e => e.category === category)) throw new Error('Flag evidence could not be resolved');
    }
    const result = {
      invoice, purchase_order: po.rows[0] ?? null, invoice_lines: lines.rows,
      duplicate_candidates: duplicates.rows,
      flags: categories.map(category => ({
        category, details: recorded.rows.filter(r => r.flag_type === category).map(r => r.detail),
        evidence_ids: evidence.filter(e => e.category === category).map(e => e.evidence_id)
      })),
      evidence, check_limitations: LIMITATIONS
    };
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally { client.release(); }
}

function invoiceFlagsHandler(pool) {
  return async (req, res) => {
    res.set('Cache-Control','no-store');
    if (!validInvoiceId(req.params.id)) return res.status(400).json({ error: 'Invalid invoice ID' });
    try {
      const result = await readInvoiceContext(pool, Number(req.params.id));
      return result ? res.json(result) : res.status(404).json({ error: 'Invoice not found' });
    } catch {
      return res.status(503).json({ error: 'Invoice evidence unavailable. No review result was produced.' });
    }
  };
}
module.exports = { readInvoiceContext, invoiceFlagsHandler, validInvoiceId, LIMITATIONS };
