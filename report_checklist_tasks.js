#!/usr/bin/env node

const admin = require('firebase-admin');
if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

function normalize(s) { return (s||'').toString().trim().toLowerCase().replace(/\s+/g,' '); }
function taskAggressiveKey(d){
  if (d.isCarryForward) return `cf|${d.originalChecklistId || ''}|${d.originalTaskId || ''}`;
  const name = normalize(d.taskName || d.name || d.title || d.description || '');
  const templateName = normalize(d.templateName || (Array.isArray(d.templateNames)?d.templateNames[0]:d.templateNames) || '');
  const section = normalize(d.sectionName || d.section || d.groupName || d.area || d.category || '');
  const photoBool = !!(d.photoRequired || d.requiresPhoto || d.requirePhoto || d.needsPhoto || d.isPhotoRequired);
  return `ag|${name}|${templateName}|${section}|${photoBool ? '1' : '0'}`;
}

async function run(orgId, locId, checklistId) {
  const clRef = db.collection('organizations').doc(orgId)
    .collection('locations').doc(locId)
    .collection('daily_checklists').doc(checklistId);
  const cl = await clRef.get();
  if (!cl.exists) { console.error('Checklist not found'); process.exit(2); }
  const tasksSnap = await clRef.collection('tasks').get();
  console.log(`Checklist ${checklistId} tasks: ${tasksSnap.size}`);

  const byName = new Map();
  const byTpl = new Map();
  const byCF = new Map();
  const sampleKeys = [];

  tasksSnap.forEach(doc => {
    const d = doc.data();
    const name = normalize(d.taskName || d.name || d.title || d.description || '');
    const tpl = d.templateTaskId || '';
    const cfKey = d.isCarryForward ? `${d.originalChecklistId || ''}|${d.originalTaskId || ''}` : '';
    const nKey = `${name}|${normalize(d.templateName || (Array.isArray(d.templateNames)?d.templateNames[0]:d.templateNames) || '')}|${normalize(d.sectionName || d.section || d.groupName || d.area || d.category || '')}|${d.photoRequired?'1':'0'}`;
    byName.set(nKey, (byName.get(nKey)||0)+1);
    byTpl.set(tpl, (byTpl.get(tpl)||0)+1);
    if (cfKey) byCF.set(cfKey, (byCF.get(cfKey)||0)+1);
    sampleKeys.push({id: doc.id, key: taskAggressiveKey(d), name: d.taskName || d.name || ''});
  });

  const dupByName = [...byName.entries()].filter(([k,v])=>v>1).sort((a,b)=>b[1]-a[1]);
  const dupByTpl = [...byTpl.entries()].filter(([k,v])=>k && v>1).sort((a,b)=>b[1]-a[1]);
  const dupByCF  = [...byCF.entries()].filter(([k,v])=>v>1).sort((a,b)=>b[1]-a[1]);

  console.log('\nDuplicates by normalized name/template/section/photo:');
  dupByName.forEach(([k,v])=>console.log(`  x${v}  ${k}`));
  console.log('\nDuplicates by templateTaskId:');
  dupByTpl.forEach(([k,v])=>console.log(`  x${v}  ${k}`));
  console.log('\nDuplicates by carry-forward original pair:');
  dupByCF.forEach(([k,v])=>console.log(`  x${v}  ${k}`));

  console.log('\nSample task keys (first 20):');
  sampleKeys.slice(0,20).forEach(s=>console.log(`  ${s.id} :: ${s.key} :: ${normalize(s.name)}`));
}

const [,, orgId, locId, checklistId] = process.argv;
if (!orgId || !locId || !checklistId) {
  console.log('Usage: report_checklist_tasks.js <orgId> <locationId> <checklistId>');
  process.exit(1);
}
run(orgId, locId, checklistId).then(()=>process.exit(0)).catch(e=>{console.error(e);process.exit(1);});
