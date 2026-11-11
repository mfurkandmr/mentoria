// Öğrencinin sınıf seviyesi ve hangi konunun hangi sınıfta işlendiği
// (NOTLAR §91). Sunucuda yalnızca profiles.grade_level (9-12) tutulur;
// konu listesi uygulamada süzülür.
//
//  * 9, 10, 11: yalnızca o sınıfta işlenen konular.
//  * 12 (12. sınıf ve mezun aynı): bütün YKS konuları.
//  * Seviye bilinmiyorsa (eski hesap) 12 gibi davranılır.
//
// Eşleme MEB lise müfredatının ünite sırasına göre, YKS konu adları
// üzerinden yapılmıştır (supabase/seed.sql, seed_ayt_ydt_topics.sql). Burada
// olmayan konu yalnızca 12 / mezunda görünür. TYT ile AYT'de aynı konu
// varsa alt sınıflara bir kez (TYT'deki) gösterilir.
import '../i18n/i18n.dart';
import '../../features/tracking/data/tracking_models.dart';

/// Kayıtta seçilen sınıf seviyeleri.
const gradeLevels = [9, 10, 11, 12];

/// "9. sınıf" … "12. sınıf / mezun".
String gradeLabel(int grade) =>
    grade >= 12 ? tr('12. sınıf / mezun') : tr('{n}. sınıf', {'n': grade});

/// Bilinmeyen seviye 12 sayılır (bütün konular).
int effectiveGrade(int? grade) =>
    grade == null || grade >= 12 || grade < 9 ? 12 : grade;

/// Konu bu sınıf seviyesinde görünür mü?
bool topicVisibleForGrade(Topic t, int? grade) {
  final g = effectiveGrade(grade);
  if (g == 12) return true;
  return topicGrades[t.subjectCode]?[t.name]?.contains(g) ?? false;
}

/// Sınıf seviyesine göre süzülmüş konular.
List<Topic> topicsForGrade(List<Topic> topics, int? grade) => [
  for (final t in topics)
    if (topicVisibleForGrade(t, grade)) t,
];

/// Ders kodu → konu adı → işlendiği sınıflar (9-11). 12. sınıf konuları
/// yazılmaz: 12 / mezun zaten her şeyi görür.
const Map<String, Map<String, Set<int>>> topicGrades = {
  'TYT_TUR': {
    'Sözcükte Anlam': {9, 10, 11},
    'Cümlede Anlam': {9, 10, 11},
    'Paragraf': {9, 10, 11},
    'Ses Bilgisi': {9},
    'Yazım Kuralları': {9},
    'Noktalama İşaretleri': {9},
    'Sözcükte Yapı': {10},
    'Sözcük Türleri': {10},
    'Fiiller ve Fiilimsiler': {10, 11},
    'Cümlenin Ögeleri': {11},
    'Cümle Türleri': {11},
    'Anlatım Bozuklukları': {11},
  },
  'TYT_MAT': {
    'Temel Kavramlar': {9},
    'Sayı Basamakları': {9},
    'Bölme ve Bölünebilme': {9},
    'EBOB - EKOK': {9},
    'Rasyonel Sayılar': {9},
    'Basit Eşitsizlikler': {9},
    'Mutlak Değer': {9},
    'Üslü Sayılar': {9},
    'Köklü Sayılar': {9},
    'Çarpanlara Ayırma': {10},
    'Oran - Orantı': {9},
    'Denklem Çözme': {9},
    'Problemler': {9},
    'Kümeler': {9},
    'Mantık': {9},
    'Fonksiyonlar': {10},
    'Polinomlar': {10},
    'Permütasyon - Kombinasyon': {10},
    'Olasılık': {10},
    'Veri - İstatistik': {9},
    'Geometri: Doğruda ve Üçgende Açılar': {9},
    'Geometri: Üçgenler': {9},
    'Geometri: Çokgenler ve Dörtgenler': {10},
    'Geometri: Çember ve Daire': {11},
    'Geometri: Katı Cisimler': {10},
    'Analitik Geometri': {11},
  },
  'TYT_FIZ': {
    'Fizik Bilimine Giriş': {9},
    'Madde ve Özellikleri': {9},
    'Hareket ve Kuvvet': {9},
    'İş, Güç ve Enerji': {9},
    'Isı, Sıcaklık ve Genleşme': {9},
    'Elektrostatik': {9},
    'Basınç ve Kaldırma Kuvveti': {10},
    'Elektrik ve Manyetizma': {10},
    'Dalgalar': {10},
    'Optik': {10},
  },
  'TYT_KIM': {
    'Kimya Bilimi': {9},
    'Atom ve Periyodik Sistem': {9},
    'Kimyasal Türler Arası Etkileşimler': {9},
    'Maddenin Halleri': {9},
    'Doğa ve Kimya': {9},
    'Kimyanın Temel Kanunları ve Hesaplamalar': {10},
    'Karışımlar': {10},
    'Asitler, Bazlar ve Tuzlar': {10},
    'Kimya Her Yerde': {10},
  },
  'TYT_BIY': {
    'Canlıların Ortak Özellikleri': {9},
    'Canlıların Temel Bileşenleri': {9},
    'Hücre ve Organeller': {9},
    'Canlıların Sınıflandırılması': {9},
    'Hücre Bölünmeleri ve Üreme': {10},
    'Kalıtım': {10},
    'Ekosistem Ekolojisi ve Güncel Çevre Sorunları': {10},
  },
  'TYT_TAR': {
    'Tarih ve Zaman': {9},
    'İlk ve Orta Çağlarda Türk Dünyası': {9},
    'İslam Medeniyetinin Doğuşu': {9},
    'Türklerin İslamiyet\'i Kabulü ve İlk Türk-İslam Devletleri': {9},
    'Beylikten Devlete Osmanlı': {10},
    'Dünya Gücü Osmanlı': {10},
    'Değişen Dünya Dengeleri Karşısında Osmanlı': {11},
  },
  'TYT_COG': {
    'Doğa ve İnsan': {9},
    'Dünya\'nın Şekli ve Hareketleri': {9},
    'Harita Bilgisi': {9},
    'İklim Bilgisi': {9},
    'Yer Şekilleri': {10},
    'Nüfus ve Yerleşme': {10},
    'Bölgeler ve Ülkeler': {10},
    'Doğal Afetler': {10},
  },
  'TYT_FEL': {
    'Felsefeye Giriş': {10},
    'Bilgi Felsefesi': {10},
    'Varlık Felsefesi': {10},
    'Ahlak Felsefesi': {10},
    'Sanat Felsefesi': {10},
    'Din Felsefesi': {10},
    'Siyaset Felsefesi': {10},
    'Bilim Felsefesi': {10},
  },
  'TYT_DIN': {
    'Bilgi ve İnanç': {9},
    'Din ve İslam': {9},
    'İslam ve İbadet': {9},
    'Ahlak ve Değerler': {9},
    'Hz. Muhammed\'in Hayatı': {10},
    'İslam Düşüncesinde Yorumlar': {10},
  },
  'AYT_MAT': {
    'İkinci Dereceden Denklemler': {10},
    'Fonksiyonlar': {11},
    'Eşitsizlikler': {11},
    'Parabol': {11},
    'Olasılık': {11},
    'Trigonometri': {11},
    'Geometri: Doğrunun Analitiği': {11},
    'Geometri: Çember ve Daire Analitiği': {11},
  },
  'AYT_FIZ': {
    'Basit Makineler': {10},
    'Vektörler': {11},
    'Bağıl Hareket': {11},
    'Newton\'un Hareket Yasaları': {11},
    'Bir Boyutta Sabit İvmeli Hareket': {11},
    'Atışlar': {11},
    'İş, Güç ve Enerji': {11},
    'İtme ve Çizgisel Momentum': {11},
    'Tork ve Denge': {11},
    'Kütle Merkezi': {11},
    'Elektriksel Kuvvet ve Alan': {11},
    'Elektriksel Potansiyel': {11},
    'Düzgün Elektrik Alan ve Sığa': {11},
    'Manyetizma ve Elektromanyetik İndüksiyon': {11},
    'Alternatif Akım ve Transformatörler': {11},
  },
  'AYT_KIM': {
    'Modern Atom Teorisi': {11},
    'Gazlar': {11},
    'Sıvı Çözeltiler ve Çözünürlük': {11},
    'Kimyasal Tepkimelerde Enerji': {11},
    'Kimyasal Tepkimelerde Hız': {11},
    'Kimyasal Denge': {11},
    'Asit-Baz Dengesi': {11},
    'Çözünürlük Dengesi': {11},
  },
  'AYT_BIY': {
    'Sinir Sistemi': {11},
    'Endokrin Sistem': {11},
    'Duyu Organları': {11},
    'Destek ve Hareket Sistemi': {11},
    'Sindirim Sistemi': {11},
    'Dolaşım ve Bağışıklık Sistemi': {11},
    'Solunum Sistemi': {11},
    'Boşaltım Sistemi': {11},
    'Üreme Sistemi ve Embriyonik Gelişim': {11},
    'Komünite ve Popülasyon Ekolojisi': {11},
  },
  'AYT_EDB': {
    'Şiir Bilgisi': {9},
    'Edebi Sanatlar': {9},
    'İslamiyet Öncesi Türk Edebiyatı': {10},
    'Geçiş Dönemi Türk Edebiyatı': {10},
    'Divan Edebiyatı': {10},
    'Halk Edebiyatı': {10},
    'Edebi Akımlar': {11},
    'Tanzimat Edebiyatı': {11},
    'Servet-i Fünun ve Fecr-i Ati': {11},
    'Milli Edebiyat': {11},
    'Dünya Edebiyatı': {11},
  },
  'AYT_TAR1': {
    'Osmanlı Duraklama ve Gerileme Dönemi': {11},
    'Osmanlı Dağılma Dönemi': {11},
  },
  'AYT_COG1': {
    'Ekosistem ve Madde Döngüleri': {11},
    'Nüfus Politikaları': {11},
    'Türkiye\'de Nüfus ve Yerleşme': {11},
    'Ekonomik Faaliyetler': {11},
    'Çevre ve Toplum': {11},
  },
  'AYT_FELG': {
    'Felsefe: Bilgi, Varlık ve Ahlak Felsefesi': {11},
    'Mantık: Klasik Mantık': {11},
    'Mantık: Sembolik Mantık': {11},
    'Psikoloji: Temel Süreçler': {11},
    'Psikoloji: Öğrenme, Bellek ve Düşünme': {11},
    'Psikoloji: Ruh Sağlığı': {11},
    'Sosyoloji: Birey ve Toplum': {11},
    'Sosyoloji: Toplumsal Yapı ve Değişme': {11},
    'Sosyoloji: Toplumsal Kurumlar': {11},
  },
  'AYT_DIN': {
    'Dünya ve Ahiret': {11},
    'Kur\'an\'a Göre Hz. Muhammed': {11},
    'Kur\'an\'da Bazı Kavramlar': {11},
    'İslam ve Bilim': {11},
    'Anadolu\'da İslam': {11},
  },
  'YDT_YD': {
    'Kelime Bilgisi': {9, 10, 11},
    'Dil Bilgisi': {9, 10, 11},
    'Paragraf': {9, 10, 11},
  },
};
