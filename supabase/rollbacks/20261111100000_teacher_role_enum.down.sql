-- 20261111100000_teacher_role_enum geri alma.
--
-- PostgreSQL enum değerini silmeye izin vermez ('drop value' yok). Değer
-- kalır; 20261111110000_teacher_role geri alındıktan sonra yeni öğretmen
-- hesabı açılamaz (create_invite 'teacher' kabul etmez). Var olan öğretmen
-- hesapları bu dosyayla değişmez; gerekirse önce elle silinmeli:
--   delete from auth.users where id in (select id from public.profiles where role = 'teacher');
-- Bilerek boş bırakıldı.
select 1;
