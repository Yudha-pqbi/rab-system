const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const crypto=require('node:crypto');
const html=fs.readFileSync(require.resolve('../index.html'),'utf8');
const source=html.slice(html.indexOf('const rabDeletePending='),html.indexOf('\nlet projectListPage='));
const {verify,actions}=require('../engine-admin-auth.js');

function harness(options={}){
 const events=[];
 const row={project_id:'test-rab',client_name:'Test',project_area:'Site',project_title:'Security',canonical_project_code:'1001',updated_at:'2026-10-28T00:00:00Z'};
 const client={rpc:async(name,args)=>{events.push({event:'rpc',name,args});return options.response||{data:{status:'DELETED',source_record_id:row.project_id}};}};
 const lease={client,close:async()=>events.push({event:'close'})};
 const sandbox={Set,console:{error(){}},RAB_CANONICAL_CANDIDATE_V2:false,projectsData:[row],supabaseClient:{supabaseUrl:'https://rljqyaycshwpoteoxgem.supabase.co',supabaseKey:'public-test'},
  EngineAdminAuth:{open:async args=>{events.push({event:'verify',action:args.action});if(options.rejected)throw Error('Owner required');return options.cancel?null:lease;}},
  confirm:()=>{events.push({event:'confirm'});return options.confirm!==false;},alert:message=>events.push({event:'alert',message}),
  renderTable:()=>events.push({event:'render'}),fetchProjects:async()=>events.push({event:'refresh'})};
 vm.runInNewContext(source,sandbox);
 return {sandbox,events,row};
}

test('all inline scripts parse',()=>{
 for(const m of html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g))if(m[1].trim())new vm.Script(m[1]);
});
test('existing submitted-RAB edit and save implementations are unchanged',()=>{
 for(const [start,end,hash] of [
  ['async function handleFormSubmit(','\nasync function fetchProjects','9d020f27d4849c3756e3ab74d9843071eb8fbc30e287ed7a02a1f581ef5e7671'],
  ['function loadProjectToForm(','\nfunction viewProjectDetail','8268e5dddb307669d779ad006a689b7f1ac1b5b14de22fa0594aff85e4551cb0']]){
  const part=html.slice(html.indexOf(start),html.indexOf(end,html.indexOf(start)));
  assert.equal(crypto.createHash('sha256').update(part).digest('hex'),hash);
 }
});
test('cancelled owner verification does not change records or call deletion',async()=>{
 const h=harness({cancel:true});await h.sandbox.deleteProject('test-rab');
 assert.deepEqual(h.events.map(x=>x.event),['verify']);assert.equal(h.sandbox.projectsData.length,1);
});
test('unapproved user never reaches confirmation or deletion',async()=>{
 const h=harness({rejected:true});await h.sandbox.deleteProject('test-rab');
 assert.deepEqual(h.events.map(x=>x.event),['verify','alert']);assert.equal(h.sandbox.projectsData.length,1);
});
test('cancelled deletion confirmation closes owner session without deleting',async()=>{
 const h=harness({confirm:false});await h.sandbox.deleteProject('test-rab');
 assert.deepEqual(h.events.map(x=>x.event),['verify','confirm','close']);assert.equal(h.sandbox.projectsData.length,1);
});
test('approved owner uses one atomic RPC with the displayed document version',async()=>{
 const h=harness();await h.sandbox.deleteProject('test-rab');
 assert.equal(h.events[0].action,'RAB_DELETE');
 const request=h.events.find(x=>x.event==='rpc');assert.equal(request.name,'rab_delete_with_owner_v1');
 assert.equal(request.args.p_project_id,h.row.project_id);assert.equal(request.args.p_expected_updated_at,h.row.updated_at);
 assert.deepEqual(h.events.map(x=>x.event),['verify','confirm','rpc','render','refresh','alert','close']);
 assert.equal(h.sandbox.projectsData.length,0);
});
test('backend rejection keeps the RAB visible and closes the owner session',async()=>{
 const h=harness({response:{error:{message:'RAB telah berubah'}}});await h.sandbox.deleteProject('test-rab');
 assert.equal(h.sandbox.projectsData.length,1);assert.equal(h.events.at(-1).event,'close');
 assert.match(h.events.find(x=>x.event==='alert').message,/telah berubah/);assert.ok(!h.events.some(x=>x.event==='render'));
});
test('unexpected RPC confirmation does not remove local records',async()=>{
 const h=harness({response:{data:{status:'DELETED',source_record_id:'other-rab'}}});await h.sandbox.deleteProject('test-rab');
 assert.equal(h.sandbox.projectsData.length,1);assert.equal(h.events.at(-1).event,'close');
});
test('duplicate clicks share one pending verification',async()=>{
 const h=harness();let release;let count=0;
 h.sandbox.EngineAdminAuth.open=()=>{count++;return new Promise(r=>release=r);};
 const first=h.sandbox.deleteProject('test-rab');await h.sandbox.deleteProject('test-rab');assert.equal(count,1);
 release(null);await first;assert.equal(h.sandbox.projectsData.length,1);
});
test('RAB owner action requires exact backend approval',async()=>{
 assert.ok(actions.has('RAB_DELETE'));
 await assert.rejects(verify({rpc:async()=>({data:{can_delete:true,action:'GL_RESET_ALL'}})},'RAB_DELETE'));
 await assert.rejects(verify({rpc:async()=>({data:{can_delete:false,action:'RAB_DELETE'}})},'RAB_DELETE'));
 await verify({rpc:async()=>({data:{can_delete:true,action:'RAB_DELETE'}})},'RAB_DELETE');
});
