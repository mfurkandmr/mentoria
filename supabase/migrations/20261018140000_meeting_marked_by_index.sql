-- =====================================================================
-- Performans: meeting_occurrences.marked_by yabancı anahtarına indeks
--
-- Supabase performans önerisi (unindexed_foreign_keys): işaretleyen kişinin
-- profili silinince (on delete set null) tablo baştan sona taranmasın.
--
-- Geri almak için: supabase/rollbacks/20261018140000_meeting_marked_by_index.down.sql
-- =====================================================================

create index if not exists meeting_occurrences_marked_by_idx
  on public.meeting_occurrences (marked_by);
