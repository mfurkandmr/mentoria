// Test projesini depodaki migration'larla eşitler (yalnızca Mentoria-Test).
//   node apply_migrations.mjs            → kayıtlı son sürümden sonrakiler
//   node apply_migrations.mjs 20261019150000   → bu sürümden (dahil) itibaren
// Her dosya kendi transaction'ında; biri düşerse durur.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { connect } from './db.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const dir = path.join(root, 'supabase/migrations');
const files = fs.readdirSync(dir).filter((f) => f.endsWith('.sql')).sort();

const db = await connect();
await db.query(`create schema if not exists supabase_migrations;
  create table if not exists supabase_migrations.schema_migrations (version text primary key, name text, statements text[])`);
const done = new Set((await db.query('select version from supabase_migrations.schema_migrations')).rows.map((r) => r.version));
const from = process.argv[2];
// Başlangıç verilmezse kayıtlı en son sürümden sonrakiler.
const last = [...done].sort().pop() ?? '';
if (!from && !last) throw new Error('İlk çalıştırmada başlangıç sürümünü ver.');

let applied = 0;
for (const f of files) {
  const version = f.slice(0, 14);
  if (done.has(version)) continue;
  if (from ? version < from : version <= last) continue;
  const sql = fs.readFileSync(path.join(dir, f), 'utf8');
  const t0 = Date.now();
  try {
    await db.query('begin');
    await db.query(sql);
    await db.query('insert into supabase_migrations.schema_migrations (version, name) values ($1, $2)',
      [version, f.slice(15, -4)]);
    await db.query('commit');
    applied++;
    console.log(`ok   ${f} (${Date.now() - t0} ms)`);
  } catch (e) {
    await db.query('rollback');
    console.error(`HATA ${f}: ${e.message}`);
    await db.end();
    process.exit(1);
  }
}
console.log(`${applied} migration uygulandı.`);
await db.end();
