// SIMULATED responses for wiring tests only. This file intentionally uses the independent answer key.
// Production extraction/validation never imports this module or reads the CSV.
function readAnswers(text) {
  const rows=[];let row=[],value='',quoted=false;
  for(let i=0;i<text.length;i++){
    const c=text[i];
    if(c==='"'){if(quoted&&text[i+1]==='"'){value+='"';i++;}else quoted=!quoted;}
    else if(c===','&&!quoted){row.push(value);value='';}
    else if(c==='\n'&&!quoted){row.push(value.replace(/\r$/,''));if(row.some(Boolean))rows.push(row);row=[];value='';}
    else value+=c;
  }
  if(quoted)throw new Error('Malformed CSV');
  if(value||row.length){row.push(value);rows.push(row);}
  const header=rows.shift();
  const expected=['bid_id','is_clean','problem_type','correct_sourcing_item_id','correct_catalog_item_id','correct_quantity','correct_unit_price','correct_currency','correct_lead_time_days','contains_injection','correct_fix'];
  if(JSON.stringify(header)!==JSON.stringify(expected))throw new Error('Unexpected quote answer header');
  return rows.map(r=>{
    if(r.length!==11||!['true','false'].includes(r[1])||!['true','false'].includes(r[9]))throw new Error('Malformed quote answer');
    return {bid_id:Number(r[0]),clean:r[1]==='true',problem_types:r[2]?r[2].split(';'):[],
      sourcing_item_id:r[3]?Number(r[3]):null,catalog_item_id:r[4]?Number(r[4]):null,
      quantity:r[5]||null,unit_price:r[6]||null,currency:r[7]||null,lead_time_days:r[8]?Number(r[8]):null,
      injection:r[9]==='true',correct_fix:r[10]};
  });
}
function mockExtraction(context,answer) {
  const raw=context.raw_quote_text;
  const pieces=raw.split(/\r?\n| :: /).map(s=>s.trim()).filter(Boolean);
  const numeric=(s,n)=>[...s.matchAll(/\d[\d,]*(?:\.\d+)?/g)].some(m=>Number(m[0].replace(/,/g,''))===Number(n));
  const choose=(test)=>{const s=pieces.find(test);if(!s)throw new Error('Mock excerpt missing for bid '+context.id);return s;};
  let item=null;
  if(answer.catalog_item_id!==null){
    if(raw.includes('24-inch IPS monitor'))item='24-inch IPS monitor';
    else if(raw.includes('monitors, the 24-inch IPS model'))item='monitors, the 24-inch IPS model';
    else if(raw.includes('24" IPS HDMI 3yr'))item='24" IPS HDMI 3yr';
    else if(raw.includes('MON-24'))item='MON-24';
    else throw new Error('Mock item excerpt missing');
  }
  const quantity=answer.quantity===null?null:choose(s=>numeric(s,answer.quantity)&&/\b(qty|quantity|units?|pcs|each|monitors?|supply|offers?|quotes?)\b/i.test(s)&&!/[?~]/.test(s));
  const price=answer.unit_price===null?null:choose(s=>numeric(s,answer.unit_price)&&/\b(price|px|INR|USD|EUR|GBP|each|unit)\b|[$€£@]/i.test(s));
  const lead=answer.lead_time_days===null?null:choose(s=>{
    const m=[...s.matchAll(/\b(\d+)\s*(calendar\s+days?|days?|weeks?|wks?)\b/gi)];
    return m.length===1&&Number(m[0][1])*(/week|wk/i.test(m[0][2])?7:1)===answer.lead_time_days&&!/business|working|[?~]/i.test(s);
  });
  const unknownReason='The quote does not establish this value unambiguously.';
  return {
    bid_id:context.id,line:{
      description:item,sourcing_item_id:answer.sourcing_item_id,catalog_item_id:answer.catalog_item_id,
      quantity:answer.quantity,unit_price:answer.unit_price,currency:answer.currency,lead_time_days:answer.lead_time_days,
      evidence:{item,quantity,unit_price:price,currency:answer.currency,lead_time:lead},
      unknown_reasons:{item:item===null?unknownReason:null,quantity:quantity===null?unknownReason:null,
        unit_price:price===null?unknownReason:null,currency:answer.currency===null?unknownReason:null,lead_time:lead===null?unknownReason:null}
    },
    injection_detected:answer.injection,
    injection_evidence:answer.injection?pieces.filter(s=>/AI assistant:|Ignore previous instructions/i.test(s)):[],
    review_questions:['Which supplier facts need clarification before further review?']
  };
}
module.exports={readAnswers,mockExtraction};
