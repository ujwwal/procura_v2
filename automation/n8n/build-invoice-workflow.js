const fs = require('node:fs');
const path = require('node:path');
const {validInvoiceId} = require('../../lib/invoice-context');
const {validateExplanation, buildPrompt, SYSTEM_PROMPT} = require('../../lib/invoice-explanation');
const nodes = [
  {name:'Run manually',type:'n8n-nodes-base.manualTrigger',typeVersion:1,parameters:{}},
  {name:'Choose invoice',type:'n8n-nodes-base.code',typeVersion:2,parameters:{jsCode:'// Change this invoice ID, then click Execute Workflow.\nreturn [{ json: { invoice_id: 5010 } }];'}},
  {name:'Validate invoice ID',type:'n8n-nodes-base.code',typeVersion:2,parameters:{mode:'runOnceForEachItem',jsCode:validInvoiceId.toString()+'\nif (!validInvoiceId($json.invoice_id)) throw new Error("Invalid invoice ID");\nreturn {json:{invoice_id:Number($json.invoice_id)}};'}},
  {name:'Fetch invoice evidence',type:'n8n-nodes-base.httpRequest',typeVersion:4.2,parameters:{
    method:'GET',url:'=http://127.0.0.1:3000/api/invoices/{{ $json.invoice_id }}/flags',
    options:{timeout:20000,response:{response:{responseFormat:'json'}}}
  }},
  {name:'Prepare prompt',type:'n8n-nodes-base.code',typeVersion:2,parameters:{mode:'runOnceForEachItem',jsCode:
    buildPrompt.toString()+'\nreturn {json:{context:$json,prompt:buildPrompt($json),system_prompt:'+JSON.stringify(SYSTEM_PROMPT)+'}};'}},
  {name:'Explain with Gemini',type:'@n8n/n8n-nodes-langchain.chainLlm',typeVersion:1.7,parameters:{
    promptType:'define',text:'={{ $json.prompt }}',hasOutputParser:false,
    messages:{messageValues:[{type:'SystemMessagePromptTemplate',message:'={{ $json.system_prompt }}'}]},
    options:{}
  }},
  {name:'Validate explanation',type:'n8n-nodes-base.code',typeVersion:2,parameters:{mode:'runOnceForEachItem',jsCode:
    validateExplanation.toString()+'\nconst context=$("Prepare prompt").all()[$itemIndex].json.context;\nconst raw=$json.text ?? $json.output ?? $json;\nreturn {json:validateExplanation(raw,context)};'}},
  {name:'Gemini model',type:'@n8n/n8n-nodes-langchain.lmChatGoogleGemini',typeVersion:1,parameters:{
    modelName:'models/gemini-3.5-flash-lite',options:{temperature:0,maxOutputTokens:4096}
  },notes:'Model reused from the saved requisition workflow. Select your existing Google Gemini API credential. No API key is exported.',notesInFlow:true},
  {name:'Read me',type:'n8n-nodes-base.stickyNote',typeVersion:1,parameters:{
    content:'## Invoice exception explainer\nStart Procura: npm run dev.\nSelect your existing credential in Gemini model.\nEdit the ID in Choose invoice.\nClick Execute Workflow, then open Validate explanation.\n\nThis workflow prepares review suggestions. No business records are written.\nNo public webhook or publishing is needed.\nSee docs/invoice-explainer.md.',height:300,width:360
  }}
];
const workflow = {name:'Procura - Invoice Exception Explainer (Gemini)',nodes:nodes.map((n,i)=>({...n,id:'invoice-'+i,position:i<7?[i*250,0]:i===7?[1250,270]:[-400,-80]})),connections:{},settings:{executionOrder:'v1',executionTimeout:300},active:false,pinData:{}};
for(let i=0;i<6;i++) workflow.connections[nodes[i].name]={main:[[{node:nodes[i+1].name,type:'main',index:0}]]};
workflow.connections['Gemini model']={ai_languageModel:[[{node:'Explain with Gemini',type:'ai_languageModel',index:0}]]};
if(require.main===module) {
  const target=path.join(__dirname,'workflows/invoice-explainer.json');
  fs.writeFileSync(target,JSON.stringify(workflow,null,2)+'\n');
  console.log('Generated '+target);
}
module.exports=workflow;
