// ÜRETİLDİ: python tool/faq/make_faq.py. Elle düzenleme; metinleri
// tool/faq/faq_content.py içinde değiştirip komutu yeniden çalıştır.
import 'package:flutter/material.dart';

import '../../../core/i18n/i18n.dart';
import '../../auth/data/profile.dart';

/// Bir soru ve cevabı.
class FaqItem {
  const FaqItem(this.question, this.answer);
  final String question;
  final String answer;
}

/// Başlıklı bir soru grubu.
class FaqSection {
  const FaqSection(this.title, this.icon, this.items);
  final String title;
  final IconData icon;
  final List<FaqItem> items;
}

/// Rolün sıkça sorulan soruları; ortak sorular sonda. Metinler o anki
/// dilde üretilir.
List<FaqSection> faqFor(UserRole role, {bool superAdmin = false}) => [
  ...switch (role) {
    UserRole.student => _student(),
    UserRole.coach => _coach(),
    UserRole.admin => _admin(),
    UserRole.parent => _parent(),
  },
  if (superAdmin) ..._platform(),
  ..._common(),
];

List<FaqSection> _student() => [
  FaqSection(tr('Başlarken'), Icons.rocket_launch_rounded, [
    FaqItem(
      tr('Nasıl kayıt olurum?'),
      tr(
        'Koçunun ya da dershanenin verdiği davet koduyla (veya davet bağlantısıyla) kayıt olursun. Şifreni iki kez girip e-postana gelen doğrulama kodunu yazınca hesabın açılır.',
      ),
    ),
    FaqItem(
      tr('Şifremi unuttum, ne yapmalıyım?'),
      tr(
        'Giriş ekranında "Şifremi unuttum"a dokun. E-postana gelen bağlantıyla yeni şifre belirlersin.',
      ),
    ),
    FaqItem(
      tr('Verilerimi kimler görebilir?'),
      tr(
        'Yalnızca koçun, dershane müdürün ve bağladığın velin görür. Sınıf arkadaşların verilerini göremez; sıralamalarda yalnızca adının kısaltması görünür.',
      ),
    ),
  ]),
  FaqSection(tr('Çalışma takibi'), Icons.insights_rounded, [
    FaqItem(
      tr('Çözdüğüm soruları nasıl kaydederim?'),
      tr(
        '"Sorular" sekmesinde "Soru ekle"ye dokun; dersi ve doğru, yanlış, boş sayılarını gir. Günlük soru ve çalışma hedeflerini profilindeki Hedefler kartından ayarlayabilirsin.',
      ),
    ),
    FaqItem(
      tr('Deneme sonuçlarım nereden geliyor?'),
      tr(
        'Koçun ya da dershanen sonuçları girer veya Excel dosyasıyla yükler; sen "Denemeler" sekmesinde görürsün. "Analiz" bölümü her derste gelişimini ve tahminini gösterir.',
      ),
    ),
    FaqItem(
      tr('Seri (alev) nasıl artar?'),
      tr(
        'Her gün soru kaydı ya da çalışma süresi eklediğinde serin bir gün artar. Bir gün hiç kayıt olmazsa seri sıfırlanır.',
      ),
    ),
    FaqItem(
      tr('Odak Bahçesi nedir?'),
      tr(
        '"Süre" sekmesinde zamanlayıcıyla çalıştığın her oturum bahçende bir çiçek açtırır. Uzun oturumlar daha büyük çiçek demektir.',
      ),
    ),
  ]),
  FaqSection(tr('Eğitim ve sorular'), Icons.school_rounded, [
    FaqItem(
      tr('Eğitim sekmesinde günde kaç soru çözebilirim?'),
      tr(
        'TYT ve AYT için ayrı haklar vardır: Türkçe, TYT/AYT Matematik ve Edebiyat günde 20, diğer dersler 10 soru. Haklar her gece Türkiye saatiyle yenilenir.',
      ),
    ),
    FaqItem(
      tr('Günün Sorusu nedir?'),
      tr(
        'Her sabah 09.00\'da bir soru gelir. Günlük hakkını harcamaz; art arda doğru cevapladığın günler serini büyütür.',
      ),
    ),
    FaqItem(
      tr('Hata Defteri nasıl çalışır?'),
      tr(
        'Yanlış yaptığın soruyu deftere ekle (istersen fotoğrafıyla). Soru 1, 3, 7 ve 21 gün sonra yeniden karşına çıkar. Eğitim\'de yanlış cevaptan sonra tek dokunuşla da ekleyebilirsin.',
      ),
    ),
    FaqItem(
      tr('Arkadaş düellosu nasıl oynanır?'),
      tr(
        'Eğitim sekmesindeki düello kartından bir arkadaşını ve dersi seç. İkiniz de aynı 10 soruyu çözersiniz; en çok doğru yapan, eşitlikte testi daha kısa sürede bitiren kazanır. Kazananlar avatar ödülü açar.',
      ),
    ),
  ]),
  FaqSection(tr('Avatar ve ödüller'), Icons.emoji_events_rounded, [
    FaqItem(
      tr('Yeni avatar parçalarını nasıl açarım?'),
      tr(
        'Parçalar soru sayısı, seri, deneme, odak süresi, düello galibiyetleri gibi başarımlarla açılır. Avatar düzenleyicide kilitli parçanın koşulu yazar.',
      ),
    ),
    FaqItem(
      tr('Haftanın Bal Raporu nedir?'),
      tr(
        'Haftanın özetini hikâye biçiminde gösteren karttır: çözdüğün sorular, odak süren ve haftanın öne çıkanları. İstersen paylaşabilirsin.',
      ),
    ),
  ]),
  FaqSection(tr('Hesap'), Icons.manage_accounts_rounded, [
    FaqItem(
      tr('Velimi nasıl bağlarım?'),
      tr(
        'Profilinde "Veli davet kodu oluştur"a dokun ve kodu velinle paylaş. Velin bu kodla kayıt olunca gelişimini görebilir.',
      ),
    ),
    FaqItem(
      tr('Hesabımı nasıl silerim?'),
      tr(
        'Profil > Güvenlik > "Hesabımın silinmesini iste". Talebin koçuna gider; hesabını ve tüm verilerini koçun siler. Talebi geri de alabilirsin.',
      ),
    ),
  ]),
];

List<FaqSection> _coach() => [
  FaqSection(tr('Öğrenciler'), Icons.groups_rounded, [
    FaqItem(
      tr('Öğrenciyi nasıl eklerim?'),
      tr(
        'Ana sayfada "Öğrenci davet et"e dokun, kodu kaç öğrencinin kullanacağını seç (tek öğrenci, 5 kişi ya da sınıf). Kodu ya da davet bağlantısını öğrenciye gönder; kayıt olunca listene eklenir.',
      ),
    ),
    FaqItem(
      tr('Öğrencinin hangi bilgilerini görebilirim?'),
      tr(
        'Öğrenci detayında Özet, Denemeler, Sorular, Konular, Süre, Görevler, Ödevler, Notlar, Hata Defteri ve Eğitim sekmeleri vardır. Eğitim karnesinde ders ders isabet ve en çok yanlış yapılan konu görünür.',
      ),
    ),
    FaqItem(
      tr('Öğrenciye nasıl hedef belirlerim?'),
      tr(
        'Öğrenci detayının Özet sekmesindeki Hedefler kartından günlük soru ve günlük çalışma (dakika) hedefini, hedef üniversite, bölüm ve sıralamayı girebilirsin.',
      ),
    ),
  ]),
  FaqSection(tr('Görev, ödev ve görüşme'), Icons.assignment_rounded, [
    FaqItem(
      tr('Görev ile ödev arasındaki fark nedir?'),
      tr(
        'Görev tek maddelik kısa bir hatırlatmadır. Ödev birden çok maddeden (konu, soru sayısı) oluşur ve öğrenci her maddeyi işaretleyerek bitirir. İkisinde de öğrenciye bildirim gider.',
      ),
    ),
    FaqItem(
      tr('Görüşmeleri nasıl planlarım?'),
      tr(
        '"Görüşme ekle" ile tek seferlik ya da her hafta tekrarlanan görüşme planla. Öğrenciye görüşmeden 24 saat önce hatırlatma gider; görüşme sonrasında yapıldı ya da yapılmadı diye işaretleyebilirsin.',
      ),
    ),
    FaqItem(
      tr('Notlarımı öğrenci görür mü?'),
      tr(
        'Evet, öğrenciye yazdığın notlar öğrencinin ana sayfasında görünür ve bildirim olarak gider.',
      ),
    ),
  ]),
  FaqSection(tr('Denemeler'), Icons.upload_file_rounded, [
    FaqItem(
      tr('Deneme sonuçlarını toplu nasıl yüklerim?'),
      tr(
        '"Deneme yükle" ile Excel (.xlsx, .xls), CSV ya da TXT dosyasını seç. Satırlar öğrencilerin okul numarasıyla eşleşir; ders sütunları kendiliğinden tanınır. Kaydetmeden önce önizlersin.',
      ),
    ),
    FaqItem(
      tr('Bazı satırlar eşleşmedi, neden?'),
      tr(
        'Dosyadaki numara hiçbir öğrencinin okul numarasıyla eşleşmiyordur. Öğrencinin profilinde okul numarasının girili olduğundan emin ol.',
      ),
    ),
    FaqItem(
      tr('Yanlış yüklediğim denemeyi silebilir miyim?'),
      tr(
        'Evet. "Yüklediğin denemeler" ekranında son 7 gün içinde yüklediğin denemeleri toplu silebilirsin.',
      ),
    ),
  ]),
  FaqSection(tr('Hesaplar'), Icons.manage_accounts_rounded, [
    FaqItem(
      tr('Öğrenci hesap silme talebi gönderdi, ne yapmalıyım?'),
      tr(
        'Öğrencinin kartında rozet görünür. Öğrenci detayındaki uyarıdan hesabı silebilirsin; silinen hesap ve verileri geri getirilemez. Öğrenci talebini geri de alabilir.',
      ),
    ),
  ]),
];

List<FaqSection> _admin() => [
  FaqSection(tr('Kurum'), Icons.apartment_rounded, [
    FaqItem(
      tr('Koç ve öğrenciyi nasıl davet ederim?'),
      tr(
        '"Koç davet et" ile koça, "Öğrenci davet et" ile öğrenciye kod oluştur. Öğrenci davetinde öğrencinin bağlanacağı koçu seçersin.',
      ),
    ),
    FaqItem(
      tr('Lisans ve koltuk sayısı ne demek?'),
      tr(
        'Kurumunun kaç öğrenciye kadar ve hangi tarihe kadar kullanabileceğini belirler. Koltuklar dolduysa ya da lisans süresi bittiyse yeni öğrenci kayıt olamaz.',
      ),
    ),
    FaqItem(
      tr('Öğrencinin koçunu değiştirebilir miyim?'),
      tr(
        'Evet. Öğrenciler listesinde öğrencinin seçeneklerinden "Koçunu değiştir"i kullan.',
      ),
    ),
    FaqItem(
      tr('Kurumun görünümünü değiştirebilir miyim?'),
      tr(
        'Evet. Ana sayfadaki "Kurum görünümü: logo, renk ve yazı tipi" düğmesiyle logoyu, renkleri ve yazı tipini; "Kurum adını değiştir" ile kurumun adını düzenleyebilirsin.',
      ),
    ),
  ]),
  FaqSection(tr('Takip'), Icons.insights_rounded, [
    FaqItem(
      tr('Hangi öğrenciler bu hafta çalışmadı?'),
      tr(
        'Ana sayfadaki "Bu hafta hareketsiz öğrenciler" kartı, bu hafta soru ya da çalışma kaydı olmayanları listeler.',
      ),
    ),
    FaqItem(
      tr('Başarı sıralamasını nasıl açarım?'),
      tr(
        'Başarı sıralaması ekranından aç ya da kapat. Açınca öğrenciler deneme netlerine göre kurum içi sıralamayı görür; kapalıyken yalnızca sen önizlersin.',
      ),
    ),
    FaqItem(
      tr('Koçların verdiği bilgileri görebilir miyim?'),
      tr(
        'Evet. Her öğrencinin detayını koçun gördüğü gibi görürsün: denemeler, sorular, görevler, ödevler, notlar ve Eğitim karnesi.',
      ),
    ),
  ]),
  FaqSection(tr('Hesap'), Icons.manage_accounts_rounded, [
    FaqItem(
      tr('Kendi hesabımı silebilir miyim?'),
      tr(
        'Profil > Güvenlik > "Hesabımı sil" ile silebilirsin. Kurumun tek müdürüysen önce başka bir müdür eklenmelidir.',
      ),
    ),
  ]),
];

List<FaqSection> _parent() => [
  FaqSection(tr('Başlarken'), Icons.family_restroom_rounded, [
    FaqItem(
      tr('Çocuğumun hesabına nasıl bağlanırım?'),
      tr(
        'Çocuğun uygulamada profilinden "Veli davet kodu oluştur"a dokunur ve kodu sana verir. Bu kodla kayıt olunca çocuğunun gelişimini görürsün.',
      ),
    ),
    FaqItem(
      tr('Birden fazla çocuğumu takip edebilir miyim?'),
      tr(
        'Evet. Her çocuğun ayrı bir veli kodu oluşturur; bağlandığın tüm çocuklar ana sayfanda listelenir.',
      ),
    ),
  ]),
  FaqSection(tr('Takip'), Icons.insights_rounded, [
    FaqItem(
      tr('Neleri görebilirim?'),
      tr(
        'Çocuğunun denemelerini, çözdüğü soruları, konularını, çalışma süresini, ödevlerini, Hata Defteri\'ni ve haftalık Bal Raporu\'nu görürsün.',
      ),
    ),
    FaqItem(
      tr('Haftalık rapor ne zaman gelir?'),
      tr(
        'Her pazar akşamı haftanın özeti bildirim olarak gelir: çözülen soru, odak süresi ve çalışılan gün sayısı.',
      ),
    ),
    FaqItem(
      tr('Verilerde değişiklik yapabilir miyim?'),
      tr(
        'Hayır. Veli paneli yalnızca izlemek içindir; kayıtları çocuğun ve koçu girer.',
      ),
    ),
    FaqItem(
      tr('Koçla nasıl iletişime geçerim?'),
      tr(
        'Uygulamada mesajlaşma yoktur. Koçla dershane üzerinden iletişime geçebilirsin.',
      ),
    ),
  ]),
];

List<FaqSection> _common() => [
  FaqSection(tr('Uygulama'), Icons.settings_rounded, [
    FaqItem(
      tr('Bildirimler gelmiyor, ne yapmalıyım?'),
      tr(
        'Telefonunun ayarlarında Mentoria için bildirim iznini açık tut ve uygulamayı bir kez açıp kapat. Uygulama açıkken bildirimler ekranda kart olarak görünür.',
      ),
    ),
    FaqItem(
      tr('Dili ya da görünümü nasıl değiştiririm?'),
      tr(
        'Profildeki "Görünüm, dil ve ses" kartından dili (Türkçe / İngilizce), temayı (sistem, açık, koyu) ve sesleri ayarlayabilirsin.',
      ),
    ),
    FaqItem(
      tr('Şifremi nasıl değiştiririm?'),
      tr('Profil > Güvenlik > "Şifre değiştir".'),
    ),
    FaqItem(
      tr('Fotoğraf ya da yüz verisi toplanıyor mu?'),
      tr(
        'Hayır. Avatar hazır parçalardan oluşur. Hata Defteri\'ne eklediğin soru fotoğrafları yalnızca sen, koçun ve velin tarafından görülür.',
      ),
    ),
  ]),
];

List<FaqSection> _platform() => [
  FaqSection(tr('Platform yönetimi'), Icons.admin_panel_settings_rounded, [
    FaqItem(
      tr('Yeni dershane nasıl eklenir?'),
      tr(
        'Profil > "Dershane yönetimi" ekranından yeni dershane ekleyip logo, renk ve yazı tipini düzenleyebilirsin. Dershanenin bağlantısıyla gelen kullanıcılar o görünümü görür.',
      ),
    ),
  ]),
];
