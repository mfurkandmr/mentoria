// admin_cockpit gövdesini test kurumu için EXPLAIN ANALYZE eder (yalnızca
// Mentoria-Test). Fonksiyon dosyası argüman: varsayılan ilk sürüm.
//   node explain_cockpit.mjs [migration.sql]
import fs from 'node:fs';
import { connect } from './db.mjs';

const file = process.argv[2] ?? '../../supabase/migrations/20261106160000_admin_cockpit.sql';
const src = fs.readFileSync(file, 'utf8');
const fn = src.slice(src.lastIndexOf('create or replace function public.admin_cockpit()'));
const body = fn.slice(fn.indexOf('with st as'), fn.indexOf(') into v_out;') + 1);

const db = await connect();
const org = (await db.query(`select p.org_id from public.profiles p join auth.users u on u.id = p.id
  where u.email = 'yuk-admin@example.com'`)).rows[0].org_id;
const sql = body
  .replaceAll('v_org', `'${org}'::uuid`)
  .replaceAll('v_week', `date_trunc('week', current_date)::date`);
const t0 = Date.now();
await db.query(sql);
console.log('çalışma süresi (sıcak değil):', Date.now() - t0, 'ms');
const plan = (await db.query(`explain (analyze, timing, buffers off) ${sql}`)).rows.map((r) => r['QUERY PLAN']);
// En pahalı düğümler: actual time ve loops olan satırlar.
const nodes = plan
  .map((l) => {
    const m = l.match(/actual time=[\d.]+\.\.([\d.]+) rows=(\d+) loops=(\d+)/);
    return m ? { total: Number(m[1]) * Number(m[3]), rows: Number(m[2]), loops: Number(m[3]), line: l.trim().slice(0, 110) } : null;
  })
  .filter(Boolean)
  .sort((a, b) => b.total - a.total)
  .slice(0, 14);
console.table(nodes);
console.log(plan.at(-1));
await db.end();
