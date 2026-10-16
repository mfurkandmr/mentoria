-- =====================================================================
-- Mentoria · Referans veriler (dersler ve konular)
-- Kodlar Flutter tarafındaki lib/core/constants/exam_subjects.dart ile aynı.
-- =====================================================================

insert into public.subjects (code, exam_type, name, question_count, sort) values
  ('TYT_TUR',  'TYT', 'Türkçe',                 40,  1),
  ('TYT_TAR',  'TYT', 'Tarih',                   5,  2),
  ('TYT_COG',  'TYT', 'Coğrafya',                5,  3),
  ('TYT_FEL',  'TYT', 'Felsefe',                 5,  4),
  ('TYT_DIN',  'TYT', 'Din Kültürü',             5,  5),
  ('TYT_MAT',  'TYT', 'Matematik',              40,  6),
  ('TYT_FIZ',  'TYT', 'Fizik',                   7,  7),
  ('TYT_KIM',  'TYT', 'Kimya',                   7,  8),
  ('TYT_BIY',  'TYT', 'Biyoloji',                6,  9),
  ('AYT_MAT',  'AYT', 'Matematik',              40, 10),
  ('AYT_FIZ',  'AYT', 'Fizik',                  14, 11),
  ('AYT_KIM',  'AYT', 'Kimya',                  13, 12),
  ('AYT_BIY',  'AYT', 'Biyoloji',               13, 13),
  ('AYT_EDB',  'AYT', 'Türk Dili ve Edebiyatı', 24, 14),
  ('AYT_TAR1', 'AYT', 'Tarih-1',                10, 15),
  ('AYT_COG1', 'AYT', 'Coğrafya-1',              6, 16),
  ('AYT_TAR2', 'AYT', 'Tarih-2',                11, 17),
  ('AYT_COG2', 'AYT', 'Coğrafya-2',             11, 18),
  ('AYT_FELG', 'AYT', 'Felsefe Grubu',          12, 19),
  ('AYT_DIN',  'AYT', 'Din Kültürü',             6, 20),
  ('YDT_YD',   'YDT', 'Yabancı Dil',            80, 21);

-- Konular: (ders kodu, sıra, konu adı). İlk sürüm için ana başlıklar;
-- alt konular ve kalan AYT dersleri sonraki seed'lerde eklenecek.
insert into public.topics (subject_id, sort, name)
select s.id, t.sort, t.name
from (values
  ('TYT_TUR', 1, 'Sözcükte Anlam'),
  ('TYT_TUR', 2, 'Cümlede Anlam'),
  ('TYT_TUR', 3, 'Paragraf'),
  ('TYT_TUR', 4, 'Ses Bilgisi'),
  ('TYT_TUR', 5, 'Yazım Kuralları'),
  ('TYT_TUR', 6, 'Noktalama İşaretleri'),
  ('TYT_TUR', 7, 'Sözcükte Yapı'),
  ('TYT_TUR', 8, 'Sözcük Türleri'),
  ('TYT_TUR', 9, 'Fiiller ve Fiilimsiler'),
  ('TYT_TUR', 10, 'Cümlenin Ögeleri'),
  ('TYT_TUR', 11, 'Cümle Türleri'),
  ('TYT_TUR', 12, 'Anlatım Bozuklukları'),

  ('TYT_MAT', 1, 'Temel Kavramlar'),
  ('TYT_MAT', 2, 'Sayı Basamakları'),
  ('TYT_MAT', 3, 'Bölme ve Bölünebilme'),
  ('TYT_MAT', 4, 'EBOB - EKOK'),
  ('TYT_MAT', 5, 'Rasyonel Sayılar'),
  ('TYT_MAT', 6, 'Basit Eşitsizlikler'),
  ('TYT_MAT', 7, 'Mutlak Değer'),
  ('TYT_MAT', 8, 'Üslü Sayılar'),
  ('TYT_MAT', 9, 'Köklü Sayılar'),
  ('TYT_MAT', 10, 'Çarpanlara Ayırma'),
  ('TYT_MAT', 11, 'Oran - Orantı'),
  ('TYT_MAT', 12, 'Denklem Çözme'),
  ('TYT_MAT', 13, 'Problemler'),
  ('TYT_MAT', 14, 'Kümeler'),
  ('TYT_MAT', 15, 'Mantık'),
  ('TYT_MAT', 16, 'Fonksiyonlar'),
  ('TYT_MAT', 17, 'Polinomlar'),
  ('TYT_MAT', 18, 'Permütasyon - Kombinasyon'),
  ('TYT_MAT', 19, 'Olasılık'),
  ('TYT_MAT', 20, 'Veri - İstatistik'),
  ('TYT_MAT', 21, 'Geometri: Doğruda ve Üçgende Açılar'),
  ('TYT_MAT', 22, 'Geometri: Üçgenler'),
  ('TYT_MAT', 23, 'Geometri: Çokgenler ve Dörtgenler'),
  ('TYT_MAT', 24, 'Geometri: Çember ve Daire'),
  ('TYT_MAT', 25, 'Geometri: Katı Cisimler'),
  ('TYT_MAT', 26, 'Analitik Geometri'),

  ('TYT_FIZ', 1, 'Fizik Bilimine Giriş'),
  ('TYT_FIZ', 2, 'Madde ve Özellikleri'),
  ('TYT_FIZ', 3, 'Hareket ve Kuvvet'),
  ('TYT_FIZ', 4, 'İş, Güç ve Enerji'),
  ('TYT_FIZ', 5, 'Isı, Sıcaklık ve Genleşme'),
  ('TYT_FIZ', 6, 'Basınç ve Kaldırma Kuvveti'),
  ('TYT_FIZ', 7, 'Elektrostatik'),
  ('TYT_FIZ', 8, 'Elektrik ve Manyetizma'),
  ('TYT_FIZ', 9, 'Dalgalar'),
  ('TYT_FIZ', 10, 'Optik'),

  ('TYT_KIM', 1, 'Kimya Bilimi'),
  ('TYT_KIM', 2, 'Atom ve Periyodik Sistem'),
  ('TYT_KIM', 3, 'Kimyasal Türler Arası Etkileşimler'),
  ('TYT_KIM', 4, 'Maddenin Halleri'),
  ('TYT_KIM', 5, 'Doğa ve Kimya'),
  ('TYT_KIM', 6, 'Kimyanın Temel Kanunları ve Hesaplamalar'),
  ('TYT_KIM', 7, 'Karışımlar'),
  ('TYT_KIM', 8, 'Asitler, Bazlar ve Tuzlar'),
  ('TYT_KIM', 9, 'Kimya Her Yerde'),

  ('TYT_BIY', 1, 'Canlıların Ortak Özellikleri'),
  ('TYT_BIY', 2, 'Canlıların Temel Bileşenleri'),
  ('TYT_BIY', 3, 'Hücre ve Organeller'),
  ('TYT_BIY', 4, 'Canlıların Sınıflandırılması'),
  ('TYT_BIY', 5, 'Hücre Bölünmeleri ve Üreme'),
  ('TYT_BIY', 6, 'Kalıtım'),
  ('TYT_BIY', 7, 'Ekosistem Ekolojisi ve Güncel Çevre Sorunları'),

  ('TYT_TAR', 1, 'Tarih ve Zaman'),
  ('TYT_TAR', 2, 'İlk ve Orta Çağlarda Türk Dünyası'),
  ('TYT_TAR', 3, 'İslam Medeniyetinin Doğuşu'),
  ('TYT_TAR', 4, 'Türklerin İslamiyet''i Kabulü ve İlk Türk-İslam Devletleri'),
  ('TYT_TAR', 5, 'Beylikten Devlete Osmanlı'),
  ('TYT_TAR', 6, 'Dünya Gücü Osmanlı'),
  ('TYT_TAR', 7, 'Değişen Dünya Dengeleri Karşısında Osmanlı'),
  ('TYT_TAR', 8, 'Milli Mücadele'),
  ('TYT_TAR', 9, 'Atatürkçülük ve Türk İnkılabı'),

  ('TYT_COG', 1, 'Doğa ve İnsan'),
  ('TYT_COG', 2, 'Dünya''nın Şekli ve Hareketleri'),
  ('TYT_COG', 3, 'Harita Bilgisi'),
  ('TYT_COG', 4, 'İklim Bilgisi'),
  ('TYT_COG', 5, 'Yer Şekilleri'),
  ('TYT_COG', 6, 'Nüfus ve Yerleşme'),
  ('TYT_COG', 7, 'Bölgeler ve Ülkeler'),
  ('TYT_COG', 8, 'Doğal Afetler'),

  ('TYT_FEL', 1, 'Felsefeye Giriş'),
  ('TYT_FEL', 2, 'Bilgi Felsefesi'),
  ('TYT_FEL', 3, 'Varlık Felsefesi'),
  ('TYT_FEL', 4, 'Ahlak Felsefesi'),
  ('TYT_FEL', 5, 'Sanat Felsefesi'),
  ('TYT_FEL', 6, 'Din Felsefesi'),
  ('TYT_FEL', 7, 'Siyaset Felsefesi'),
  ('TYT_FEL', 8, 'Bilim Felsefesi'),

  ('TYT_DIN', 1, 'Bilgi ve İnanç'),
  ('TYT_DIN', 2, 'Din ve İslam'),
  ('TYT_DIN', 3, 'İslam ve İbadet'),
  ('TYT_DIN', 4, 'Hz. Muhammed''in Hayatı'),
  ('TYT_DIN', 5, 'Ahlak ve Değerler'),
  ('TYT_DIN', 6, 'İslam Düşüncesinde Yorumlar')
) as t(code, sort, name)
join public.subjects s on s.code = t.code;

-- NOT: score_types / score_coefficients / rank_tables burada doldurulmaz.
-- ÖSYM'nin yayımladığı güncel katsayılar ve önceki yılın puan-sıralama
-- verileri tahmin özelliği yazılırken ayrı bir seed ile eklenecek.
