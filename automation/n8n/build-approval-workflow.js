const fs = require('node:fs');
const path = require('node:path');
const {validApprovalId} = require('../../lib/approval-context');
const {validateReview, buildReviewPrompt, SYSTEM_PROMPT} = require('../../lib/approval-review');
const existingModel = require('./build-invoice-workflow').nodes.find(n => n.name === 'Gemini model');
const nodes = [
  {name:'Run manually',type:'n8n-nodes-base.manualTrigger',typeVersion:1,parameters:{}},
  {name:'Choose approval',type:'n8n-nodes-base.code',typeVersion:2,parameters:{jsCode:'// Change this approval ID, then click Execute Workflow.\nreturn [{json:{approval_id:6004}}];'}},
  {name:'Validate approval ID',type:'n8n-nodes-base.code',typeVersion:2,parameters:{mode:'runOnceForEachItem',jsCode:validApprovalId.toString()+'\nif (!validApprovalId($json.approval_id)) throw new Error("Invalid approval ID");\nreturn {json:{approval_id:Number($json.approval_id)}};'}},
  {name:'Fetch approval evidence',type:'n8n-nodes-base.httpRequest',typeVersion:4.2,parameters:{
    method:'GET',url:'=http://127.0.0.1:3000/api/approvals/{{ $json.approval_id }}/review',
    options:{timeout:20000,response:{response:{responseFormat:'json'}}}
  }},
  {name:'Prepare prompt',type:'n8n-nodes-base.code',typeVersion:2,parameters:{mode:'runOnceForEachItem',jsCode:
    buildReviewPrompt.toString()+'\nreturn {json:{context:$json,prompt:buildReviewPrompt($json),system_prompt:'+JSON.stringify(SYSTEM_PROMPT)+'}};'}},
  {name:'Summarize with Gemini',type:'@n8n/n8n-nodes-langchain.chainLlm',typeVersion:1.7,parameters:{
    promptType:'define',text:'={{ $json.prompt }}',hasOutputParser:false,batching:{batchSize:1},
    messages:{messageValues:[{type:'SystemMessagePromptTemplate',message:'={{ $json.system_prompt }}'}]},options:{}
  }},
  {name:'Validate review brief',type:'n8n-nodes-base.code',typeVersion:2,parameters:{mode:'runOnceForEachItem',jsCode:
    validateReview.toString()+'\nconst context=$("Prepare prompt").all()[$itemIndex].json.context;\nconst raw=$json.text ?? $json.output ?? $json;\nreturn {json:validateReview(raw,context)};'}},
  {...structuredClone(existingModel),name:'Gemini model',notes:'Model configuration reused from the invoice workflow. Select your saved Gemini credential; no secret is exported.'},
  {name:'Read me',type:'n8n-nodes-base.stickyNote',typeVersion:1,parameters:{
    content:'## Approval review summarizer\nStart Procura: npm run dev.\nSelect your existing credential in Gemini model.\nChange Choose approval (default: 6004).\nExecute Workflow, then inspect Validate review brief.\n\nReview only: no decisions or record changes.\nFlags cover the whole linked requisition.\nSee docs/approval-review.md.',height:310,width:360
  }}
];
const workflow = {name:'Procura - Approval Review Summarizer (Gemini)',nodes:nodes.map((n,i)=>({...n,id:'approval-'+i,position:i<7?[i*250,0]:i===7?[1250,270]:[-400,-80]})),connections:{},settings:{executionOrder:'v1',executionTimeout:300},active:false,pinData:{}};
for(let i=0;i<6;i++) workflow.connections[nodes[i].name]={main:[[{node:nodes[i+1].name,type:'main',index:0}]]};
workflow.connections['Gemini model']={ai_languageModel:[[{node:'Summarize with Gemini',type:'ai_languageModel',index:0}]]};
if(require.main===module) {
  const target=path.join(__dirname,'workflows/approval-review.json');
  fs.writeFileSync(target,JSON.stringify(workflow,null,2)+'\n');
  console.log('Generated '+target);
}
module.exports=workflow;
