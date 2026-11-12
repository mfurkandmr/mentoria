// Veritabanının kendi süreleri (ağ hariç), pg_stat_statements'tan.
//   node pgstats.mjs reset   → sayaçları sıfırla (testten önce)
//   node pgstats.mjs         → en çok zaman alan sorgular (testten sonra)
import { connect } from './db.mjs';

const db = await connect();
if (process.argv[2] === 'reset') {
  await db.query('select extensions.pg_stat_statements_reset()');
  console.log('sıfırlandı');
} else if (process.argv[2] === 'json') {
  // Kademe sonucu: sorgu başına ortalama ve en kötü süre + toplam DB zamanı.
  const { rows } = await db.query(`
    select calls::int, round(mean_exec_time::numeric, 2)::float mean_ms,
           round(max_exec_time::numeric, 1)::float max_ms, round(total_exec_time::numeric)::float total_ms,
           regexp_replace(left(query, 90), '\\s+', ' ', 'g') q
    from extensions.pg_stat_statements
    where calls >= 3 and query ilike '%pgrst_source%'
    order by total_exec_time desc limit 12`);
  const fs = await import('node:fs');
  fs.writeFileSync(`results/pg-${process.argv[3]}.json`, JSON.stringify(rows, null, 1));
  console.log(`pg-${process.argv[3]}.json yazıldı`);
} else {
  const { rows } = await db.query(`
    select calls, round(mean_exec_time::numeric, 2) mean_ms, round(max_exec_time::numeric, 1) max_ms,
           round(total_exec_time::numeric) total_ms,
           regexp_replace(left(query, 110), '\\s+', ' ', 'g') q
    from extensions.pg_stat_statements
    where calls >= 5 and query not ilike '%pg_stat_statements%'
      and (query ilike '%student_home%' or query ilike '%student_summaries%' or query ilike '%admin_cockpit%'
        or query ilike '%my_timetable%' or query ilike '%open_tutoring_sessions%' or query ilike '%my_announcements%'
        or query ilike '%question_logs%' or query ilike '%exams%' or query ilike '%notifications%')
    order by total_exec_time desc limit 15`);
  console.table(rows);
  const cpu = await db.query(`select count(*) filter (where state = 'active') active,
    count(*) total from pg_stat_activity`);
  console.log('bağlantılar:', cpu.rows[0]);
}
await db.end();
