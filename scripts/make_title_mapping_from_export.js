#!/usr/bin/env node
/**
 * Create a simple mapping CSV (order,newTitle) from an exported template-tasks CSV.
 *
 * Usage:
 *   node scripts/make_title_mapping_from_export.js \
 *     --csv tmp/exports/<templateId>-tasks.csv \
 *     --out tmp/exports/<templateId>-order_to_title.csv [--all]
 *
 * By default, only includes rows where currentTitle looks like "Task N".
 * Pass --all to include all rows.
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

function parseCsvLine(line) {
  const out = [];
  let i = 0, cur = '', inQuotes = false;
  while (i < line.length) {
    const ch = line[i];
    if (inQuotes) {
      if (ch === '"') {
        if (i + 1 < line.length && line[i + 1] === '"') { cur += '"'; i += 2; continue; }
        inQuotes = false; i++; continue;
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
  if (lines.length && lines[lines.length - 1].trim() === '') lines.pop();
  return lines.map(parseCsvLine);
}

function isDefaultTitle(title) { return /^Task\s+\d+$/i.test(String(title || '')); }

const argv = parseArgs(process.argv.slice(2));
const CSV_PATH = argv.csv;
const OUT_PATH = argv.out;
const INCLUDE_ALL = /^true|1|yes$/i.test(String(argv.all || 'false'));

if (!CSV_PATH || !OUT_PATH) {
  console.error('Usage: node scripts/make_title_mapping_from_export.js --csv <exported.csv> --out <mapping.csv> [--all]');
  process.exit(1);
}

const src = fs.readFileSync(CSV_PATH, 'utf8');
const rows = parseCsv(src);
if (!rows.length) { console.error('Empty CSV:', CSV_PATH); process.exit(1); }
const header = rows[0];
const idx = Object.fromEntries(header.map((h, i) => [h, i]));
for (const h of ['order','currentTitle']) {
  if (!(h in idx)) { console.error('Missing column in source CSV:', h); process.exit(1); }
}

const outRows = [['order','newTitle']];
for (let r = 1; r < rows.length; r++) {
  const cols = rows[r];
  if (!cols || cols.length <= idx.currentTitle) continue;
  const cur = cols[idx.currentTitle] || '';
  const ord = cols[idx.order] || '';
  if (!INCLUDE_ALL && !isDefaultTitle(cur)) continue;
  outRows.push([String(ord), '']);
}

const esc = v => '"' + String(v ?? '').replace(/"/g, '""') + '"';
const outContent = outRows.map(r => r.map(esc).join(',')).join('\n') + '\n';
const abs = path.resolve(OUT_PATH);
fs.mkdirSync(path.dirname(abs), { recursive: true });
fs.writeFileSync(abs, outContent, 'utf8');
console.log('Wrote mapping template to', abs, 'rows:', outRows.length - 1);
