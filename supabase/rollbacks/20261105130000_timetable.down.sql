-- Geri alma: 20261105130000_timetable
-- Ders programı tabloları ve bütün kayıtları silinir.
drop function if exists public.my_timetable();
drop function if exists public.publish_schedule(uuid);
drop function if exists public.save_schedule_entries(uuid, jsonb, integer);
drop table if exists public.schedule_entries;
drop table if exists public.schedules;
drop table if exists public.class_lessons;
drop table if exists public.time_slots;
drop table if exists public.classroom_students;
drop table if exists public.classrooms;
drop table if exists public.teacher_availability;
drop table if exists public.teachers;
drop table if exists public.rooms;
drop function if exists public.guard_timetable_row();
drop function if exists public.is_org_admin(uuid);
