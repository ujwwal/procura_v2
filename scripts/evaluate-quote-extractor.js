const fs=require('node:fs');
const path=require('node:path');
const {spawn}=require('node:child_process');
const assert=require('node:assert/strict');
const express=require('express');
const {app,pool}=require('../server');
const {validateExtraction}=require('../lib/quote-extraction');
const {readAnswers,mockExtraction}=require('../tests/quote-fixtures');
const {parseExecution,nodeItems}=require('./n8n-execution');
const template=require('../automation/n8n/build-quote-workflow');

function cli(args,folder){
  return new Promise((resolve,reject)=>{
    const child=spawn('powershell.exe',['-NoProfile','-ExecutionPolicy','Bypass','-File',path.resolve('automation/n8n/start.ps1'),...args],{
      cwd:path.resolve('.'),windowsHide:true,env:{...process.env,N8N_DIAGNOSTICS_ENABLED:'false',N8N_PERSONALIZATION_ENABLED:'false',N8N_RUNNERS_BROKER_PORT:'5691'}
    });
    let output='';child.stdout.on('data',d=>output+=d);child.stderr.on('data',d=>output+=d);
    const timer=setTimeout(()=>{child.kill();reject(new Error('n8n timed out; inspect private logs'));},300000);
    child.on('error',e=>{clearTimeout(timer);reject(e);});
    child.on('close',code=>{
      clearTimeout(timer);
      const label=args[0]==='execute'?'execute':args[1].includes('demo-workflow')?'import-demo':'import-evaluation';
      fs.writeFileSync(path.join(folder,label+'.log'),output);
      if(code!==0&&args[0]!=='execute')reject(new Error('n8n import failed; inspect private logs'));else resolve(output);
    });
  });
}
function checkExtraction(result,answer){
  const l=result.lines[0];
  assert.equal(result.bid_id,answer.bid_id);assert.equal(l.sourcing_item_id,answer.sourcing_item_id);
  assert.equal(l.catalog_item_id,answer.catalog_item_id);
  for(const field of ['quantity','unit_price']){
    if(answer[field]===null)assert.equal(l[field],null);else assert.equal(Number(l[field]),Number(answer[field]));
  }
  assert.equal(l.currency,answer.currency);assert.equal(l.lead_time_days,answer.lead_time_days);
  assert.equal(result.injection_detected,answer.injection);assert(result.draft_only);
}
async function fingerprints(){
  const results={};
  for(const [table,filter] of [
    ['supplier_bids','id BETWEEN 4000 AND 4024'],['bid_lines','bid_id BETWEEN 4000 AND 4024'],
    ['sourcing_events','id BETWEEN 4000 AND 4006'],['sourcing_items','event_id BETWEEN 4000 AND 4006'],
    ['extracted_bid_lines','bid_id BETWEEN 4000 AND 4024']
  ]){
    const r=await pool.query('SELECT count(*)::int AS count,md5(COALESCE(jsonb_agg(to_jsonb(t) ORDER BY id)::text,\'[]\')) AS fingerprint FROM public.'+table+' t WHERE '+filter);
    results[table]=r.rows[0];
  }
  return results;
}
async function runN8n(answers,packets,base,report,folder,mock){
  const {DatabaseSync}=require('node:sqlite');
  const db=new DatabaseSync(path.resolve('automation/n8n/.data/.n8n/database.sqlite'),{readOnly:true});
  let configured;
  for(const name of ['Procura - Invoice Exception Explainer (Gemini)','Procura - Requisition Assistant (Gemini)']){
    const saved=db.prepare('SELECT nodes FROM workflow_entity WHERE name=?').get(name);
    configured=saved&&JSON.parse(saved.nodes).find(n=>n.type==='@n8n/n8n-nodes-langchain.lmChatGoogleGemini'&&n.credentials?.googlePalmApi);
    if(configured)break;
  }
  const previous=db.prepare('SELECT id FROM workflow_entity WHERE name=?').get(template.name);db.close();
  if(!configured)throw new Error('No saved Gemini configuration; select its credential in n8n.');
  const w=structuredClone(template),model=w.nodes.find(n=>n.name==='Gemini model');
  model.parameters.modelName=configured.parameters.modelName;model.credentials=configured.credentials;
  report.model=mock?null:configured.parameters.modelName;
  if(!previous){
    const demo=structuredClone(w);demo.id='QuoteDemo'+Date.now();
    const file=path.join(folder,'demo-workflow.json');fs.writeFileSync(file,JSON.stringify(demo));
    await cli(['import:workflow','--input='+file],folder);report.imported_workflow_id=demo.id;
  }else report.imported_workflow_id=previous.id;
  w.id='QuoteEval'+Date.now();w.name='Procura - Quote '+(mock?'Wiring ':'Evaluation ')+report.run_at;
  const inputs=answers.map(a=>({bid_id:a.bid_id,save_draft:false}));
  if(mock)inputs.push({bid_id:4000,save_draft:true});
  w.nodes.find(n=>n.name==='Choose quote').parameters.jsCode='return '+JSON.stringify(inputs)+'.map(json=>({json}));';
  w.nodes.find(n=>n.name==='Fetch quote').parameters.url='='+base+'/api/supplier_bids/{{ $json.bid_id }}/quote-context';
  w.nodes.find(n=>n.name==='search_catalog').parameters.url=base+'/api/catalog_items';
  // Actual model evaluations always preview. The mock save branch uses a separate fake HTTP service.
  w.nodes.find(n=>n.name==='Save draft lines').parameters.url='='+base+'/api/supplier_bids/{{ $json.bid_id }}/extracted-lines';
  let mockServer,simulatedSaves=0;
  try{
    if(mock){
      const responses=Object.fromEntries(answers.map((a,i)=>[a.bid_id,mockExtraction(packets[i],a)]));
      const fake=express();fake.use(express.json());
      fake.post('/api/supplier_bids/:id/extracted-lines',(req,res)=>{
        try{
          assert.equal(Number(req.params.id),4000);assert.equal(req.body.source_hash,packets[0].source_hash);
          const result=validateExtraction(req.body.extraction,packets[0]);checkExtraction(result,answers[0]);
          simulatedSaves++;res.status(201).json({draft_only:true,simulated_storage:true,review:result});
        }catch{res.status(400).json({error:'Simulated save validation failed'});}
      });
      mockServer=fake.listen(0,'127.0.0.1');await new Promise(r=>mockServer.once('listening',r));
      w.nodes.find(n=>n.name==='Save draft lines').parameters.url='=http://127.0.0.1:'+mockServer.address().port+'/api/supplier_bids/{{ $json.bid_id }}/extracted-lines';
      w.nodes=w.nodes.filter(n=>n.name!=='Gemini model');delete w.connections['Gemini model'];
      const chain=w.nodes.find(n=>n.name==='Extract with Gemini');chain.type='n8n-nodes-base.code';chain.typeVersion=2;
      chain.parameters={mode:'runOnceForEachItem',jsCode:'const responses='+JSON.stringify(responses)+'; return {json:{text:JSON.stringify(responses[$json.context.id])}};'};
    }
    const file=path.join(folder,'evaluation-workflow.json');fs.writeFileSync(file,JSON.stringify(w));
    await cli(['import:workflow','--input='+file],folder);
    console.log(mock?'Running n8n simulated quote extraction and save wiring...':'Running actual Gemini quote extraction...');
    const execution=parseExecution(await cli(['execute','--id='+w.id,'--rawOutput'],folder));
    fs.writeFileSync(path.join(folder,'execution.json'),JSON.stringify(execution,null,2));
    const data=execution.data.resultData,run=data.runData??{},error=data.error;
    const generated=nodeItems(run,'Extract with Gemini'),outputs=nodeItems(run,'Validate extraction'),preview=nodeItems(run,'Preview only');
    const prepared=nodeItems(run,'Prepare prompt'),results=mock?report.wiring:report.ai;
    for(let i=0;i<answers.length;i++){
      let result=null,failure=null;
      if(!generated[i])failure='No model response; extraction was not evaluated.';
      else try{
        result=validateExtraction(generated[i].text??generated[i].output??generated[i],prepared[i]?.context??packets[i]);
        checkExtraction(result,answers[i]);assert.deepEqual(outputs[i],{...result,save_draft:false});
        assert.equal(preview[i].storage_status,'Preview only; no draft row was written.');
      }catch(e){failure=e.message;}
      results.push({bid_id:answers[i].bid_id,passed:!failure,status:generated[i]?'executed':error?'blocked_provider_or_workflow_error':'not_executed',
        error:failure,result,expected_fix:answers[i].correct_fix,contains_injection:answers[i].injection});
    }
    if(mock){
      const saves=nodeItems(run,'Save draft lines');
      report.simulated_save={passed:simulatedSaves===1&&saves.length===1&&saves[0].simulated_storage===true,count:simulatedSaves,
        scope:'Fake HTTP storage; no Neon insert. Real storage transaction behavior is covered by local tests.'};
    }
    report.execution={started_at:execution.startedAt,stopped_at:execution.stoppedAt,
      latency_ms:execution.startedAt&&execution.stoppedAt?new Date(execution.stoppedAt)-new Date(execution.startedAt):null,
      error:error?.message??null,provider_error:error?.description??null};
    const calls=run['Gemini model']??[];
    report.model_calls=calls.map(c=>({latency_ms:c.executionTime??null,started_at:c.startTime?new Date(c.startTime).toISOString():null}));
    const usage=calls.map(c=>{const j=c.data?.ai_languageModel?.[0]?.[0]?.json;return j?.tokenUsage??j?.response_metadata?.tokenUsage??j?.usage_metadata??null;}).filter(Boolean);
    report.token_usage={available:usage.length>0,usage:usage.length?usage:null,reason:mock?'No model called.':usage.length?'Reported by n8n/Gemini.':'Usage not returned; no estimate made.'};
    if(error||results.some(r=>!r.passed)||(mock&&!report.simulated_save.passed))throw new Error('Quote workflow evaluation did not pass; inspect its report.');
    console.log(mock?'All 25 simulated previews and the simulated save branch passed.':'All 25 actual extractions passed deterministic fixture checks; human semantic review remains pending.');
  }finally{if(mockServer)await new Promise(r=>mockServer.close(r));}
}
async function main(){
  const args=new Set(process.argv.slice(2)),mock=args.has('--mock'),llm=args.has('--llm')||mock,persist=args.has('--persist-fixture');
  if(persist&&llm)throw new Error('Run --persist-fixture independently of model or simulated workflow evaluation.');
  const answers=readAnswers(fs.readFileSync(path.resolve('db/quote-extraction-qtest-answers.csv'),'utf8'));
  assert.deepEqual(answers.map(a=>a.bid_id),Array.from({length:25},(_,i)=>4000+i));
  assert.equal(answers.filter(a=>a.injection).length,5);
  const now=new Date().toISOString(),folder=path.resolve('automation/n8n/.data/quote-evaluations',now.replace(/[:.]/g,'-'));
  fs.mkdirSync(folder,{recursive:true});
  const report={run_at:now,mode:persist?'API and manually validated fixture storage; no AI quality claim':mock?'API and SIMULATED n8n wiring; no AI quality claim':llm?'API and actual Gemini':'API only',
    model:null,api:[],invalid_ids:[],write_rejections:[],ai:[],wiring:[],token_usage:{available:false,usage:null},
    semantic_review:{status:'pending_human_review',checks:['Item and sourcing matches are justified','Quoted spans refer to the right fields','Ambiguities and missing values are preserved','Instruction attempts do not control behavior','Clarification questions address the missing information']},
    live_persistence:{status:'not_executed',reason:'Evaluation previews do not save draft rows. Positive storage and retry behavior are tested with a local database test double.'}};
  let server,before;
  try{
    before=await fingerprints();report.before=before;
    server=app.listen(0,'127.0.0.1');await new Promise(r=>server.once('listening',r));
    const base='http://127.0.0.1:'+server.address().port,packets=[];
    // Explicit mapping for all fixtures, independently transcribed from the construction.
    const fixtureSuppliers={4000:1,4001:2,4002:3,4003:10,4004:1,4005:2,4006:3,4007:10,4008:1,4009:2,4010:3,4011:10,4012:1,4013:2,4014:3,4015:1,4016:2,4017:10,4018:1,4019:3,4020:10,4021:1,4022:2,4023:3,4024:10};
    for(const a of answers){
      const started=performance.now();let packet=null,failure=null,mockResult=null;
      try{
        const res=await fetch(base+'/api/supplier_bids/'+a.bid_id+'/quote-context',{signal:AbortSignal.timeout(25000)});assert.equal(res.status,200);
        packet=await res.json();assert.equal(packet.id,a.bid_id);assert.equal(packet.bid_no,'PROCURA-QTEST-BID-'+a.bid_id);
        assert.equal(packet.supplier_id,fixtureSuppliers[a.bid_id]);assert.equal(packet.supplier.id,packet.supplier_id);
        const event=a.bid_id<4004?4000:a.bid_id<4008?4001:a.bid_id<4012?4002:a.bid_id<4015?4003:a.bid_id<4018?4004:a.bid_id<4021?4005:4006;
        assert.equal(packet.event_id,event);assert.equal(packet.sourcing_event.id,event);assert.equal(packet.sourcing_items.length,1);assert.equal(packet.sourcing_items[0].id,event);
        assert.equal(packet.sourcing_event.currency,'INR');assert.equal(Number(packet.sourcing_items[0].quantity),5);
        assert.equal(packet.status,'Draft');assert.equal(typeof packet.raw_quote_text,'string');assert(packet.raw_quote_text.trim());
        assert(/^[a-f0-9]{64}$/.test(packet.source_hash));
        const cat=await fetch(base+'/api/catalog_items?search='+encodeURIComponent(packet.catalog_search_query)+'&limit=100');assert.equal(cat.status,200);
        const rows=await cat.json();assert(Array.isArray(rows));assert(rows.length<100);
        packet.catalog_candidates=rows.filter(c=>c.status==='Active').map(c=>({id:c.id,sku:c.sku,description:c.description,unit:c.unit}));
        assert(packet.catalog_candidates.some(c=>c.id===1&&c.sku==='MON-24'));
        if(mock){mockResult=validateExtraction(mockExtraction(packet,a),packet);checkExtraction(mockResult,a);}
      }catch(e){failure=e.message;}
      packets.push(packet);report.api.push({bid_id:a.bid_id,passed:!failure,error:failure,latency_ms:Math.round(performance.now()-started)});
    }
    for(const [id,status] of [['abc',400],['0',400],['2147483648',400],['2147483647',404]]){
      let error=null;try{const res=await fetch(base+'/api/supplier_bids/'+id+'/quote-context');assert.equal(res.status,status);assert((await res.json()).error);}catch(e){error=e.message;}
      report.invalid_ids.push({id,expected_status:status,passed:!error,error});
    }
    // Exercise live rejection paths without any INSERT/UPDATE/DELETE.
    for(const [label,body,status] of [
      ['missing_payload',{},400],
      ['stale_quote',{source_hash:'0'.repeat(64),extraction:{}},409],
      ['invalid_extraction',{source_hash:packets[0]?.source_hash,extraction:{bid_id:999}},400]
    ]){
      let error=null;try{const res=await fetch(base+'/api/supplier_bids/4000/extracted-lines',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});assert.equal(res.status,status);assert((await res.json()).error);}catch(e){error=e.message;}
      report.write_rejections.push({label,expected_status:status,passed:!error,error});
    }
    if([...report.api,...report.invalid_ids,...report.write_rejections].some(r=>!r.passed))throw new Error('Quote API or simulated-output preparation failed; model run skipped.');
    console.log('API: 25 fixture contexts, 4 invalid/missing IDs and 3 save-rejection checks passed.');
    if(persist){
      const extraction=mockExtraction(packets[0],answers[0]);
      const reviewed=validateExtraction(extraction,packets[0]);checkExtraction(reviewed,answers[0]);
      const payload={source_hash:packets[0].source_hash,extraction:reviewed.extraction};
      const post=()=>fetch(base+'/api/supplier_bids/4000/extracted-lines',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(payload)});
      const first=await post();assert([200,201].includes(first.status));
      const saved=await first.json();assert(saved.draft_only);assert.equal(saved.rows.length,1);
      const retry=await post();assert.equal(retry.status,200);const repeated=await retry.json();
      assert.equal(repeated.created,false);assert.equal(repeated.rows[0].id,saved.rows[0].id);
      assert.equal(Number(saved.rows[0].quantity),5);assert.equal(Number(saved.rows[0].unit_price),9800);
      assert.equal(saved.rows[0].currency,'INR');assert.equal(saved.rows[0].lead_time_days,7);
      const conflict=structuredClone(payload);conflict.extraction.line.currency=null;conflict.extraction.line.evidence.currency=null;
      conflict.extraction.line.unknown_reasons.currency='Currency needs clarification.';
      const rejected=await fetch(base+'/api/supplier_bids/4000/extracted-lines',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(conflict)});
      assert.equal(rejected.status,409);
      report.manual_persistence={passed:true,bid_id:4000,draft_id:saved.rows[0].id,created:saved.created,
        idempotent_retry_passed:true,conflicting_draft_rejected:true,source:'Manually constructed fixture extraction checked against source text; NOT AI output.'};
      report.live_persistence={status:'passed',scope:'One synthetic draft insert/reuse, retry and conflict checks; no authoritative records changed.'};
      console.log('Live draft storage: validated manual fixture saved/reused; retry and conflict checks passed. No AI accuracy claim.');
    }
    if(llm)await runN8n(answers,packets,base,report,folder,mock);
    else report.ai_status='not_executed; use --llm for Gemini or --mock for simulated wiring';
  }catch(e){report.error=e.message;console.error(e.message);process.exitCode=1;}
  finally{
    if(before)try{
      report.after=await fingerprints();
      if(persist&&report.manual_persistence?.passed){
        for(const table of ['supplier_bids','bid_lines','sourcing_events','sourcing_items'])assert.deepEqual(report.after[table],before[table]);
        assert.equal(report.after.extracted_bid_lines.count,before.extracted_bid_lines.count+(report.manual_persistence.created?1:0));
        report.authoritative_fixtures_unchanged=true;report.draft_rows_added=report.manual_persistence.created?1:0;
      }else{assert.deepEqual(report.after,before);report.fixtures_unchanged=true;}
    }catch(e){report.fixtures_unchanged=false;report.integrity_error=e.message;process.exitCode=1;}
    fs.writeFileSync(path.join(folder,'report.json'),JSON.stringify(report,null,2));console.log('Report: '+path.join(folder,'report.json'));
    if(server)await new Promise(r=>server.close(r));await pool.end();
  }
}
if(require.main===module)main();
module.exports={checkExtraction};
