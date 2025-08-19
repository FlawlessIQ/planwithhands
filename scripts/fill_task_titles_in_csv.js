#!/usr/bin/env node
/**
 * Fill the newTitle column in an exported template-tasks CSV.
 *
 * Supports two sources:
 *  - --fromTxt=path.txt     One title per line (applied in the current CSV row order)
 *  - --fromCsv=map.csv      CSV with header: order,newTitle (matched by numeric order)
 *
 * Usage examples:
 *   node scripts/fill_task_titles_in_csv.js --csv tmp/exports/RBP1Q...-tasks.csv --fromTxt my_titles.txt --preview
 *   node scripts/fill_task_titles_in_csv.js --csv tmp/exports/RBP1Q...-tasks.csv --fromCsv order_to_title.csv --out tmp/exports/RBP1Q...-tasks.filled.csv
 *
 * Notes:
 *  - Makes a .bak backup if writing in place.
 *  - Only fills rows where newTitle is empty. Use --overwrite to replace existing newTitle values.
 *  - By default, only fills rows whose currentTitle matches /^Task\s+\d+$/i. Use --all to fill any row.
 */

const fs = require('fs');
const path = require('path');

function parseArgs(argvArr) {
  const out = {};
  for (let i = 0; i < argvArr.length; i++) {
    const a = argvArr[i];
    if (!a.startsWith('--')) continue;
    let [k, v] = a.slice(2).split('=');
    if (v === undefined && i + 1 < argvArr.length && !argvArr[i + 1].startsWith('--')) v = argvArr[++i];
    if (v === undefined) v = 'true';
    out[k] = v;
  }
  return out;
}

const argv = parseArgs(process.argv.slice(2));
const CSV_PATH = argv.csv;
const FROM_TXT = argv.fromTxt || null;
const FROM_CSV = argv.fromCsv || null;
const OUT_PATH = argv.out || null;
const PREVIEW = /^true|1|yes$/i.test(String(argv.preview || 'false'));
const OVERWRITE = /^true|1|yes$/i.test(String(argv.overwrite || 'false'));
const FILL_ALL = /^true|1|yes$/i.test(String(argv.all || 'false'));

if (!CSV_PATH || (!FROM_TXT && !FROM_CSV)) {
  console.error('Usage: node scripts/fill_task_titles_in_csv.js --csv path.csv [--fromTxt titles.txt | --fromCsv order_title.csv] [--out out.csv] [--preview] [--overwrite] [--all]');
  process.exit(1);
}

function escCsv(value) {
  return '"' + String(value ?? '').replace(/"/g, '""') + '"';
}

function parseCsvLine(line) {
  // Basic CSV parser for a single line, handling quotes and commas.
  const out = [];
  let i = 0, cur = '', inQuotes = false;
  while (i < line.length) {
    const ch = line[i];
    if (inQuotes) {
      if (ch === '"') {
        if (i + 1 < line.length && line[i + 1] === '"') { // escaped quote
          cur += '"';
          i += 2;
          continue;
        } else {
          inQuotes = false; i++; continue;
        }
      }
      cur += ch; i++; continue;
    } else {
      if (ch === '"') { inQuotes = true; i++; continue; }
      if (ch === ',') { out.push(cur); cur = ''; i++; continue; }
      cur += ch; i++; continue;
    }
  }
  out.push(cur);
  return out;
}

function parseCsv(content) {
  const lines = content.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n');
  // Drop trailing empty line
  if (lines.length && lines[lines.length - 1].trim() === '') lines.pop();
  const rows = lines.map(parseCsvLine);
  return rows;
}

function readTextLines(p) {
  return fs.readFileSync(p, 'utf8').replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n').filter(x => x.length > 0);
}

function isDefaultTitle(title) {
  return /^Task\s+\d+$/i.test(String(title || ''));
}

// Load input CSV
const csvContent = fs.readFileSync(CSV_PATH, 'utf8');
const rows = parseCsv(csvContent);
if (!rows.length) {
  console.error('Empty CSV:', CSV_PATH);
  process.exit(1);
}

const header = rows[0];
const required = ['orgId','templateId','taskId','order','currentTitle','newTitle'];
for (const h of required) {
  if (!header.includes(h)) {
    console.error('Missing header column', h, 'in', CSV_PATH);
    process.exit(1);
  }
}
const idx = Object.fromEntries(header.map((h, i) => [h, i]));

// Build source of titles
let titlesFromTxt = null;
let mapFromCsv = null; // order -> newTitle

if (FROM_TXT) {
  titlesFromTxt = readTextLines(FROM_TXT).map(s => s.trim());
}

if (FROM_CSV) {
  const mapContent = fs.readFileSync(FROM_CSV, 'utf8');
  const mapRows = parseCsv(mapContent);
  if (!mapRows.length) {
    console.error('Empty mapping CSV:', FROM_CSV);
    process.exit(1);
  }
  const mh = mapRows[0];
  const orderIdx = mh.indexOf('order');
  const newTitleIdx = mh.indexOf('newTitle');
  if (orderIdx === -1 || newTitleIdx === -1) {
    console.error('Mapping CSV must have header: order,newTitle');
    process.exit(1);
  }
  mapFromCsv = new Map();
  for (let r = 1; r < mapRows.length; r++) {
    const rr = mapRows[r];
    if (!rr || rr.length <= Math.max(orderIdx, newTitleIdx)) continue;
    const oStr = rr[orderIdx].trim();
    const tStr = (rr[newTitleIdx] || '').trim();
    if (oStr === '' || tStr === '') continue;
    const on = Number(oStr);
    if (!Number.isNaN(on)) mapFromCsv.set(on, tStr);
  }
}

// Apply fills
let filled = 0;
let considered = 0;
const previewChanges = [];

// Collect data rows and keep their original order; rows are exported ordered by order asc.
const dataRows = rows.slice(1);
for (let i = 0; i < dataRows.length; i++) {
  const row = dataRows[i];
  if (!row || row.length <= idx.newTitle) continue;
  const cur = row[idx.currentTitle] || '';
  const existingNew = row[idx.newTitle] || '';
  const orderStr = row[idx.order] || '';
  const orderNum = orderStr === '' ? NaN : Number(orderStr);
  const canFill = FILL_ALL || isDefaultTitle(cur);
  if (!canFill) continue;
  considered++;
  if (existingNew && !OVERWRITE) continue;

  let candidate = '';
  if (mapFromCsv && !Number.isNaN(orderNum)) {
    candidate = mapFromCsv.get(orderNum) || '';
  } else if (titlesFromTxt) {
    // Use sequential order based on row index in the CSV (not order number), skipping blanks
    if (i < titlesFromTxt.length) candidate = titlesFromTxt[i] || '';
  }

  if (candidate && candidate.trim()) {
    const trimmed = candidate.trim();
    if (!PREVIEW) row[idx.newTitle] = trimmed;
    filled++;
    if (previewChanges.length < 10) previewChanges.push({ order: orderStr, currentTitle: cur, newTitle: trimmed });
  }
}

if (PREVIEW) {
  console.log(JSON.stringify({ csv: CSV_PATH, considered, filledIfApplied: filled, sample: previewChanges }, null, 2));
  process.exit(0);
}

// Write output
const outRows = [header, ...dataRows];
const outContent = outRows.map(cols => cols.map(escCsv).join(',')).join('\n') + '\n';

if (OUT_PATH) {
  const outAbs = path.resolve(OUT_PATH);
  fs.mkdirSync(path.dirname(outAbs), { recursive: true });
  fs.writeFileSync(outAbs, outContent, 'utf8');
  console.log('Wrote filled CSV to', outAbs, 'filled:', filled);
} else {
  // Write in-place with .bak backup
  const abs = path.resolve(CSV_PATH);
  const bak = abs + '.' + new Date().toISOString().replace(/[:.]/g, '-') + '.bak';
  fs.copyFileSync(abs, bak);
  fs.writeFileSync(abs, outContent, 'utf8');
  console.log('Updated CSV in place:', abs, 'backup:', bak, 'filled:', filled);
}
