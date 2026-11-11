-- Geri alma: 20261112100000_book_topic_marks (işaretler silinir).
drop function if exists public.set_book_topic_mark(uuid, int, boolean);
drop table if exists public.book_topic_marks;
