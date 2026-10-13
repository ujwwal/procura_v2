const fs=require('node:fs');
const path=require('node:path');
const {validApprovalId}=require('../../lib/approval-context');
const {validateExtraction,buildQuotePrompt,SYSTEM_PROMPT}=require('../../lib/quote-extraction');
const model=require('./build-invoice-workflow').nodes.find(n=>n.name==='Gemini model');
const nodes=[
  {name:'Run manually',type:'n8n-nodes-base.manualTrigger',typeVersion:1,parameters:{}},
  {name:'Choose quote',type:'n8n-nodes-base.code',typeVersion:2,parameters:{jsCode:'// Set save_draft=true to store the generated draft. Human verification is still needed.\nreturn [{json:{bid_id:4022,save_draft:false}}];'}},
  {name:'Validate bid ID',type:'n8n-nodes-base.code',typeVersion:2,parameters:{mode:'runOnceForEachItem',jsCode:validApprovalId.toString()+'\nif(!validApprovalId($json.bid_id)||typeof $json.save_draft!=="boolean")throw new Error("Invalid bid ID or save_draft");\nreturn {json:{bid_id:Number($json.bid_id),save_draft:$json.save_draft}};'}},
  {name:'Fetch quote',type:'n8n-nodes-base.httpRequest',typeVersion:4.2,parameters:{method:'GET',url:'=http://127.0.0.1:3000/api/supplier_bids/{{ $json.bid_id }}/quote-context',options:{timeout:20000,response:{response:{responseFormat:'json'}}}}},
  {name:'search_catalog',type:'n8n-nodes-base.httpRequest',typeVersion:4.2,parameters:{
    method:'GET',url:'http://127.0.0.1:3000/api/catalog_items',sendQuery:true,
    queryParameters:{parameters:[{name:'search',value:'={{ $json.catalog_search_query }}'},{name:'limit',value:'100'}]},
    options:{timeout:20000,response:{response:{responseFormat:'json',fullResponse:true}}}
  }},
  {name:'Prepare prompt',type:'n8n-nodes-base.code',typeVersion:2,parameters:{mode:'runOnceForEachItem',jsCode:
    buildQuotePrompt.toString()+'\nif($json.statusCode!==200||!Array.isArray($json.body)||$json.body.length>=100)throw new Error("Catalog lookup failed or needs a narrower search");\nconst context=$("Fetch quote").all()[$itemIndex].json;\ncontext.catalog_candidates=$json.body.filter(c=>c.status==="Active").map(c=>({id:c.id,sku:c.sku,description:c.description,unit:c.unit}));\nreturn {json:{context,prompt:buildQuotePrompt(context),system_prompt:'+JSON.stringify(SYSTEM_PROMPT)+'}};'}},
  {name:'Extract with Gemini',type:'@n8n/n8n-nodes-langchain.chainLlm',typeVersion:1.7,parameters:{
    promptType:'define',text:'={{ $json.prompt }}',hasOutputParser:false,batching:{batchSize:1},
    messages:{messageValues:[{type:'SystemMessagePromptTemplate',message:'={{ $json.system_prompt }}'}]},options:{}
  }},
  {name:'Validate extraction',type:'n8n-nodes-base.code',typeVersion:2,parameters:{mode:'runOnceForEachItem',jsCode:
    validateExtraction.toString()+'\nconst context=$("Prepare prompt").all()[$itemIndex].json.context;\nconst result=validateExtraction($json.text??$json.output??$json,context);\nreturn {json:{...result,save_draft:$("Validate bid ID").all()[$itemIndex].json.save_draft}};'}},
  {name:'Save draft?',type:'n8n-nodes-base.if',typeVersion:2.2,parameters:{conditions:{
    options:{caseSensitive:true,leftValue:'',typeValidation:'strict',version:2},combinator:'and',
    conditions:[{id:'save-flag',leftValue:'={{ $json.save_draft }}',rightValue:true,operator:{type:'boolean',operation:'true',singleValue:true}}]
  },options:{}}},
  {name:'Save draft lines',type:'n8n-nodes-base.httpRequest',typeVersion:4.2,parameters:{
    method:'POST',url:'=http://127.0.0.1:3000/api/supplier_bids/{{ $json.bid_id }}/extracted-lines',
    sendBody:true,specifyBody:'json',jsonBody:'={{ JSON.stringify({source_hash:$json.source_hash,extraction:$json.extraction}) }}',
    options:{timeout:20000,response:{response:{responseFormat:'json'}}}
  }},
  {name:'Preview only',type:'n8n-nodes-base.code',typeVersion:2,parameters:{mode:'runOnceForEachItem',jsCode:'return {json:{...$json,storage_status:"Preview only; no draft row was written."}};'}},
  {...structuredClone(model),name:'Gemini model',notes:'Reuse your saved Gemini credential. No key is exported.'},
  {name:'Read me',type:'n8n-nodes-base.stickyNote',typeVersion:1,parameters:{
    content:'## Supplier quote extractor\nDefault: bid 4022, preview only.\nStart Procura, select your saved Gemini credential, execute and inspect Validate extraction.\nUnknown quote values stay null. Catalog prices never fill quote gaps.\n\nAfter reviewing, set save_draft=true in Choose quote. Only extracted_bid_lines is written; original bid lines stay unchanged.\nSee docs/quote-extractor.md.',height:330,width:370
  }}
];
const workflow={name:'Procura - Supplier Quote Extractor (Gemini)',nodes:nodes.map((n,i)=>({...n,id:'quote-'+i,position:i<9?[i*250,0]:i===9?[2250,-100]:i===10?[2250,150]:i===11?[1500,280]:[-430,-100]})),connections:{},settings:{executionOrder:'v1',executionTimeout:300},active:false,pinData:{}};
for(let i=0;i<8;i++)workflow.connections[nodes[i].name]={main:[[{node:nodes[i+1].name,type:'main',index:0}]]};
workflow.connections['Save draft?']={main:[[{node:'Save draft lines',type:'main',index:0}],[{node:'Preview only',type:'main',index:0}]]};
workflow.connections['Gemini model']={ai_languageModel:[[{node:'Extract with Gemini',type:'ai_languageModel',index:0}]]};
if(require.main===module){const target=path.join(__dirname,'workflows/quote-extractor.json');fs.writeFileSync(target,JSON.stringify(workflow,null,2)+'\n');console.log('Generated '+target);}
module.exports=workflow;
