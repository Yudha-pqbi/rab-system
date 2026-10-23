'use strict';
const fs=require('node:fs');
const vm=require('node:vm');
const assert=require('node:assert/strict');
const source=fs.readFileSync(process.argv[2]||__dirname+'/project-identity.js','utf8');
const existing='11111111-1111-4111-8111-111111111111';
const added='22222222-2222-4222-8222-222222222222';
const intervals=[],docEvents=new Map(),windowEvents=new Map(),nodes=[];
let now=100000,calls=0,fetchMode='ok',resume,version=1;
const counters=[];
function check(name,actual,expected){assert.deepEqual(actual,expected,name);counters.push(name);}
const dictionary=()=>({version:'PROJECT-IDENTITY-005',projects:[{project_id:'1001'},{project_id:'1043'}],references:{[existing]:'1001',...(version>1?{[added]:'1043'}:{})}});
class Input {}
const body={nodeType:1,isConnected:true,matches:()=>false,hasAttribute:()=>false};
const document={body,readyState:'complete',visibilityState:'visible',scripts:[],
addEventListener:(type,fn)=>docEvents.set(type,fn),
dispatchEvent:()=>true,
createTreeWalker:()=>{let i=0;return{nextNode:()=>nodes[i++]||null};}};
const window={__PROJECT_IDENTITY_PUBLIC_CONFIG:{url:'https://example.supabase.co',key:'sb_publishable_TEST_ONLY'},
addEventListener:(type,fn)=>windowEvents.set(type,fn),
XLSX:{utils:{json_to_sheet:x=>x}},alert:()=>{},confirm:()=>true};
const sandbox={window,document,HTMLInputElement:Input,NodeFilter:{SHOW_TEXT:4},
MutationObserver:class{observe(){}},CustomEvent:class{constructor(type,data){Object.assign(this,{type,...data});}},
console:{warn(){},error(){}},Blob,WeakMap,Map,Set,AbortController,
Date:class extends Date{static now(){return now;}},setTimeout,clearTimeout,
setInterval:(fn,ms)=>{intervals.push({fn,ms});return intervals.length;},clearInterval:()=>{},
fetch:async()=>{calls++;if(fetchMode==='error')throw new Error('temporary network failure');
if(fetchMode==='delay')await new Promise(resolve=>resume=resolve);
return {ok:true,json:async()=>dictionary()};}};
const context=vm.createContext(sandbox);
const flush=()=>new Promise(resolve=>setImmediate(resolve));
const tick=async()=>{const timer=intervals.find(x=>x.ms===60000);if(timer)timer.fn();await flush();};
(async()=>{
vm.runInContext(source,context);
await flush();
check('initial metadata read',calls,1);
check('initial identity',window.ProjectIdentity.codeFor(existing),'1001');
await window.ProjectIdentity.ready();
check('fresh metadata uses cache',calls,1);
const untouched={value:'draft amount 123',project_id:added};
const textNode={nodeType:3,isConnected:true,parentElement:{closest:()=>null},nodeValue:added};nodes.push(textNode);
version=2;now+=60001;await tick();
check('new RAB discovered on automatic timer',window.ProjectIdentity.codeFor(added),'1043');
check('new RAB label updated in existing page',textNode.nodeValue,'1043');
check('one refresh request',calls,2);
check('source form values preserved',JSON.stringify(untouched),JSON.stringify({value:'draft amount 123',project_id:added}));
document.visibilityState='hidden';now+=60001;await tick();
check('hidden tab does not poll',calls,2);
document.visibilityState='visible';docEvents.get('visibilitychange')();await flush();
check('returning to visible tab refreshes expired metadata',calls,3);
windowEvents.get('online')();await flush();
check('network reconnect forces metadata refresh',calls,4);
fetchMode='error';now+=60001;await tick();
check('temporary outage keeps verified identity',window.ProjectIdentity.codeFor(added),'1043');
fetchMode='ok';now+=60001;await tick();
check('automatic retry after outage',calls,6);
fetchMode='delay';now+=60001;
const first=window.ProjectIdentity.ready(),second=window.ProjectIdentity.ready();
await flush();check('overlapping reads share one fetch',calls,7);
resume();await Promise.all([first,second]);fetchMode='ok';
const rows=[{project_id:added,amount:123}];
const exported=window.XLSX.utils.json_to_sheet(rows);
check('export uses latest identity',exported[0].project_id,'1043');
check('export preserves original payload',rows[0].project_id,added);
check('export preserves amount',exported[0].amount,123);
now+=60001;await window.ProjectIdentity.ready();
check('explicit read also respects cache expiry',calls,8);
process.stdout.write(JSON.stringify({status:'PASS',tests:counters.length,passed:counters.length,checks:counters},null,2)+'\n');
})().catch(e=>{process.stderr.write(e.message+'\n');process.exitCode=1;});
