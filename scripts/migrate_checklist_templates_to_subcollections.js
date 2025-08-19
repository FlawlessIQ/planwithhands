/*
Migration script: move `tasks` array on
organizations/{orgId}/checklist_templates/{templateId}
into a subcollection:
organizations/{orgId}/checklist_templates/{templateId}/tasks

Usage:
  # dry-run (no writes)
  GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccount.json node scripts/migrate_checklist_templates_to_subcollections.js --dry-run

  # apply changes
  GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccount.json node scripts/migrate_checklist_templates_to_subcollections.js

Notes:
 - Script uses firebase-admin; install deps in repo root: npm install firebase-admin
 - It is strongly recommended to run with --dry-run first and to have backups.
 - The script will remove the top-level `tasks` field from templates after creating subcollection docs.
*/

const admin = require('firebase-admin');
const crypto = require('crypto');

const DRY_RUN = process.argv.includes('--dry-run');

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error('ERROR: set GOOGLE_APPLICATION_CREDENTIALS to your service account JSON file');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
});

const db = admin.firestore();

async function migrate() {
  console.log(`Starting migration (${DRY_RUN ? 'DRY RUN' : 'APPLY'})`);

  const orgsSnap = await db.collection('organizations').get();
  console.log(`Found ${orgsSnap.size} organizations`);

  for (const orgDoc of orgsSnap.docs) {
    const orgId = orgDoc.id;
    console.log(`\n=== org: ${orgId} ===`);

    const templatesRef = db.collection('organizations').doc(orgId).collection('checklist_templates');
    const templatesSnap = await templatesRef.get();
    console.log(`Found ${templatesSnap.size} templates in org ${orgId}`);

    for (const tmplDoc of templatesSnap.docs) {
      const tmplId = tmplDoc.id;
      const data = tmplDoc.data();
      const tasks = data.tasks;

      if (!tasks || !Array.isArray(tasks) || tasks.length === 0) {
        console.log(` - template ${tmplId}: no array tasks, skipping`);
        continue;
      }

      console.log(` - template ${tmplId}: migrating ${tasks.length} tasks`);

      // create tasks in subcollection
      const tasksCollRef = templatesRef.doc(tmplId).collection('tasks');

      const batch = db.batch();
      let writes = 0;

      for (let i = 0; i < tasks.length; i++) {
        const t = tasks[i] || {};
        // create a stable id from name+index if possible
        const name = (t.name || t.title || t.taskName || t.description || '').toString();
        const seed = `${tmplId}|${i}|${name}`;
        const id = crypto.createHash('sha1').update(seed).digest('hex').substr(0, 20);
        const taskRef = tasksCollRef.doc(id);

        const taskDoc = {
          taskId: id,
          taskName: name || `task-${i}`,
          order: typeof t.order === 'number' ? t.order : i,
          photoRequired: !!t.photoRequired,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          completed: false,
          isCarryForward: false,
          // copy any other commonly useful fields if present
          ...('notes' in t ? { notes: t.notes } : {}),
        };

        if (DRY_RUN) {
          console.log(`    [DRY] would write task ${id} ->`, taskDoc);
        } else {
          batch.set(taskRef, taskDoc, { merge: true });
          writes++;
          // commit every 400 writes to avoid batch size limit
          if (writes >= 400) {
            await batch.commit();
            console.log(`    committed 400 writes`);
            // reset
            writes = 0;
          }
        }
      }

      if (!DRY_RUN) {
        if (writes > 0) {
          await batch.commit();
          console.log(`    committed final ${writes} writes`);
        }

        // remove the top-level tasks array from the template doc
        await templatesRef.doc(tmplId).update({ tasks: admin.firestore.FieldValue.delete() });
        console.log(`    removed top-level tasks array from template ${tmplId}`);
      }
    }
  }

  console.log('\nMigration finished');
}

migrate().catch((err) => {
  console.error('Migration failed', err);
  process.exit(1);
});
