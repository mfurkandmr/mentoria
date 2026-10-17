/// Türkçe kaynak metin → İngilizce.
///
/// Anahtarlar koddaki `tr('...')` metinleriyle birebir aynıdır. Eksik bir
/// anahtar Türkçe gösterilir; `test/i18n_test.dart` eksikleri yakalar.
const enStrings = <String, String>{
  // Genel
  'Kaydet': 'Save',
  'Vazgeç': 'Cancel',
  'Sil': 'Delete',
  'Kapat': 'Close',
  'Tamam': 'OK',
  'Ekle': 'Add',
  'Düzenle': 'Edit',
  'Değiştir': 'Change',
  'Kopyala': 'Copy',
  'Gönder': 'Send',
  'Devam': 'Resume',
  'Atla': 'Skip',
  'Seçenekler': 'Options',
  'Tekrar dene': 'Try again',
  'Yükleniyor': 'Loading',
  'Profil': 'Profile',
  'Çıkış yap': 'Sign out',
  'Çıkış yapılsın mı?': 'Sign out?',
  'Tekrar girmek için e-posta ve şifren gerekecek.':
      'You will need your email and password to sign in again.',
  'Veriler yüklenemedi. İnternet bağlantını kontrol et.':
      'Couldn\'t load data. Check your internet connection.',
  'Kaydedilemedi. Tekrar dene.': 'Couldn\'t save. Please try again.',
  'Bir şeyler ters gitti. Lütfen tekrar dene.':
      'Something went wrong. Please try again.',
  'Hedefine giden yolda her gün biraz daha.':
      'A little closer to your goal every day.',
  'Bugün': 'Today',
  'Bu hafta': 'This week',
  'Son 7 gün': 'Last 7 days',
  'son 7 gün': 'last 7 days',
  'Son 30 gün': 'Last 30 days',
  'Ana Sayfa': 'Home',
  'Özet': 'Overview',
  'Genel': 'Overview',

  // Roller, alanlar, dersler
  'Kurum Müdürü': 'Institution Manager',
  'Koç': 'Coach',
  'Öğrenci': 'Student',
  'Veli': 'Parent',
  'Sayısal': 'Science (SAY)',
  'Eşit Ağırlık': 'Equal Weight (EA)',
  'Sözel': 'Verbal (SÖZ)',
  'Dil': 'Language',
  'Türkçe': 'Turkish',
  'Tarih': 'History',
  'Coğrafya': 'Geography',
  'Felsefe': 'Philosophy',
  'Din Kültürü': 'Religious Culture',
  'Matematik': 'Mathematics',
  'Fizik': 'Physics',
  'Kimya': 'Chemistry',
  'Biyoloji': 'Biology',
  'Türk Dili ve Edebiyatı': 'Turkish Language & Literature',
  'Tarih-1': 'History-1',
  'Coğrafya-1': 'Geography-1',
  'Tarih-2': 'History-2',
  'Coğrafya-2': 'Geography-2',
  'Felsefe Grubu': 'Philosophy Group',
  'Yabancı Dil': 'Foreign Language',
  'Sosyal Bilimler': 'Social Sciences',
  'Temel Matematik': 'Basic Mathematics',
  'Fen Bilimleri': 'Natural Sciences',

  // Durumlar
  'Başlanmadı': 'Not started',
  'Çalışılıyor': 'In progress',
  'Bitti': 'Done',
  'Tekrar gerekli': 'Needs review',
  'Bekliyor': 'Pending',
  'Tamamlandı': 'Completed',
  'Yapılmadı': 'Skipped',
  'Pomodoro': 'Pomodoro',
  'Kronometre': 'Stopwatch',

  // Giriş / kayıt
  'Giriş yap': 'Sign in',
  'E-posta': 'Email',
  'Şifre': 'Password',
  'Geçerli bir e-posta gir': 'Enter a valid email',
  'Şifreni gir': 'Enter your password',
  'Şifremi unuttum': 'Forgot password',
  'Şifreyi göster': 'Show password',
  'Şifreyi gizle': 'Hide password',
  'Davet kodum var, hesap oluştur': 'I have an invite code, create account',
  'Hesap oluştur': 'Create account',
  '{app} hesabı yalnızca davetle açılır. Kurumundan, koçundan ya da çocuğundan aldığın davet kodunu gir.':
      '{app} accounts are invite-only. Enter the invite code you got from your institution, coach or child.',
  'Harika! Şimdi hesap bilgilerini gir.':
      'Great! Now enter your account details.',
  'Davet kodu': 'Invite code',
  'Kodu doğrula': 'Verify code',
  'Davet kodu en az 6 karakter olmalı.':
      'The invite code must be at least 6 characters.',
  'Bu davet kodu geçersiz veya süresi dolmuş.':
      'This invite code is invalid or has expired.',
  '{p0} · {p1} olarak katılıyorsun': '{p0} · you\'re joining as {p1}',
  'Ad Soyad': 'Full name',
  'Ad soyad': 'Full name',
  'Adını ve soyadını gir': 'Enter your first and last name',
  'Adını ve soyadını gir.': 'Enter your first and last name.',
  'Şifre (en az 8 karakter)': 'Password (at least 8 characters)',
  'Şifre en az 8 karakter olmalı': 'Password must be at least 8 characters',
  'Şifre en az 8 karakter olmalı.': 'Password must be at least 8 characters.',
  'KVKK aydınlatma metnini okudum, kişisel verilerimin işlenmesine onay veriyorum.':
      'I have read the privacy notice (KVKK) and consent to the processing of my personal data.',
  'Devam etmek için aydınlatma metnini onaylamalısın.':
      'You need to accept the privacy notice to continue.',
  'Hesabımı oluştur': 'Create my account',
  'Hesabın oluşturuldu! E-postana gelen bağlantıyla adresini doğruladıktan sonra giriş yapabilirsin.':
      'Your account is ready! Verify your address with the link we emailed you, then sign in.',
  'E-posta veya şifre hatalı.': 'Incorrect email or password.',
  'E-posta adresini henüz doğrulamadın.':
      'You haven\'t verified your email address yet.',
  'Bu e-posta ile zaten bir hesap var.':
      'An account with this email already exists.',
  'Yeni şifre eskisiyle aynı olamaz.':
      'Your new password can\'t be the same as the old one.',
  'Davet kodu geçersiz, süresi dolmuş veya kurumun lisans kotası dolu.':
      'The invite code is invalid or expired, or the institution has no seats left.',
  'Yeni kayıtlar şu an kapalı. Kurum yöneticine haber ver.':
      'Sign-ups are currently closed. Please contact your institution.',
  'Kısa sürede çok fazla deneme yapıldı. Biraz bekleyip tekrar dene.':
      'Too many attempts in a short time. Wait a moment and try again.',
  'Hesabının e-posta adresini yaz; şifreni yenilemen için bir bağlantı gönderelim.':
      'Enter your account email and we\'ll send you a link to reset your password.',
  'Bağlantı gönder': 'Send link',
  'Sıfırlama bağlantısını {email} adresine gönderdik. Gelen kutunu kontrol et.':
      'We sent a reset link to {email}. Check your inbox.',
  'Yeni şifreni belirle': 'Set a new password',
  'Yeni şifre (en az 8 karakter)': 'New password (at least 8 characters)',
  'Yeni şifre (tekrar)': 'New password (again)',
  'Şifreler aynı değil': 'Passwords don\'t match',
  'Şifremi kaydet': 'Save my password',
  'Şifren güncellendi.': 'Your password has been updated.',
  'Supabase bağlantısı eksik': 'Supabase connection missing',
  'Uygulama Supabase anahtarları olmadan başlatıldı. VS Code veya Android Studio\'da "Mentoria" çalıştırma ayarını seç ya da terminalde şu komutu kullan:':
      'The app was started without Supabase keys. Pick the "Mentoria" run configuration in VS Code or Android Studio, or run this command in a terminal:',
  'Profilin yüklenemedi. İnternet bağlantını kontrol et.':
      'Couldn\'t load your profile. Check your internet connection.',
  'Hesabına ait profil bulunamadı.': 'No profile was found for your account.',

  // Profil ve ayarlar
  'Bilgilerim': 'My details',
  'Sınav yılı': 'Exam year',
  'Alan': 'Track',
  'Bilgilerin kaydedildi.': 'Your details have been saved.',
  'Tema': 'Theme',
  'Sistem': 'System',
  'Açık': 'Light',
  'Koyu': 'Dark',
  'Açık tema': 'Light theme',
  'Koyu tema': 'Dark theme',
  'Güvenlik': 'Security',
  'Şifre değiştir': 'Change password',
  'Şifren değiştirildi.': 'Your password has been changed.',
  'Hesabımı sil': 'Delete my account',
  'Hesabın silinsin mi?': 'Delete your account?',
  'Hesabın ve tüm verilerin (denemeler, soru kayıtları, çalışma süreleri, görevler, notlar) kalıcı olarak silinir. Bu işlem geri alınamaz.':
      'Your account and all of your data (exams, question logs, study time, tasks, notes) will be permanently deleted. This can\'t be undone.',
  'Onaylamak için SİL yaz:': 'Type SİL (delete) to confirm:',
  'Kurumun tek müdürüsün. Önce başka bir müdür eklenmeli.':
      'You\'re the institution\'s only manager. Another manager must be added first.',
  'Bağlı öğrencilerin var. Önce kurum müdürünün öğrencilerini başka bir koça devretmesi gerekiyor.':
      'You still have students. Your institution manager needs to move them to another coach first.',
  'Hesap silinemedi. Tekrar dene.':
      'Couldn\'t delete the account. Please try again.',
  'Veli bağlantısı': 'Parent access',
  'Henüz bağlı velin yok': 'No parent connected yet',
  '{count} veli bağlı · istatistiklerini görebiliyor':
      '{count} parent(s) connected · can see your stats',
  'Velin, bu kodla uygulamaya kayıt olduğunda denemelerini, soru ve çalışma istatistiklerini görebilir; hiçbir şeyi değiştiremez. Kod 30 gün geçerli ve tek kullanımlık.':
      'When your parent signs up with this code they can see your exams, question and study stats — but can\'t change anything. The code is valid for 30 days and can be used once.',
  'Veli davet kodu oluştur': 'Create parent invite code',
  'Kod kopyalandı': 'Code copied',
  'Kod oluşturulamadı.': 'Couldn\'t create a code.',

  // Hedefler
  'Hedefler': 'Goals',
  'Hedef': 'Target',
  'Günlük soru': 'Daily questions',
  'Günlük çalışma': 'Daily study',
  'Hedef sıralama': 'Target rank',
  'Henüz hedef belirlenmedi.': 'No goals set yet.',
  'Henüz hedef belirlenmedi. "Düzenle"ye dokun.':
      'No goals set yet. Tap "Edit".',
  'Günlük soru hedefi': 'Daily question goal',
  'Günlük çalışma hedefi (dakika)': 'Daily study goal (minutes)',
  'Hedef üniversite': 'Target university',
  'Hedef bölüm': 'Target program',
  'Hedefler kaydedilemedi.': 'Couldn\'t save goals.',

  // Öğrenci ana sayfası
  'Merhaba {firstName}!': 'Hi {firstName}!',
  'soru': 'questions',
  'çalışma': 'study',
  'hedef yok': 'no goal',
  'hedef tamam ✓': 'goal reached ✓',
  'Soru ekle': 'Add questions',
  'Görevlerim': 'My tasks',
  'Koçunun verdiği görevler': 'Tasks from your coach',
  'Şu an bekleyen görevin yok. 🎉': 'No pending tasks right now. 🎉',
  'Koçundan notlar': 'Notes from your coach',
  'Son deneme': 'Latest exam',

  // Denemeler
  'Denemeler': 'Exams',
  'Son net': 'Latest net',
  'Son 5 ort.': 'Last 5 avg.',
  'En iyi': 'Best',
  'Toplam net gelişimi': 'Total net progress',
  'Toplam net gelişimi grafiği, {p0} deneme. İlk {p1}, son {p2} net.':
      'Total net progress chart, {p0} exams. First {p1}, latest {p2} net.',
  'Ders bazlı gelişim': 'Progress by subject',
  'Bu ders için en az 2 deneme gerekiyor.':
      'At least 2 exams are needed for this subject.',
  'Ders bazlı ortalama': 'Average by subject',
  'Son 5 deneme': 'Last 5 exams',
  'son 5 deneme': 'last 5 exams',
  '{name}: ortalama {p0} net, {max} soruda':
      '{name}: average {p0} net out of {max} questions',
  'Tüm denemeler': 'All exams',
  'Henüz {p0} denemen yok': 'No {p0} exams yet',
  'Henüz {p0} denemesi yok': 'No {p0} exams yet',
  'Koçun deneme sonuçlarını yükledikçe netlerinin nasıl yükseldiğini burada göreceksin.':
      'As your coach uploads exam results, you\'ll see your nets climb here.',
  'Deneme sonuçlarını girdikçe gelişim burada görünecek.':
      'Progress will show up here as exam results are entered.',
  '{p0} denemesi gir': 'Enter a {p0} exam',
  'Denemeler yüklenemedi. İnternet bağlantını kontrol et.':
      'Couldn\'t load exams. Check your internet connection.',
  'Ders': 'Subject',
  'Net': 'Net',
  'Toplam net': 'Total net',
  'Denemeyi sil': 'Delete exam',
  'Deneme silinsin mi?': 'Delete this exam?',
  '"{p0}" ve tüm ders sonuçları silinecek.':
      '"{p0}" and all of its subject results will be deleted.',
  'Deneme silinemedi. Tekrar dene.':
      'Couldn\'t delete the exam. Please try again.',
  'Deneme ekle': 'Add exam',
  'Deneme gir': 'Enter exam',
  'Deneme adı': 'Exam name',
  'ör. Türkiye Geneli 4': 'e.g. Nationwide Mock 4',
  'Yayın (isteğe bağlı)': 'Publisher (optional)',
  'Yayın': 'Publisher',
  'Sonuçlar': 'Results',
  'Doğru': 'Correct',
  'Yanlış': 'Wrong',
  'Boş': 'Blank',
  '{n} soru': '{n} questions',
  '{p0} soruyu geçti': 'exceeds {p0} questions',
  'Denemeye bir ad ver (ör. "3D Türkiye Geneli 4").':
      'Give the exam a name (e.g. "3D Nationwide Mock 4").',
  'Denemeye bir ad ver.': 'Give the exam a name.',
  '{p0}: doğru + yanlış + boş, {p1} soruyu geçemez.':
      '{p0}: correct + wrong + blank can\'t exceed {p1} questions.',
  'En az bir dersin sonucunu gir.': 'Enter results for at least one subject.',
  'Deneme kaydedildi: {p0} net 🐝': 'Exam saved: {p0} net 🐝',
  'Deneme kaydedilemedi. Tekrar dene.':
      'Couldn\'t save the exam. Please try again.',
  '{p0}\n': '{p0}\n',

  // Deneme yükleme
  'Deneme sonuçlarını yükle': 'Upload exam results',
  '1. Sonuç dosyası': '1. Results file',
  'Yayınevinin ya da optik okuyucunun verdiği dosya: Excel (.xlsx, .xls), CSV ya da TXT':
      'The file from the publisher or optical reader: Excel (.xlsx, .xls), CSV or TXT',
  'Dosyadaki her satır bir öğrenci olmalı; öğrenciler okul numarasıyla eşleştirilir. Kaydetmeden önce önizlemede kontrol edebilirsin.':
      'Each row should be one student; students are matched by school number. You can review everything in the preview before saving.',
  'Dosya seç': 'Choose file',
  'Başka dosya seç': 'Choose another file',
  'Sayfa': 'Sheet',
  'Dosya açılamadı. Telefona indirip yeniden seçmeyi dene (bulut klasörlerinden okuma bazen engellenir).':
      'Couldn\'t open the file. Download it to the phone and choose it again (reading from cloud folders is sometimes blocked).',
  'Dosya şifreli. Excel\'de açıp şifresini kaldırdıktan sonra yeniden yükle.':
      'The file is password-protected. Remove the password in Excel, then upload it again.',
  'Dosyada okunacak bir tablo bulunamadı.':
      'No table to read was found in the file.',
  'Bu dosya bir tablo değil. Excel (.xlsx, .xls) ya da CSV / TXT sonuç dosyası seç.':
      'This file isn\'t a spreadsheet. Choose an Excel (.xlsx, .xls) or CSV / TXT results file.',
  'Dosya okunamadı; bozuk olabilir. Excel\'de açıp "Farklı kaydet → Excel Çalışma Kitabı (.xlsx)" ile kaydedip yeniden dene.':
      'Couldn\'t read the file; it may be damaged. Open it in Excel, use "Save As → Excel Workbook (.xlsx)", then try again.',
  '2. Deneme bilgileri': '2. Exam details',
  '3. Sütun eşleştirmesi': '3. Column mapping',
  '{p0} ders otomatik bulundu{p1}': '{p0} subjects detected automatically{p1}',
  ' · numara sütunu bulunamadı!': ' · number column not found!',
  'Okul no': 'School no.',
  'Bu sayfada ders sütunları bulunamadı. Sınav türünün doğru seçildiğinden ve dosyada "Türkçe D / Türkçe Y" gibi başlıklar olduğundan emin ol. Dosyayı bize gönderirsen formatını tanıtabiliriz.':
      'No subject columns were found on this sheet. Make sure the right exam type is selected and the file has headers like "Türkçe D / Türkçe Y". Send us the file and we can add support for its format.',
  '4. Önizleme': '4. Preview',
  '{p0} satır · {matched} eşleşti · {p1} eşleşmedi':
      '{p0} rows · {matched} matched · {p1} unmatched',
  'Dosyada öğrenci satırı bulunamadı.':
      'No student rows were found in the file.',
  'Sonuç yok': 'No results',
  '{subject}: D+Y soru sayısını aşıyor':
      '{subject}: correct + wrong exceeds the question count',
  '→ {p0} ({matchedBy} ile eşleşti)': '→ {p0} (matched by {matchedBy})',
  'numara': 'number',
  'isim': 'name',
  'elle': 'hand',
  'Öğrenci seç': 'Choose student',
  '{selected} öğrenciye kaydet': 'Save for {selected} students',
  'Kaydediliyor… {_savedCount} / {selected}':
      'Saving… {_savedCount} / {selected}',
  'Kaydedilecek öğrenci seçilmedi.': 'No students selected to save.',
  'Denemeler kaydedilsin mi?': 'Save the exams?',
  '"{p0}" denemesi {p1} öğrencinin hesabına eklenecek.':
      '"{p0}" will be added to {p1} students\' accounts.',
  'Yükleme tamamlandı': 'Upload complete',
  '{_savedCount} öğrenciye deneme eklendi.{p0}':
      'Exam added for {_savedCount} students.{p0}',

  // Soru takibi
  'Soru takibi': 'Question log',
  'Soru': 'Questions',
  'Henüz soru kaydı yok': 'No questions logged yet',
  'Çözdüğün soruları ders ders gir; günlük hedefini ve gelişimini burada takip et.':
      'Log the questions you solve by subject and track your daily goal and progress here.',
  'Öğrenci soru girdikçe istatistikler burada görünecek.':
      'Stats will appear here as the student logs questions.',
  'İlk kaydını ekle': 'Add your first entry',
  'Doğruluk': 'Accuracy',
  'Günlük çözülen soru': 'Questions solved per day',
  'Ders dağılımı': 'By subject',
  'Son 30 gün · soru sayısı ve doğruluk':
      'Last 30 days · questions and accuracy',
  'Kayıtlar': 'Entries',
  'Kayıt silinsin mi?': 'Delete entry?',
  '{p0} · {p1} soru kaydı silinecek.': '{p0} · {p1} questions will be deleted.',
  'Konu (isteğe bağlı)': 'Topic (optional)',
  'Karışık / belirtme': 'Mixed / not specified',
  'Kaynak (isteğe bağlı)': 'Source (optional)',
  'En az bir değer gir.': 'Enter at least one value.',
  'Tek kayıtta en fazla 500 soru girilebilir.':
      'You can log at most 500 questions per entry.',
  '{total} soruyu kaydet': 'Save {total} questions',
  '{p0} soru kaydedildi 🐝': '{p0} questions saved 🐝',
  'Günlük soru hedefini tamamladın! 🎉': 'You hit your daily question goal! 🎉',
  'Belirtme': 'Not specified',
  'Ders (isteğe bağlı)': 'Subject (optional)',

  // Konu takibi
  'Konu takibi': 'Topic tracker',
  'Konular': 'Topics',
  'Konu listesi boş': 'Topic list is empty',
  'Bu sınav türü için konu listesi henüz eklenmedi.':
      'The topic list for this exam type hasn\'t been added yet.',
  'Tamamlanan': 'Completed',
  'Bir konunun durumunu değiştirmek için üstüne dokun.':
      'Tap a topic to change its status.',

  // Çalışma süresi
  'Çalışma süresi': 'Study time',
  'Süre': 'Time',
  'Odak': 'Focus',
  'Mola': 'Break',
  'Duraklatıldı': 'Paused',
  'Başlat': 'Start',
  'Duraklat': 'Pause',
  'Bitir ve kaydet': 'Finish & save',
  'Molayı atla': 'Skip break',
  'Mola bitti! Yeni bir pomodoroya hazır mısın? 🐝':
      'Break\'s over! Ready for another pomodoro? 🐝',
  '1 dakikadan kısa oturumlar kaydedilmez.':
      'Sessions shorter than 1 minute aren\'t saved.',
  '{p0} dakika kaydedildi 🐝': '{p0} minutes saved 🐝',
  'Oturum kaydedilemedi.': 'Couldn\'t save the session.',
  'Seri': 'Streak',
  'devam ediyor 🔥': 'keep it going 🔥',
  'bugün başla': 'start today',
  'Günlük çalışma (dakika)': 'Daily study (minutes)',
  'Derslere göre': 'By subject',
  'Ders belirtilmedi': 'No subject',
  'Oturumlar': 'Sessions',
  'Henüz kayıtlı çalışma oturumu yok.': 'No study sessions saved yet.',
  'Oturum silinsin mi?': 'Delete session?',
  '{p0} çalışma kaydı silinecek.': '{p0} of study will be deleted.',
  '{h} sa {m} dk': '{h} h {m} min',

  // Görevler ve notlar
  'Görevler': 'Tasks',
  'Görev': 'Task',
  'Görev ver': 'Assign task',
  'Görevi ver': 'Assign task',
  'ör. Paragraf 40 soru': 'e.g. 40 reading questions',
  'Açıklama (isteğe bağlı)': 'Description (optional)',
  'Hedef soru': 'Target questions',
  'Son gün': 'Due date',
  'Son gün {p0}': 'Due {p0}',
  'Göreve bir başlık yaz.': 'Give the task a title.',
  'Görev kaydedilemedi.': 'Couldn\'t save the task.',
  'Görev seçenekleri': 'Task options',
  'Görev silinsin mi?': 'Delete task?',
  '{p0} olarak işaretle': 'Mark as {p0}',
  'Yapmadım olarak işaretle': 'Mark as skipped',
  'Süresi geçti': 'Overdue',
  'Henüz görev yok.': 'No tasks yet.',
  'Henüz görev vermedin. "Görev ver"e dokun.':
      'You haven\'t assigned any tasks yet. Tap "Assign task".',
  'Bekleyen görevler': 'Pending tasks',
  'Bekleyen görev yok.': 'No pending tasks.',
  'Şu an görev yok.': 'No tasks right now.',
  'Notlar': 'Notes',
  'Öğrencine bir not ya da geri bildirim yaz…':
      'Write a note or feedback for your student…',
  'Henüz not yazmadın.': 'You haven\'t written any notes yet.',
  'Koçundan henüz not yok.': 'No notes from your coach yet.',
  'Not kaydedilemedi.': 'Couldn\'t save the note.',
  'Not silinsin mi?': 'Delete note?',
  'Bu not kalıcı olarak silinecek.': 'This note will be permanently deleted.',

  // Koç paneli
  'Merhaba {p0}': 'Hi {p0}',
  '{p0} öğrencin var': 'You have {p0} students',
  'Öğrenciler': 'Students',
  'Bekleyen': 'Pending',
  'görev': 'tasks',
  'soru çözüldü': 'questions solved',
  'Öğrenci adı veya numarası ara': 'Search by student name or number',
  '"{_query}" ile eşleşen öğrenci yok.': 'No students match "{_query}".',
  '{count} öğrencinin okul numarası eksik. Deneme sonuç dosyaları öğrencilere okul numarasıyla eşleştirilir; öğrenciye dokunup numarasını gir.':
      '{count} students are missing a school number. Exam result files are matched to students by school number — tap a student to add it.',
  'Henüz deneme yok': 'No exams yet',
  'Bu hafta {p0} soru · {p1}{p2}': 'This week {p0} questions · {p1}{p2}',
  'No yok': 'No number',
  'No: {number}': 'No: {number}',
  'Henüz öğrencin yok': 'You don\'t have any students yet',
  'Bir davet kodu oluştur ve öğrencine gönder. Kodla kayıt olan öğrenci otomatik olarak sana bağlanır.':
      'Create an invite code and send it to your student. Anyone who signs up with it is linked to you automatically.',
  'Öğrenci davet et': 'Invite student',
  'Öğrenciler yüklenemedi.': 'Couldn\'t load students.',
  'Kodu öğrencine gönder. Uygulamada "Davet kodum var" diyerek kayıt olduğunda sana bağlanır. Kodlar 14 gün geçerli.':
      'Send the code to your student. When they sign up via "I have an invite code" they\'re linked to you. Codes are valid for 14 days.',
  'Kaç öğrenci kullanabilsin?': 'How many students can use it?',
  '1 kişi': '1 person',
  '5 kişi': '5 people',
  'Sınıf (30)': 'Class (30)',
  'Kod oluştur': 'Create code',
  'Kod oluşturulamadı. Tekrar dene.':
      'Couldn\'t create a code. Please try again.',
  'Aktif kodların': 'Your active codes',
  'Aktif davet kodun yok.': 'You have no active invite codes.',
  'Kodlar yüklenemedi.': 'Couldn\'t load codes.',
  '{p0} kişilik hak kaldı · {p1} tarihine kadar': '{p0} uses left · until {p1}',
  '{code} kopyalandı': '{code} copied',
  'Davet kodun': 'Your invite code',
  'Tek öğrenci kullanabilir': 'One student can use it',
  '{maxUses} öğrenci kullanabilir': '{maxUses} students can use it',
  'Yeni kod': 'New code',
  'Sorular': 'Questions',
  'Okul no: {number}': 'School no.: {number}',
  'Okul numarası girilmemiş': 'No school number',
  'Deneme dosyaları bu numarayla eşleştirilir':
      'Exam files are matched using this number',
  'Okul numarası': 'School number',
  'ör. 1042': 'e.g. 1042',
  'Bu numara kurumda başka bir öğrenciye ait.':
      'This number belongs to another student in the institution.',
  'Numara en fazla 20 karakter olmalı; yalnızca rakam, harf ve tire.':
      'Use at most 20 characters: digits, letters and dashes only.',
  'henüz yok': 'none yet',
  '{p0} · {p1} net · {p2}': '{p0} · {p1} net · {p2}',
  'Koçu: {p0}': 'Coach: {p0}',
  'Son {p0} {p1} net': 'Latest {p0} {p1} net',

  // Kurum paneli
  'Koçlar': 'Coaches',
  'Davetler': 'Invites',
  'Öğrenci lisansı: {students} / {p0}': 'Student seats: {students} / {p0}',
  'Lisans dolu. Yeni öğrenci kaydı için lisans artırılmalı.':
      'All seats are used. Increase the license to add new students.',
  '{p0} öğrencilik yer var': '{p0} seats available',
  'Süresiz': 'No expiry',
  'Lisans süresi doldu ({expiry})': 'License expired ({expiry})',
  'Lisans bitişi: {expiry}': 'License ends: {expiry}',
  'Kurum adı': 'Institution name',
  'Kurum adını değiştir': 'Rename institution',
  'Ort. son TYT': 'Avg. latest TYT',
  '{p0} öğrenci': '{p0} students',
  '{noNumber} öğrencinin okul numarası eksik':
      '{noNumber} students are missing a school number',
  'Deneme dosyaları numarayla eşleştirildiği için numaraları gir.':
      'Exam files are matched by number, so please add them.',
  'Bu hafta hareketsiz öğrenciler': 'Inactive students this week',
  'Soru ya da çalışma kaydı olmayanlar': 'No questions or study logged',
  'Herkes bu hafta çalışmış. 🎉': 'Everyone studied this week. 🎉',
  'Koç: {p0}': 'Coach: {p0}',
  '{p0} · koçu': '{p0} · coach',
  'Koç değiştirildi.': 'Coach changed.',
  'Koç değiştirilemedi.': 'Couldn\'t change the coach.',
  'Ad veya okul numarası ara': 'Search by name or school number',
  'Tüm koçlar': 'All coaches',
  'Henüz öğrenci yok': 'No students yet',
  '"Davetler" sekmesinden bir koç için öğrenci davet kodu oluştur.':
      'Create a student invite code for a coach on the "Invites" tab.',
  'Bu hafta {p0} soru': 'This week {p0} questions',
  'Detay / okul numarası': 'Details / school number',
  'Koçunu değiştir': 'Change coach',
  'Koç davet et': 'Invite coach',
  'Henüz koç yok': 'No coaches yet',
  '"Koç davet et" ile kod oluştur ve koçuna gönder.':
      'Use "Invite coach" to create a code and send it to your coach.',
  '{p0} öğrenci · bu hafta {week} soru · {pending} bekleyen görev':
      '{p0} students · {week} questions this week · {pending} pending tasks',
  'Bu koça öğrenci daveti': 'Invite a student for this coach',
  'Öğrenci daveti': 'Student invite',
  'Kurumdaki aktif davet kodları. Kodlar 14 gün geçerli; kullanım hakkı dolan kodlar listeden düşer.':
      'Active invite codes in the institution. Codes are valid for 14 days; fully used codes drop off the list.',
  'Aktif davet yok': 'No active invites',
  'Koç ya da öğrenci daveti oluşturduğunda burada görünür.':
      'Coach and student invites you create will show up here.',
  '{p0} tarihine kadar': 'until {p0}',
  'İptal et': 'Revoke',
  'Davet iptal edilsin mi?': 'Revoke invite?',
  '{p0} artık kullanılamayacak.': '{p0} will no longer work.',
  'Öğrencinin bağlanacağı koçu seç.': 'Choose the coach for the student.',
  'Bağlanacağı koç': 'Coach',
  'Kaç kişi kullanabilsin?': 'How many people can use it?',
  '{_uses} kişi kullanabilir · 14 gün geçerli':
      '{_uses} people can use it · valid for 14 days',

  // Veli
  'Bağlı öğrenci yok': 'No linked student',
  'Çocuğunun profilinden oluşturduğu veli davet koduyla kayıt olduğunda gelişimi burada görünür.':
      'Once you sign up with the parent invite code from your child\'s profile, their progress shows up here.',
  '{name} bu hafta': '{name} this week',
  'Çözülen soru': 'Questions solved',
  'Çalışma': 'Study',
  'Aktif gün': 'Active days',
  'Son TYT neti': 'Latest TYT net',
  'TYT ortalaması': 'TYT average',

  // Grafik erişilebilirliği
  'Net {p0}': 'Net {p0}',
  'No {p0}': 'No. {p0}',
  'konu': 'topics',
  'dk': 'min',
  '{minutes} dk': '{minutes} min',
  '{h} sa': '{h} h',
  'hedef {goal}': 'goal {goal}',
  'Son {p0} gün: {p1}': 'Last {p0} days: {p1}',

  // Dil düğmeleri (aynı kalır)
  '🇬🇧 EN': '🇬🇧 EN',
  '🇹🇷 TR': '🇹🇷 TR',

  // Öğrenci ana sayfası: gökyüzü, sayaç, söz, kavanoz, seri, rozetler
  'Günaydın': 'Good morning',
  'İyi günler': 'Good afternoon',
  'İyi akşamlar': 'Good evening',
  'Merhaba gece kuşu': 'Hello night owl',
  'Bugünkü hedefi tutturdun, harikasın! 🎉':
      'You hit today\'s goal — amazing! 🎉',
  'Geç oldu; birkaç soru, sonra güzel bir uyku 🌙':
      'It\'s late — a few questions, then a good sleep 🌙',
  'Bugünün ilk sorusuyla başlayalım mı?':
      'Shall we start with today\'s first question?',
  'Hedefe {n} soru kaldı, az kaldı!':
      '{n} questions to your goal — almost there!',
  'Bugün {n} soru çözdün, süpersin!':
      'You solved {n} questions today, superstar!',
  '{n} gündür buradasın, seriyi bozmayalım 🔥':
      '{n} days in a row — let\'s keep the streak 🔥',
  'Sabah zihni taze olur, zor konular şimdi!':
      'Morning minds are fresh — tackle the hard topics now!',
  'Kısa bir mola, bir bardak su, sonra devam 💧':
      'A short break, a glass of water, then back to it 💧',
  'Akşam tekrarı, öğrendiklerini kalıcı yapar.':
      'An evening review makes what you learned stick.',
  'Uyku da çalışmanın bir parçası, unutma 😴':
      'Sleep is part of studying too, don\'t forget 😴',
  'Bana dokunursan yeni bir şey söylerim 🐝':
      'Tap me and I\'ll say something new 🐝',
  'YKS {year} için {days} gün kaldı': '{days} days left until YKS {year}',
  'YKS {year} için geri sayım': 'Countdown to YKS {year}',
  'ÖSYM tarihi açıklayınca güncellenecek':
      'Will be updated when ÖSYM announces the date',
  'tahmini': 'estimated',
  'gün': 'days',
  'sa': 'h',
  'sn': 's',
  'Bugün o gün! Sakin ol, sen hazırsın. 🍀':
      'Today\'s the day! Stay calm, you\'re ready. 🍀',
  'Son viraj: tekrar, deneme ve iyi uyku.':
      'Final stretch: review, mock exams and good sleep.',
  'Son 100 gün! Deneme temposunu artır.':
      'Last 100 days! Step up your mock exams.',
  'Tempoyu artırma zamanı, her gün say.':
      'Time to pick up the pace — every day counts.',
  'Uzun bir yol, ama her gün bir adım yeter.':
      'A long road, but one step a day is enough.',
  'Hazırlık yolculuğunun %{p}\'i geride': '{p}% of your prep journey done',
  'Söz kopyalandı': 'Quote copied',
  'Günün sözü': 'Quote of the day',
  'Yarın yeni bir söz seni bekliyor 🐝': 'A new quote awaits you tomorrow 🐝',
  'Atasözü': 'Proverb',
  'Latin atasözü': 'Latin proverb',
  'Aristoteles': 'Aristotle',
  'Konfüçyüs': 'Confucius',
  'Sokrates': 'Socrates',
  'Mevlânâ': 'Rumi',
  'Bal kavanozu': 'Honey jar',
  'Bu haftanın soruları': 'This week\'s questions',
  'hedef koyunca dolmaya başlar': 'set a goal to start filling',
  'Art arda çalışılan günler': 'Days studied in a row',
  '{n} gün seri': '{n}-day streak',
  'Bugün başla, seriyi yak!': 'Start today, light the streak!',
  'İlk adım': 'First step',
  'İlk soru kaydını gir.': 'Log your first questions.',
  '3 gün seri': '3-day streak',
  'Üç gün üst üste çalış.': 'Study three days in a row.',
  '100 soru': '100 questions',
  'Toplam 100 soru çöz.': 'Solve 100 questions in total.',
  'İlk deneme': 'First exam',
  'İlk deneme sonucun sisteme girilsin.':
      'Get your first exam result recorded.',
  'Haftalık seri': 'Weekly streak',
  'Yedi gün üst üste çalış.': 'Study seven days in a row.',
  'Odak ustası': 'Focus master',
  'Toplam 10 saat odaklan.': 'Focus for 10 hours in total.',
  'Konu avcısı': 'Topic hunter',
  '10 konuyu bitir.': 'Finish 10 topics.',
  'Bin soru': 'Thousand questions',
  'Toplam 1000 soru çöz.': 'Solve 1,000 questions in total.',
  'Aylık seri': 'Monthly streak',
  'Otuz gün üst üste çalış.': 'Study thirty days in a row.',
  'Soru makinesi': 'Question machine',
  'Toplam 5000 soru çöz.': 'Solve 5,000 questions in total.',
  'Rozetlerim': 'My badges',
  '{open}/{all} rozet açıldı': '{open}/{all} badges unlocked',
  'açıldı': 'unlocked',
  'kilitli': 'locked',
  'Rozet açıldı! 🎉': 'Badge unlocked! 🎉',
  'Hızlı doğru:': 'Quick correct:',
  'Ders tamamlandı': 'Subject complete',
  '{p0} tamamen bitti, altın madalya senin! 🏅':
      '{p0} is fully done — the gold medal is yours! 🏅',
  '{done} / {all} konu bitti': '{done} / {all} topics done',

  // Ödevler, bildirimler, geri tuşu
  '"{q}" ile eşleşen konu yok': 'No topic matches "{q}"',
  '"{title}" öğrencinin listesinden kaldırılacak.':
      '"{title}" will be removed from the student\'s list.',
  '{done}/{all} tamam': '{done}/{all} done',
  '{from} sana {n} maddelik ödev gönderdi':
      '{from} sent you homework with {n} items',
  '{n} dk önce': '{n} min ago',
  '{n} gün kaldı': '{n} days left',
  '{n} gün önce': '{n} days ago',
  '{n} madde · {q} soru': '{n} items · {q} questions',
  '{n} maddelik yeni bir ödevin var': 'You have new homework with {n} items',
  '{n} sa önce': '{n} h ago',
  '{name} için {n} madde · {q} soru': '{n} items · {q} questions for {name}',
  '{subject} konularında ara': 'Search {subject} topics',
  '{subject} ödevi': '{subject} homework',
  'Artır': 'Increase',
  'az önce': 'just now',
  'Azalt': 'Decrease',
  'Başka bir isim ya da numara dene.': 'Try another name or number.',
  'Bekleyen ödevin yok. 🎉': 'No pending homework. 🎉',
  'Bildirimler': 'Notifications',
  'Bugün son gün': 'Due today',
  'Bütün ödevlerin bitti, süpersin! 🎉':
      'All your homework is done — superstar! 🎉',
  'Çıkmak için tekrar geri bas': 'Press back again to exit',
  'Deneme sonucun geldi': 'Your exam result is in',
  'Genel tekrar': 'General review',
  'Gönderilemedi. Tekrar dene.': 'Couldn\'t send. Try again.',
  'Haftalık ödev': 'Weekly homework',
  'Henüz bildirim yok': 'No notifications yet',
  'Henüz ödev vermedin. "Ödev ver"e dokun.':
      'No homework yet. Tap "Assign homework".',
  'Henüz ödev yok.': 'No homework yet.',
  'Henüz ödevin yok': 'No homework yet',
  'İsim veya okul numarası': 'Name or school number',
  'Kime ödev vereceksin?': 'Who gets the homework?',
  'Koçun ödev gönderdiğinde burada göreceksin.':
      'You\'ll see homework here when your coach sends it.',
  'Koçun ödev, görev ya da deneme sonucu gönderince burada göreceksin.':
      'You\'ll see it here when your coach sends homework, a task or an exam result.',
  'Koçundan yeni not': 'New note from your coach',
  'Koçunun gönderdiği ödevler': 'Homework from your coach',
  'Konu seçmeden tüm {subject}': 'All of {subject}, no specific topic',
  'Konulara dokunarak sepete ekle': 'Tap topics to add them to the basket',
  'Okul numarası yok': 'No school number',
  'Ödev {name} adlı öğrenciye gönderildi 🐝': 'Homework sent to {name} 🐝',
  'Ödev başlığı': 'Homework title',
  'Ödev sepeti': 'Homework basket',
  'Ödev silinsin mi?': 'Delete homework?',
  'Ödev tamamlandı, harikasın! 🎉': 'Homework complete — amazing! 🎉',
  'Ödev ver': 'Assign homework',
  'Ödeve bir başlık ver.': 'Give the homework a title.',
  'Ödevler': 'Homework',
  'Ödevlerim': 'My homework',
  'Öğrenci bulunamadı': 'No student found',
  'Öğrenciye gönder': 'Send to student',
  'Öğrenciye not (isteğe bağlı)': 'Note to student (optional)',
  'Önce öğrencilerini davet et.': 'Invite your students first.',
  'Sepeti gör': 'View basket',
  'Sepetten çıkar': 'Remove from basket',
  'Son tarih yok': 'No due date',
  'Son tarih: {date}': 'Due: {date}',
  'Son tarihi kaldır': 'Remove due date',
  'Tamamlananlar ({n})': 'Completed ({n})',
  'Tümü': 'All',
  'Yarın son gün': 'Due tomorrow',
  'Yeni görev': 'New task',
  'Yeni ödev: {title}': 'New homework: {title}',

  // White label: dershaneler
  '{name} dershanesinin müdürü bu kodla ya da linkle kayıt olur. Kod 14 gün geçerli ve tek kullanımlık.':
      'The director of {name} signs up with this code or link. It is single-use and valid for 14 days.',
  '{name} için erişim şu an kapalı. Kurumunla iletişime geç.':
      'Access to {name} is currently closed. Please contact your institution.',
  '3-32 karakter: küçük harf, rakam ve tire.':
      '3-32 characters: lowercase letters, digits and hyphens.',
  'Aktif': 'Active',
  'Ana renk': 'Primary color',
  'Bu dershane kodu kullanılıyor, başka bir kod seç.':
      'This code is already taken, pick another one.',
  'Bu hesap seçtiğin dershaneye ait değil. Dershane kodunu kontrol et.':
      'This account doesn\'t belong to the selected school. Check the school code.',
  'Bu kodla aktif bir dershane bulunamadı.':
      'No active school found with this code.',
  'Davet linki kopyalandı': 'Invite link copied',
  'Davet linkini kopyala': 'Copy invite link',
  'Dershane adı': 'School name',
  'Dershane bilgisi alınamadı. İnternet bağlantını kontrol et.':
      'Couldn\'t load the school. Check your internet connection.',
  'Dershane bulunamadı': 'School not found',
  'Dershane ekle, logo ve renkleri düzenle':
      'Add schools, edit logos and colors',
  'Dershane kaydedildi.': 'School saved.',
  'Dershane kodu': 'School code',
  'Dershane kodu (slug)': 'School code (slug)',
  'Dershane kodu küçük harf, rakam ve tire içerir.':
      'A school code uses lowercase letters, digits and hyphens.',
  'Dershane kodun var mı?': 'Have a school code?',
  'Dershane linkini kopyala': 'Copy school link',
  'Dershane yönetimi': 'School management',
  'Dershane: {name}. Değiştir': 'School: {name}. Change',
  'Dershaneler': 'Schools',
  'Dershanenin sana verdiği kodu gir (örn. bal-akademi).':
      'Enter the code your school gave you (e.g. bal-akademi).',
  'Dershaneyi düzenle': 'Edit school',
  'Dershaneyi oluştur': 'Create school',
  'En az 2 karakter olmalı.': 'Must be at least 2 characters.',
  'Girişe dön': 'Back to sign in',
  'Girişte ve linklerde kullanılır: küçük harf, rakam, tire.':
      'Used at sign-in and in links: lowercase letters, digits, hyphens.',
  'Henüz dershane yok': 'No schools yet',
  'İkincil renk': 'Secondary color',
  'İlk dershaneyi "Yeni dershane" ile ekle.':
      'Add the first school with "New school".',
  'Kodu kaldır': 'Remove code',
  'Kodu kopyala': 'Copy code',
  'Kurum müdürü davet kodu oluştur': 'Create director invite code',
  'Kurum müdürü daveti': 'Director invite',
  'Link eski ya da dershane şu an aktif değil. Kurumundan yeni link iste.':
      'The link is old or the school isn\'t active right now. Ask your institution for a new link.',
  'Link kopyalandı': 'Link copied',
  'Linki kopyala': 'Copy link',
  'Logo': 'Logo',
  'Logo en fazla 1 MB olabilir.': 'The logo can be at most 1 MB.',
  'Logo seç': 'Choose logo',
  'Logo seçilemedi.': 'Couldn\'t pick the logo.',
  'Logoyu kaldır': 'Remove logo',
  'Öğrenci lisansı (koltuk)': 'Student licenses (seats)',
  'Pasif': 'Inactive',
  'Pasif dershanenin kullanıcıları giriş yapsa da verilerine erişemez.':
      'Users of an inactive school can sign in but can\'t access their data.',
  'PNG, JPG ya da WebP · en fazla 1 MB · kare ve şeffaf zeminli önerilir':
      'PNG, JPG or WebP · max 1 MB · square with a transparent background recommended',
  'Tema önizlemesi': 'Theme preview',
  'Yeni dershane': 'New school',

  // Avatar
  'Saç': 'Hair',
  'Ten': 'Skin',
  'Kıyafet': 'Outfit',
  'Aksesuar': 'Accessory',
  '"{badge}" rozetini aç': 'Unlock the "{badge}" badge',
  '{exam} denemesinde {n} net yap': 'Score {n} net in a {exam} exam',
  '{n} gün üst üste çalış': 'Study {n} days in a row',
  '{n} yeni avatar parçası açıldı! 🎉': '{n} new avatar items unlocked! 🎉',
  '{name} (sen)': '{name} (you)',
  '{rank}. sıra, {name}, {n} soru': 'Rank {rank}, {name}, {n} questions',
  'Açmak için: {rule}': 'To unlock: {rule}',
  'Avatar önizlemesi': 'Avatar preview',
  'Avatarım': 'My avatar',
  'Avatarın': 'Your avatar',
  'Avatarın kaydedildi 🐝': 'Avatar saved 🐝',
  'Avatarın yalnızca seçtiğin parçalardan oluşur; fotoğraf kullanılmaz.':
      'Your avatar is made only of the items you pick; no photos are used.',
  'Avatarını düzenle': 'Edit your avatar',
  'Bu hafta soru çözen ilk arı sen ol!':
      'Be the first bee to solve questions this week!',
  'Bu parça henüz açılmadı.': 'This item isn\'t unlocked yet.',
  'Çık': 'Leave',
  'Çıkarsan yaptığın değişiklikler kaybolur.':
      'If you leave, your changes will be lost.',
  'Daha fazla': 'Load more',
  'Değişiklikler kaydedilmedi': 'Unsaved changes',
  'Dershanendeki haftalık soru sıralaması':
      'Weekly question ranking at your school',
  'Gör': 'View',
  'Haftanın arıları': 'Bees of the week',
  'Henüz sıralama yok': 'No ranking yet',
  'Herkese açık': 'Free for everyone',
  'İnternet bağlantını kontrol edip aşağı çek.':
      'Check your connection and pull down to retry.',
  'Kaydedildi': 'Saved',
  'Kilitli': 'Locked',
  'Kilitli parça': 'Locked item',
  'Seçili': 'Selected',
  'Sıralama yüklenemedi': 'Couldn\'t load the ranking',
  'Son 7 günde çözülen sorulara göre, dershanendeki öğrenciler.':
      'Students at your school, by questions solved in the last 7 days.',
  'Yakında': 'Coming soon',
  'Yok': 'None',

  // Hesap silme kuralları
  'Öğrenci hesabını yalnızca koçun silebilir.':
      'Only your coach can delete a student account.',
  'Diğer': 'More',
  'Öğrenci hesabını sil': 'Delete student account',
  'Öğrenci hesabı silinsin mi?': 'Delete student account?',
  '{name} adlı öğrencinin hesabı ve tüm verileri (denemeler, soru kayıtları, ödevler, notlar) kalıcı olarak silinir. Bu işlem geri alınamaz.':
      '{name}\'s account and all data (exams, question logs, homework, notes) will be permanently deleted. This can\'t be undone.',
  'Onaylamak için SİL yaz': 'Type SİL to confirm',
  'Kalıcı olarak sil': 'Delete permanently',
  'Öğrenci hesabı silindi.': 'Student account deleted.',
  'Bu öğrenciyi silme yetkin yok.':
      'You\'re not allowed to delete this student.',

  // Hesap silme talebi
  'Hesabımın silinmesini iste': 'Request deletion of my account',
  'Talebin koçuna iletilir; hesabını ve tüm verilerini koçun siler.':
      'Your request goes to your coach, who deletes your account and all your data.',
  'Hesabının silinmesini istiyor musun?': 'Do you want your account deleted?',
  'Talebin koçuna iletilir. Koçun hesabını sildiğinde tüm verilerin (denemeler, soru kayıtları, çalışma süreleri, görevler, notlar) kalıcı olarak silinir. Fikrini değiştirirsen talebi geri alabilirsin.':
      'Your request goes to your coach. When your coach deletes your account, all your data (exams, question logs, study time, tasks, notes) is permanently deleted. You can withdraw the request if you change your mind.',
  'Talep gönder': 'Send request',
  'Talebin koçuna iletildi.': 'Your request was sent to your coach.',
  'Hesap silme talebin iletildi': 'Account deletion requested',
  '{date} tarihinde istedin. Hesabını koçun silecek.':
      'You asked on {date}. Your coach will delete your account.',
  'Geri al': 'Withdraw',
  'Hesap silme talebin geri alındı.':
      'Your account deletion request was withdrawn.',
  'İşlem yapılamadı. Tekrar dene.': 'Something went wrong. Try again.',
  'Hesap silme talebi': 'Account deletion request',
  '{name} hesabının silinmesini istedi':
      '{name} asked for their account to be deleted',
  '{date} tarihinde hesabının silinmesini istedi.':
      'Asked on {date} for their account to be deleted.',
  'Hesabı sil': 'Delete account',

  // Kurum görünümü (müdür)
  'Bunu yalnızca kurum müdürü değiştirebilir.':
      'Only the institution director can change this.',
  'Kurum görünümü': 'Institution branding',
  'Kurum görünümü kaydedildi. Koç ve öğrencilerin uygulamayı yenileyince görür.':
      'Branding saved. Your coaches and students will see it after they refresh the app.',
  'Kurum linkini kopyala': 'Copy institution link',
  // Başarı sıralaması
  'Başarı sıralaması': 'Success ranking',
  'Başarı sıralaması açıldı. Öğrenciler artık görebilir.':
      'Success ranking is on. Students can see it now.',
  'Başarı sıralaması kapatıldı.': 'Success ranking is off.',
  'Bu bir önizleme. Öğrenciler, sen açana kadar göremez.':
      'This is a preview. Students can\'t see it until you turn it on.',
  'Bu türde denemesi olan öğrenci yok.':
      'No students have mock exams of this type yet.',
  'Deneme sonuçların girilince sıralamaya katılırsın.':
      'You\'ll join the ranking once your mock exam results are in.',
  'Kurumun başarı sıralamasını açtığında burada göreceksin.':
      'You\'ll see it here once your institution turns on the success ranking.',
  'Son 5 denemenin ortalama netine göre, kurumundaki öğrenciler.':
      'Students in your institution, by average net of their last 5 mock exams.',
  'Sıralama kapalı': 'Ranking is off',
  'Sıralamayı gör': 'View ranking',
  'Sıranı korudukça avatarında kalır.':
      'They stay on your avatar as long as you keep your place.',
  'TYT ödülleri': 'TYT rewards',
  'Başarı sıralaması · TYT\'de {rank}.': 'Success ranking · #{rank} in TYT',
  '{net} net': '{net} net',
  '{n} deneme': '{n} mock exams',
  '{rank}. sıra, {name}, {net} net': 'Rank {rank}, {name}, {net} net',
  'Önizle': 'Preview',
  'Öğrenciler son 5 denemelerinin ortalamasına göre sıralanır. TYT\'de 1. kral tacı, ilk 3 altın kanat, 4. ve 5. gümüş kanat kazanır.':
      'Students are ranked by the average of their last 5 mock exams. In TYT, #1 gets a king\'s crown, the top 3 get golden wings, and #4–5 get silver wings.',
  'İlk 3': 'Top 3',
  '1.': '#1',
  '4. ve 5.': '#4 and #5',
  'Kral tacı': 'King\'s crown',
  'Altın kanatlar': 'Golden wings',
  'Gümüş kanatlar': 'Silver wings',
  // Koç ve müdür panelleri
  'Bu hafta hareketsiz': 'Inactive this week',
  'Bu hafta öğrencilerin {n} soru çözdü 🐝':
      'Your students solved {n} questions this week 🐝',
  'Davet et': 'Invite',
  'Deneme yükle': 'Upload exams',
  'Hadi ilk öğrencini davet edelim! 🐝': 'Let\'s invite your first student! 🐝',
  'Herkes bu hafta çalışmış, süper takım! 🎉':
      'Everyone studied this week, great team! 🎉',
  'Lisans doldu; yeni öğrenci için lisansı artırmalısın.':
      'Your licence is full; increase it to add new students.',
  'Lisansta {n} öğrencilik yer kaldı.':
      '{n} student seats left on your licence.',
  '{c} koç ve {s} öğrenciyle çalışıyorsun.':
      'You work with {c} coaches and {s} students.',
  '{name} bu haftanın yıldızı: {n} soru! ⭐':
      '{name} is this week\'s star: {n} questions! ⭐',
  '{n} aktif': '{n} active',
  '{n} görev bekliyor': '{n} tasks pending',
  '{n} görev öğrencilerinde bekliyor.':
      '{n} tasks are waiting on your students.',
  '{n} öğrenci': '{n} students',
  '{n} öğrencin bu hafta hiç çalışmadı. Bir not bıraksan?':
      '{n} of your students haven\'t studied this week. Leave them a note?',
  'Öğrencilerin': 'Your students',
  // Deneme yüklemeleri
  '"{name}" ve tüm ders sonuçları silinecek. Bu işlem geri alınamaz.':
      '"{name}" and all its subject results will be deleted. This can\'t be undone.',
  '"{name}" {n} öğrenciden silindi.': '"{name}" was deleted from {n} students.',
  '"{name}" {n} öğrencinin hepsinden silinecek; sonuçları ve bildirimleri de gider. Bu işlem geri alınamaz.':
      '"{name}" will be deleted from all {n} students, along with its results and notifications. This can\'t be undone.',
  '7 günden eski; silinemez': 'Older than 7 days; can\'t be deleted',
  'Bu deneme 7 günden eski; artık silinemez.':
      'This exam is older than 7 days and can no longer be deleted.',
  'Bu deneme 7 günden eski; silinemez ve değiştirilemez.':
      'This exam is older than 7 days; it can\'t be deleted or edited.',
  'Bugün kilitleniyor': 'Locks today',
  'Excel\'den yüklediğin ya da elle girdiğin denemeler burada listelenir.':
      'Exams you upload from Excel or enter by hand are listed here.',
  'Henüz deneme yüklemedin': 'You haven\'t uploaded any exams yet',
  'Herkesten sil': 'Delete for everyone',
  'Son denemeyi herkesten sil': 'Delete latest exam for everyone',
  'Son yüklenen deneme': 'Latest upload',
  'Son yüklenen deneme herkesten silinsin mi?':
      'Delete the latest upload for everyone?',
  'Tüm yüklemeler': 'All uploads',
  'Yanlış dosya ya da hatalı sonuç mu yükledin? Bu denemeyi {n} öğrencinin hepsinden tek seferde kaldırabilirsin.':
      'Uploaded the wrong file or wrong results? You can remove this exam from all {n} students at once.',
  'Yüklediğin denemeler': 'Your uploaded exams',
  'Yüklediğin denemeleri 7 gün içinde silebilirsin. Daha eskiler kilitlenir ve öğrencilerin kayıtlarında kalır.':
      'You can delete exams you uploaded within 7 days. Older ones are locked and stay in students\' records.',
  'ort. {net} net': 'avg. {net} net',
  '{date} yüklendi': 'uploaded {date}',
  '{n} gün daha silinebilir': 'deletable for {n} more days',
  '{n} yükleme · son yüklenen en üstte': '{n} uploads · latest first',
  // Ortak sekmeler ve veli paneli (yeni tasarım)
  '/ {n} hedef': '/ {n} goal',
  '/ {time} hedef': '/ {time} goal',
  '{n} gün': '{n} days',
  '{n} kayıt': '{n} entries',
  '{n} ders': '{n} subjects',
  'Dersler': 'Subjects',
  '{done} / {all} konu': '{done} / {all} topics',
  // Görüşmeler
  'Yapıldı': 'Held',
  'İptal': 'Cancelled',
  'Her {day} {time}': 'Every {day} {time}',
  'Planlı': 'Scheduled',
  'İşaretlenmedi': 'Not marked',
  'Yarın': 'Tomorrow',
  'Dün': 'Yesterday',
  'Görüşme yapıldı': 'Meeting held',
  'Görüşme yapılmadı': "Meeting didn't happen",
  'Bu haftalık iptal': 'Cancel this week',
  'İşareti kaldır': 'Clear mark',
  'Görüşme saati gelince "yapıldı" ya da "yapılmadı" olarak işaretleyebilirsin.':
      'Once the meeting time comes, you can mark it as "held" or "didn\'t happen".',
  '{n} dk': '{n} min',
  'Bu haftaki görüşmeler': "This week's meetings",
  'Öğrenciye dokunup görüşme ekleyebilirsin': 'Tap a student to add a meeting',
  '{held} / {n} görüşme yapıldı': '{held} / {n} meetings held',
  'Bu hafta planlı görüşme yok. Haftalık rutin için öğrencinin sayfasında "Görüşme ekle"ye dokun.':
      'No meetings scheduled this week. For a weekly routine, tap "Add meeting" on the student\'s page.',
  'Rutin görüşme bitirilsin mi?': 'End the recurring meeting?',
  'Görüşme kaldırılsın mı?': 'Remove the meeting?',
  '"{p0}" görüşmeleri bundan sonra planlanmaz. Geçmiş görüşme kayıtları kalır.':
      '"{p0}" meetings won\'t be scheduled from now on. Past meeting records are kept.',
  '{p0} görüşmesi kaldırılacak.': 'The {p0} meeting will be removed.',
  'Bitir': 'End',
  'Kaldır': 'Remove',
  'Görüşmeler': 'Meetings',
  'Haftalık rutin ya da tek seferlik': 'Weekly routine or one-off',
  'Görüşme ekle': 'Add meeting',
  'Henüz planlı görüşme yok. "Görüşme ekle" ile her hafta aynı gün ve saatte tekrarlanan bir görüşme planlayabilirsin.':
      'No meetings scheduled yet. With "Add meeting" you can plan a meeting that repeats every week on the same day and time.',
  'Planlı görüşme yok.': 'No meetings scheduled.',
  'Rutini bitir': 'End routine',
  'Görüşmeyi kaldır': 'Remove meeting',
  'Koçunla görüşme: {when}': 'Meeting with your coach: {when}',
  'Koçunla görüşme': 'Meeting with your coach',
  '{coach} ile görüşme': 'Meeting with {coach}',
  'Koç görüşmeleri': 'Coach meetings',
  'Bu hafta · {r}': 'This week · {r}',
  'Önceki hafta': 'Previous week',
  'Sonraki hafta': 'Next week',
  'Henüz koç yok.': 'No coaches yet.',
  '{held} / {n} yapıldı': '{held} / {n} held',
  'Bu hafta planlı görüşme yok.': 'No meetings scheduled this week.',
  'Görüşme zamanı geçmiş olamaz.': "The meeting time can't be in the past.",
  'Rutin görüşme planlandı: her {day} {time} 🐝':
      'Recurring meeting scheduled: every {day} {time} 🐝',
  'Görüşme planlandı 🐝': 'Meeting scheduled 🐝',
  'Her hafta': 'Every week',
  'Tek sefer': 'One-off',
  'Gün': 'Day',
  'Saat': 'Time',
  'Not (isteğe bağlı)': 'Note (optional)',
  'ör. Haftalık değerlendirme': 'e.g. Weekly review',
  'Her {day} {time}. İlk görüşme {first}. Öğrenciye her görüşmeden 24 saat önce bildirim gider.':
      'Every {day} {time}. First meeting {first}. The student is notified 24 hours before each meeting.',
  '{day} {time}. Öğrenciye görüşmeden 24 saat önce bildirim gider.':
      '{day} {time}. The student is notified 24 hours before the meeting.',
  'Görüşmeyi kaydet': 'Save meeting',
  'Görüşme hatırlatması': 'Meeting reminder',
  'Koçunla görüşmen yaklaşıyor': 'Your meeting with your coach is coming up',
  '{day} {time} · koçunla görüşmen var':
      '{day} {time} · you have a meeting with your coach',
  '{day} {time} · {coach} ile görüşmen var':
      '{day} {time} · you have a meeting with {coach}',
  // Pomodoro alarmı
  'Bal Kavanozu': 'Honey Jar',
  'Arı Vızıltısı': 'Bee Buzz',
  'Kristal': 'Crystal',
  'Marimba': 'Marimba',
  'Gong': 'Gong',
  'Yalnızca titreşim': 'Vibration only',
  'Çalışan zamanlayıcı': 'Running timer',
  'Pomodoro sürerken geri sayım': 'Countdown while a pomodoro runs',
  'Pomodoro: {tone}': 'Pomodoro: {tone}',
  'Pomodoro ve mola bitince': 'When a pomodoro or break ends',
  'Kronometre · {subject}': 'Stopwatch · {subject}',
  'Çalışma süren sayılıyor': 'Counting your study time',
  'Pomodoro bitti! 🐝': 'Pomodoro done! 🐝',
  '{n} dakikalık odak tamamlandı. Mola zamanı.':
      '{n}-minute focus complete. Time for a break.',
  'Odak · {subject}': 'Focus · {subject}',
  'Bitince {tone}': 'Then {tone}',
  'Mola bitti': 'Break over',
  'Yeni bir pomodoroya hazır mısın? 🐝': 'Ready for another pomodoro? 🐝',
  'Zilin tam zamanında çalması için "Alarmlar ve hatırlatıcılar" iznini aç.':
      'Turn on "Alarms & reminders" so the bell rings right on time.',
  'İzin ver': 'Allow',
  'Uygulamadan çıksan da süre bitince: {tone}':
      'Even if you leave the app, when time is up: {tone}',
  'Bitiş sesi': 'End sound',
  'Pomodoro ve mola bitince çalar; uygulama kapalıyken de. Dinlemek için dokun.':
      'Plays when a pomodoro or break ends, even when the app is closed. Tap to listen.',
  'Seç': 'Choose',
  // Sesler
  'Görünüm, dil ve ses': 'Appearance, language and sound',
  'Sesler': 'Sounds',
  'Bızz’a dokununca ve uygulama açılırken çalan sesler':
      'Sounds when you tap Bızz and when the app opens',
  // Kurum yazı tipi
  'Kurum görünümü: logo, renk ve yazı tipi': 'Branding: logo, colors and font',
  'Yazı tipi': 'Font',
  'Yuvarlak': 'Rounded',
  'Geometrik': 'Geometric',
  'Klasik tırnaklı': 'Classic serif',
  'Zarif': 'Elegant',
  'Kalın tırnaklı': 'Slab serif',
  'Dar ve uzun': 'Condensed',
  'Tombul ve neşeli': 'Chunky & playful',
  'El yazısı': 'Handwriting',
  'Daktilo': 'Typewriter',
  'Fütüristik': 'Futuristic',
  'Kurumdaki herkes (koçlar, öğrenciler, veliler) uygulamayı bu yazı tipiyle görür.':
      'Everyone in your institution (coaches, students, parents) sees the app in this font.',
  'Ayrıntılar': 'Details',
  'Yükle': 'Upload',
  'Denemeler, sorular, konular ve çalışma süresi':
      'Exams, questions, topics and study time',
  'Gelişim': 'Progress',
  'Çocuğun kayıt olunca gelişimini birlikte izleriz! 🐝':
      "Once your child signs up, we'll follow their progress together! 🐝",
  '{name} bu hafta {n} soru çözdü 🐝':
      '{name} solved {n} questions this week 🐝',
  '{name} bu hafta henüz soru girmedi.':
      "{name} hasn't logged any questions this week yet.",
  'Bu hafta {time} çalıştı ⏱️': 'Studied {time} this week ⏱️',
  'Son 7 günün {n} gününde çalıştı.': 'Studied on {n} of the last 7 days.',
  'Küçük bir moral mesajı bu hafta çok iyi gelebilir 💛':
      'A little word of encouragement could go a long way this week 💛',
  'Son TYT denemesinde {net} net, öncekinden {d} fazla! 📈':
      'Scored {net} net on the last TYT exam, {d} more than before! 📈',
  'Son TYT denemesinde {net} net yaptı.':
      'Scored {net} net on the last TYT exam.',

  // Kayıt: şifre tekrarı ve e-posta doğrulama kodu
  'Şifre (tekrar)': 'Password (again)',
  'Şifreler birbiriyle eşleşmiyor': 'Passwords do not match',
  'Geçerli bir e-posta gir (ör. ad@gmail.com)':
      'Enter a valid email (e.g. name@gmail.com)',
  'E-posta adresini kontrol et': 'Check your email address',
  'Bunu mu demek istedin: {email}?': 'Did you mean {email}?',
  'Hayır, böyle kalsın': 'No, keep it',
  'Evet, düzelt': 'Yes, fix it',
  'Devam et: e-postamı doğrula': 'Continue: verify my email',
  'Bilgiler': 'Details',
  'Doğrulama': 'Verify',
  '{email} adresine bir doğrulama kodu gönderdik.':
      'We sent a verification code to {email}.',
  'Kodu aşağıya yaz; hesabın o zaman açılır. Gelmediyse istenmeyen (spam) klasörüne de bak.':
      'Enter the code below to open your account. If it hasn’t arrived, check your spam folder too.',
  'Doğrulama kodu': 'Verification code',
  'Doğrula ve hesabımı aç': 'Verify and open my account',
  'Kodu yeniden gönder ({n} sn)': 'Resend code ({n} s)',
  'Kodu yeniden gönder': 'Resend code',
  'E-posta adresini değiştir': 'Change email address',
  'E-postana gelen kodu eksiksiz gir.': 'Enter the full code from your email.',
  'Yeni kod gönderildi.': 'A new code has been sent.',
  'Kod hatalı ya da süresi dolmuş. Yeni kod isteyebilirsin.':
      'The code is wrong or has expired. You can request a new one.',
  'Bu e-posta adresi geçerli değil.': 'This email address is not valid.',

  // Telefonu salla: Bızz değişimi
  'Arılar dinleniyor 😴 {n} dk sonra yine salla.':
      'The bees are resting 😴 Shake again in {n} min.',
  'Nöbet değişimi! Şimdi sıra bende 🐝': 'Shift change! My turn now 🐝',
  'Pardon, çarptım! Ama enerjim tam ⚡':
      'Oops, sorry for the bump! But I’m fully charged ⚡',
  'Yeni arı, yeni enerji! Hadi bir soru daha 💪':
      'New bee, new energy! One more question 💪',
  'Vızz! Arkadaşım mola verdi, ben buradayım 😄':
      'Bzz! My friend is on a break, I’m here now 😄',

  // Avatar: yeni açılma koşulları
  'Toplam {n} soru çöz': 'Solve {n} questions in total',
  'Toplam {n} saat odaklan': 'Focus for {n} hours in total',
  '{n} konuyu bitir': 'Finish {n} topics',
  '{n} denemeye gir': 'Take {n} practice exams',

  // Haftanın Bal Raporu
  'İstikrar Arısı': 'Steady Bee',
  'Keskin Nişancı Arı': 'Sharpshooter Bee',
  'Gece Kuşu Arı': 'Night Owl Bee',
  'Sabahçı Arı': 'Early Bird Bee',
  'Maratoncu Arı': 'Marathon Bee',
  'Soru Avcısı Arı': 'Question Hunter Bee',
  "Haftanın her günü kovandaydın. Bu istikrar YKS'de altın değerinde.":
      'You were in the hive every day this week. That consistency is gold for the exam.',
  'Az yanlış, çok doğru. Soruları gözünü kırpmadan vurdun.':
      'Few mistakes, lots of right answers. You hit every question dead on.',
  'Şehir uyurken sen çalıştın. Uykunu da ihmal etme!':
      'You studied while the city slept. Don’t forget to sleep too!',
  'Güneşten önce kalktın, balı ilk sen topladın.':
      'Up before the sun, you collected the honey first.',
  'Uzun ve derin odaklandın. Dikkat kasın çok güçlü.':
      'Long, deep focus. Your attention muscle is strong.',
  'Soruları tek tek avladın. Kovan seninle gurur duyuyor.':
      'You hunted down question after question. The hive is proud of you.',
  'Bu hafta kovan sessiz. Raporu doldurmaya başla!':
      'The hive is quiet this week. Start filling your report!',
  '{n} soru · {d} aktif gün · {emoji} {persona}':
      '{n} questions · {d} active days · {emoji} {persona}',
  'Haftanın Bal Raporu': 'Weekly Honey Report',
  'YENİ · HAFTALIK': 'NEW · WEEKLY',
  'İzle': 'Watch',
  'Bu haftaki Bal Raporum 🐝 #Mentoria':
      'My Honey Report this week 🐝 #Mentoria',
  'Önceki': 'Previous',
  'Sonraki': 'Next',
  '{name}, haftanın Bal Raporu hazır!':
      '{name}, your weekly Honey Report is ready!',
  'Bu hafta kovanda neler yaptığına bir bakalım. 🐝':
      'Let’s see what you did in the hive this week. 🐝',
  'Bu hafta kovan biraz sessizdi, {name}.':
      'The hive was a little quiet this week, {name}.',
  'Bir soru kaydı ya da bir pomodoro ile başla; gelecek hafta raporun parıl parıl olsun! ✨':
      'Start with one question log or one pomodoro, and next week’s report will shine! ✨',
  'Soru avı': 'Question hunt',
  'soru çözdün': 'questions solved',
  'Geçen haftadan %{n} fazla!': '{n}% more than last week!',
  'Geçen haftadan %{n} az, toparlanıyoruz!':
      '{n}% less than last week, let’s bounce back!',
  '{n} doğru = {jars} kavanoz bal 🍯': '{n} correct = {jars} jars of honey 🍯',
  'Odak zamanı': 'Focus time',
  'saat {m} dk': 'h {m} min',
  'odaklandın': 'of focus',
  '{n} pomodoro · {s} oturum': '{n} pomodoros · {s} sessions',
  'Haftanın ritmi': 'Your week’s rhythm',
  '{n} günün {d} günü kovandaydın': 'You were in the hive {d} of {n} days',
  'En parlak günün: {day} · {n} soru':
      'Your brightest day: {day} · {n} questions',
  'Favori dersin': 'Your favourite subject',
  '{n} soruyla haftanın yıldızı': 'Star of the week with {n} questions',
  'isabet': 'accuracy',
  'Deneme cephesi': 'Exam front',
  '{n} denemeye girdin': 'You took {n} practice exams',
  'en iyi netin': 'your best net',
  'Bu haftaki arı tipin': 'Your bee type this week',
  'Yeniden izle': 'Watch again',
  'Paylaş': 'Share',
  'Bal Raporu': 'Honey Report',
  'saat odak': 'hours focus',
  'dk odak': 'min focus',
  'aktif gün': 'active days',
  'Favori ders: {s}': 'Favourite subject: {s}',

  // Odak Bahçesi
  'Türkçe, Edebiyat, Dil': 'Turkish, Literature, Languages',
  'Fen': 'Science',
  'Sosyal': 'Social sciences',
  'Ders seçilmemiş': 'No subject',
  'Papatya': 'Daisy',
  'Lale': 'Tulip',
  'Çan çiçeği': 'Bellflower',
  'Ayçiçeği': 'Sunflower',
  'Kozmos': 'Cosmos',
  'Yarıda kaldı (soldu)': 'Left unfinished (wilted)',
  'Filiz (10 dk altı)': 'Sprout (under 10 min)',
  'Tomurcuk (10-25 dk)': 'Bud (10-25 min)',
  'Çiçek (25-50 dk)': 'Flower (25-50 min)',
  'Dev çiçek (50 dk+)': 'Giant flower (50+ min)',
  'Bu ay': 'This month',
  'Odak Bahçem 🌸 #Mentoria': 'My Focus Garden 🌸 #Mentoria',
  'Bu pomodoro yarıda kalmış, çiçek soldu 🥀':
      'This pomodoro was left unfinished, the flower wilted 🥀',
  'Odak Bahçem': 'My Focus Garden',
  'Çiçekler ne anlama geliyor?': 'What do the flowers mean?',
  'Her çalışma oturumu bahçene bir çiçek eker.':
      'Every study session plants a flower in your garden.',
  'çiçek': 'flowers',
  'tam açmış': 'in full bloom',
  'Bahçen tohumlarla dolu ama henüz filiz yok.':
      'Your garden is full of seeds, but nothing has sprouted yet.',
  'Bir pomodoro tamamla, ilk çiçeğin açsın! 🌱':
      'Finish a pomodoro and your first flower will bloom! 🌱',
  '{n} çiçek açtı': '{n} flowers bloomed',
  'İlk çiçeğini ek': 'Plant your first flower',
  '{p0} dakika kaydedildi, bahçende bir çiçek açtı 🌸':
      '{p0} minutes saved, a flower bloomed in your garden 🌸',
  'Bahçeye bak': 'See garden',

  // Hata Defteri
  'Hata Defteri': 'Mistake Notebook',
  'Hata ekle': 'Add mistake',
  '{n} g': '{n} d',
  'Öğrenildi': 'Learned',
  '{n}. tekrar basamağı': 'Review step {n}',
  'Soru fotoğrafı': 'Question photo',
  'Bugün tekrar': 'Review today',
  '{date} tekrar': 'Review on {date}',
  'Hata defteri boş': 'The mistake notebook is empty',
  'Hata defterin boş': 'Your mistake notebook is empty',
  'Öğrenci yanlış yaptığı soruları ekledikçe burada görünür.':
      'Questions the student got wrong will appear here as they are added.',
  'Yanlış yaptığın bir sorunun fotoğrafını çek; Bızz onu 1, 3, 7 ve 21 gün sonra sana yeniden sorsun. Unutma eğrisini birlikte yeneriz!':
      'Snap a photo of a question you got wrong; Bızz will ask it again after 1, 3, 7 and 21 days. Together we beat the forgetting curve!',
  'Yaklaşan tekrarlar': 'Upcoming reviews',
  'bugün tekrar': 'due today',
  'yolda': 'in progress',
  'öğrenildi': 'learned',
  '{n} soruyu şimdi tekrar et': 'Review {n} questions now',
  'Bugünlük tekrar yok. Harika! 🎉': 'No reviews for today. Great! 🎉',
  'En çok takıldığı yerler': 'Where they struggle most',
  'Hata sayısı ve tekrarda yeniden yanlışlara göre':
      'By number of mistakes and repeated errors in review',
  'Tekrarda {n} kez yeniden yanlış yapıldı':
      'Got it wrong {n} more times in review',
  'Kart silinsin mi?': 'Delete this card?',
  'Fotoğrafı ve tekrar geçmişi de silinir.':
      'Its photo and review history will be deleted too.',
  'Kartı sil': 'Delete card',
  'Fotoğraf alınamadı. İzinleri kontrol et.':
      'Couldn’t get the photo. Check permissions.',
  'Bir fotoğraf ya da kısa bir not ekle.': 'Add a photo or a short note.',
  'Deftere eklendi. Bızz yarın sana yeniden soracak! 🐝':
      'Added to the notebook. Bızz will ask you again tomorrow! 🐝',
  'Hata defterine ekle': 'Add to mistake notebook',
  'Fotoğraf çek': 'Take photo',
  'Galeriden seç': 'Choose from gallery',
  'Fotoğrafı kaldır': 'Remove photo',
  'Seçilmedi': 'Not selected',
  'Nerede takıldın? (isteğe bağlı)': 'Where did you get stuck? (optional)',
  'ör. işlem hatası, formülü unuttum':
      'e.g. calculation error, forgot the formula',
  'Deftere ekle': 'Add to notebook',
  'Tekrar bitti': 'Review finished',
  '{i} / {n}': '{i} / {n}',
  'Notun: {n}': 'Your note: {n}',
  'Soruyu kağıtta yeniden çöz, sonra dürüstçe işaretle.':
      'Solve the question again on paper, then mark it honestly.',
  'Yine yapamadım': 'Still couldn’t',
  'Çözdüm': 'Solved it',
  '{s} / {n} soruyu çözdün': 'You solved {s} / {n} questions',
  '{m} soru artık tamamen öğrenildi! 🏆':
      '{m} questions are now fully learned! 🏆',
  'Hepsi doğru! Bir sonraki tekrar daha ileri bir tarihte.':
      'All correct! The next review is further ahead.',
  'Yapamadıkların yarın yeniden gelecek. Pes etmek yok! 💪':
      'The ones you missed come back tomorrow. Never give up! 💪',
  'Deftere dön': 'Back to notebook',
  '{n} soru tekrar bekliyor': '{n} questions to review',
  'Yanlışlarını unutma': 'Don’t forget your mistakes',
  'Bugünlük tekrar yok ✓': 'No reviews today ✓',

  // Bildirimler: tekrar ve veli raporu
  'Tekrar zamanı! 🔁': 'Review time! 🔁',
  '{child} için haftalık Bal Raporu 🐝': 'Weekly Honey Report for {child} 🐝',
  'Hata defterinde {n} soru seni bekliyor. Unutmadan bir daha çöz!':
      '{n} questions are waiting in your mistake notebook. Solve them again before you forget!',
  'Bu hafta {q} soru çözdü, {m} dk odaklandı, {d} gün çalıştı.':
      'This week: {q} questions, {m} min of focus, {d} active days.',
  'Bu hafta henüz kayıt yok. Küçük bir teşvik iyi gelebilir! 💛':
      'No activity yet this week. A little encouragement could help! 💛',
  'Her pazar akşamı bu özeti bildirim olarak da alırsın.':
      'You’ll also get this summary as a notification every Sunday evening.',

  // Deneme analizi
  'Analiz': 'Analysis',
  'Son 5': 'Last 5',
  'Son 10': 'Last 10',
  'Yükselişte': 'Rising',
  'Düşüşte': 'Falling',
  'Dalgalı': 'Fluctuating',
  'İstikrarlı': 'Steady',
  'Tek deneme': 'Single exam',
  '{v} net/deneme': '{v} net/exam',
  'Analiz için en az 2 deneme gerekiyor.':
      'At least 2 exams are needed for analysis.',
  'Ders ders gelişim': 'Progress by subject',
  '{n} deneme · kesikli çizgi eğilimi gösterir':
      '{n} exams · the dashed line shows the trend',
  'Toplam net eğilimi': 'Total net trend',
  'net / deneme': 'net / exam',
  'Bu gidişle 5 deneme sonra ≈ {p} net (şu an {n})':
      'At this pace, ≈ {p} net in 5 exams (now {n})',
  'En hızlı yükselen': 'Fastest rising',
  'Dikkat isteyen': 'Needs attention',
  '{s} · %{p} ustalık': '{s} · {p}% mastery',
  'En istikrarlı': 'Most consistent',
  'Isı haritası': 'Heat map',
  'Hücredeki sayı net; renk o dersteki doluluk oranı':
      'The number is the net; the colour shows how full the subject is',
  'Eğilim: {v} · uyum %{r}': 'Trend: {v} · fit {r}%',
  'Son': 'Last',
  'Ortalama': 'Average',
  'İsabet': 'Accuracy',
  '%{p} ustalık': '{p}% mastery',
  '🔮 Bu gidişle 5 deneme sonra ≈ {p} / {q} net':
      '🔮 At this pace, ≈ {p} / {q} net in 5 exams',
  '{s} net grafiği: ilk {a}, son {b}': '{s} net chart: first {a}, last {b}',

  // Eğitim
  'Eğitim': 'Learn',
  'Bugünkü çalışman': 'Today’s practice',
  'soru çözüldü · her gün yenilenir': 'questions solved · resets every day',
  '{s}: bugün {u} / {l} soru': '{s}: {u} / {l} questions today',
  'Bugünlük tamam ✓': 'Done for today ✓',
  '{n} soru hakkın var': '{n} questions left',
  '{n} bilgi kartı': '{n} info cards',
  'Bilgi kartları': 'Info cards',
  'Soru çöz': 'Practice',
  '{t} kartı, çevirmek için dokun': '{t} card, tap to flip',
  'Çevirmek için dokun': 'Tap to flip',
  'Bugünkü hakkın doldu. Yarın yeni sorular seni bekliyor!':
      'You’ve used today’s questions. New ones are waiting tomorrow!',
  'Cevap kaydedilemedi. İnternet bağlantını kontrol et.':
      'Couldn’t save your answer. Check your internet connection.',
  'Soru {n} / {l}': 'Question {n} / {l}',
  '🔥 {n} doğru üst üste': '🔥 {n} correct in a row',
  'Doğru!': 'Correct!',
  'Doğru cevap: {l}': 'Correct answer: {l}',
  'Sonraki soru': 'Next question',
  'doğru': 'correct',
  'yanlış': 'wrong',
  'Bugünlük bu ders tamam!': 'This subject is done for today!',
  '{c} / {n} doğru': '{c} / {n} correct',
  'Günlük {l} soru hakkını kullandın. Yarın havuzdan yepyeni sorular gelecek. 🐝':
      'You’ve used your {l} daily questions. Brand-new ones arrive tomorrow. 🐝',

  // Hata Defteri'ne ekle, Günün Sorusu, Eğitim karnesi
  'Doğru cevap': 'Correct answer',
  "Hata Defteri'ne ekle": 'Add to Mistake Notebook',
  'Deftere eklendi · yarın yeniden sorulacak':
      'Added · you’ll see it again tomorrow',
  'Günün Sorusu': 'Question of the Day',
  '{subject} · çöz, serini büyüt': '{subject} · solve it, grow your streak',
  'Bugünkü soruyu bildin ✓ Yarın yenisi gelir':
      'You got today’s question ✓ A new one comes tomorrow',
  'Bugünkü soru çözüldü · yarın yenisi gelir':
      'Today’s question is done · a new one comes tomorrow',
  '🔥 {n} gün': '🔥 {n} days',
  'Günün Sorusu öğrencilere özel.': 'The Question of the Day is for students.',
  'Bugünkü soru yüklenemedi.': 'Couldn’t load today’s question.',
  'Günlük hakkını harcamaz': 'Doesn’t use your daily questions',
  'Doğru! Serin {n} gün 🔥': 'Correct! Your streak is {n} days 🔥',
  'Bu sefer olmadı. Seri sıfırlandı, yarın yeniden başla!':
      'Not this time. Your streak reset — start again tomorrow!',
  "Yarın sabah 09.00'da yeni soru gelecek.":
      'A new question arrives tomorrow at 09:00.',
  'Günün Sorusu hazır ☀️': 'Question of the Day is ready ☀️',
  'Bugün {subject} sorusu seni bekliyor. Çöz, serini büyüt!':
      'Today’s {subject} question is waiting. Solve it, grow your streak!',
  'Henüz soru çözülmedi': 'No questions solved yet',
  'Öğrenci Eğitim sekmesinde soru çözdükçe karnesi burada oluşur.':
      'As the student solves questions in the Learn tab, their report appears here.',
  'Toplam': 'Total',
  'tüm zamanlar': 'all time',
  'En zayıf ders: {subject} (%{p} isabet).':
      'Weakest subject: {subject} ({p}% accuracy).',
  'En zayıf ders: {subject} (%{p} isabet). Önce "{topic}" konusuna odaklanılabilir.':
      'Weakest subject: {subject} ({p}% accuracy). Focusing on "{topic}" first could help.',
  'Eğitim sekmesinde günlük çözülen soru':
      'Questions solved per day in the Learn tab',
  'Ders ders': 'By subject',
  'Çözülen soru, isabet ve en çok yanlış yapılan konu':
      'Questions solved, accuracy and the most-missed topic',
  'En çok yanlış: {topic} ({n})': 'Most missed: {topic} ({n})',

  'TYT': 'TYT',
  'AYT': 'AYT',

  // Bildirim kanalı
  'Mentoria bildirimleri': 'Mentoria notifications',
  'Ödev, görüşme, mesaj ve deneme bildirimleri':
      'Homework, meeting, message and exam notifications',
};
