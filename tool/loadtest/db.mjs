// Test veritabanına doğrudan bağlantı (yalnızca Mentoria-Test!).
// Bağlantı adresi tool/loadtest/.env.local dosyasında (git'e girmez):
//   LT_DB_URL=postgresql://postgres:<parola>@db.iruiyvfndxhkuiwbekuf.supabase.co:5432/postgres
//   LT_PASSWORD=<test kullanıcılarına verilecek parola; yoksa üretilir>
//   LT_DB_CA=<isteğe bağlı: Supabase SSL sertifikasının yolu>
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import pg from 'pg';

const here = path.dirname(fileURLToPath(import.meta.url));
export const envFile = path.join(here, '.env.local');

export function readEnv() {
  const env = {};
  if (fs.existsSync(envFile)) {
    for (const line of fs.readFileSync(envFile, 'utf8').split(/\r?\n/)) {
      const m = line.match(/^\s*([A-Z_]+)\s*=\s*(.*)\s*$/);
      if (m) env[m[1]] = m[2];
    }
  }
  return { ...env, ...Object.fromEntries(Object.entries(process.env).filter(([k]) => k.startsWith('LT_'))) };
}

export async function connect() {
  const env = readEnv();
  const url = env.LT_DB_URL;
  if (!url) throw new Error(`LT_DB_URL yok: ${envFile} dosyasına yaz.`);
  // Canlı projeye yanlışlıkla bağlanmayı engelle.
  if (url.includes('lmbykdvvxormfiaomysn')) throw new Error('Bu canlı proje! Yalnızca Mentoria-Test.');
  if (!url.includes('iruiyvfndxhkuiwbekuf')) throw new Error('Adres Mentoria-Test (iruiyvfndxhkuiwbekuf) değil.');
  // Sertifika doğrulanır; Supabase kök sertifikası LT_DB_CA (Dashboard →
  // Database → SSL) ile verilebilir.
  const ssl = env.LT_DB_CA ? { ca: fs.readFileSync(path.resolve(here, env.LT_DB_CA), 'utf8') } : true;
  const client = new pg.Client({ connectionString: url, ssl });
  await client.connect();
  return client;
}
