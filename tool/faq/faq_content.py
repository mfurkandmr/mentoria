"""Sıkça sorulan sorular: tek kaynak (Türkçe + İngilizce).

    python tool/faq/make_faq.py

lib/features/help/data/faq.dart dosyasını ve strings_en.dart içindeki SSS
çevirilerini bu listeden üretir. Metni burada değiştir, sonra komutu çalıştır.
"""

# (bölüm başlığı, ikon, [(soru_tr, soru_en, cevap_tr, cevap_en), ...])
STUDENT = [
    (('Başlarken', 'Getting started'), 'rocket_launch_rounded', [
        ('Nasıl kayıt olurum?', 'How do I sign up?',
         'Koçunun ya da dershanenin verdiği davet koduyla (veya davet bağlantısıyla) kayıt olursun. Şifreni iki kez girip e-postana gelen doğrulama kodunu yazınca hesabın açılır.',
         'You sign up with the invite code (or invite link) from your coach or school. Enter your password twice and type the verification code sent to your email to open your account.'),
        ('Şifremi unuttum, ne yapmalıyım?', 'I forgot my password. What should I do?',
         'Giriş ekranında "Şifremi unuttum"a dokun. E-postana gelen bağlantıyla yeni şifre belirlersin.',
         'Tap "Forgot password" on the sign-in screen. You set a new password from the link sent to your email.'),
        ('Verilerimi kimler görebilir?', 'Who can see my data?',
         'Yalnızca koçun, dershane müdürün ve bağladığın velin görür. Sınıf arkadaşların verilerini göremez; sıralamalarda yalnızca adının kısaltması görünür.',
         'Only your coach, your school manager and any parent you have linked. Classmates can’t see your data; rankings only show a shortened name.'),
    ]),
    (('Çalışma takibi', 'Tracking your study'), 'insights_rounded', [
        ('Çözdüğüm soruları nasıl kaydederim?', 'How do I log the questions I solved?',
         '"Sorular" sekmesinde "Soru ekle"ye dokun; dersi ve doğru, yanlış, boş sayılarını gir. Günlük soru ve çalışma hedeflerini profilindeki Hedefler kartından ayarlayabilirsin.',
         'Tap "Add questions" on the Questions tab and enter the subject with your correct, wrong and blank counts. You can set your daily question and study goals on the Goals card in your profile.'),
        ('Deneme sonuçlarım nereden geliyor?', 'Where do my exam results come from?',
         'Koçun ya da dershanen sonuçları girer veya Excel dosyasıyla yükler; sen "Denemeler" sekmesinde görürsün. "Analiz" bölümü her derste gelişimini ve tahminini gösterir.',
         'Your coach or school enters results or uploads them from an Excel file, and you see them on the Exams tab. The "Analysis" view shows your progress and forecast for each subject.'),
        ('Seri (alev) nasıl artar?', 'How does my streak (flame) grow?',
         'Her gün soru kaydı ya da çalışma süresi eklediğinde serin bir gün artar. Bir gün hiç kayıt olmazsa seri sıfırlanır.',
         'Your streak grows by one each day you log questions or study time. If you log nothing for a day, it resets.'),
        ('Odak Bahçesi nedir?', 'What is the Focus Garden?',
         '"Süre" sekmesinde zamanlayıcıyla çalıştığın her oturum bahçende bir çiçek açtırır. Uzun oturumlar daha büyük çiçek demektir.',
         'Every session you complete with the timer on the Time tab grows a flower in your garden. Longer sessions grow bigger flowers.'),
    ]),
    (('Eğitim ve sorular', 'Learning and questions'), 'school_rounded', [
        ('Eğitim sekmesinde günde kaç soru çözebilirim?', 'How many questions can I solve per day in the Learn tab?',
         'TYT ve AYT için ayrı haklar vardır: Türkçe, TYT/AYT Matematik ve Edebiyat günde 20, diğer dersler 10 soru. Haklar her gece Türkiye saatiyle yenilenir.',
         'TYT and AYT have separate limits: Turkish, TYT/AYT Maths and Literature get 20 a day, other subjects 10. Limits reset every night (Turkey time).'),
        ('Günün Sorusu nedir?', 'What is the Question of the Day?',
         'Her sabah 09.00\'da bir soru gelir. Günlük hakkını harcamaz; art arda doğru cevapladığın günler serini büyütür.',
         'A new question arrives every morning at 09:00. It doesn’t use your daily limit, and answering correctly on consecutive days grows your streak.'),
        ('Hata Defteri nasıl çalışır?', 'How does the Mistake Notebook work?',
         'Yanlış yaptığın soruyu deftere ekle (istersen fotoğrafıyla). Soru 1, 3, 7 ve 21 gün sonra yeniden karşına çıkar. Eğitim\'de yanlış cevaptan sonra tek dokunuşla da ekleyebilirsin.',
         'Add a question you got wrong to the notebook (with a photo if you like). It comes back after 1, 3, 7 and 21 days. In Learn you can also add it with one tap after a wrong answer.'),
        ('Arkadaş düellosu nasıl oynanır?', 'How does a friend duel work?',
         'Eğitim sekmesindeki düello kartından bir arkadaşını ve dersi seç. İkiniz de aynı 10 soruyu çözersiniz; en çok doğru yapan, eşitlikte testi daha kısa sürede bitiren kazanır. Kazananlar avatar ödülü açar.',
         'Pick a friend and a subject from the duel card on the Learn tab. You both solve the same 10 questions; the most correct answers wins, and on a tie the faster finisher wins. Winners unlock avatar rewards.'),
    ]),
    (('Avatar ve ödüller', 'Avatar and rewards'), 'emoji_events_rounded', [
        ('Yeni avatar parçalarını nasıl açarım?', 'How do I unlock new avatar parts?',
         'Parçalar soru sayısı, seri, deneme, odak süresi, düello galibiyetleri gibi başarımlarla açılır. Avatar düzenleyicide kilitli parçanın koşulu yazar.',
         'Parts unlock through achievements such as questions solved, streaks, exams, focus time and duel wins. The avatar editor shows the condition for each locked part.'),
        ('Haftanın Bal Raporu nedir?', 'What is the Weekly Honey Report?',
         'Haftanın özetini hikâye biçiminde gösteren karttır: çözdüğün sorular, odak süren ve haftanın öne çıkanları. İstersen paylaşabilirsin.',
         'A story-style card that sums up your week: questions solved, focus time and your highlights. You can share it if you like.'),
        ('Duyuruları nerede görürüm?', 'Where can I see announcements?',
         'Kurumun ya da koçun duyuru yapınca bildirim gelir ve son duyuru ana sayfanda görünür. Hepsi için "Duyurular" kartında "Tümü"ne dokun.',
         'When your school or coach makes an announcement you get a notification and the latest one appears on your home screen. Tap "All" on the "Announcements" card to see them all.'),
    ]),
    (('Hesap', 'Account'), 'manage_accounts_rounded', [
        ('Velimi nasıl bağlarım?', 'How do I link a parent?',
         'Profilinde "Veli davet kodu oluştur"a dokun ve kodu velinle paylaş. Velin bu kodla kayıt olunca gelişimini görebilir.',
         'Tap "Create parent invite code" in your profile and share the code with your parent. Once they sign up with it, they can follow your progress.'),
        ('Hesabımı nasıl silerim?', 'How do I delete my account?',
         'Profil > Güvenlik > "Hesabımın silinmesini iste". Talebin koçuna gider; hesabını ve tüm verilerini koçun siler. Talebi geri de alabilirsin.',
         'Profile > Security > "Request deletion of my account". Your request goes to your coach, who deletes your account and all your data. You can also withdraw the request.'),
    ]),
]

COACH = [
    (('Öğrenciler', 'Students'), 'groups_rounded', [
        ('Öğrenciyi nasıl eklerim?', 'How do I add a student?',
         'Ana sayfada "Öğrenci davet et"e dokun, kodu kaç öğrencinin kullanacağını seç (tek öğrenci, 5 kişi ya da sınıf). Kodu ya da davet bağlantısını öğrenciye gönder; kayıt olunca listene eklenir.',
         'Tap "Invite student" on the home screen and choose how many students can use the code (one, 5 or a class). Send the code or invite link; the student joins your list after signing up.'),
        ('Öğrencinin hangi bilgilerini görebilirim?', 'What can I see about a student?',
         'Öğrenci detayında Özet, Denemeler, Sorular, Konular, Süre, Görevler, Ödevler, Notlar, Hata Defteri ve Eğitim sekmeleri vardır. Eğitim karnesinde ders ders isabet ve en çok yanlış yapılan konu görünür.',
         'A student’s page has Overview, Exams, Questions, Topics, Time, Tasks, Homework, Notes, Mistake Notebook and Learn tabs. The Learn report shows accuracy by subject and the most-missed topic.'),
        ('Öğrenciye nasıl hedef belirlerim?', 'How do I set goals for a student?',
         'Öğrenci detayının Özet sekmesindeki Hedefler kartından günlük soru ve günlük çalışma (dakika) hedefini, hedef üniversite, bölüm ve sıralamayı girebilirsin.',
         'Use the Goals card on the Overview tab of the student’s page to set daily question and daily study (minutes) goals, plus target university, department and ranking.'),
    ]),
    (('Görev, ödev ve görüşme', 'Tasks, homework and meetings'), 'assignment_rounded', [
        ('Görev ile ödev arasındaki fark nedir?', 'What’s the difference between a task and homework?',
         'Görev tek maddelik kısa bir hatırlatmadır. Ödev birden çok maddeden (konu, soru sayısı) oluşur ve öğrenci her maddeyi işaretleyerek bitirir. İkisinde de öğrenciye bildirim gider.',
         'A task is a short single-item reminder. Homework has several items (topics, question counts) that the student ticks off. Both send the student a notification.'),
        ('Görüşmeleri nasıl planlarım?', 'How do I schedule meetings?',
         '"Görüşme ekle" ile tek seferlik ya da her hafta tekrarlanan görüşme planla. Öğrenciye görüşmeden 24 saat önce hatırlatma gider; görüşme sonrasında yapıldı ya da yapılmadı diye işaretleyebilirsin.',
         'Use "Add meeting" to schedule a one-off or weekly recurring meeting. The student gets a reminder 24 hours before, and afterwards you can mark it as held or missed.'),
        ('Notlarımı öğrenci görür mü?', 'Can the student see my notes?',
         'Evet, öğrenciye yazdığın notlar öğrencinin ana sayfasında görünür ve bildirim olarak gider.',
         'Yes. Notes you write to a student appear on their home screen and are sent as a notification.'),
        ('Öğrencilerime toplu duyuru yapabilir miyim?', 'Can I send an announcement to all my students?',
         'Evet. Ana sayfadaki "Duyurular" kartında "Yeni duyuru"ya dokun; öğrencilerine ya da onların velilerine tek seferde bildirim gönderirsin.',
         'Yes. Tap "New announcement" on the "Announcements" card on the home screen to notify your students or their parents at once.'),
    ]),
    (('Denemeler', 'Exams'), 'upload_file_rounded', [
        ('Deneme sonuçlarını toplu nasıl yüklerim?', 'How do I upload exam results in bulk?',
         '"Deneme yükle" ile Excel (.xlsx, .xls), CSV ya da TXT dosyasını seç. Satırlar öğrencilerin okul numarasıyla eşleşir; ders sütunları kendiliğinden tanınır. Kaydetmeden önce önizlersin.',
         'Use "Upload exams" to pick an Excel (.xlsx, .xls), CSV or TXT file. Rows are matched by students’ school numbers and subject columns are detected automatically. You preview before saving.'),
        ('Bazı satırlar eşleşmedi, neden?', 'Some rows didn’t match. Why?',
         'Dosyadaki numara hiçbir öğrencinin okul numarasıyla eşleşmiyordur. Öğrencinin profilinde okul numarasının girili olduğundan emin ol.',
         'The number in the file doesn’t match any student’s school number. Make sure the student’s school number is filled in.'),
        ('Yanlış yüklediğim denemeyi silebilir miyim?', 'Can I delete an exam I uploaded by mistake?',
         'Evet. "Yüklediğin denemeler" ekranında son 7 gün içinde yüklediğin denemeleri toplu silebilirsin.',
         'Yes. On "Your uploaded exams" you can delete exams uploaded in the last 7 days.'),
    ]),
    (('Hesaplar', 'Accounts'), 'manage_accounts_rounded', [
        ('Öğrenci hesap silme talebi gönderdi, ne yapmalıyım?', 'A student requested account deletion. What should I do?',
         'Öğrencinin kartında rozet görünür. Öğrenci detayındaki uyarıdan hesabı silebilirsin; silinen hesap ve verileri geri getirilemez. Öğrenci talebini geri de alabilir.',
         'A badge appears on the student’s card. You can delete the account from the notice on their page; deleted accounts and data can’t be recovered. The student can also withdraw the request.'),
    ]),
]

ADMIN = [
    (('Kurum', 'School'), 'apartment_rounded', [
        ('Koç ve öğrenciyi nasıl davet ederim?', 'How do I invite coaches and students?',
         '"Koç davet et" ile koça, "Öğrenci davet et" ile öğrenciye kod oluştur. Öğrenci davetinde öğrencinin bağlanacağı koçu seçersin.',
         'Create a code with "Invite coach" for coaches and "Invite student" for students. For student invites you choose which coach they’ll be linked to.'),
        ('Lisans ve koltuk sayısı ne demek?', 'What are the licence and seat count?',
         'Kurumunun kaç öğrenciye kadar ve hangi tarihe kadar kullanabileceğini belirler. Koltuklar dolduysa ya da lisans süresi bittiyse yeni öğrenci kayıt olamaz.',
         'They set how many students your school can have and until when. If seats are full or the licence has expired, new students can’t sign up.'),
        ('Öğrencinin koçunu değiştirebilir miyim?', 'Can I change a student’s coach?',
         'Evet. Öğrenciler listesinde öğrencinin seçeneklerinden "Koçunu değiştir"i kullan.',
         'Yes. Use "Change coach" in the student’s options on the Students list.'),
        ('Kurumun görünümünü değiştirebilir miyim?', 'Can I change how my school looks in the app?',
         'Evet. Ana sayfadaki "Kurum görünümü: logo, renk ve yazı tipi" düğmesiyle logoyu, renkleri ve yazı tipini; "Kurum adını değiştir" ile kurumun adını düzenleyebilirsin.',
         'Yes. Use the "Branding: logo, colors and font" button on the home screen for the logo, colours and font, and "Rename institution" for its name.'),
        ('Toplu duyuru nasıl gönderirim?', 'How do I send an announcement to everyone?',
         'Ana sayfadaki "Duyurular" kartında "Yeni duyuru"ya dokun. Herkes, öğrenciler, veliler ya da koçlardan birini seç, başlığı ve metni yaz. Duyuru herkese bildirim olarak gider; 24 saatte en fazla 10 duyuru gönderebilirsin.',
         'Tap "New announcement" on the "Announcements" card on the home screen. Choose everyone, students, parents or coaches, then write a title and text. It is sent to everyone as a notification; you can send up to 10 announcements in 24 hours.'),
    ]),
    (('Takip', 'Monitoring'), 'insights_rounded', [
        ('Hangi öğrenciler bu hafta çalışmadı?', 'Which students didn’t study this week?',
         'Ana sayfadaki "Bu hafta hareketsiz öğrenciler" kartı, bu hafta soru ya da çalışma kaydı olmayanları listeler.',
         'The "Inactive students this week" card on the home screen lists students with no questions or study logged this week.'),
        ('Başarı sıralamasını nasıl açarım?', 'How do I turn on the success ranking?',
         'Başarı sıralaması ekranından aç ya da kapat. Açınca öğrenciler deneme netlerine göre kurum içi sıralamayı görür; kapalıyken yalnızca sen önizlersin.',
         'Turn it on or off from the success ranking screen. When on, students see the in-school ranking by exam scores; when off, only you can preview it.'),
        ('Koçların verdiği bilgileri görebilir miyim?', 'Can I see what coaches enter?',
         'Evet. Her öğrencinin detayını koçun gördüğü gibi görürsün: denemeler, sorular, görevler, ödevler, notlar ve Eğitim karnesi.',
         'Yes. You see each student’s page as their coach does: exams, questions, tasks, homework, notes and the Learn report.'),
    ]),
    (('Hesap', 'Account'), 'manage_accounts_rounded', [
        ('Kendi hesabımı silebilir miyim?', 'Can I delete my own account?',
         'Profil > Güvenlik > "Hesabımı sil" ile silebilirsin. Kurumun tek müdürüysen önce başka bir müdür eklenmelidir.',
         'Yes, from Profile > Security > "Delete my account". If you’re the school’s only manager, another manager must be added first.'),
    ]),
]

PARENT = [
    (('Başlarken', 'Getting started'), 'family_restroom_rounded', [
        ('Çocuğumun hesabına nasıl bağlanırım?', 'How do I connect to my child’s account?',
         'Çocuğun uygulamada profilinden "Veli davet kodu oluştur"a dokunur ve kodu sana verir. Bu kodla kayıt olunca çocuğunun gelişimini görürsün.',
         'Your child taps "Create parent invite code" in their profile and gives you the code. After you sign up with it, you can follow their progress.'),
        ('Birden fazla çocuğumu takip edebilir miyim?', 'Can I follow more than one child?',
         'Evet. Her çocuğun ayrı bir veli kodu oluşturur; bağlandığın tüm çocuklar ana sayfanda listelenir.',
         'Yes. Each child creates their own parent code, and every linked child is listed on your home screen.'),
    ]),
    (('Takip', 'Following progress'), 'insights_rounded', [
        ('Neleri görebilirim?', 'What can I see?',
         'Çocuğunun denemelerini, çözdüğü soruları, konularını, çalışma süresini, ödevlerini, Hata Defteri\'ni ve haftalık Bal Raporu\'nu görürsün.',
         'You see your child’s exams, solved questions, topics, study time, homework, Mistake Notebook and weekly Honey Report.'),
        ('Haftalık rapor ne zaman gelir?', 'When does the weekly report arrive?',
         'Her pazar akşamı haftanın özeti bildirim olarak gelir: çözülen soru, odak süresi ve çalışılan gün sayısı.',
         'Every Sunday evening you get the week’s summary as a notification: questions solved, focus time and days studied.'),
        ('Kurumun duyurularını nereden görürüm?', 'Where do I see the school’s announcements?',
         'Kurum ya da koç velilere duyuru yapınca bildirim gelir; son duyuru ana sayfanda "Duyurular" kartında görünür.',
         'When the school or coach makes an announcement to parents you get a notification, and the latest one appears on the "Announcements" card on your home screen.'),
        ('Verilerde değişiklik yapabilir miyim?', 'Can I change any data?',
         'Hayır. Veli paneli yalnızca izlemek içindir; kayıtları çocuğun ve koçu girer.',
         'No. The parent panel is view-only; your child and their coach enter the records.'),
        ('Koçla nasıl iletişime geçerim?', 'How do I contact the coach?',
         'Uygulamada mesajlaşma yoktur. Koçla dershane üzerinden iletişime geçebilirsin.',
         'There’s no messaging in the app. You can reach the coach through the school.'),
    ]),
]

COMMON = [
    (('Uygulama', 'The app'), 'settings_rounded', [
        ('Bildirimler gelmiyor, ne yapmalıyım?', 'I’m not getting notifications. What should I do?',
         'Telefonunun ayarlarında Mentoria için bildirim iznini açık tut ve uygulamayı bir kez açıp kapat. Uygulama açıkken bildirimler ekranda kart olarak görünür.',
         'Make sure notifications are allowed for Mentoria in your phone settings, then open and close the app once. While the app is open, notifications appear as cards on screen.'),
        ('Dili ya da görünümü nasıl değiştiririm?', 'How do I change the language or appearance?',
         'Profildeki "Görünüm, dil ve ses" kartından dili (Türkçe / İngilizce), temayı (sistem, açık, koyu) ve sesleri ayarlayabilirsin.',
         'Use the "Appearance, language and sound" card in your profile to set the language (Turkish / English), theme (system, light, dark) and sounds.'),
        ('Şifremi nasıl değiştiririm?', 'How do I change my password?',
         'Profil > Güvenlik > "Şifre değiştir".',
         'Profile > Security > "Change password".'),
        ('Fotoğraf ya da yüz verisi toplanıyor mu?', 'Does the app collect photos or face data?',
         'Hayır. Avatar hazır parçalardan oluşur. Hata Defteri\'ne eklediğin soru fotoğrafları yalnızca sen, koçun ve velin tarafından görülür.',
         'No. Avatars are built from ready-made parts. Question photos you add to the Mistake Notebook are only visible to you, your coach and your parent.'),
    ]),
]

PLATFORM = [
    (('Platform yönetimi', 'Platform management'), 'admin_panel_settings_rounded', [
        ('Yeni dershane nasıl eklenir?', 'How do I add a new school?',
         'Profil > "Dershane yönetimi" ekranından yeni dershane ekleyip logo, renk ve yazı tipini düzenleyebilirsin. Dershanenin bağlantısıyla gelen kullanıcılar o görünümü görür.',
         'Add a school from Profile > "School management" and edit its logo, colours and font. Users arriving through the school’s link see that look.'),
    ]),
]
