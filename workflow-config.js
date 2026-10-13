/* Shared form/API definitions. Reference fields are presented as named selectors. */
(function (root) {
  const ref = (name, label, target, required = true) => [name, label, 'reference', required, target];
  const text = (name, label, required = true) => [name, label, 'text', required];
  const num = (name, label, required = true) => [name, label, 'number', required];
  const memo = (name, label, required = false) => [name, label, 'textarea', required];
  const select = (name, label, values) => [name, label, 'select', true, values];
  const currency = text('currency', 'Currency (3-letter code)');
  const lineFields = [num('line_no','Line number'),text('description','Description'),num('quantity','Quantity'),text('unit','Unit'),num('unit_price','Unit price')];
  const resources = {
    catalog_items: {label:'Catalog items',icon:'CA',id:'sku',title:'description',fields:[text('sku','SKU'),text('description','Description'),ref('supplier_id','Supplier','suppliers'),text('category','Category'),text('unit','Unit'),num('unit_price','Unit price'),currency,select('status','Status',['Active','Inactive'])]},
    procurement_policies: {label:'Procurement policies',icon:'PL',id:'code',title:'title',fields:[text('code','Policy code'),text('title','Title'),text('category','Category'),text('department','Department (All for all departments)'),ref('preferred_supplier_id','Preferred supplier','suppliers',false),num('approval_threshold','Approval threshold',false),num('invoice_tolerance_percent','Invoice tolerance (%)'),currency,memo('rules_text','Policy rules',true),select('status','Status',['Draft','Published','Retired'])]},
    requisition_lines: {label:'Requisition lines',icon:'RL',id:'line_no',title:'description',fields:[ref('requisition_id','Requisition','requisitions'),ref('catalog_item_id','Catalog item','catalog_items',false),ref('supplier_id','Supplier','suppliers',false),...lineFields]},
    purchase_order_lines: {label:'Purchase order lines',icon:'OL',id:'line_no',title:'description',fields:[ref('po_id','Purchase order','purchase_orders'),ref('requisition_line_id','Requisition line','requisition_lines',false),...lineFields]},
    invoice_lines: {label:'Invoice lines',icon:'IL',id:'line_no',title:'description',fields:[ref('invoice_id','Invoice','invoices'),ref('po_id','Matched purchase order','purchase_orders',false),ref('po_line_id','Matched PO line','purchase_order_lines',false),...lineFields]},
    goods_receipts: {label:'Goods receipts',icon:'GR',id:'receipt_no',title:'receipt_no',fields:[text('receipt_no','Receipt number'),ref('po_line_id','PO line','purchase_order_lines'),num('quantity','Quantity received'),text('received_by','Received by'),['received_at','Received date','date',true],memo('notes','Receipt notes')]},
    invoice_holds: {label:'Invoice holds',icon:'IH',id:'hold_no',title:'reason',fields:[text('hold_no','Hold number'),ref('invoice_id','Invoice','invoices'),ref('policy_id','Policy','procurement_policies',false),text('reason','Reason'),memo('evidence','Evidence / investigation notes',true),text('owner','Owner'),select('status','Status',['Open','Resolved']),memo('resolution_note','Resolution note (required to resolve)')]},
    sourcing_items: {label:'Sourcing items',icon:'SI',id:'line_no',title:'description',fields:[ref('event_id','Sourcing event','sourcing_events'),num('line_no','Line number'),text('description','Description'),memo('specification','Required specification',true),num('quantity','Quantity'),text('unit','Unit')]},
    supplier_bids: {label:'Supplier bids',icon:'SB',id:'bid_no',title:'bid_no',fields:[text('bid_no','Bid number'),ref('event_id','Sourcing event','sourcing_events'),ref('supplier_id','Supplier','suppliers'),num('freight','Freight'),num('tax_amount','Tax amount'),num('delivery_days','Delivery days',false),text('payment_terms','Payment terms',false),memo('exclusions','Exclusions'),select('status','Status',['Draft','Submitted','Withdrawn'])]},
    bid_lines: {label:'Bid lines',icon:'BL',id:'id',title:'offered_specification',fields:[ref('bid_id','Supplier bid','supplier_bids'),ref('event_id','Sourcing event','sourcing_events'),ref('sourcing_item_id','Requested item','sourcing_items'),num('quantity','Quantity offered'),num('unit_price','Unit price'),memo('offered_specification','Offered specification',true)]},
    evaluation_criteria: {label:'Evaluation criteria',icon:'EC',id:'name',title:'name',fields:[ref('event_id','Sourcing event','sourcing_events'),text('name','Criterion'),num('weight','Weight (%)'),memo('rubric','Scoring rubric',true)]}
  };
  const additions = {
    requisitions:[currency,text('delivery_location','Delivery location',false),['needed_by','Needed by','date'],memo('justification','Justification')],
    purchase_orders:[ref('requisition_id','Source requisition','requisitions',false),ref('contract_id','Contract','contracts',false),currency],
    invoices:[currency], contracts:[currency,memo('document_text','Contract text')], sourcing_events:[currency]
  };
  const references = {supplier_id:'suppliers',po_id:'purchase_orders'};
  const children = {
    suppliers:[['catalog_items','supplier_id'],['contracts','supplier_id'],['purchase_orders','supplier_id'],['invoices','supplier_id'],['supplier_bids','supplier_id']],
    requisitions:[['requisition_lines','requisition_id'],['purchase_orders','requisition_id']],
    purchase_orders:[['purchase_order_lines','po_id'],['invoices','po_id']],
    purchase_order_lines:[['goods_receipts','po_line_id'],['invoice_lines','po_line_id']],
    invoices:[['invoice_lines','invoice_id'],['invoice_holds','invoice_id']],
    sourcing_events:[['sourcing_items','event_id'],['supplier_bids','event_id'],['evaluation_criteria','event_id']],
    supplier_bids:[['bid_lines','bid_id']], contracts:[['purchase_orders','contract_id']]
  };
  const config = {resources,additions,references,children};
  if (typeof module !== 'undefined' && module.exports) module.exports = config;
  else root.workflowConfig = config;
})(globalThis);
