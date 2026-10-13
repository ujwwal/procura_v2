const {createHash} = require('node:crypto');
const {validApprovalId} = require('./approval-context');
const {validateExtraction} = require('./quote-extraction');

class QuoteError extends Error {constructor(status,message){super(message);this.status=status;}}
function sourceHash(context) {
  return createHash('sha256').update(JSON.stringify({
    id:context.id,event_id:context.event_id,supplier_id:context.supplier_id,raw_quote_text:context.raw_quote_text,
    sourcing_items:context.sourcing_items
  })).digest('hex');
}
async function loadQuoteContext(client,id,lock=false) {
  const bid=await client.query('SELECT id,bid_no,event_id,supplier_id,freight::text,tax_amount::text,delivery_days,payment_terms,exclusions,status,created_at,raw_quote_text FROM public.supplier_bids WHERE id=$1'+(lock?' FOR UPDATE':''),[id]);
  if(!bid.rows.length)return null;
  const row=bid.rows[0];
  if(typeof row.raw_quote_text!=='string'||!row.raw_quote_text.trim())throw new QuoteError(422,'Quote text is missing. No extraction was produced.');
  if(row.raw_quote_text.length>50000)throw new QuoteError(422,'Quote text exceeds the prototype size limit.');
  const event=await client.query('SELECT id,event_no,title,category,status,currency FROM public.sourcing_events WHERE id=$1',[row.event_id]);
  const supplier=await client.query('SELECT id,code,name,status FROM public.suppliers WHERE id=$1',[row.supplier_id]);
  if(!event.rows.length||!supplier.rows.length)throw new QuoteError(409,'Quote source relationships are missing.');
  const items=await client.query('SELECT id,event_id,line_no,description,specification,quantity::text,unit FROM public.sourcing_items WHERE event_id=$1 ORDER BY line_no,id'+(lock?' FOR SHARE':''),[row.event_id]);
  if(items.rows.length!==1)throw new QuoteError(422,'This prototype requires one requested item per sourcing event.');
  const words=items.rows[0].description.match(/[A-Za-z]{3,}/g)??[];
  const query=words.at(-1)??'';
  if(!query)throw new QuoteError(422,'A catalog search keyword could not be formed from the requested item.');
  const context={...row,sourcing_event:event.rows[0],supplier:supplier.rows[0],sourcing_items:items.rows,
    catalog_search_query:query,check_limitations:[
      'This prototype extracts one offered line for one requested item.',
      'Catalog matching is item identity only; it does not verify supplier identity, prices, availability or specification compliance.',
      'Unknown quote values remain null. Only explicit days or unambiguous weeks become calendar-day lead times.',
      'Injection detection uses model output and a limited set of text patterns; it is not a guarantee against all attacks.',
      'Draft storage has no columns for sourcing item ID, evidence, warnings or model metadata. Keep the workflow output alongside the saved draft.'
    ]};
  context.source_hash=sourceHash(context);
  return context;
}
async function catalogCandidates(client,query) {
  // Same literal substring search used by the existing search_catalog HTTP capability.
  const result=await client.query(
    'SELECT id,sku,description,unit,status FROM public.catalog_items WHERE (sku ILIKE $1 OR description ILIKE $1 OR category ILIKE $1 OR unit ILIKE $1 OR currency::text ILIKE $1 OR status ILIKE $1) ORDER BY created_at DESC,id DESC LIMIT 101',
    ['%'+query+'%']);
  if(result.rows.length>100)throw new QuoteError(422,'Catalog results are truncated; narrow the item search before saving.');
  return result.rows.filter(c=>c.status==='Active');
}
async function readQuoteContext(pool,id) {
  const client=await pool.connect();
  try {
    await client.query('BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY');await client.query("SET LOCAL TIME ZONE 'UTC'");
    const result=await loadQuoteContext(client,id);
    await client.query('COMMIT');return result;
  }catch(e){await client.query('ROLLBACK').catch(()=>{});throw e;}
  finally{client.release();}
}
function sameDraft(row,line) {
  return row.catalog_item_id===line.catalog_item_id&&row.description===line.description&&
    (row.quantity===null||line.quantity===null?row.quantity===line.quantity:Number(row.quantity)===Number(line.quantity))&&
    (row.unit_price===null||line.unit_price===null?row.unit_price===line.unit_price:Number(row.unit_price)===Number(line.unit_price))&&
    row.currency===line.currency&&row.lead_time_days===line.lead_time_days;
}
async function saveDraftExtraction(pool,id,body) {
  if(!body||Object.keys(body).sort().join(',')!=='extraction,source_hash'||
      typeof body.source_hash!=='string'||!/^[a-f0-9]{64}$/.test(body.source_hash))
    throw new QuoteError(400,'Supply source_hash and extraction from a reviewed quote preview.');
  const client=await pool.connect();
  try {
    await client.query('BEGIN');await client.query("SET LOCAL TIME ZONE 'UTC'");
    const context=await loadQuoteContext(client,id,true);
    if(!context)throw new QuoteError(404,'Supplier bid not found');
    if(context.source_hash!==body.source_hash)throw new QuoteError(409,'Quote or sourcing context changed. Fetch and review it again.');
    context.catalog_candidates=await catalogCandidates(client,context.catalog_search_query);
    let result;
    try{result=validateExtraction(body.extraction,context);}
    catch{throw new QuoteError(400,'Extraction failed validation. Inspect the preview and its quoted evidence.');}
    const line=result.lines[0];
    const prior=await client.query('SELECT id,bid_id,catalog_item_id,description,quantity::text,unit_price::text,currency,lead_time_days,extracted_at FROM public.extracted_bid_lines WHERE bid_id=$1 ORDER BY id',[id]);
    if(prior.rows.length) {
      if(prior.rows.length!==1||!sameDraft(prior.rows[0],line))throw new QuoteError(409,'A different draft already exists for this bid. Review it separately; existing drafts were not overwritten.');
      await client.query('COMMIT');return {created:false,row:prior.rows[0],review:result};
    }
    const inserted=await client.query(
      'INSERT INTO public.extracted_bid_lines (bid_id,catalog_item_id,description,quantity,unit_price,currency,lead_time_days) VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING id,bid_id,catalog_item_id,description,quantity::text,unit_price::text,currency,lead_time_days,extracted_at',
      [id,line.catalog_item_id,line.description,line.quantity,line.unit_price,line.currency,line.lead_time_days]);
    await client.query('COMMIT');return {created:true,row:inserted.rows[0],review:result};
  }catch(e){await client.query('ROLLBACK').catch(()=>{});throw e;}
  finally{client.release();}
}
function sendQuoteError(res,error) {
  return res.status(error instanceof QuoteError?error.status:503).json({
    error:error instanceof QuoteError?error.message:'Quote evidence or draft storage unavailable. No successful extraction save was reported.'
  });
}
function quoteHandler(pool) {
  return async(req,res)=>{
    res.set('Cache-Control','no-store');
    if(!validApprovalId(req.params.id))return res.status(400).json({error:'Invalid supplier bid ID'});
    try{const result=await readQuoteContext(pool,Number(req.params.id));
      return result?res.json(result):res.status(404).json({error:'Supplier bid not found'});
    }catch(e){return sendQuoteError(res,e);}
  };
}
function draftHandler(pool) {
  return async(req,res)=>{
    res.set('Cache-Control','no-store');
    if(!validApprovalId(req.params.id))return res.status(400).json({error:'Invalid supplier bid ID'});
    try{const result=await saveDraftExtraction(pool,Number(req.params.id),req.body);
      return res.status(result.created?201:200).json({draft_only:true,created:result.created,rows:[result.row],review:result.review});
    }catch(e){return sendQuoteError(res,e);}
  };
}
module.exports={sourceHash,loadQuoteContext,readQuoteContext,saveDraftExtraction,quoteHandler,draftHandler,sameDraft};
