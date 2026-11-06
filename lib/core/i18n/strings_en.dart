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
  'Rutin görüşme planlandı: her {day} {time}':
      'Recurring meeting scheduled: every {day} {time}',
  'Görüşme planlandı.': 'Meeting scheduled.',
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
  'İzin ver': 'Allow',
  'Telefon kilitliyken zilin zamanında çalması için "Alarmlar ve hatırlatıcılar" iznini aç.':
      'To ring on time while the phone is locked, turn on "Alarms & reminders".',
  'Bildirimler kapalı: zil yalnızca uygulama açıkken çalar.':
      'Notifications are off: the bell only rings while the app is open.',
  'İzni aç': 'Turn on',
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

  // Deneme eğilimi (koç / müdür ana sayfası)
  'Son 5 denemede değişim': 'Change over the last 5 exams',
  'İlk ve son denemenin toplam neti karşılaştırılır':
      'Compares the total net of the first and latest exam',
  'Karşılaştırmak için en az 2 {type} denemesi olan öğrenci yok.':
      'No student has at least 2 {type} exams to compare.',
  'En çok yükselen': 'Biggest rises',
  'Yükselen öğrenci yok.': 'No students are rising.',
  'En çok düşen': 'Biggest drops',
  'Düşen öğrenci yok.': 'No students are dropping.',
  '{a} → {b} net · {n} deneme': '{a} → {b} net · {n} exams',

  // YKS puan hesaplayıcı
  'Plan': 'Plan',
  'Puan hesapla': 'Score calculator',
  'Tahmini {type} yerleştirme puanın': 'Your estimated {type} placement score',
  'Ham puan {raw} · diploma notunu girersen OBP eklenir':
      'Raw score {raw} · enter your diploma grade to add OBP',
  'Ham puan {raw} · OBP katkısı +{obp}': 'Raw score {raw} · OBP bonus +{obp}',
  'Hedef puan': 'Target score',
  'Hedef bölümünün geçen yılki taban puanını yazabilirsin':
      'You can enter last year’s minimum score for your target programme',
  '{type} hedef puanı': '{type} target score',
  'Netlerin': 'Your nets',
  'Son denemelerinden dolduruldu; değiştirip deneyebilirsin':
      'Filled from your latest exams; change them to try scenarios',
  'Sıfırla': 'Reset',
  'Diploma notu (OBP)': 'Diploma grade (OBP)',
  'Diploma notu (50-100)': 'Diploma grade (50-100)',
  'Geçen yıl bir programa yerleştim': 'I was placed in a programme last year',
  'OBP katkısı yarıya iner': 'The OBP bonus is halved',
  'Puanlar tahminidir. ÖSYM puanları adayların ortalaması ve standart sapmasıyla hesaplar; gerçek puanın birkaç puan farklı olabilir.':
      'Scores are estimates. ÖSYM calculates scores using candidates’ averages and standard deviations, so your real score may differ by a few points.',
  'Hedefinin {p} puan üstündesin 🎉': 'You’re {p} points above your target 🎉',
  'Hedefe {p} puan kaldı': '{p} points to your target',
  'Tek bir dersten kapanmıyor; birkaç derste birden net artırmalısın.':
      'One subject alone won’t close the gap; raise your nets in several subjects.',
  'Tek başına şu derslerden biriyle kapanır:':
      'Any one of these subjects alone closes the gap:',
  '{subject}: +{n} net (1 net ≈ {c} puan)':
      '{subject}: +{n} nets (1 net ≈ {c} points)',

  // Haftalık plan
  'Haftalık planın hazır 📅': 'Your weekly plan is ready 📅',
  '{from} {week} haftasının planını hazırladı. Göz at, yaptıkça işaretle!':
      '{from} has prepared your plan for the week of {week}. Take a look and tick items off as you go!',
  'Bugünün planı': 'Today’s plan',
  'Hafta %{p}': 'Week {p}%',
  'Bugün için madde yok. Haftanın planına bak.':
      'Nothing planned for today. See the week’s plan.',
  '+{n} madde daha': '+{n} more items',
  'Haftalık plan': 'Weekly plan',
  'Silinemedi. Tekrar dene.': 'Couldn’t delete. Try again.',
  'Geçen hafta plan yok.': 'There was no plan last week.',
  'Geçen haftanın planı kopyalandı.': 'Last week’s plan was copied.',
  '{n} madde kopyalanamadı.': '{n} items couldn’t be copied.',
  'Bu haftaya dön': 'Back to this week',
  '{d} / {n} madde · %{p}': '{d} / {n} items · {p}%',
  'Bu hafta için plan yok': 'No plan for this week',
  'Günlere madde ekle ya da geçen haftanın planını kopyala.':
      'Add items to the days or copy last week’s plan.',
  'Koçun plan hazırlayınca burada görünecek.':
      'It will appear here once your coach makes a plan.',
  'Günlere "Madde ekle" ile kendi programını yap. Koçunun eklediği maddeler de burada görünür.':
      'Build your own schedule with "Add item" on each day. Items your coach adds show up here too.',
  'Çalışma programını yap': 'Make your study schedule',
  'Hangi gün, saat kaçta, hangi ders?': 'Which day, what time, which subject?',
  'Öğrenci ekledi': 'Added by student',
  'Koçundan': 'From your coach',
  'Başlangıç saati': 'Start time',
  'Saati kaldır': 'Remove time',
  // Haftalık veli özeti
  'Haftalık özet': 'Weekly summary',
  'Veliye gönder': 'Send to parent',
  'Özet yüklenemedi. Tekrar dene.': 'Couldn’t load the summary. Try again.',
  '{d} / 7 gün çalıştı': 'Studied {d} / 7 days',
  '{d}/7 gün çalıştı': 'studied {d}/7 days',
  '{n} koç görüşmesini kaçırdı': 'Missed {n} coach meeting(s)',
  '{n} koç görüşmesine katıldı': 'Attended {n} coach meeting(s)',
  '{n} görüşme kaçırıldı': '{n} meeting(s) missed',
  'Net trendi': 'Net trend',
  'Son {type}: {net} net': 'Last {type}: {net} net',
  'öncekinden {d}': '{d} vs. previous',
  'Ödev': 'Homework',
  'Bu hafta teslimli ödev yok': 'No homework due this week',
  '{d} / {n} tamamlandı · %{p}': '{d} / {n} done · {p}%',
  'ödev %{p}': 'homework {p}%',
  '{name} · haftalık özet': '{name} · weekly summary',
  '{name} · haftalık özet (son 7 gün)': '{name} · weekly summary (last 7 days)',
  '{q} soru · {time} çalışma': '{q} questions · {time} of study',
  // Risk erken uyarısı
  'Bu hafta konuşulacaklar': 'Talk to this week',
  'Devam, net düşüşü ve ödeve göre son 7 gün':
      'Last 7 days by attendance, net drop and homework',
  'Bu hafta risk işareti veren öğrenci yok.':
      'No students show warning signs this week.',
  'Bu hafta {n} öğrenciyle konuş': 'Talk to {n} students this week',
  '{names}: devam, net ya da ödevde geriye düşüş var. Listeye bak.':
      '{names}: attendance, nets or homework slipped. Check the list.',
  'Risk skoru': 'Risk score',
  'Risk skoru {n}': 'Risk score {n}',
  'Skor nasıl hesaplanır?': 'How is the score calculated?',
  'Çalışmadığı her gün 5 puan, kaçırılan her koç görüşmesi 7,5 puan (en çok 2). Son 30 gündeki denemesi bir öncekinden düşükse her net 3 puan (en çok 10 net). Bu haftanın ödevinde yapılmayan oran × 20. Toplam 100 üzerinden; 30 ve üstü listeye girer.':
      '5 points for each day without study, 7.5 for each missed coach meeting (up to 2). If the latest mock exam (last 30 days) is below the previous one, 3 points per net (up to 10 nets). Share of this week’s homework not done × 20. Out of 100; 30 and above make the list.',
  '{n} gün çalışmadı': '{n} days without study',
  '{n} görüşme kaçırdı': 'missed {n} meeting(s)',
  '{type} {n} net düştü': '{type} down {n} nets',
  // Konu reçetesi
  'Konu reçetesi': 'Topic prescription',
  'Konu reçetesi · {date}': 'Topic prescription · {date}',
  'Son 3 denemenin eksik konularından haftalık ödev taslağı':
      'Weekly homework draft from weak topics in the last 3 mock exams',
  'Son denemelerdeki eksik konulardan hazırlandı.':
      'Prepared from weak topics in recent mock exams.',
  'Onayla ve gönder · {n} konu, {q} soru':
      'Approve and send · {n} topics, {q} questions',
  'Reçete ödev olarak gönderildi.': 'Prescription sent as homework.',
  'Teslim: 1 hafta sonra. Öğrenciye ödev bildirimi gider.':
      'Due in 1 week. The student gets a homework notification.',
  '{e} denemede {n} yanlış': '{n} wrong in {e} exams',
  '{n} yanlış': '{n} wrong',
  'Önerilecek konu yok: son denemelerde konu bazlı yanlış kaydı yok ya da hepsine yakın zamanda ödev verildi.':
      'Nothing to suggest: no topic-level mistakes in recent exams, or they were all assigned recently.',
  // Rehberlik görüşme kaydı
  'Rehberlik': 'Guidance',
  'Görüşme kaydı': 'Meeting record',
  'Görüşme tarihi': 'Meeting date',
  'Yüz yüze': 'In person',
  'Telefon': 'Phone',
  'Online': 'Online',
  'Veli görüşmesi': 'Parent meeting',
  'Ders başarısı': 'Academic progress',
  'Motivasyon': 'Motivation',
  'Tercih / bölüm': 'University / major',
  'Sınav kaygısı': 'Exam anxiety',
  'Zaman yönetimi': 'Time management',
  'Aile': 'Family',
  'Kurum içi kayıt: öğrenci ve veli görmez. Koç değişse de geçmiş kurumda kalır.':
      'Internal record: students and parents can’t see it. The history stays with the school even if the coach changes.',
  'Henüz görüşme kaydı yok': 'No meeting records yet',
  'Her görüşmeden sonra "Görüşme kaydı"na dokun; 2 dakikada not bırak.':
      'After each meeting tap "Meeting record" and leave a note in 2 minutes.',
  'Bu görüşme kaydı kalıcı olarak silinir.':
      'This meeting record will be deleted permanently.',
  'Sonraki adım': 'Next step',
  'Sonraki adım (isteğe bağlı)': 'Next step (optional)',
  'Takip: {date}': 'Follow-up: {date}',
  'Takip tarihi (isteğe bağlı)': 'Follow-up date (optional)',
  'Tarihi kaldır': 'Remove date',
  'Yazan bilinmiyor': 'Author unknown',
  'Kısa bir not yaz.': 'Write a short note.',
  'Konular (en çok 5)': 'Topics (up to 5)',
  'Ne konuşuldu?': 'What was discussed?',
  'ör. Son denemede matematik düştü, çalışma düzeni konuşuldu.':
      'e.g. Maths dropped in the last mock exam; we talked about the study routine.',
  'Geçen haftayı kopyala': 'Copy last week',
  'Madde ekle': 'Add item',
  'Madde yok': 'No items',
  'Soru 1-1000, süre 5-600 dakika olmalı.':
      'Questions must be 1-1000 and time 5-600 minutes.',
  'Bir güne en çok 12 madde eklenebilir.': 'A day can have at most 12 items.',
  'Geçmiş haftalara madde eklenemez.': 'You can’t add items to past weeks.',
  '{day} için madde': 'Item for {day}',
  'ör. Problemler': 'e.g. Word problems',
  'Soru hedefi': 'Question goal',
  'Süre (dk)': 'Time (min)',

  // Sıkça sorulan sorular (ekran)
  'Sıkça sorulan sorular': 'Frequently asked questions',
  'Öğrenci paneli hakkında': 'About the student panel',
  'Koç paneli hakkında': 'About the coach panel',
  'Kurum müdürü paneli hakkında': 'About the school manager panel',
  'Veli paneli hakkında': 'About the parent panel',
  'Soru ara': 'Search questions',
  'Temizle': 'Clear',
  'Başka bir kelimeyle aramayı dene.': 'Try searching with a different word.',
  'Sorunun cevabını bulamadın mı? Koçuna sorabilirsin.':
      'Didn’t find your answer? You can ask your coach.',
  'Sorunun cevabını bulamadın mı? Kurum müdürüne ulaşabilirsin.':
      'Didn’t find your answer? You can contact your school manager.',
  'Sorunun cevabını bulamadın mı? Platform yöneticisine ulaşabilirsin.':
      'Didn’t find your answer? You can contact the platform administrator.',
  'Sorunun cevabını bulamadın mı? Çocuğunun dershanesine ulaşabilirsin.':
      'Didn’t find your answer? You can contact your child’s school.',

  // Arkadaş düellosu
  '{n} düello kazan': 'Win {n} duels',
  'Arkadaş düellosu': 'Friend duel',
  '{n} düello seni bekliyor': '{n} duels are waiting for you',
  'Arkadaşınla aynı 10 soruyu çöz, kazanan ödül alsın':
      'Solve the same 10 questions as a friend; the winner gets a reward',
  'Düello başlat': 'Start a duel',
  'Henüz düello yok': 'No duels yet',
  'Bir arkadaşını seç, aynı 10 soruyu çözün. Kim daha iyi, görelim!':
      'Pick a friend and solve the same 10 questions. Let’s see who’s better!',
  'Sıra sende': 'Your turn',
  'Rakibin bekleniyor': 'Waiting for your opponent',
  'Sonuçlananlar': 'Finished',
  'Başla': 'Start',
  'Kabul et': 'Accept',
  'Bekleniyor': 'Waiting',
  'Kazandın 🏆': 'You won 🏆',
  'Kaybettin': 'You lost',
  'Berabere': 'Draw',
  'Süresi doldu': 'Expired',
  '{name} bitirdi, sıra sende': '{name} finished — your turn',
  '{name} seni düelloya çağırdı': '{name} challenged you to a duel',
  'Daveti gönderdin, önce sen çöz': 'Invite sent — you solve first',
  '{c} / 10 doğru · {t}': '{c} / 10 correct · {t}',
  '{a} - {b} doğru': '{a} - {b} correct',
  'Düello tamamlanmadı': 'The duel wasn’t completed',
  'İkiniz de aynı 10 soruyu çözersiniz.':
      'You both solve the same 10 questions.',
  'En çok doğru yapan kazanır.': 'Whoever gets the most right wins.',
  'Doğru sayınız eşitse testi daha kısa sürede bitiren kazanır.':
      'If you get the same number right, whoever finishes faster wins.',
  'Süre "Başla"ya bastığın anda başlar ve durmaz. 30 dakika içinde bitirmelisin.':
      'The clock starts the moment you tap "Start" and doesn’t stop. You must finish within 30 minutes.',
  'Cevabı seçince sonraki soruya geçersin, geri dönülmez. Emin değilsen "Boş geç".':
      'Picking an answer moves you to the next question; you can’t go back. Not sure? Tap "Skip".',
  "Kazanana avatar ödülü: 1. galibiyette madalya, 5'te defne tacı, 10'da şampiyon pelerini.":
      'Winners earn avatar rewards: a medal for the 1st win, a laurel wreath at 5, a champion cape at 10.',
  'Kurallar': 'Rules',
  'Bu arkadaşınla zaten açık bir düellon var.':
      'You already have an open duel with this friend.',
  'Bugün en fazla 10 düello başlatabilirsin.':
      'You can start at most 10 duels a day.',
  'Düello başlatılamadı. Tekrar dene.': 'Couldn’t start the duel. Try again.',
  'Yeni düello': 'New duel',
  'Rakibini seç': 'Pick your opponent',
  'Dershanende henüz başka öğrenci yok.':
      'There are no other students at your school yet.',
  'Bu düellonun süresi doldu.': 'This duel has expired.',
  'Düello': 'Duel',
  'Sen': 'You',
  '{subject} · 10 soru': '{subject} · 10 questions',
  '{name} testi bitirdi. Sonucu sen bitirince görünecek.':
      '{name} has finished. You’ll see their score when you finish.',
  "Süre Başla'ya bastığında başlar.": 'The clock starts when you tap Start.',
  '30 dakika doldu; bu düello tamamlanamadı.':
      '30 minutes are up; this duel couldn’t be completed.',
  'Cevaplar gönderilemedi. İnternet bağlantını kontrol et.':
      'Couldn’t send your answers. Check your internet connection.',
  'Düellodan çıkılsın mı?': 'Leave the duel?',
  'Süre işlemeye devam eder ve cevapların kaydedilmez. 30 dakika içinde dönüp baştan çözebilirsin.':
      'The clock keeps running and your answers won’t be saved. You can come back within 30 minutes and start over.',
  'Soru {n} / {t}': 'Question {n} / {t}',
  'Boş geç': 'Skip',
  'Düello sonucu': 'Duel result',
  'Kazandın!': 'You won!',
  '{name} kazandı': '{name} won',
  'Berabere!': 'It’s a draw!',
  '{name} bitirince sonuç gelecek; sana bildirim göndereceğiz.':
      'The result comes when {name} finishes; we’ll notify you.',
  'Doğru sayınız eşit; testi daha kısa sürede bitiren kazandı.':
      'You got the same number right; whoever finished faster won.',
  'En çok doğru yapan kazandı.': 'Whoever got the most right won.',
  "Galibiyetler avatar ödülü açar: 1. galibiyette madalya, 5'te defne tacı, 10'da şampiyon pelerini.":
      'Wins unlock avatar rewards: a medal for the 1st win, a laurel wreath at 5, a champion cape at 10.',
  'Cevapların': 'Your answers',
  '{from} seni düelloya çağırdı ⚔️': '{from} challenged you to a duel ⚔️',
  'Düelloyu kazandın! 🏆': 'You won the duel! 🏆',
  'Düello sonucu: {name} kazandı': 'Duel result: {name} won',
  'Düello berabere bitti 🤝': 'The duel ended in a draw 🤝',
  '{subject} · 10 soru. Aynı soruları çözün, kim daha iyi görelim!':
      '{subject} · 10 questions. Solve the same ones — let’s see who’s better!',
  '{subject} düellosu sonuçlandı. Sonuca bak.':
      'Your {subject} duel is over. See the result.',

  // Toplu duyuru
  'Cumartesi TYT denemesi': 'TYT mock exam on Saturday',
  "Bu cumartesi saat 10.00'da kurumumuzda TYT deneme sınavı var. Kimliğini ve kurşun kalemini unutma!":
      "There is a TYT mock exam at our school this Saturday at 10:00. Don't forget your ID and pencil!",
  'Paragraf haftası başlıyor': 'Paragraph week starts',
  "Bu hafta her gün 20 paragraf sorusu çözüyoruz. Takıldığın soruları Hata Defteri'ne ekle, görüşmede bakalım.":
      "This week we solve 20 paragraph questions every day. Add the ones you get stuck on to your Mistake Notebook and we'll go over them in our meeting.",
  'Herkes': 'Everyone',
  'Veliler': 'Parents',
  'Öğrencilerim': 'My students',
  'Öğrencilerimin velileri': "My students' parents",
  'Kurumdaki tüm öğrenci, veli ve koçlar':
      'All students, parents and coaches in the school',
  'Kurumdaki tüm öğrenciler': 'All students in the school',
  'Kurumdaki öğrencilerin velileri': 'Parents of students in the school',
  'Kurumdaki tüm koçlar': 'All coaches in the school',
  'Koçu olduğun öğrenciler': 'Students you coach',
  'Koçu olduğun öğrencilerin velileri': 'Parents of the students you coach',
  'Başlık 2-80, metin 1-600 karakter olmalı.':
      'Title must be 2-80 and text 1-600 characters.',
  '24 saatte en fazla 10 duyuru gönderebilirsin.':
      'You can send at most 10 announcements in 24 hours.',
  'Bu kitlede henüz kimse yok, duyuru gönderilmedi.':
      'Nobody is in this audience yet; the announcement was not sent.',
  'Bu duyuruyu gönderme yetkin yok.':
      'You are not allowed to send this announcement.',
  'Duyuru gönderilemedi.': 'The announcement could not be sent.',
  'Duyurular': 'Announcements',
  'Yeni duyuru': 'New announcement',
  'Henüz duyuru yok': 'No announcements yet',
  'Deneme günü, tatil ya da önemli bir hatırlatma: tek seferde herkese ulaştır.':
      'Exam day, a holiday or an important reminder: reach everyone at once.',
  'Kurumun ya da koçun duyuru yapınca burada görürsün.':
      "When your school or coach makes an announcement, you'll see it here.",
  'Sen · {audience}': 'You · {audience}',
  'Sen · {audience} · {n} kişi': 'You · {audience} · {n} people',
  '{audience} · {n} kişi': '{audience} · {n} people',
  'Tek seferde öğrencilere, velilere ya da koçlara':
      'To students, parents or coaches at once',
  'Duyuru gönderilsin mi?': 'Send the announcement?',
  '"{title}" duyurusu {audience} kitlesine bildirim olarak gidecek. Gönderdikten sonra geri alınamaz.':
      'The announcement "{title}" will be sent as a notification to: {audience}. It cannot be undone once sent.',
  'Duyuru {n} kişiye gönderildi.': 'Announcement sent to {n} people.',
  'Kime?': 'To whom?',
  'Başlık': 'Title',
  'Örn. Cumartesi TYT denemesi': 'E.g. TYT mock exam on Saturday',
  'Duyuru metni': 'Announcement text',

  // SSS (üretildi: python tool/faq/make_faq.py; elle düzenleme)
  'Başlarken': 'Getting started',
  'Nasıl kayıt olurum?': 'How do I sign up?',
  'Koçunun ya da dershanenin verdiği davet koduyla (veya davet bağlantısıyla) kayıt olursun. Şifreni iki kez girip e-postana gelen doğrulama kodunu yazınca hesabın açılır.':
      'You sign up with the invite code (or invite link) from your coach or school. Enter your password twice and type the verification code sent to your email to open your account.',
  'Şifremi unuttum, ne yapmalıyım?': 'I forgot my password. What should I do?',
  'Giriş ekranında "Şifremi unuttum"a dokun. E-postana gelen bağlantıyla yeni şifre belirlersin.':
      'Tap "Forgot password" on the sign-in screen. You set a new password from the link sent to your email.',
  'Verilerimi kimler görebilir?': 'Who can see my data?',
  'Yalnızca koçun, dershane müdürün ve bağladığın velin görür. Sınıf arkadaşların verilerini göremez; sıralamalarda yalnızca adının kısaltması görünür.':
      'Only your coach, your school manager and any parent you have linked. Classmates can’t see your data; rankings only show a shortened name.',
  'Çalışma takibi': 'Tracking your study',
  'Çözdüğüm soruları nasıl kaydederim?': 'How do I log the questions I solved?',
  '"Sorular" sekmesinde "Soru ekle"ye dokun; dersi ve doğru, yanlış, boş sayılarını gir. Günlük soru ve çalışma hedeflerini profilindeki Hedefler kartından ayarlayabilirsin.':
      'Tap "Add questions" on the Questions tab and enter the subject with your correct, wrong and blank counts. You can set your daily question and study goals on the Goals card in your profile.',
  'Deneme sonuçlarım nereden geliyor?': 'Where do my exam results come from?',
  'Koçun ya da dershanen sonuçları girer veya Excel dosyasıyla yükler; sen "Denemeler" sekmesinde görürsün. "Analiz" bölümü her derste gelişimini ve tahminini gösterir.':
      'Your coach or school enters results or uploads them from an Excel file, and you see them on the Exams tab. The "Analysis" view shows your progress and forecast for each subject.',
  'Seri (alev) nasıl artar?': 'How does my streak (flame) grow?',
  'Her gün soru kaydı ya da çalışma süresi eklediğinde serin bir gün artar. Bir gün hiç kayıt olmazsa seri sıfırlanır.':
      'Your streak grows by one each day you log questions or study time. If you log nothing for a day, it resets.',
  'Odak Bahçesi nedir?': 'What is the Focus Garden?',
  '"Süre" sekmesinde zamanlayıcıyla çalıştığın her oturum bahçende bir çiçek açtırır. Uzun oturumlar daha büyük çiçek demektir.':
      'Every session you complete with the timer on the Time tab grows a flower in your garden. Longer sessions grow bigger flowers.',
  'Eğitim ve sorular': 'Learning and questions',
  'Eğitim sekmesinde günde kaç soru çözebilirim?':
      'How many questions can I solve per day in the Learn tab?',
  'TYT ve AYT için ayrı haklar vardır: Türkçe, TYT/AYT Matematik ve Edebiyat günde 20, diğer dersler 10 soru. Haklar her gece Türkiye saatiyle yenilenir.':
      'TYT and AYT have separate limits: Turkish, TYT/AYT Maths and Literature get 20 a day, other subjects 10. Limits reset every night (Turkey time).',
  'Günün Sorusu nedir?': 'What is the Question of the Day?',
  'Her sabah 09.00\'da bir soru gelir. Günlük hakkını harcamaz; art arda doğru cevapladığın günler serini büyütür.':
      'A new question arrives every morning at 09:00. It doesn’t use your daily limit, and answering correctly on consecutive days grows your streak.',
  'Hata Defteri nasıl çalışır?': 'How does the Mistake Notebook work?',
  'Yanlış yaptığın soruyu deftere ekle (istersen fotoğrafıyla). Soru 1, 3, 7 ve 21 gün sonra yeniden karşına çıkar. Eğitim\'de yanlış cevaptan sonra tek dokunuşla da ekleyebilirsin.':
      'Add a question you got wrong to the notebook (with a photo if you like). It comes back after 1, 3, 7 and 21 days. In Learn you can also add it with one tap after a wrong answer.',
  'Arkadaş düellosu nasıl oynanır?': 'How does a friend duel work?',
  'Eğitim sekmesindeki düello kartından bir arkadaşını ve dersi seç. İkiniz de aynı 10 soruyu çözersiniz; en çok doğru yapan, eşitlikte testi daha kısa sürede bitiren kazanır. Kazananlar avatar ödülü açar.':
      'Pick a friend and a subject from the duel card on the Learn tab. You both solve the same 10 questions; the most correct answers wins, and on a tie the faster finisher wins. Winners unlock avatar rewards.',
  'Avatar ve ödüller': 'Avatar and rewards',
  'Yeni avatar parçalarını nasıl açarım?': 'How do I unlock new avatar parts?',
  'Parçalar soru sayısı, seri, deneme, odak süresi, düello galibiyetleri gibi başarımlarla açılır. Avatar düzenleyicide kilitli parçanın koşulu yazar.':
      'Parts unlock through achievements such as questions solved, streaks, exams, focus time and duel wins. The avatar editor shows the condition for each locked part.',
  'Haftanın Bal Raporu nedir?': 'What is the Weekly Honey Report?',
  'Haftanın özetini hikâye biçiminde gösteren karttır: çözdüğün sorular, odak süren ve haftanın öne çıkanları. İstersen paylaşabilirsin.':
      'A story-style card that sums up your week: questions solved, focus time and your highlights. You can share it if you like.',
  'Duyuruları nerede görürüm?': 'Where can I see announcements?',
  'Kurumun ya da koçun duyuru yapınca bildirim gelir ve son duyuru ana sayfanda görünür. Hepsi için "Duyurular" kartında "Tümü"ne dokun.':
      'When your school or coach makes an announcement you get a notification and the latest one appears on your home screen. Tap "All" on the "Announcements" card to see them all.',
  'Hesap': 'Account',
  'Velimi nasıl bağlarım?': 'How do I link a parent?',
  'Profilinde "Veli davet kodu oluştur"a dokun ve kodu velinle paylaş. Velin bu kodla kayıt olunca gelişimini görebilir.':
      'Tap "Create parent invite code" in your profile and share the code with your parent. Once they sign up with it, they can follow your progress.',
  'Hesabımı nasıl silerim?': 'How do I delete my account?',
  'Profil > Güvenlik > "Hesabımın silinmesini iste". Talebin koçuna gider; hesabını ve tüm verilerini koçun siler. Talebi geri de alabilirsin.':
      'Profile > Security > "Request deletion of my account". Your request goes to your coach, who deletes your account and all your data. You can also withdraw the request.',
  'Öğrenciyi nasıl eklerim?': 'How do I add a student?',
  'Ana sayfada "Öğrenci davet et"e dokun, kodu kaç öğrencinin kullanacağını seç (tek öğrenci, 5 kişi ya da sınıf). Kodu ya da davet bağlantısını öğrenciye gönder; kayıt olunca listene eklenir.':
      'Tap "Invite student" on the home screen and choose how many students can use the code (one, 5 or a class). Send the code or invite link; the student joins your list after signing up.',
  'Öğrencinin hangi bilgilerini görebilirim?':
      'What can I see about a student?',
  'Öğrenci detayında Özet, Denemeler, Sorular, Konular, Süre, Görevler, Ödevler, Notlar, Hata Defteri ve Eğitim sekmeleri vardır. Eğitim karnesinde ders ders isabet ve en çok yanlış yapılan konu görünür.':
      'A student’s page has Overview, Exams, Questions, Topics, Time, Tasks, Homework, Notes, Mistake Notebook and Learn tabs. The Learn report shows accuracy by subject and the most-missed topic.',
  'Öğrenciye nasıl hedef belirlerim?': 'How do I set goals for a student?',
  'Öğrenci detayının Özet sekmesindeki Hedefler kartından günlük soru ve günlük çalışma (dakika) hedefini, hedef üniversite, bölüm ve sıralamayı girebilirsin.':
      'Use the Goals card on the Overview tab of the student’s page to set daily question and daily study (minutes) goals, plus target university, department and ranking.',
  'Görev, ödev ve görüşme': 'Tasks, homework and meetings',
  'Görev ile ödev arasındaki fark nedir?':
      'What’s the difference between a task and homework?',
  'Görev tek maddelik kısa bir hatırlatmadır. Ödev birden çok maddeden (konu, soru sayısı) oluşur ve öğrenci her maddeyi işaretleyerek bitirir. İkisinde de öğrenciye bildirim gider.':
      'A task is a short single-item reminder. Homework has several items (topics, question counts) that the student ticks off. Both send the student a notification.',
  'Görüşmeleri nasıl planlarım?': 'How do I schedule meetings?',
  '"Görüşme ekle" ile tek seferlik ya da her hafta tekrarlanan görüşme planla. Öğrenciye görüşmeden 24 saat önce hatırlatma gider; görüşme sonrasında yapıldı ya da yapılmadı diye işaretleyebilirsin.':
      'Use "Add meeting" to schedule a one-off or weekly recurring meeting. The student gets a reminder 24 hours before, and afterwards you can mark it as held or missed.',
  'Notlarımı öğrenci görür mü?': 'Can the student see my notes?',
  'Evet, öğrenciye yazdığın notlar öğrencinin ana sayfasında görünür ve bildirim olarak gider.':
      'Yes. Notes you write to a student appear on their home screen and are sent as a notification.',
  'Öğrencilerime toplu duyuru yapabilir miyim?':
      'Can I send an announcement to all my students?',
  'Evet. Ana sayfadaki "Duyurular" kartında "Yeni duyuru"ya dokun; öğrencilerine ya da onların velilerine tek seferde bildirim gönderirsin.':
      'Yes. Tap "New announcement" on the "Announcements" card on the home screen to notify your students or their parents at once.',
  'Deneme sonuçlarını toplu nasıl yüklerim?':
      'How do I upload exam results in bulk?',
  '"Deneme yükle" ile Excel (.xlsx, .xls), CSV ya da TXT dosyasını seç. Satırlar öğrencilerin okul numarasıyla eşleşir; ders sütunları kendiliğinden tanınır. Kaydetmeden önce önizlersin.':
      'Use "Upload exams" to pick an Excel (.xlsx, .xls), CSV or TXT file. Rows are matched by students’ school numbers and subject columns are detected automatically. You preview before saving.',
  'Bazı satırlar eşleşmedi, neden?': 'Some rows didn’t match. Why?',
  'Dosyadaki numara hiçbir öğrencinin okul numarasıyla eşleşmiyordur. Öğrencinin profilinde okul numarasının girili olduğundan emin ol.':
      'The number in the file doesn’t match any student’s school number. Make sure the student’s school number is filled in.',
  'Yanlış yüklediğim denemeyi silebilir miyim?':
      'Can I delete an exam I uploaded by mistake?',
  'Evet. "Yüklediğin denemeler" ekranında son 7 gün içinde yüklediğin denemeleri toplu silebilirsin.':
      'Yes. On "Your uploaded exams" you can delete exams uploaded in the last 7 days.',
  'Hesaplar': 'Accounts',
  'Öğrenci hesap silme talebi gönderdi, ne yapmalıyım?':
      'A student requested account deletion. What should I do?',
  'Öğrencinin kartında rozet görünür. Öğrenci detayındaki uyarıdan hesabı silebilirsin; silinen hesap ve verileri geri getirilemez. Öğrenci talebini geri de alabilir.':
      'A badge appears on the student’s card. You can delete the account from the notice on their page; deleted accounts and data can’t be recovered. The student can also withdraw the request.',
  'Kurum': 'School',
  'Koç ve öğrenciyi nasıl davet ederim?':
      'How do I invite coaches and students?',
  '"Koç davet et" ile koça, "Öğrenci davet et" ile öğrenciye kod oluştur. Öğrenci davetinde öğrencinin bağlanacağı koçu seçersin.':
      'Create a code with "Invite coach" for coaches and "Invite student" for students. For student invites you choose which coach they’ll be linked to.',
  'Lisans ve koltuk sayısı ne demek?': 'What are the licence and seat count?',
  'Kurumunun kaç öğrenciye kadar ve hangi tarihe kadar kullanabileceğini belirler. Koltuklar dolduysa yeni öğrenci kayıt olamaz. Lisans süresi bitince öğrenci, koç ve veliler uygulamaya giremez; lisans uzatılınca erişim kendiliğinden geri gelir.':
      'They set how many students your school can have and until when. If seats are full, new students can’t sign up. When the licence expires, students, coaches and parents can’t use the app; access returns automatically once it is renewed.',
  'Lisans süresi doldu ({expiry}). Öğrenci, koç ve veliler giriş yapamıyor.':
      'License expired ({expiry}). Students, coaches and parents can’t sign in.',
  'Kurumunun lisans süresi doldu. Kurum yöneticinle iletişime geç.':
      'Your school’s licence has expired. Contact your school administrator.',
  'Öğrencinin koçunu değiştirebilir miyim?': 'Can I change a student’s coach?',
  'Evet. Öğrenciler listesinde öğrencinin seçeneklerinden "Koçunu değiştir"i kullan.':
      'Yes. Use "Change coach" in the student’s options on the Students list.',
  'Kurumun görünümünü değiştirebilir miyim?':
      'Can I change how my school looks in the app?',
  'Evet. Ana sayfadaki "Kurum görünümü: logo, renk ve yazı tipi" düğmesiyle logoyu, renkleri ve yazı tipini; "Kurum adını değiştir" ile kurumun adını düzenleyebilirsin.':
      'Yes. Use the "Branding: logo, colors and font" button on the home screen for the logo, colours and font, and "Rename institution" for its name.',
  'Toplu duyuru nasıl gönderirim?':
      'How do I send an announcement to everyone?',
  'Ana sayfadaki "Duyurular" kartında "Yeni duyuru"ya dokun. Herkes, öğrenciler, veliler ya da koçlardan birini seç, başlığı ve metni yaz. Duyuru herkese bildirim olarak gider; 24 saatte en fazla 10 duyuru gönderebilirsin.':
      'Tap "New announcement" on the "Announcements" card on the home screen. Choose everyone, students, parents or coaches, then write a title and text. It is sent to everyone as a notification; you can send up to 10 announcements in 24 hours.',
  'Takip': 'Following progress',
  'Hangi öğrenciler bu hafta çalışmadı?':
      'Which students didn’t study this week?',
  'Ana sayfadaki "Bu hafta hareketsiz öğrenciler" kartı, bu hafta soru ya da çalışma kaydı olmayanları listeler.':
      'The "Inactive students this week" card on the home screen lists students with no questions or study logged this week.',
  'Başarı sıralamasını nasıl açarım?': 'How do I turn on the success ranking?',
  'Başarı sıralaması ekranından aç ya da kapat. Açınca öğrenciler deneme netlerine göre kurum içi sıralamayı görür; kapalıyken yalnızca sen önizlersin.':
      'Turn it on or off from the success ranking screen. When on, students see the in-school ranking by exam scores; when off, only you can preview it.',
  'Koçların verdiği bilgileri görebilir miyim?':
      'Can I see what coaches enter?',
  'Evet. Her öğrencinin detayını koçun gördüğü gibi görürsün: denemeler, sorular, görevler, ödevler, notlar ve Eğitim karnesi.':
      'Yes. You see each student’s page as their coach does: exams, questions, tasks, homework, notes and the Learn report.',
  'Kendi hesabımı silebilir miyim?': 'Can I delete my own account?',
  'Profil > Güvenlik > "Hesabımı sil" ile silebilirsin. Kurumun tek müdürüysen önce başka bir müdür eklenmelidir.':
      'Yes, from Profile > Security > "Delete my account". If you’re the school’s only manager, another manager must be added first.',
  'Çocuğumun hesabına nasıl bağlanırım?':
      'How do I connect to my child’s account?',
  'Çocuğun uygulamada profilinden "Veli davet kodu oluştur"a dokunur ve kodu sana verir. Bu kodla kayıt olunca çocuğunun gelişimini görürsün.':
      'Your child taps "Create parent invite code" in their profile and gives you the code. After you sign up with it, you can follow their progress.',
  'Birden fazla çocuğumu takip edebilir miyim?':
      'Can I follow more than one child?',
  'Evet. Her çocuğun ayrı bir veli kodu oluşturur; bağlandığın tüm çocuklar ana sayfanda listelenir.':
      'Yes. Each child creates their own parent code, and every linked child is listed on your home screen.',
  'Neleri görebilirim?': 'What can I see?',
  'Çocuğunun denemelerini, çözdüğü soruları, konularını, çalışma süresini, ödevlerini, Hata Defteri\'ni ve haftalık Bal Raporu\'nu görürsün.':
      'You see your child’s exams, solved questions, topics, study time, homework, Mistake Notebook and weekly Honey Report.',
  'Haftalık rapor ne zaman gelir?': 'When does the weekly report arrive?',
  'Her pazar akşamı haftanın özeti bildirim olarak gelir: çözülen soru, odak süresi ve çalışılan gün sayısı.':
      'Every Sunday evening you get the week’s summary as a notification: questions solved, focus time and days studied.',
  'Kurumun duyurularını nereden görürüm?':
      'Where do I see the school’s announcements?',
  'Kurum ya da koç velilere duyuru yapınca bildirim gelir; son duyuru ana sayfanda "Duyurular" kartında görünür.':
      'When the school or coach makes an announcement to parents you get a notification, and the latest one appears on the "Announcements" card on your home screen.',
  'Verilerde değişiklik yapabilir miyim?': 'Can I change any data?',
  'Hayır. Veli paneli yalnızca izlemek içindir; kayıtları çocuğun ve koçu girer.':
      'No. The parent panel is view-only; your child and their coach enter the records.',
  'Koçla nasıl iletişime geçerim?': 'How do I contact the coach?',
  'Uygulamada mesajlaşma yoktur. Koçla dershane üzerinden iletişime geçebilirsin.':
      'There’s no messaging in the app. You can reach the coach through the school.',
  'Uygulama': 'The app',
  'Bildirimler gelmiyor, ne yapmalıyım?':
      'I’m not getting notifications. What should I do?',
  'Telefonunun ayarlarında Mentoria için bildirim iznini açık tut ve uygulamayı bir kez açıp kapat. Uygulama açıkken bildirimler ekranda kart olarak görünür.':
      'Make sure notifications are allowed for Mentoria in your phone settings, then open and close the app once. While the app is open, notifications appear as cards on screen.',
  'Dili ya da görünümü nasıl değiştiririm?':
      'How do I change the language or appearance?',
  'Profildeki "Görünüm, dil ve ses" kartından dili (Türkçe / İngilizce), temayı (sistem, açık, koyu) ve sesleri ayarlayabilirsin.':
      'Use the "Appearance, language and sound" card in your profile to set the language (Turkish / English), theme (system, light, dark) and sounds.',
  'Şifremi nasıl değiştiririm?': 'How do I change my password?',
  'Profil > Güvenlik > "Şifre değiştir".':
      'Profile > Security > "Change password".',
  'Fotoğraf ya da yüz verisi toplanıyor mu?':
      'Does the app collect photos or face data?',
  'Hayır. Avatar hazır parçalardan oluşur. Hata Defteri\'ne eklediğin soru fotoğrafları yalnızca sen, koçun ve velin tarafından görülür.':
      'No. Avatars are built from ready-made parts. Question photos you add to the Mistake Notebook are only visible to you, your coach and your parent.',
  'Platform yönetimi': 'Platform management',
  'Yeni dershane nasıl eklenir?': 'How do I add a new school?',
  'Profil > "Dershane yönetimi" ekranından yeni dershane ekleyip logo, renk ve yazı tipini düzenleyebilirsin. Dershanenin bağlantısıyla gelen kullanıcılar o görünümü görür.':
      'Add a school from Profile > "School management" and edit its logo, colours and font. Users arriving through the school’s link see that look.',
  // SSS sonu

  // Bildirim kanalı
  'Mentoria bildirimleri': 'Mentoria notifications',
  'Ödev, görüşme, mesaj ve deneme bildirimleri':
      'Homework, meeting, message and exam notifications',

  // KVKK: gizlilik ve izinler, kayıt rızaları
  '18 yaşından küçük olup olmadığını bilmemiz gerekiyor. Doğum yılını bir kez girmen yeterli.':
      'We need to know whether you are under 18. You only need to enter your birth year once.',
  '18 yaşından küçük öğrenciler için gerekli.':
      'Required for students under 18.',
  '18 yaşından küçük öğrencilerin velilerinden onayı kurumumuz aldı ve saklıyor.':
      'Our institution has obtained and keeps the parents\' consent for students under 18.',
  '18 yaşından küçükler için veli onayı gerekiyor.':
      'Parental consent is required for under-18s.',
  '18 yaşından küçüksen velinin onayı gerekir. Kurumun aldıysa bir şey yapmana gerek yok; almadıysa giriş yaptıktan sonra velini davet edersin.':
      'If you are under 18, your parent\'s consent is required. If your institution has obtained it, you don\'t need to do anything; otherwise you\'ll invite your parent after signing in.',
  'Aydınlatma Metni\'ni oku': 'Read the Privacy Notice',
  'Aydınlatma Metni\'ni okudum.': 'I have read the Privacy Notice.',
  'Kullanım Koşulları\'nı kabul ediyorum; Aydınlatma Metni\'ni okudum.':
      'I accept the Terms of Use and have read the Privacy Notice.',
  'Kullanım Koşulları\'nı oku': 'Read the Terms of Use',
  'Kullanım Koşulları': 'Terms of Use',
  'Gizlilik Politikası': 'Privacy Policy',
  'Tüm hakları saklıdır.': 'All rights reserved.',
  'Sürüm {v}': 'Version {v}',
  // Kurum kredisi ve kurum kodu
  'Öğrenci kredisi: {n}': 'Student credits: {n}',
  'Kredi bitti. Yeni öğrenci eklenemez; yöneticinizle iletişime geçin.':
      'No credits left. New students can\'t be added; please contact your administrator.',
  '{n} öğrenci kayıtlı': '{n} students registered',
  'Kurumunun öğrenci kredisi bitti. Kurum yöneticinle iletişime geç.':
      'Your institution has no student credits left. Please contact your institution\'s administrator.',
  'Kurumunda henüz koç yok. Kurum yöneticinle iletişime geç.':
      'Your institution has no coaches yet. Please contact your institution\'s administrator.',
  'Kurumun hesabı şu an kapalı. Kurum yöneticinle iletişime geç.':
      'Your institution\'s account is currently inactive. Please contact your institution\'s administrator.',
  'Davet kodu geçersiz ya da süresi dolmuş veya kurumun öğrenci kredisi bitmiş.':
      'The invite code is invalid or expired, or the institution has no student credits left.',
  'Koçunun verdiği kod ya da kurum kodu (MENTORIA-…)':
      'The code from your coach or your institution code (MENTORIA-…)',
  'Kurum hesabı kapalı': 'Institution account inactive',
  'Öğrenci krediniz bitti': 'You have no student credits left',
  'Öğrenci krediniz azalıyor: {n} kaldı':
      'Student credits running low: {n} left',
  'Yeni öğrenci eklenemez. Yöneticinizle iletişime geçin.':
      'New students can\'t be added. Please contact your administrator.',
  'Yöneticinizle iletişime geçin.': 'Please contact your administrator.',
  'Kurum kodu yenilensin mi?': 'Renew the institution code?',
  'Eski kod hemen geçersiz olur. Kodu paylaştığın öğrencilere yenisini göndermen gerekir.':
      'The old code stops working right away. You\'ll need to send the new one to the students you shared it with.',
  'Yenile': 'Renew',
  'Kod yenilenemedi. Tekrar dene.': 'Couldn\'t renew the code. Try again.',
  'Kurum kodu': 'Institution code',
  'Öğrenciler kayıt olurken bu kodu yazar; en az öğrencisi olan koça bağlanır. Her yeni öğrenci 1 kredi kullanır.':
      'Students enter this code when signing up and are assigned to the coach with the fewest students. Each new student uses 1 credit.',
  'Kodu yenile': 'Renew code',
  'Kalan öğrenci kredisi: {n}': 'Student credits left: {n}',
  'Açık rıza metnini oku': 'Read the explicit consent text',
  'Başarı sıralamasında görün': 'Appear in the success ranking',
  'Başarı sıralamasında görünsün': 'Appear in the success ranking',
  'Bir kez girilir; sonra yalnızca koçun ya da kurumun değiştirebilir.':
      'Entered once; after that only your coach or institution can change it.',
  'Biraz sonra yeniden dene.': 'Try again in a moment.',
  'Bu kodla katılan öğrencilerden ayrıca veli onayı istenmez.':
      'Students joining with this code won\'t be asked for parental consent separately.',
  'Davet ettiğin velin çalışma sürelerini, soru sayılarını ve deneme sonuçlarını görür.':
      'The parent you invite sees your study time, question counts and exam results.',
  'Davet ettiğin velin çalışma sürelerini, soru sayılarını, deneme sonuçlarını ve haftalık özetini görür. İzni istediğin zaman "Gizlilik ve izinler"den geri çekebilirsin; o zaman velinin bağlantısı kaldırılır.':
      'The parent you invite sees your study time, question counts, exam results and weekly summary. You can withdraw this permission at any time in "Privacy & permissions"; your parent\'s link is then removed.',
  'Devam etmek için Aydınlatma Metni\'ni okuduğunu onayla.':
      'To continue, confirm that you have read the Privacy Notice.',
  'Doğum yılı': 'Birth year',
  'Doğum yılı: {year}': 'Birth year: {year}',
  'Doğum yılın': 'Your birth year',
  'Doğum yılını gir': 'Enter your birth year',
  'Doğum yılını seç.': 'Select your birth year.',
  'Gizlilik ve izinler': 'Privacy & permissions',
  'Haklarınla ilgili başvurular için: {email}. En geç 30 gün içinde ücretsiz cevap verilir.':
      'For requests about your rights: {email}. You\'ll get a free answer within 30 days at the latest.',
  'Hepsi isteğe bağlı. Kapatsan da Mentoria\'yı kullanmaya devam edersin.':
      'All optional. You can keep using Mentoria even if you turn them off.',
  'KVKK metinleri, izinlerin ve verilerini indirme':
      'Privacy texts, your permissions and downloading your data',
  'Kaydedilemedi.': 'Couldn\'t save.',
  'Kurumumdaki başarı sıralamasında adımın kısaltması, avatarım ve netimle görünmek istiyorum.':
      'I want to appear in my institution\'s success ranking with my shortened name, avatar and net score.',
  'Kurumundaki diğer öğrenciler adının kısaltmasını (ör. "El***"), avatarını ve netini görür.':
      'Other students at your institution see your shortened name (e.g. "El***"), avatar and net score.',
  'Kurumundaki diğer öğrenciler adının kısaltmasını, avatarını ve netini görür.':
      'Other students at the institution see the shortened name, avatar and net score.',
  'Mentoria verilerim': 'My Mentoria data',
  'Mentoria\'daki bütün kayıtların tek bir dosyada (JSON). Kaydedebilir ya da paylaşabilirsin.':
      'All your Mentoria records in one file (JSON). You can save or share it.',
  'Mentoria\'yı kullanmasına onay veriyorum':
      'I consent to my child using Mentoria',
  'Metin açılamadı': 'Couldn\'t open the text',
  'Metinler': 'Texts',
  'Onay kurum kaydında alındı.':
      'Consent was obtained at institution enrolment.',
  'Onayı geri çek': 'Withdraw consent',
  'Onayını geri çekmek istiyor musun?': 'Do you want to withdraw your consent?',
  'Sağlık, aile durumu gibi özel bilgileri yazma.':
      'Don\'t write sensitive information such as health or family situation.',
  'Veli onay metnini oku': 'Read the parental consent text',
  'Veli onayı bekleniyor': 'Waiting for parental consent',
  'Veli onayı bekleniyor. 18 yaşından küçük olduğun için velinin onayı gerekiyor. Profil sayfasındaki "Veli bağlantısı"ndan velini davet et; velin kayıt olurken onay verir.':
      'Waiting for parental consent. Because you are under 18, your parent\'s consent is required. Invite your parent from "Parent link" on your profile; they give consent when signing up.',
  'Veli onayı gelince sıralamada görünürsün (adının kısaltması, avatarın ve netin).':
      'You\'ll appear in the ranking once your parent consents (shortened name, avatar and net score).',
  'Veli onayın kurumun tarafından alındı.':
      'Your parental consent was obtained by your institution.',
  'Velim çalışmalarımı görebilsin': 'Let my parent see my progress',
  'Velin artık çalışmalarını ve denemelerini göremez. İstersen sonra yeniden davet edebilirsin.':
      'Your parent will no longer see your studies and exams. You can invite them again later.',
  'Velin onay verdi.': 'Your parent has given consent.',
  'Velin çalışmalarını görebilsin mi?': 'Let your parent see your progress?',
  'Velini davet et; kayıt olurken onay verir.':
      'Invite your parent; they consent when signing up.',
  'Velinin erişimi kaldırılsın mı?': 'Remove your parent\'s access?',
  'Veriler hazırlanamadı.': 'Couldn\'t prepare your data.',
  'Verilerimi indir': 'Download my data',
  'Verilerinin nasıl işlendiğini buradan okuyabilirsin.':
      'Read here how your data is processed.',
  'Yaş ve veli onayı': 'Age and parental consent',
  'Çocuğumun Mentoria\'yı kullanmasına ve bu kapsamda kişisel verilerinin işlenmesine yasal temsilcisi olarak onay veriyorum.':
      'As their legal representative, I consent to my child using Mentoria and to the processing of their personal data for this purpose.',
  'Çocuğumun kurumundaki başarı sıralamasında adının kısaltması, avatarı ve netiyle görünmesine izin veriyorum.':
      'I allow my child to appear in their institution\'s success ranking with a shortened name, avatar and net score.',
  'Çocuğunun Mentoria\'yı kullanabilmesi için veli onayı gerekiyor.':
      'Parental consent is required for your child to use Mentoria.',
  'Çocuğunun hesabı için silme talebi açılır; koçu ya da kurumu hesabı kapatır. Bu işlem geri alınamaz.':
      'A deletion request is opened for your child\'s account; their coach or institution closes it. This can\'t be undone.',
  'Öğrencinin doğum yılı.': 'The student\'s birth year.',
  'İsteğe bağlı': 'Optional',
  'İzin veriyorum': 'I allow',
  'İzinlerin': 'Your permissions',
  'İşaretlemezsen 18 yaşından küçük öğrenciler velilerini uygulamadan davet edip onay alır.':
      'If unchecked, students under 18 invite their parents in the app to get consent.',
  'Aydınlatma Metni': 'Privacy Notice',
  'Açık Rıza Metni': 'Explicit Consent Text',
  'Veli Onay Metni': 'Parental Consent Text',

  // Zorunlu güncelleme
  'Yeni sürüm gerekli': 'New version required',
  'Uygulamanın bu sürümü artık desteklenmiyor. Devam etmek için en yeni sürümü yükle; verilerin kaybolmaz.':
      'This version of the app is no longer supported. Install the latest version to continue; your data won\'t be lost.',
  'Güncelle': 'Update',
  'Yeni sürümü kurumundan ya da koçundan isteyebilirsin.':
      'You can ask your institution or coach for the new version.',
  'Senin sürümün: {v}': 'Your version: {v}',
  // Koç listesi
  'Silme talebi': 'Deletion request',
  // KVKK: saklama uyarısı ve web'den hesap silme
  'Hesabın yakında silinecek': 'Your account will be deleted soon',
  'Uzun süredir giriş yapmadın. {n} gün içinde uygulamayı açmazsan hesabın ve verilerin silinecek.':
      'You haven\'t signed in for a long time. If you don\'t open the app within {n} days, your account and data will be deleted.',
  'Talebin alındı. Hesabını ve tüm verilerini koçun siler; 29 gün içinde silinmezse sistem otomatik olarak siler.':
      'Your request has been received. Your coach will delete your account and all your data; if it is not deleted within 29 days, the system deletes it automatically.',
  'Hesabın kalıcı olarak silinsin mi?': 'Permanently delete your account?',
  'Hesabın ve tüm verilerin hemen silinir. Bu işlem geri alınamaz.':
      'Your account and all your data will be deleted immediately. This cannot be undone.',
  'Hesabın ve tüm verilerin silindi.':
      'Your account and all your data have been deleted.',
  '{email} adresi kayıtlıysa 6 haneli bir kod gönderdik. Kodu aşağıya yaz.':
      'If {email} is registered, we sent a 6-digit code to it. Enter the code below.',
  'Doğrula': 'Verify',
  'E-postayı değiştir': 'Change email',
  'Hesabının e-posta adresini yaz. Hesabın sana ait olduğunu doğrulamak için bu adrese bir kod göndereceğiz.':
      'Enter your account\'s email address. We\'ll send a code to it to confirm the account is yours.',
  'Kod gönder': 'Send code',
  'Hesap silme': 'Account deletion',
  'Giriş yapılan hesap: {name} ({role})': 'Signed in as: {name} ({role})',
  'Öğrenci hesabını koçun siler. Talebin koçuna iletilir; 29 gün içinde silinmezse hesabın ve tüm verilerin sistem tarafından otomatik olarak silinir.':
      'Student accounts are deleted by the coach. Your request is sent to your coach; if it is not deleted within 29 days, your account and all your data are deleted automatically by the system.',
  'Hesabın ve tüm verilerin hemen ve kalıcı olarak silinir.':
      'Your account and all your data will be deleted immediately and permanently.',
  'Silme talebi gönder': 'Send deletion request',
  'Vazgeç ve çıkış yap': 'Cancel and sign out',
  'Neler silinir?': 'What is deleted?',
  'Profilin, denemelerin, soru ve çalışma kayıtların, görevler, notlar, hata defteri fotoğrafları, bildirimler ve izin kayıtların silinir. Sistem yedeklerindeki kopyalar en geç 7 gün içinde kendiliğinden silinir.':
      'Your profile, exams, question and study logs, tasks, notes, mistake-book photos, notifications and consent records are deleted. Copies in system backups are removed automatically within 7 days at most.',
  'Sorun yaşarsan {email} adresine yazabilirsin.':
      'If you run into a problem, you can write to {email}.',
  // Optik okuma
  'Başarı %': 'Success %',
  'Başlık satırı bulunamadı. Tabloda "Ders", "Soru No" ve "Cevap" sütunları olmalı.':
      'Header row not found. The table must have "Subject", "Question No" and "Answer" columns.',
  'Bu denemenin optik formu uygulamada yok. Uygulamayı güncelle.':
      'This exam\'s answer sheet form isn\'t in the app. Update the app.',
  'Bu sınav türü için uygulamada optik form şablonu yok. Kullandığınız formun boş ve dolu birer fotoğrafını gönderin; şablon eklenince okuyabilirsiniz.':
      'There\'s no answer sheet template for this exam type yet. Send one blank and one filled photo of the form you use; you can scan once the template is added.',
  'Bu öğrencinin denemesi 7 günden eski; optiği yeniden okunamaz.':
      'This student\'s exam is older than 7 days; the sheet can\'t be scanned again.',
  'Bu öğrencinin optiği daha önce okunmuştu; kaydedersen sonucu güncellenir.':
      'This student\'s sheet was already scanned; saving will update the result.',
  'Cevap anahtarı': 'Answer key',
  'Cevap anahtarı silinsin mi?': 'Delete the answer key?',
  'Cevap anahtarını sil': 'Delete answer key',
  'Cevaplar': 'Answers',
  'Deneme tarihi': 'Exam date',
  'Dosya okunamadı. Excel (.xlsx, .xls) ya da CSV kazanım tablosu seç.':
      'The file couldn\'t be read. Choose an Excel (.xlsx, .xls) or CSV outcome table.',
  'Doğru Cevap': 'Correct Answer',
  'Emin olunamayan sorular ({n})': 'Uncertain questions ({n})',
  'En çok yanlış yapılan kazanımlar': 'Most missed outcomes',
  'Excel dosyası seç': 'Choose Excel file',
  'Excel hazırlanamadı.': 'The Excel file couldn\'t be prepared.',
  'Excel indir': 'Download Excel',
  'Excel\'de "Ders", "Soru No", "Cevap" ve "Kazanım" sütunları olmalı. Ders yerine test adı (ör. Sosyal Bilimler 1–20) da olur.':
      'The Excel file needs "Subject", "Question No", "Answer" and "Outcome" columns. A test name (e.g. Social Sciences 1–20) works instead of a subject too.',
  'Formda öğrenci numarası işaretlenmemiş.':
      'No student number is marked on the form.',
  'Formdaki numara net okunamadı: {n}':
      'The number on the form couldn\'t be read clearly: {n}',
  'Formdaki numaradan bulundu: {n}': 'Found from the number on the form: {n}',
  'Formun dört köşesindeki siyah kareler bulunamadı. Kâğıdı düz bir yere koy, dört köşesi de görünecek şekilde tepeden ve iyi ışıkta çek.':
      'The black squares in the form\'s four corners weren\'t found. Lay the sheet flat and shoot from above in good light with all four corners visible.',
  'Fotoğraf okunamadı. Tekrar dene.': 'The photo couldn\'t be read. Try again.',
  'Kaydet ({n} soru boş sayılacak)': 'Save ({n} questions will count as blank)',
  'Kaydet ve optik okumaya geç': 'Save and start scanning',
  'Kaydettikten sonra cevap anahtarı değiştirilemez; yanlışsa silip yeniden ekle.':
      'The answer key can\'t be changed after saving; if it\'s wrong, delete it and add it again.',
  'Kazanım': 'Outcome',
  'Kazanım ve cevap anahtarı': 'Outcomes and answer key',
  'Kazanımlar': 'Outcomes',
  'Okunamayan {n} satır: {rows}': '{n} unreadable rows: {rows}',
  'Okunan optikler': 'Scanned sheets',
  'Okunmuş optikler öğrencilerin denemelerinde kalır; onları "Denemeler" ekranından silebilirsin.':
      'Scanned sheets stay in the students\' exams; you can delete them from the "Exams" screen.',
  'Optik form': 'Answer sheet form',
  'Optik formları telefonla oku': 'Scan answer sheets with your phone',
  'Optik oku': 'Scan sheet',
  'Optik okuma': 'Answer sheet scanning',
  'Optik okunamadı': 'The sheet couldn\'t be read',
  'Optiği kontrol et': 'Check the sheet',
  'Satır {n}: {label} {no}': 'Row {n}: {label} {no}',
  'Seçilen dosya bir fotoğraf değil.': 'The selected file isn\'t a photo.',
  'Sonuç': 'Result',
  'Sıra': 'Rank',
  'Tabloda {type} sorusu bulunamadı. Sınav türünü kontrol et.':
      'No {type} questions found in the table. Check the exam type.',
  'Toplam Boş': 'Total Blank',
  'Toplam Doğru': 'Total Correct',
  'Toplam Net': 'Total Net',
  'Toplam Yanlış': 'Total Wrong',
  'Tüm soruları doğru yaptın!': 'You got every question right!',
  'En çok kaçırılan konular': 'Most missed topics',
  'Metinlerimiz güncellendi': 'Our terms have been updated',
  'Devam etmeden önce Kullanım Koşulları\'nı ve Aydınlatma Metni\'ni okuyup onaylaman gerekiyor.':
      'Before continuing, please read and accept the Terms of Use and the Privacy Notice.',
  'Onayla ve devam et': 'Accept and continue',
  // Kurum finansı
  'Nakit': 'Cash',
  'Havale / EFT': 'Bank transfer',
  'Kart': 'Card',
  'Kira': 'Rent',
  'Maaş': 'Salary',
  'Prim': 'Bonus',
  'Faturalar': 'Utilities',
  'Kitap / materyal': 'Books / materials',
  'Reklam': 'Advertising',
  'Vergi / SGK': 'Tax / social security',
  'Finans': 'Finance',
  'Ücretler': 'Fees',
  'Giderler': 'Expenses',
  'Önceki ay': 'Previous month',
  'Sonraki ay': 'Next month',
  'Tahsilat': 'Collected',
  'Beklenen: {v}': 'Expected: {v}',
  'Gider': 'Expenses',
  'Tahsilat − gider': 'Collected − expenses',
  'Geciken': 'Overdue',
  '{n} taksit': '{n} instalments',
  'Son 6 ay': 'Last 6 months',
  'Tahsilat ve gider': 'Collected and expenses',
  'Geciken taksitler': 'Overdue instalments',
  'Vade: {d}': 'Due: {d}',
  'Yalnızca gecikenler': 'Overdue only',
  'Ücret ekle': 'Add fee',
  'Geciken taksit yok': 'No overdue instalments',
  'Henüz ücret yok': 'No fees yet',
  'Öğrenciye ücret ve taksit planı ekle; ödeme gelince işaretle.':
      'Add a fee and instalment plan for a student; mark payments as they come in.',
  '{p} / {t} ödendi': '{p} / {t} paid',
  '{n} gecikmiş': '{n} overdue',
  'Ödenmedi olarak geri alınsın mı?': 'Mark as unpaid?',
  '{v} tutarındaki taksit ödenmemiş görünecek.':
      'The {v} instalment will show as unpaid.',
  'Nasıl ödendi?': 'How was it paid?',
  'Kalan: {v}': 'Remaining: {v}',
  'Ödendi: {d} · {m}': 'Paid: {d} · {m}',
  'Gecikti': 'Overdue',
  'Ücret silinsin mi?': 'Delete this fee?',
  'Ücret ve tüm taksitleri silinecek.':
      'The fee and all its instalments will be deleted.',
  'Ücreti sil': 'Delete fee',
  'YKS kursu': 'YKS course',
  'Öğrenci, başlık ve tutarı gir.': 'Enter the student, title and amount.',
  'Toplam tutar': 'Total amount',
  'Taksit': 'Instalments',
  'Peşin': 'Single payment',
  'Gider ekle': 'Add expense',
  'Henüz gider yok': 'No expenses yet',
  'Kira, maaş, fatura gibi giderleri buraya yaz.':
      'Record expenses such as rent, salaries and utilities here.',
  'Gider silinsin mi?': 'Delete this expense?',
  '{c} · {v}': '{c} · {v}',
  'Tutarı gir.': 'Enter the amount.',
  'Tür': 'Type',
  'Koç (isteğe bağlı)': 'Coach (optional)',
  'Aylık maaş': 'Monthly salary',
  'Bu ay tahsilat {v}': 'Collected this month: {v}',
  'Bu ay tahsilat {v} · {n} geciken taksit':
      'Collected this month: {v} · {n} overdue instalments',
  'Bu ay ödendi': 'Paid this month',
  'Bu ay: {v}': 'This month: {v}',
  'Koç davet edince maaş ve primi buradan tutarsın.':
      'Once you invite coaches, track their salary and bonus here.',
  'Maaş ve primi düzenle': 'Edit salary and bonus',
  'Tutar': 'Amount',
  '{m} maaşı': '{m} salary',
  '{n} öğrenci · maaş {s} · öğrenci başı {p}':
      '{n} students · salary {s} · per student {p}',
  'Ödemeyi kaydet': 'Record payment',
  'Önerilen ödeme = aylık maaş + öğrenci sayısı × öğrenci başı prim.':
      'Suggested payment = monthly salary + number of students × bonus per student.',
  'Öğrenci başı prim': 'Bonus per student',
  'Ücret, taksit, gider ve koç maaşları':
      'Fees, instalments, expenses and coach salaries',
  'Bugün hatırlatılacak ödenmemiş taksit yok.':
      'No unpaid instalments to remind about today.',
  'Bugün hatırlatıldı': 'Reminded today',
  'Bugün {n} taksitin günü geldi': '{n} instalments are due today',
  'Cep telefonunu 05XX XXX XX XX biçiminde yaz.':
      'Enter the mobile number as 05XX XXX XX XX.',
  'Gönder ({n})': 'Send ({n})',
  'Hatırlatma SMS\'i gönderilsin mi?': 'Send a reminder SMS?',
  'Hatırlatma gönderilmedi: telefon yok ya da bugün gönderildi.':
      'No reminder sent: no phone number, or already sent today.',
  'Hatırlatıldı: {d}': 'Reminded: {d}',
  'Her ayın {d}. günü': 'Day {d} of each month',
  'Seçilen velilere SMS gider.': 'An SMS goes to the selected parents.',
  'Taksit hatırlatma SMS\'i bu numaraya gider.':
      'Instalment reminder SMS messages go to this number.',
  'Taksit hatırlatması gönderilsin mi?': 'Send instalment reminders?',
  'Toplam {v}. Velilere hatırlatma gönderilsin mi?':
      'Total {v}. Send reminders to parents?',
  'Veli adı (isteğe bağlı)': 'Parent name (optional)',
  'Veli cep telefonu': 'Parent mobile number',
  'Veli telefonu yok': 'No parent phone number',
  'Veliye hatırlat': 'Remind parent',
  '{n} hatırlatma SMS sırasına alındı.': '{n} reminder SMS queued.',
  '{who} · {phone}\n{v} · vade {d}': '{who} · {phone}\n{v} · due {d}',
  'Ödeme günü': 'Payment day',
  'Ödeme günü ve veli': 'Payment day and parent',
  'Önce veli telefonunu ekle.': 'Add the parent phone number first.',
  'İlk taksit': 'First instalment',
  '{n} boş': '{n} blank',
  'Tüm konuları göster (+{n})': 'Show all topics (+{n})',
  'Soru soru': 'Question by question',
  'Daha az göster': 'Show less',
  'Yalnızca anahtarı ekleyen kişi silebilir.':
      'Only the person who added the key can delete it.',
  'Yanlış + boş, tüm okunan optiklerde':
      'Wrong + blank, across all scanned sheets',
  'Yanlışların ve boşların ({w} yanlış, {b} boş)':
      'Your wrong and blank answers ({w} wrong, {b} blank)',
  'Yayınevi (isteğe bağlı)': 'Publisher (optional)',
  'Yeni deneme': 'New exam',
  'Yeni deneme ekleyip kazanım tablosunu yükleyince optik okumaya başlayabilirsin.':
      'Add a new exam and upload its outcome table to start scanning sheets.',
  'Yeniden çek': 'Retake',
  '{c} D · {w} Y · {b} B': '{c} C · {w} W · {b} B',
  '{c} doğru · {w} yanlış · {b} boş': '{c} correct · {w} wrong · {b} blank',
  '{name}: optik yeniden okundu, {net} net.':
      '{name}: sheet scanned again, {net} net.',
  '{name}: {net} net kaydedildi.': '{name}: {net} net saved.',
  '{n} numaralı öğrencin yok; listeden seç.':
      'You have no student numbered {n}; pick from the list.',
  '{n} optik okundu': '{n} sheets scanned',
  '{n} soru · {k} kazanım · {c} iptal':
      '{n} questions · {k} outcomes · {c} cancelled',
  '{n} öğrenci · nete göre': '{n} students · by net',
  '{subject} {n}. soru · boş · doğru: {c}':
      '{subject} Q{n} · blank · correct: {c}',
  '{subject} {n}. soru · görünen: {c}': '{subject} Q{n} · visible: {c}',
  '{subject} {n}. soru · sen: {m} · doğru: {c}':
      '{subject} Q{n} · you: {m} · correct: {c}',
  '{subject}: {n} soru': '{subject}: {n} questions',
  '{subject}: {n}/{total} soru (eksik sorular değerlendirilmez)':
      '{subject}: {n}/{total} questions (missing questions are not scored)',
  'Önce denemenin kazanım ve cevap anahtarı Excel\'ini yükle. Sonra optikleri telefonla tek tek çek; her öğrencinin yanlışları kazanımlarıyla birlikte kaydedilir.':
      'First upload the exam\'s outcome and answer key Excel. Then photograph the sheets one by one; each student\'s mistakes are saved with their outcomes.',
  'Öğrenci No': 'Student No',
  'ör. Kasım TYT-1': 'e.g. November TYT-1',
  'İki şık işaretli ya da işaret silik. Kâğıda bakıp doğru şıkkı seç; seçmezsen boş sayılır.':
      'Two options are marked or the mark is faint. Check the paper and pick the right option; if you don\'t, it counts as blank.',
  'İpucu: kâğıdı düz bir masaya koy, dört köşedeki siyah kareler kadraja girsin ve gölge düşmesin. Kaydedince kamera sıradaki optik için yeniden açılır.':
      'Tip: lay the sheet on a flat table, keep the four black corner squares in frame and avoid shadows. After saving, the camera reopens for the next sheet.',
  // Optik okuma: cevap kâğıdı ve kitapçık
  'Boş cevap kâğıdını indir (PDF)': 'Download blank answer sheet (PDF)',
  'Bu denemenin cevap anahtarında B kitapçığı numaraları yok. Kazanım Excel\'ine "B Soru No" sütununu ekleyip denemeyi yeniden oluştur.':
      'This exam\'s answer key has no booklet B numbers. Add a "B Question No" column to the outcome Excel and create the exam again.',
  'Cevap anahtarında B kitapçığı numaraları yok.':
      'The answer key has no booklet B numbers.',
  'Form hazırlanamadı. Tekrar dene.':
      'The form couldn\'t be prepared. Try again.',
  'Formda kitapçık işaretlenmemiş; A sayıldı.':
      'No booklet is marked on the form; counted as A.',
  'Formda {form} işaretli ama bu deneme {key}. Doğru denemeyi okuttuğundan emin ol.':
      'The form is marked {form} but this exam is {key}. Make sure you are scanning for the right exam.',
  'Formdaki kitapçık işareti net değil; kâğıda bakıp seç.':
      'The booklet mark on the form isn\'t clear; check the paper and choose.',
  'Formdan okundu: {b}': 'Read from the form: {b}',
  'Kitapçık': 'Booklet',
  'Mentoria YKS cevap kâğıdı': 'Mentoria YKS answer sheet',
  '{subject} {n}: B numarası tekrar ediyor':
      '{subject} {n}: booklet B number is repeated',
  // Optik okuma: form seçimi
  'Hangi cevap kâğıdı?': 'Which answer sheet?',
  'Kenarında zamanlama çizgisi olan, yayınevi tarzı form':
      'Publisher-style sheet with timing marks along the edge',
  'Köşelerinde siyah kare olan, kamera için en sağlam form':
      'Sheet with black corner squares, the most reliable for the camera',
  'Bu denemenin boş kâğıdını indir (PDF)':
      'Download this exam\'s blank sheet (PDF)',
  'Öğrencilere cevap kâğıdını dağıt: TYT ve AYT aynı kâğıtta. PDF\'i indirip istediğin kadar çoğaltabilirsin.':
      'Hand out the answer sheet: TYT and AYT are on the same sheet. Download the PDF and print as many as you need.',
  'Standart YKS optik formu (kenar çizgili)':
      'Standard YKS answer sheet (edge timing marks)',
  // Yoklama
  'Geldi': 'Present',
  'Gelmedi': 'Absent',
  'Geç geldi': 'Late',
  'İzinli': 'Excused',
  'Kaydedilmemiş yoklama': 'Unsaved attendance',
  'Yaptığın işaretler silinsin mi?': 'Discard the marks you made?',
  'Yoklama kaydedildi.': 'Attendance saved.',
  'Yoklama': 'Attendance',
  'Gelmeyenlerin velisine SMS': 'SMS parents of absent students',
  'Önceki gün': 'Previous day',
  'Bugün · {d}': 'Today · {d}',
  'Sonraki gün': 'Next day',
  'Yoklama alınacak öğrenci yok.':
      'There are no students to take attendance for.',
  'İşaretsiz {n}': 'Unmarked {n}',
  'İşaretsizlerin hepsi geldi': 'Mark all unmarked as present',
  'Yoklamayı kaydet ({n})': 'Save attendance ({n})',
  'Veli telefonu kaydedildi.': 'Parent\'s phone saved.',
  'No {n}': 'No. {n}',
  'Veliye SMS gönderildi': 'SMS sent to parent',
  'Kaydedilmedi': 'Not saved',
  'Veli telefonu': 'Parent\'s phone',
  'Veli telefonu ekle': 'Add parent\'s phone',
  'Şu an kurum finansındaki veli numarası kullanılıyor. Buraya yazarsan bu numara kullanılır.':
      'The parent number from the institution\'s finance records is used now. If you enter one here, this number is used instead.',
  '"Gelmedi" SMS\'i bu numaraya gider.':
      'The "absent" SMS goes to this number.',
  'SMS gönderilecek gelmeyen öğrenci yok.':
      'There are no absent students to send an SMS for.',
  'Gelmeyenlerin velisine SMS gönderilsin mi?':
      'Send an SMS to the parents of absent students?',
  'Seçilen velilere "öğrenciniz bugün kuruma gelmedi" SMS\'i gider.':
      'Selected parents get a "your child did not come to the institution" SMS.',
  'Kurumdaki veli numarası': 'Parent number on file',
  'Gönderme': 'Don\'t send',
  'SMS gönderilmedi: telefon yok ya da bugün gönderildi.':
      'No SMS sent: no phone, or already sent today.',
  '{n} veliye SMS sırasına alındı.': 'SMS queued for {n} parents.',
  'Günlük yoklama ve gelmeyenin velisine SMS':
      'Daily attendance and SMS to parents of absent students',
  'Bugünkü yoklama alınmadı': 'Today\'s attendance hasn\'t been taken',
  'Bugün {p} geldi · {a} gelmedi': 'Today {p} present · {a} absent',
  '{n} işaretsiz': '{n} unmarked',
  // Ders programı
  'Ders programı': 'Timetable',
  'Bugün ders yok': 'No lessons today',
  'Bugün: {list}': 'Today: {list}',
  'Yayında program yok.': 'No published timetable.',
  '{day} (bugün)': '{day} (today)',
  'Yayında: {name}': 'Published: {name}',
  'Öğretmen, sınıf ve derslikten çakışmasız program':
      'Clash-free timetable from teachers, classes and rooms',
  'Dosya hazırlanamadı. Tekrar dene.':
      'The file couldn\'t be prepared. Try again.',
  'Kurulum': 'Setup',
  'Yeni program': 'New timetable',
  'Kurulumu başlat': 'Start setup',
  'Ders saatlerini, sınıfları, öğretmenleri ve dersleri gir; program çakışmasız oluşturulsun.':
      'Enter lesson times, classes, teachers and lessons; a clash-free timetable is created.',
  'Henüz program yok.': 'No timetable yet.',
  'Yayında': 'Published',
  'Taslak': 'Draft',
  'ceza puanı {n}': 'penalty score {n}',
  'Haftalık program': 'Weekly timetable',
  'Program adı': 'Timetable name',
  'Oluştur': 'Create',
  '{name} silinsin mi?': 'Delete {name}?',
  'Yayındaki program silinirse öğretmen ve öğrenciler programı göremez.':
      'If the published timetable is deleted, teachers and students can\'t see it.',
  'Program oluşturuldu ({ms} ms).': 'Timetable created ({ms} ms).',
  '{n} saat yerleşmedi; nedenleri aşağıda.':
      '{n} hours couldn\'t be placed; reasons below.',
  'Program oluşturulamadı. Tekrar dene.':
      'The timetable couldn\'t be created. Try again.',
  'Program kaydedildi.': 'Timetable saved.',
  'Program yayınlansın mı?': 'Publish the timetable?',
  'Öğretmenler, öğrenciler ve veliler programı uygulamada görür. Yayındaki öteki program taslağa döner.':
      'Teachers, students and parents see the timetable in the app. The other published timetable goes back to draft.',
  'Dikkat: {n} saat ders henüz yerleşmedi.':
      'Note: {n} lesson hours aren\'t placed yet.',
  'Yayınla': 'Publish',
  'Program yayından kaldırıldı.': 'Timetable unpublished.',
  'Program yayınlandı.': 'Timetable published.',
  'Kilitli ders taşınamaz; önce kilidi aç.':
      'A locked lesson can\'t be moved; unlock it first.',
  'Ders taşındı.': 'Lesson moved.',
  'Taşınamadı:': 'Couldn\'t move:',
  'Kilidi aç': 'Unlock',
  'Bu saate kilitle': 'Lock to this time',
  'Kilitli ders yeniden oluşturmada yerinde kalır.':
      'A locked lesson stays in place when regenerating.',
  'Çakışmasız taşınabileceği saat yok.':
      'There is no clash-free time to move it to.',
  'Çakışmasız taşınabileceği saatler': 'Clash-free times to move it to',
  'Kaydedilmemiş değişiklikler': 'Unsaved changes',
  'Program kaydedilmeden çıkılsın mı?': 'Leave without saving the timetable?',
  'Yeniden oluştur (kilitliler korunur)': 'Regenerate (locked lessons kept)',
  'Dışa aktar': 'Export',
  'Sınıflar · PDF': 'Classes · PDF',
  'Öğretmenler · PDF': 'Teachers · PDF',
  'Sınıflar · Excel': 'Classes · Excel',
  'Öğretmenler · Excel': 'Teachers · Excel',
  'Yayından kaldır': 'Unpublish',
  'Sınıf': 'Class',
  'Öğretmen': 'Teacher',
  'Derslik': 'Room',
  'Programı kaydet': 'Save timetable',
  'Yüklenemedi. Tekrar dene.': 'Couldn\'t load. Try again.',
  'Program hazırlanıyor… (en çok 10 sn)':
      'Preparing the timetable… (up to 10 s)',
  'Ceza puanı {n}': 'Penalty score {n}',
  'Ceza puanı düşükse program dengeli: öğretmen penceresi, aynı derse yığılma, öğleden sonra sayısal ders ve sık sınıf değişimi puan ekler.':
      'A low penalty score means a balanced timetable: teacher gaps, the same lesson piling up, afternoon maths/science and frequent class changes add points.',
  'Çakışmalar ve eksikler': 'Clashes and gaps',
  '{lesson}: {n} saat yerleşmedi': '{lesson}: {n} hours not placed',
  'Derslik tanımlı değil.': 'No rooms defined.',
  'Kayıt yok.': 'No records.',
  'Derse dokun: kilitle ya da taşı. Basılı tutup sürükle: başka saate taşı.':
      'Tap a lesson to lock or move it. Press and drag to move it to another time.',
  'Ders programı kurulumu': 'Timetable setup',
  'Geri': 'Back',
  'Ders saatleri': 'Lesson times',
  'Henüz yok': 'None yet',
  '{n} ders saati': '{n} lesson periods',
  'Sınıflar ve derslikler': 'Classes and rooms',
  '{c} sınıf · {r} derslik': '{c} classes · {r} rooms',
  'Öğretmenler ve müsaitlik': 'Teachers and availability',
  '{n} öğretmen': '{n} teachers',
  '{n} ders ihtiyacı': '{n} lesson requirements',
  'Programı oluştur': 'Create timetable',
  'Günler': 'Days',
  'İlk ders': 'First lesson',
  'Günlük ders sayısı': 'Lessons per day',
  'Ders süresi (dk)': 'Lesson length (min)',
  'Teneffüs (dk)': 'Break (min)',
  'Öğle arası şu dersten sonra (0: yok)': 'Lunch break after lesson (0: none)',
  'Öğle arası (dk)': 'Lunch break (min)',
  'Ders saatleri kaydedildi.': 'Lesson times saved.',
  'Şablonu kaydet': 'Save template',
  'Kaldırılan saatlerdeki dersler programlardan silinir.':
      'Lessons in removed periods are deleted from timetables.',
  'Sınıf ekle': 'Add class',
  'Derslikler (isteğe bağlı)': 'Rooms (optional)',
  'Derslik ekle': 'Add room',
  'Programlardaki ilgili dersler de silinir.':
      'Related lessons in timetables are deleted too.',
  'Derslik adı': 'Room name',
  'Kapasite (isteğe bağlı)': 'Capacity (optional)',
  'Sınıfı düzenle': 'Edit class',
  'Sınıf adı': 'Class name',
  'Örn. Sayısal-1': 'E.g. Science-1',
  'Seviye': 'Level',
  'Sınıfın dersliği': 'Class room',
  'Öğrenciler ({n})': 'Students ({n})',
  'Öğrenciler ve velileri programı uygulamada görür.':
      'Students and their parents see the timetable in the app.',
  'Sınıf adını yaz.': 'Enter the class name.',
  'Müsaitlik için önce ders saatlerini kaydet.':
      'Save the lesson times first to set availability.',
  'en çok {n} saat': 'up to {n} hours',
  'her saat müsait': 'available any time',
  '{n} saat müsait': '{n} hours available',
  'Öğretmen ekle': 'Add teacher',
  'Ad ve en az bir branş gerekli.':
      'A name and at least one subject are required.',
  'Öğretmeni düzenle': 'Edit teacher',
  'Branşlar': 'Subjects',
  'Başka branş': 'Other subject',
  'Branş ekle': 'Add subject',
  'Haftalık en çok ders saati': 'Max lesson hours per week',
  'Uygulama hesabı (isteğe bağlı)': 'App account (optional)',
  'Bağlanırsa öğretmen programını kendi panelinde görür.':
      'If linked, the teacher sees their timetable in their own panel.',
  'Bağlı değil': 'Not linked',
  'Müsait saatler': 'Available times',
  'Hepsi': 'All',
  'Hiçbiri': 'None',
  'Dokunarak işaretle: yeşil müsait, gri değil.':
      'Tap to mark: green is available, grey is not.',
  'Önce ders saatlerini kaydet.': 'Save the lesson times first.',
  'Önce sınıf ekle.': 'Add a class first.',
  'Haftada {n} / {max} saat': '{n} / {max} hours per week',
  '{branch} · {n} saat': '{branch} · {n} hours',
  'Öğretmen otomatik seçilir': 'Teacher chosen automatically',
  'günde en çok {n}': 'up to {n} per day',
  'Ders ekle': 'Add lesson',
  'Dersi düzenle': 'Edit lesson',
  'Branş': 'Subject',
  'Haftalık ders saati': 'Hours per week',
  'Günde en çok': 'Max per day',
  'Otomatik seç (branşı tutan)': 'Choose automatically (matching subject)',
  'Bu branşa giren öğretmen yok; önce öğretmen ekle.':
      'No teacher teaches this subject; add a teacher first.',
  '{c} sınıf, {t} öğretmen, haftada toplam {h} saat ders, {s} ders saati.':
      '{c} classes, {t} teachers, {h} lesson hours per week in total, {s} periods.',
  'Dönem (isteğe bağlı)': 'Term (optional)',
  'Ders saati, sınıf, öğretmen ve ders gerekli.':
      'Lesson times, classes, teachers and lessons are required.',
  'Pzt': 'Mon',
  'Sal': 'Tue',
  'Çar': 'Wed',
  'Per': 'Thu',
  'Cum': 'Fri',
  'Cmt': 'Sat',
  'Paz': 'Sun',
  'Pazartesi': 'Monday',
  'Salı': 'Tuesday',
  'Çarşamba': 'Wednesday',
  'Perşembe': 'Thursday',
  'Cuma': 'Friday',
  'Cumartesi': 'Saturday',
  'Pazar': 'Sunday',
  'Seviye yok': 'No level',
  'Mezun': 'Graduate',
  '{n}. sınıf': 'Grade {n}',
  'Alan yok': 'No track',
  '{class} sınıfının {branch} dersi için öğretmen yok ({n} saat). Bu branşa giren bir öğretmen ekle.':
      'There is no teacher for {class}\'s {branch} lesson ({n} hours). Add a teacher for this subject.',
  '{teacher}: {need} saat ders atanmış ama haftalık en çok {have} saat girebiliyor. Üst sınırı artır ya da dersin bir kısmını başka öğretmene ver.':
      '{teacher}: {need} hours assigned but can teach at most {have} hours a week. Raise the limit or give part of the lesson to another teacher.',
  '{teacher}: müsait {have} saati var ama {need} saat ders atanmış. Müsaitliği genişlet ya da dersin bir kısmını başka öğretmene ver.':
      '{teacher}: {have} hours available but {need} hours assigned. Extend availability or give part of the lesson to another teacher.',
  '{class}: haftada {need} saat ders istiyor ama şablonda {have} ders saati var. Ders saati ekle ya da dersleri azalt.':
      '{class}: needs {need} hours a week but the template has {have} periods. Add periods or reduce lessons.',
  '{class} {branch}: {have} saat kilitli ama haftalık ihtiyaç {need} saat. Fazla kilitleri kaldır.':
      '{class} {branch}: {have} hours locked but the weekly need is {need} hours. Remove extra locks.',
  'Silinmiş bir öğretmen, sınıf ya da saate bağlı kilitli ders kaldırıldı.':
      'A locked lesson tied to a deleted teacher, class or period was removed.',
  '{class} {branch} ({teacher}) kilitli dersi bir kuralı bozuyor: öğretmen o saatte müsait değil ya da aynı saatte başka dersi var. Kilidi kaldır.':
      'The locked {class} {branch} ({teacher}) lesson breaks a rule: the teacher isn\'t available then or has another lesson at the same time. Remove the lock.',
  '{class} {branch}: {need} saat yerleşmedi. {teacher} ile sınıfın ortak boş saati {have}. Öğretmenin müsaitliğini artır ya da kilitli dersleri gözden geçir.':
      '{class} {branch}: {need} hours not placed. {teacher} and the class share {have} free periods. Extend the teacher\'s availability or review locked lessons.',
  'Öğretmenin o saatte başka dersi var.':
      'The teacher has another lesson then.',
  'Sınıfın o saatte başka dersi var.': 'The class has another lesson then.',
  'Derslik o saatte dolu.': 'The room is taken then.',
  'Öğretmen o saatte müsait değil.': 'The teacher isn\'t available then.',
  'Dersin haftalık saati tutmuyor.': 'The lesson\'s weekly hours don\'t match.',
  'Kilitli ders taşınamaz.': 'A locked lesson can\'t be moved.',
  'Öğretmenin haftalık üst sınırı aşılıyor.':
      'The teacher\'s weekly limit is exceeded.',
  // Finans Excel
  'Kurum finansı': 'Institution finances',
  'Dönem': 'Period',
  'Hazırlanma tarihi': 'Prepared on',
  'Tahsilat (₺)': 'Collected (₺)',
  'Beklenen: vadesi dönemde (₺)': 'Expected: due in period (₺)',
  'Gider (₺)': 'Expenses (₺)',
  'Net: tahsilat − gider (₺)': 'Net: collected − expenses (₺)',
  'Bugün geciken taksit': 'Overdue instalments today',
  'Ay': 'Month',
  'Beklenen (₺)': 'Expected (₺)',
  'Net (₺)': 'Net (₺)',
  'Gider türü': 'Expense type',
  'Tutar (₺)': 'Amount (₺)',
  'Tahsilatlar': 'Collections',
  'Ödendiği tarih': 'Paid on',
  'Ücret kalemi': 'Fee item',
  'Vade': 'Due date',
  'Ödeme şekli': 'Payment method',
  'Taksitler': 'Instalments',
  'Durum': 'Status',
  'Ödendi': 'Paid',
  'Not': 'Note',
  'Öğrenci bakiyeleri': 'Student balances',
  'Toplam (₺)': 'Total (₺)',
  'Ödenen (₺)': 'Paid (₺)',
  'Kalan (₺)': 'Remaining (₺)',
  'Geciken (₺)': 'Overdue (₺)',
  'Excel olarak indir': 'Download as Excel',
  'Finans · {p}': 'Finances · {p}',
  'Aylık': 'Monthly',
  'Yıllık': 'Yearly',
  'Yıl': 'Year',
  'Özet, tahsilatlar, taksitler, giderler ve öğrenci bakiyeleri ayrı sayfalarda.':
      'Summary, collections, instalments, expenses and student balances on separate sheets.',
  'İndir': 'Download',
  // Öğrenci kayıt, sınıf yönetimi, öğrenci programı
  'Bu numara zaten kullanımda. Numaranı kontrol et ya da koçunla iletişime geç.':
      'This number is already in use. Check your number or contact your coach.',
  'Öğrenci numarası yalnızca rakamlardan oluşmalı.':
      'The student number must contain digits only.',
  'Bu numara kurum listesinde bulunamadı, numaranı kontrol et veya koçunla iletişime geç.':
      'This number wasn\'t found in the institution\'s list. Check your number or contact your coach.',
  'Öğrenci numaran': 'Your student number',
  'Kurumunun listesindeki numaran. Adın listeden alınır; kayıttan sonra numarayı yalnızca koçun değiştirebilir.':
      'Your number in your institution\'s list. Your name is taken from the list; after signing up only your coach can change the number.',
  'Kurumdaki öğrenci numaran. Kayıttan sonra yalnızca koçun değiştirebilir.':
      'Your student number at the institution. After signing up only your coach can change it.',
  'Öğrenci numaranı gir': 'Enter your student number',
  'Ders programın güncellendi': 'Your timetable was updated',
  'Ders programın yayınlandı': 'Your timetable is published',
  '{name}: haftalık derslerine bak.': '{name}: check your weekly lessons.',
  '{c} sınıf ve {s} öğrenci etkilenecek; öğrencilere bildirim gider.':
      '{c} classes and {s} students are affected; students get a notification.',
  'Yayında · {d}': 'Published · {d}',
  'Numara biçimi hatalı': 'Invalid number format',
  'Kullanımdaki numarayı denedi': 'Tried a number already in use',
  'Numara kurum listesinde yok': 'Number not in the institution\'s list',
  '{n} numarasını denedi (kullanımda)': 'Tried number {n} (in use)',
  'Numarası yok': 'No number',
  'Sınıfı yok': 'No class',
  'Benzer ad: {names}': 'Similar name: {names}',
  'Sınıflar': 'Classes',
  '{n} / {max} öğrenci': '{n} / {max} students',
  'Pasifleştir': 'Deactivate',
  'Etkinleştir': 'Activate',
  'Sınıfta öğrenci var; önce öğrencileri başka sınıfa taşı.':
      'The class has students; move them to another class first.',
  'Önce sınıf oluşturmalısınız': 'Create classes first',
  'Öğrencileri atamak için önce sınıflarını oluştur.':
      'Create your classes first to assign students.',
  'Kurum müdürü sınıfları oluşturunca öğrencilerini atayabilirsin.':
      'You can assign your students once the institution manager creates classes.',
  'Sınıf oluştur': 'Create class',
  'Pasif sınıfa öğrenci atanamaz.':
      'Students can\'t be assigned to an inactive class.',
  '{n} öğrenci nereye taşınsın?': 'Where should {n} students move?',
  'Sınıfsız bırak': 'Leave without a class',
  'Öğrenci ekle': 'Add students',
  'Bu sınıfta öğrenci yok.': 'No students in this class.',
  'Sınıftan çıkar': 'Remove from class',
  'Atanmadı': 'Unassigned',
  'Ekle ({n})': 'Add ({n})',
  '{n} öğrenci hangi sınıfa?': 'Which class for {n} students?',
  '{n} öğrencinin sınıfı güncellendi.': 'Class updated for {n} students.',
  'Sınıfı olmayanlar ({n})': 'Without a class ({n})',
  'Tüm öğrenciler ({n})': 'All students ({n})',
  'Şüpheli numaralar ({n})': 'Suspicious numbers ({n})',
  'Henüz kayıt olmayanlar ({n})': 'Not signed up yet ({n})',
  'Kayıt ayarları': 'Registration settings',
  'Seçilenleri sınıfa ata ({n})': 'Assign selected to a class ({n})',
  'Öğrenci yok.': 'No students.',
  'Hepsini seç': 'Select all',
  'Şüpheli numara yok.': 'No suspicious numbers.',
  'Kurum listesinde olup uygulamaya henüz kayıt olmayan öğrenciler.':
      'Students in the institution\'s list who haven\'t signed up yet.',
  'Ad soyad veya öğrenci no ara': 'Search by name or student number',
  'Şüpheli': 'Suspicious',
  'Bu numara zaten kullanımda.': 'This number is already in use.',
  'Kayıtta girdiği numara: {n}': 'Number entered at sign-up: {n}',
  'Öğrenci numarası': 'Student number',
  'Numara kullanılabilir': 'Number is available',
  'Bu değişiklik kayıt altına alınacaktır.': 'This change will be logged.',
  'Sınıflar ve öğrenciler': 'Classes and students',
  'Sınıf ataması, öğrenci numarası ve kayıtlar':
      'Class assignment, student numbers and sign-ups',
  '{n} sınıfsız': '{n} without a class',
  '{n} şüpheli': '{n} suspicious',
  'Liste ile eşleşmeli kayda geçilsin mi?': 'Switch to list-matched sign-up?',
  'Serbest kayda geçilsin mi?': 'Switch to free sign-up?',
  'Yeni öğrenciler yalnızca kurum listesindeki numarayla kayıt olabilir. Kayıtlı öğrenciler listeyle karşılaştırılır; numarası listede olmayanlar "Şüpheli numaralar"a düşer.':
      'New students can only sign up with a number in the institution\'s list. Existing students are compared with the list; those whose number isn\'t in it move to "Suspicious numbers".',
  'Dikkat: liste boş; liste yüklenene kadar hiçbir öğrenci kayıt olamaz.':
      'Note: the list is empty; no student can sign up until a list is uploaded.',
  'Öğrenciler numaralarını serbestçe girer. Hatalı ya da kullanımdaki numaralar "Şüpheli numaralar"da görünür.':
      'Students enter their numbers freely. Invalid or already used numbers appear in "Suspicious numbers".',
  'Geç': 'Switch',
  'Öğrenci kayıt ayarları': 'Student sign-up settings',
  'Kayıt modu': 'Sign-up mode',
  'Liste ile eşleşmeli kayıt (önerilen)': 'List-matched sign-up (recommended)',
  'Kurumun öğrenci listesini (Excel / CSV) yüklersin. Öğrenci kayıtta numarasını girer; numara listede yoksa kayıt olamaz, varsa adı ve sınıfı listeden gelir.':
      'You upload the institution\'s student list (Excel / CSV). Students enter their number at sign-up; if it isn\'t in the list they can\'t sign up, otherwise their name and class come from the list.',
  'Serbest kayıt': 'Free sign-up',
  'Listen yoksa: öğrenci numarasını kendisi yazar. Hatalı biçimli, kullanımdaki ya da benzer adlı kayıtlar "Şüpheli numaralar" listesinde görünür.':
      'If you have no list: students type their own number. Invalid, already used or similar-name records appear in "Suspicious numbers".',
  'Kurum listesi': 'Institution list',
  '{n} öğrenci listede': '{n} students in the list',
  '{m} kayıt oldu · {p} bekliyor': '{m} signed up · {p} waiting',
  'Excel / CSV ile liste yükle': 'Upload list from Excel / CSV',
  'Liste hesap açmaz ve numara üretmez; yalnızca kayıt olacak öğrencilerin numara, ad soyad, (varsa) sınıf ve veli telefonu listesidir.':
      'The list doesn\'t create accounts or generate numbers; it only lists the number, name, (optional) class and parent phone of students who will sign up.',
  'Dosya okunamadı. Excel (.xlsx, .xls) ya da CSV seç.':
      'The file couldn\'t be read. Choose an Excel (.xlsx, .xls) or CSV file.',
  'Öğrenci no ve ad soyad sütunlarını seç.':
      'Choose the student number and name columns.',
  '{i} yeni, {u} güncellendi, {d} silindi.':
      '{i} new, {u} updated, {d} removed.',
  'Numara yok': 'No number',
  'Numara yalnızca rakam olmalı': 'Number must be digits only',
  'Ad soyad yok': 'No name',
  'Numara dosyada tekrar ediyor': 'Number repeats in the file',
  'Veli telefonu geçersiz (atlanır)': 'Invalid parent phone (skipped)',
  'Öğrenci no': 'Student no.',
  'Ad soyad (ya da ad)': 'Full name (or first name)',
  'Soyad (ayrıysa)': 'Surname (if separate)',
  'Öğrenci listesi yükle': 'Upload student list',
  'İçe aktar ({n} satır)': 'Import ({n} rows)',
  'Dosya seç (Excel / CSV)': 'Choose file (Excel / CSV)',
  'Sütunlar: öğrenci no, ad soyad; isteğe bağlı sınıf adı ve veli telefonu.':
      'Columns: student number, name; optional class name and parent phone.',
  'Başlık satırı': 'Header row',
  'Sütun eşleştirme': 'Column mapping',
  'Sütun {n}': 'Column {n}',
  'Önizle ve doğrula': 'Preview and validate',
  'Doğrulama raporu': 'Validation report',
  '{n} satır okundu': '{n} rows read',
  '{n} satır içe aktarılacak': '{n} rows will be imported',
  '{n} mükerrer numara': '{n} duplicate numbers',
  '{n} hatalı ya da eksik numara': '{n} invalid or missing numbers',
  '{n} adı eksik satır': '{n} rows without a name',
  '{n} geçersiz veli telefonu (numarasız aktarılır)':
      '{n} invalid parent phones (imported without a phone)',
  'Listeyi yenile': 'Replace list',
  'Bu dosyada olmayan ve henüz kayıt olmamış öğrenciler listeden silinir.':
      'Students not in this file who haven\'t signed up yet are removed from the list.',
  'Hatalı satırlar (atlanır; dokunup düzeltebilirsin)':
      'Invalid rows (skipped; tap to fix)',
  'Satır {n}: {name}': 'Row {n}: {name}',
  'İlk satırlar': 'First rows',
  'Satır {n}': 'Row {n}',
  'Düzelt': 'Fix',
  'Ders programım': 'My timetable',
  'Hafta': 'Week',
  'Programın henüz yayınlanmadı': 'Your timetable isn\'t published yet',
  'Henüz bir sınıfa atanmadın': 'You haven\'t been assigned to a class yet',
  '{class} sınıfının programı yayınlanınca burada görünecek.':
      '{class}\'s timetable will appear here once it\'s published.',
  'Koçun ya da kurum müdürün seni bir sınıfa atayınca programın burada görünür.':
      'Your timetable appears here once your coach or institution manager assigns you to a class.',
  'Çevrimdışı gösteriliyor': 'Showing offline',
  'Son kaydedilen program': 'Last saved timetable',
  'Son güncelleme: {d}': 'Last updated: {d}',
  'Bugün ders yok. İyi dinlenmeler!': 'No lessons today. Enjoy your rest!',
  'Şimdi': 'Now',
  'Sıradaki': 'Next',
  'Şimdi: {branch} · {end}\'e kadar': 'Now: {branch} · until {end}',
  'Sıradaki: {time} {branch}': 'Next: {time} {branch}',
  'Bugünkü dersler bitti': 'Today\'s lessons are over',
  // Velilere toplu SMS
  '{n} veliye SMS gönderilsin mi?': 'Send an SMS to {n} parents?',
  '{n} öğrencinin veli telefonu kayıtlı değil; onlara gitmez.':
      '{n} students have no parent phone on file; they won\'t get it.',
  'Son gönderimin üzerinden 10 dakika geçmeden yeni SMS gönderilemez.':
      'A new SMS can\'t be sent until 10 minutes after the last one.',
  'Seçilenlerin hiçbirinde veli telefonu yok.':
      'None of the selected students has a parent phone.',
  'Resmi tatil': 'Public holiday',
  'Resmi tatil nedeniyle kurumumuz {gün} günü kapalıdır. Dersler {gün2} günü normal programla devam edecektir.':
      'Our institution is closed on {gün} for the public holiday. Lessons resume as usual on {gün2}.',
  'Deneme sınavı': 'Practice exam',
  '{gün} saat {saat}\'te kurumumuzda deneme sınavı yapılacaktır. Öğrencimizin kimliği ve kurşun kalemiyle zamanında gelmesini rica ederiz.':
      'A practice exam will be held at our institution on {gün} at {saat}. Please make sure your child arrives on time with an ID and a pencil.',
  'Veli toplantısı': 'Parent meeting',
  '{gün} saat {saat}\'te veli toplantımız yapılacaktır. Katılımınızı bekleriz.':
      'Our parent meeting will be held on {gün} at {saat}. We look forward to seeing you.',
  'Velilere SMS': 'SMS to parents',
  'Mesaj': 'Message',
  'Velilere gidecek metni yaz': 'Write the text for parents',
  'Başına "{org}:" eklenir. {n} karakter · yaklaşık {k} SMS':
      '"{org}:" is added at the start. {n} characters · about {k} SMS',
  'Kime': 'To',
  'Tüm veliler': 'All parents',
  'Henüz sınıf yok.': 'No classes yet.',
  'Öğrenci seç ({n})': 'Choose students ({n})',
  'Alıcılar hesaplanıyor…': 'Counting recipients…',
  '{n} veliye gidecek': 'Goes to {n} parents',
  '{n} öğrencinin veli telefonu yok': '{n} students have no parent phone',
  'Telefon ekle': 'Add phone',
  'Yalnızca bilgilendirme gönder: reklam ya da kampanya içerikli SMS için velinin ticari ileti izni (İYS) gerekir.':
      'Send information only: advertising or campaign SMS needs the parent\'s commercial message consent (İYS).',
  'Gönderilenler': 'Sent',
  'Henüz SMS gönderilmedi.': 'No SMS sent yet.',
  '{n} veli': '{n} parents',
  '{n} gitti': '{n} delivered',
  '{n} sırada': '{n} queued',
  '{n} başarısız': '{n} failed',
  'Seç ({n})': 'Choose ({n})',
  'Resmi tatil, toplantı, duyuru: istediğin metni gönder':
      'Holiday, meeting, notice: send any text you like',
  // Deneme karşılaştırma
  'Kitaplar': 'Books',
  'Deneme karşılaştırma': 'Exam comparison',
  'PDF olarak paylaş': 'Share as PDF',
  'Karşılaştırma': 'Comparison',
  '5 ve üzeri deneme için özet görünümü gösteriliyor.':
      'Summary view is shown for 5 or more exams.',
  'Farklı türde denemeler karşılaştırıyorsun, netler birebir kıyaslanamayabilir.':
      'You are comparing different exam types; scores may not be directly comparable.',
  'Karşılaştırmak için en az 2 deneme seç.':
      'Choose at least 2 exams to compare.',
  'Henüz deneme yok.': 'No exams yet.',
  '{n}/4 seçildi': '{n}/4 selected',
  '{n} seçildi · özet': '{n} selected · summary',
  '2-4 deneme: yan yana': '2-4 exams: side by side',
  '{n} net': '{n} net',
  '{d}D {y}Y {b}B': '{d}C {y}W {b}B',
  '{n}.': '#{n}',
  'Ders bazında net': 'Net by subject',
  'net': 'net',
  '{n} deneme · ortalama {avg} net': '{n} exams · average {avg} net',
  'En çok gelişen dersler': 'Most improved subjects',
  'Belirgin bir yükseliş yok.': 'No clear improvement.',
  'En çok gerileyen dersler': 'Most declined subjects',
  'Belirgin bir düşüş yok.': 'No clear decline.',
  'Ders bazında ortalama net': 'Average net by subject',
  'Ortak kazanım bulunamadı. Kazanım karşılaştırması optikle okunan denemelerde yapılır.':
      'No shared outcomes found. Outcome comparison uses exams read with the optical scanner.',
  'Seçilen denemelerin en az ikisinde ölçülen kazanımlar.':
      'Outcomes measured in at least two of the selected exams.',
  'Denemeleri karşılaştır': 'Compare exams',
  // Kitap takibi
  'Kitap talebin onaylanmadı': 'Your book request wasn\'t approved',
  'Talep ettiğin kitap eklendi': 'The book you requested was added',
  '{book} ({publisher}) havuzda; şimdi seçebilirsin.':
      '{book} ({publisher}) is in the pool; you can choose it now.',
  'Soru bankası': 'Question bank',
  'Deneme kitabı': 'Practice exam book',
  'Konu anlatımı': 'Topic guide',
  'Devam ediyor': 'In progress',
  'Bırakıldı': 'Dropped',
  'Karma': 'Mixed',
  'Tarih ileride olamaz.': 'The date can\'t be in the future.',
  'Bitiş sayfası başlangıçtan küçük olamaz.':
      'The end page can\'t be before the start page.',
  'Doğru + yanlış + boş, soru sayısını geçemez.':
      'Correct + wrong + blank can\'t exceed the question count.',
  'Bu dönem için kitap hakkı doldu. Yeni kitap eklemek için koçuna haber ver.':
      'The book allowance for this term is used up. Tell your coach to add a new book.',
  'Bu kitap havuzda zaten var; listeden seç.':
      'This book is already in the pool; pick it from the list.',
  'Bu kitap havuzda değil.': 'This book isn\'t in the pool.',
  'Kitaplarım': 'My books',
  'Öğrencinin bu dönemki kitap hakkı doldu. Önce limiti artır.':
      'The student\'s book allowance for this term is used up. Raise the limit first.',
  'Bu dönem için {n} kitap hakkını kullandın. Yeni kitap eklemek için koçuna haber ver.':
      'You\'ve used your {n} books for this term. Tell your coach to add a new book.',
  'Kitap hakkı {n} oldu.': 'Book allowance is now {n}.',
  '{u} / {l} kitap kullanıldı': '{u} / {l} books used',
  '{term} dönemi. Bitirilen ya da bırakılan kitaplar da hakka sayılır.':
      '{term} term. Finished or dropped books also count.',
  'Limiti artır': 'Raise limit',
  'Kitap ekle': 'Add book',
  'Bu dönem henüz kitap eklenmedi.': 'No books added this term yet.',
  'son çalışma {d}': 'last studied {d}',
  'Son 7 günde kitaplardan {n} soru':
      '{n} questions from books in the last 7 days',
  'Son çalışma: {d} · {topic}': 'Last study: {d} · {topic}',
  'Kitap hakkını değiştir': 'Change book allowance',
  'Bu dönem için hak': 'Allowance this term',
  'Sebep': 'Reason',
  'Sebebi yaz.': 'Enter a reason.',
  'Öğrencinin kitap hakkından düşer ({n}/{l}).':
      'Uses one of the student\'s books ({n}/{l}).',
  'Bu kitap hakkını kullanacaksın ({n}/{l}). Ekledikten sonra kendin kaldıramazsın, düzeltme için koçuna başvurman gerekir.':
      'This uses one of your books ({n}/{l}). Once added you can\'t remove it yourself; ask your coach to fix mistakes.',
  'Anladım, ekle': 'Got it, add',
  '{name} eklendi.': '{name} added.',
  'Talebin iletildi. Onaylanınca bildirim gelecek.':
      'Your request was sent. You\'ll be notified when it\'s approved.',
  'Kitap havuza eklendi.': 'Book added to the pool.',
  'Kitap seç': 'Choose book',
  'Kitap ya da yayın ara': 'Search book or publisher',
  'Onay bekleyen taleplerin': 'Your pending requests',
  'zaten listende': 'already in your list',
  'Kitabı bulamadın mı? Talep et': 'Can\'t find the book? Request it',
  'Aradığın kitap yok mu? Talep et': 'Book not listed? Request it',
  'Havuza yeni kitap ekle': 'Add a new book to the pool',
  'Koçun ya da müdürün onaylayınca havuza girer; sonra seçebilirsin.':
      'Once your coach or manager approves it, it joins the pool and you can choose it.',
  'Kurumun kitap havuzuna eklenir.': 'Added to the institution\'s book pool.',
  'Kitap talep et': 'Request a book',
  'Havuza kitap ekle': 'Add book to pool',
  'Kitabı düzenle': 'Edit book',
  'Kitap adı': 'Book title',
  'Kitap adını ve yayını yaz.': 'Enter the book title and publisher.',
  'Talep et': 'Request',
  'Bu kaydı artık düzenleyemezsin; koçuna başvur.':
      'You can no longer edit this entry; ask your coach.',
  'Kitap öğrencinin listesinden silinsin mi?':
      'Remove the book from the student\'s list?',
  'Çalışma kayıtları da silinir ve kitap hakkından düşer.':
      'Its study entries are deleted too and it no longer counts toward the allowance.',
  'Durum: {s}': 'Status: {s}',
  'Listeden sil': 'Remove from list',
  'Çalışma ekle': 'Add study',
  '{d} doğru · {y} yanlış · {b} boş': '{d} correct · {y} wrong · {b} blank',
  'Kitabı kaldırmak ya da bitti işaretlemek için koçuna başvur. Kendi çalışmanı 24 saat içinde düzeltebilirsin.':
      'Ask your coach to remove the book or mark it finished. You can fix your own entries within 24 hours.',
  'Henüz çalışma eklenmedi.': 'No study entries yet.',
  's. {a}-{b}': 'p. {a}-{b}',
  'Çalışmayı düzenle': 'Edit study',
  'Konu': 'Topic',
  'Başlangıç sayfası': 'Start page',
  'Bitiş sayfası': 'End page',
  'Soru sayısı': 'Questions',
  'Kitapla desteklenmesi gereken konular': 'Topics that need book practice',
  '{topic}: deneme başarısı %{rate} ({n} soru), son 60 günde bu konuda kitap çalışması yok.':
      '{topic}: {rate}% exam success ({n} questions), no book practice on it in the last 60 days.',
  'Çözdüğün kaynak kitaplar ve ilerlemen': 'Your study books and progress',
  'Bu kitap havuzda zaten var.': 'This book is already in the pool.',
  'Bu kitaba benziyor (mükerrer olmasın):':
      'Looks like this book (avoid duplicates):',
  '{p} · bununla birleştir': '{p} · merge with this',
  'Onayla ve havuza ekle': 'Approve and add to pool',
  'Reddet': 'Reject',
  'Talep reddedildi; öğrenciye bildirildi.':
      'Request rejected; the student was notified.',
  'Öğrenciye "kitap eklendi" bildirimi gitti.':
      'The student was notified that the book was added.',
  'Kitap havuzu': 'Book pool',
  'Excel ile toplu ekle': 'Bulk add from Excel',
  'Havuz ({n})': 'Pool ({n})',
  'Onay bekleyenler ({n})': 'Pending ({n})',
  'Havuz boş. Kitap ekle ya da Excel ile toplu yükle.':
      'The pool is empty. Add a book or bulk upload from Excel.',
  '{n} öğrencide': 'used by {n} students',
  'ort. {n} soru': 'avg. {n} questions',
  'Onay bekleyen kitap yok.': 'No pending books.',
  'benzer kitap var': 'similar book exists',
  '{i} kitap eklendi, {s} zaten havuzdaydı.':
      '{i} books added, {s} were already in the pool.',
  'Kitap havuzu yükle': 'Upload book pool',
  'İçe aktar ({n} kitap)': 'Import ({n} books)',
  'Sütunlar: kitap adı, yayın, ders ("TYT Matematik" gibi), tür (soru bankası / deneme / konu anlatımı). Aynı ad ve yayın tekrar eklenmez.':
      'Columns: title, publisher, subject (e.g. "TYT Matematik"), type (question bank / practice exam / topic guide). The same title and publisher isn\'t added twice.',
  '{n} kitap okundu': '{n} books read',
  '{n} satırda ad ya da yayın eksik; atlanacak.':
      '{n} rows are missing a title or publisher; they\'ll be skipped.',
  '{n} satırda ders tanınmadı; "Karma" eklenecek, sonra düzenleyebilirsin.':
      'Subject not recognised in {n} rows; they\'ll be added as "Mixed" and you can edit them later.',
  '{n} kitap talebi onay bekliyor': '{n} book requests pending',
  'Öğrencilerin seçtiği kaynak kitaplar': 'Study books chosen by students',
  // Kurum sınavı: optik Excel içe aktarma, kazanım analizi, karneler
  'Karneyi aç': 'Open report card',
  'Sıralama': 'Ranking',
  'Kurum sırası': 'Institution rank',
  'Sınıf sırası': 'Class rank',
  'Numara': 'Number',
  'D': 'C',
  'Y': 'W',
  'B': 'B',
  'Ort. doğru': 'Avg. correct',
  'Ort. yanlış': 'Avg. wrong',
  'Ort. boş': 'Avg. blank',
  'Ort. net': 'Avg. net',
  'Ort. toplam net': 'Avg. total net',
  'Ort. net kaybı': 'Avg. net lost',
  'Cevap': 'Answer',
  'Doğru %': 'Correct %',
  'Boş %': 'Blank %',
  'En çok işaretlenen yanlış': 'Most chosen wrong option',
  'Ayırt edicilik': 'Discrimination',
  'Cevap anahtarını kontrol et': 'Check the answer key',
  'Konu anlaşılmamış olabilir': 'Topic may not be understood',
  'Hangi sınıfın karneleri?': 'Report cards for which class?',
  'Tüm öğrenciler': 'All students',
  '{c} ({n} öğrenci)': '{c} ({n} students)',
  'Bu seçimde karne yok.': 'No report cards for this selection.',
  'Excel olarak paylaş': 'Share as Excel',
  'Karneleri PDF olarak al': 'Get report cards as PDF',
  'Henüz sonuç yok': 'No results yet',
  'Optikleri yükleyip sınavı yayınlayınca rapor oluşur.':
      'The report appears once you upload the sheets and publish the exam.',
  'En yüksek': 'Highest',
  'En düşük': 'Lowest',
  'Ders ortalamaları ve dağılım': 'Subject averages and distribution',
  'Sınıf ortalamaları': 'Class averages',
  'Kurumun en zayıf 10 kazanımı': 'The institution\'s 10 weakest outcomes',
  'Başarı yüzdesi en düşük konular; tekrar edilmeli.':
      'Topics with the lowest success; they should be revisited.',
  '{c}: tekrar edilecek konular': '{c}: topics to revisit',
  'Dikkat edilecek sorular': 'Questions to check',
  'Doğru oranı çok düşük ya da başarılı öğrencilerin daha çok yanlış yaptığı sorular: cevap anahtarı hatalı olabilir veya konu hiç anlaşılmamış.':
      'Questions with a very low correct rate, or that top students missed more often: the answer key may be wrong or the topic wasn\'t understood.',
  'Cevap anahtarını kontrol et (anahtar: {k}, en çok işaretlenen yanlış: {w}).':
      'Check the answer key (key: {k}, most chosen wrong option: {w}).',
  'Konu anlaşılmamış olabilir: {o}': 'Topic may not be understood: {o}',
  'Sırala': 'Sort by',
  '−{n} net': '−{n} net',
  '{a}-{b} net: {n} öğrenci': '{a}-{b} net: {n} students',
  'Sınav karnesi': 'Exam report card',
  'No': 'No.',
  '{b} kitapçığı': 'booklet {b}',
  'Tahmini puan': 'Estimated score',
  'Tahmini {t} puanı': 'Estimated {t} score',
  'Sınıf ort.': 'Class avg.',
  'Kurum ort.': 'Inst. avg.',
  'En çok net kaybettiren konular': 'Topics costing the most net',
  'Kazanım bilgisi yok.': 'No outcome data.',
  '{c}/{q} doğru · %{p}': '{c}/{q} correct · {p}%',
  'Yanlış ve boş sorular': 'Wrong and blank questions',
  'boş': 'blank',
  'Sınav karneleri': 'Exam report cards',
  'Henüz karne yok': 'No report cards yet',
  'Kurumun optikle okuttuğu sınavların sonuçları yayınlanınca burada görünür.':
      'Results of exams your institution reads with the optical scanner appear here once published.',
  'kurumda {n}.': '#{n} in institution',
  'Konularda gidişat': 'Topic trends',
  'Birden çok sınavda ölçülen kazanımlar': 'Outcomes measured in several exams',
  'Karne': 'Report card',
  'Konu analizi': 'Topic analysis',
  '{c} sırası': '{c} rank',
  'Önceki denemede {n} net ({d})': '{n} net in the previous exam ({d})',
  'değişmedi': 'unchanged',
  'yükseldi': 'went up',
  'düştü': 'went down',
  'Kazanım bilgisi yok': 'No outcome data',
  'Bu sınavın sorularına kazanım eşleştirilmemiş.':
      'No outcomes are linked to this exam\'s questions.',
  'Zayıf kazanımlar': 'Weak outcomes',
  'Başarısı en düşük konular': 'Topics with the lowest success',
  'Net kaybı haritası': 'Net loss map',
  'Bu konular düzelince en çok net kazanırsın (yanlış 1 + yanlış katsayısı, boş 1 net).':
      'Fixing these topics gains you the most net (wrong: 1 + penalty, blank: 1 net).',
  '{c} doğru · {w} yanlış · {b} boş / {q} soru':
      '{c} correct · {w} wrong · {b} blank / {q} questions',
  'İptal edilen soru': 'Cancelled question',
  'Boş · doğru cevap {c}': 'Blank · correct answer {c}',
  'Senin cevabın {m} · doğru cevap {c}': 'Your answer {m} · correct answer {c}',
  'Kurum sınavı karneleri': 'Institution exam report cards',
  '{c}cevap metni kısa ({d}); eksikler boş sayıldı':
      '{c}answer text too short ({d}); missing ones counted blank',
  '{c}cevap metni uzun ({d}); fazlası kesildi':
      '{c}answer text too long ({d}); the extra was cut',
  '{c}geçersiz işaret ({d}) boş sayıldı': '{c}invalid mark ({d}) counted blank',
  'kitapçık boş; A sayıldı': 'booklet empty; counted as A',
  'kitapçık tanınmadı ya da anahtarı yok ({d})':
      'booklet not recognised or has no key ({d})',
  'öğrenci numarası boş': 'student number empty',
  'Dosyada başlık satırı bulunamadı.': 'No header row found in the file.',
  'En az bir cevap sütununu bir derse eşleştir.':
      'Match at least one answer column to a subject.',
  'Aktarılacak öğrenci yok.': 'No students to import.',
  'Üzerine yazılsın mı?': 'Overwrite?',
  'Bu sınavda zaten {n} sonuç var. Dosyadaki öğrencilerin sonuçları güncellenir; kopya kayıt oluşmaz.':
      'This exam already has {n} results. Students in the file are updated; no duplicates are created.',
  'Üzerine yaz': 'Overwrite',
  'Aktarım yarıda kaldı. Tekrar yüklersen kopya oluşmaz, kalan öğrenciler eklenir.':
      'The import stopped halfway. Upload again: no duplicates are created and the rest are added.',
  'Optik sonuçlarını yükle': 'Upload optical results',
  'Sütunları eşleştir': 'Match columns',
  'Aktarım tamamlandı': 'Import complete',
  'Optik okuyucunun verdiği Excel ya da CSV dosyasını seç. Her satır bir öğrenci; cevaplar "ABDC…" biçiminde tek hücrede olmalı.':
      'Choose the Excel or CSV file from the optical reader. One row per student; answers in a single cell like "ABDC…".',
  '{f}: {n} satır okundu': '{f}: {n} rows read',
  'Şablonu kullan: {n}': 'Use template: {n}',
  'Ad soyad (kontrol için)': 'Full name (for checking)',
  'Cevap sütunları': 'Answer columns',
  'Her sütunda hangi derslerin cevapları var? Bir sütunda birden çok ders varsa (ör. Fen) sırayla seç; karakterler soru sayılarına göre bölünür.':
      'Which subjects are in each column? If a column holds several (e.g. Science), pick them in order; characters are split by question counts.',
  'Eşleştirmeyi şablon olarak kaydet': 'Save mapping as a template',
  'Sonraki sınavda "Şablonu kullan" ile seçilir.':
      'Pick it next time with "Use template".',
  'Şablon adı': 'Template name',
  'Kontrol et': 'Check',
  'satır': 'rows',
  'eşleşti': 'matched',
  'eşleşmedi': 'unmatched',
  'ad tutmuyor': 'name differs',
  'hatalı': 'invalid',
  'Eşleşmeyen numaralar': 'Unmatched numbers',
  'Kurumda bu numarayla öğrenci yok. Elle eşleştir ya da atla; atlananlar aktarılmaz.':
      'No student has this number. Match by hand or skip; skipped rows aren\'t imported.',
  'Numara tuttu, ad tutmuyor': 'Number matched, name differs',
  'Onayladıkların aktarılır.': 'The ones you approve are imported.',
  'Kurumdaki kayıt: {n}': 'Record in institution: {n}',
  'Hatalı satırlar': 'Invalid rows',
  'Bu satırlar aktarılmaz; dosyayı düzeltip yeniden yükleyebilirsin.':
      'These rows aren\'t imported; fix the file and upload again.',
  'numara dosyada ikinci kez geçiyor ({no})':
      'number appears twice in the file ({no})',
  'Uyarılar ({n})': 'Warnings ({n})',
  'Aktarılır; sorunlu işaretler boş sayılır.':
      'Imported; problematic marks count as blank.',
  'Önizleme': 'Preview',
  'Netler yaklaşık; kesin sonucu sunucu hesaplar.':
      'Nets are approximate; the server calculates the final result.',
  '%{p} aktarıldı': '{p}% imported',
  '{n} öğrenciyi aktar': 'Import {n} students',
  '{n} öğrencinin optiği kaydedildi': '{n} students\' sheets saved',
  '{n} öğrenci kurumda bulunamadığı için atlandı.':
      '{n} students were skipped because they aren\'t in the institution.',
  'Sınavda toplam {n} optik var.': 'The exam has {n} sheets in total.',
  'Sınav yayında: sonuçlar ve sıralamalar güncellendi.':
      'The exam is published: results and rankings were updated.',
  'Sınav taslakta: kontrol edip "Sonuçları yayınla" deyince öğrenciler görür.':
      'The exam is a draft: students see it after you check and tap "Publish results".',
  '{n} karakter bekleniyor, ilk satırda {m}':
      '{n} characters expected, first row has {m}',
  'Atlanacak': 'Will be skipped',
  '{n} ile eşleştirildi': 'Matched with {n}',
  'Eşleştir': 'Match',
  'Ad ya da numara ara': 'Search name or number',
  'Deneme': 'Practice exam',
  'Konu tarama': 'Topic quiz',
  'Kurum sınavları': 'Institution exams',
  'Kazanım havuzu': 'Outcome pool',
  'Yeni sınav': 'New exam',
  'Henüz sınav yok': 'No exams yet',
  'Sınavı tanımla, cevap anahtarını ve kazanımları gir, sonra optik okuyucunun Excel dosyasını yükle.':
      'Define the exam, enter the answer key and outcomes, then upload the optical reader\'s Excel file.',
  '{n} optik': '{n} sheets',
  'Sınavın adını yaz.': 'Enter the exam name.',
  'En az bir ders ekle.': 'Add at least one subject.',
  'Sınav kaydedildi.': 'Exam saved.',
  'Kaydedildi; sonuçlar yeniden hesaplandı.':
      'Saved; results were recalculated.',
  'Kaydedilmiş sınavın türü değiştirilemez.':
      'A saved exam\'s type can\'t be changed.',
  'Kaydedilemedi. Bilgileri kontrol et.': 'Couldn\'t save. Check the details.',
  'Sınav': 'Exam',
  'Kaydedilmemiş değişiklikler var': 'You have unsaved changes',
  'Çıkarsan değişiklikler kaybolur.': 'Your changes will be lost if you leave.',
  'Sınav adı': 'Exam name',
  'Sınav tarihi': 'Exam date',
  'Yanlışlar doğruyu götürür': 'Wrong answers cancel correct ones',
  '{n} yanlış bir doğruyu götürür': '{n} wrong answers cancel one correct',
  'Net = doğru sayısı': 'Net = number correct',
  'Uygulandığı sınıflar': 'Classes taking it',
  'Kurumda sınıf yok; sınıf sıralaması yapılmaz.':
      'No classes in the institution; no class ranking.',
  'Katsayı': 'Weight',
  'Dersi çıkar': 'Remove subject',
  'A (tek)': 'A (single)',
  "Her ders için cevapları sırayla yaz ya da Excel'den yapıştır (ör. ABDCE…). Cevapsız soru için \"-\" yaz; o soru iptal sayılır.":
      'Type each subject\'s answers in order or paste from Excel (e.g. ABDCE…). Use "-" for no answer; that question is cancelled.',
  "Bu kitapçığın cevaplarını yaz. Sorular A'dan farklı sıradaysa \"A'daki karşılığı\" alanına sırayla A numaralarını yaz (ör. 5 4 3 2 1); boşsa sıra aynı kabul edilir.":
      'Type this booklet\'s answers. If the questions are in a different order than A, enter the A numbers in order under "Number in A" (e.g. 5 4 3 2 1); empty means the same order.',
  '{n} / {t} cevap': '{n} / {t} answers',
  'Soru sayısından fazla cevap var; fazlası alınmaz.':
      'More answers than questions; the extra is ignored.',
  "A'daki karşılığı (isteğe bağlı)": 'Number in A (optional)',
  '1-{n} arası her numara bir kez yazılmalı.':
      'Each number from 1 to {n} must appear once.',
  'Ardışık soruları seç': 'Select a range of questions',
  'İlk soru': 'First question',
  'Son soru': 'Last question',
  '{n} soru seçili': '{n} questions selected',
  'Kazanım ata': 'Assign outcome',
  'iptal': 'cancelled',
  'Kazanım seçilmedi': 'No outcome',
  'Soru ayarları': 'Question settings',
  'Soruyu iptal et': 'Cancel question',
  'Kolay': 'Easy',
  'Orta': 'Medium',
  'Zor': 'Hard',
  'Zorluk yok': 'No difficulty',
  'Yüklenen sonuçları öğrenci ve veli görmez. Kontrol edip yayınlayınca karneler oluşur ve öğrencilere bildirim gider.':
      'Students and parents don\'t see uploaded results. Once you check and publish, report cards are created and students are notified.',
  'Sonuçlar öğrenci, veli ve koç panellerinde. Anahtarı değiştirip kaydedersen bütün sonuçlar yeniden hesaplanır.':
      'Results are on the student, parent and coach panels. If you change and save the key, all results are recalculated.',
  '{n} öğrencinin optiği yüklü': '{n} students\' sheets uploaded',
  "Optik okuyucu Excel'ini yükle": 'Upload the optical reader\'s Excel',
  'Önce cevap anahtarını gir.': 'Enter the answer key first.',
  'Kamerayla optik oku': 'Read sheets with the camera',
  'Sonuçlar yayınlansın mı?': 'Publish results?',
  '{n} öğrencinin karnesi oluşur ve öğrencilere bildirim gider.':
      'Report cards are created for {n} students and they\'re notified.',
  '{n} öğrencinin sonucu yayınlandı.': 'Results published for {n} students.',
  'Yayınlanamadı. Tekrar dene.': 'Couldn\'t publish. Try again.',
  'Sonuçları yayınla': 'Publish results',
  'Sınıf ve kurum raporu': 'Class and institution report',
  'Sınav silinsin mi?': 'Delete the exam?',
  'Cevap anahtarı ve yüklenen optikler silinir. Yayınlanmış sonuçlar öğrencilerin denemelerinde kalır.':
      'The answer key and uploaded sheets are deleted. Published results stay in students\' exams.',
  'Silinemedi. Sınavı yalnızca ekleyen kişi silebilir.':
      'Couldn\'t delete. Only the person who added the exam can delete it.',
  'Sınavı sil': 'Delete exam',
  '{n} sınavın sonuçları yayın bekliyor': '{n} exams waiting to be published',
  'Optik sonuçları, kazanım analizi ve karneler':
      'Optical results, outcome analysis and report cards',
  'Bu kazanım havuzda zaten var.': 'This outcome is already in the pool.',
  'Kazanım ya da kod ara': 'Search outcome or code',
  'Kazanımlar yüklenemedi.': 'Couldn\'t load outcomes.',
  'Kazanımı kaldır': 'Remove outcome',
  '"{name}" havuza ekle ve seç': 'Add "{name}" to the pool and select it',
  'Bu derste kazanım yok. Yukarıya yazıp havuza ekleyebilir ya da Kazanım havuzu ekranından Excel ile yükleyebilirsin.':
      'No outcomes for this subject. Type above to add one, or upload from Excel on the Outcome pool screen.',
  'Ad': 'Name',
  'Kaydedilemedi. Aynı ad zaten olabilir.':
      'Couldn\'t save. The same name may already exist.',
  'Yeni konu': 'New topic',
  'Yeni alt konu': 'New subtopic',
  'Kazanım bulunamadı. Sütunlar: Ders ("TYT Matematik" gibi), Konu, Alt konu, Kod.':
      'No outcomes found. Columns: Subject (e.g. "TYT Matematik"), Topic, Subtopic, Code.',
  '{i} kazanım eklendi, {s} zaten vardı. Dersi tanınmayan satır: {u}.':
      '{i} outcomes added, {s} already existed. Rows with unknown subject: {u}.',
  'Konu ekle': 'Add topic',
  'Bu derste kazanım yok': 'No outcomes for this subject',
  'Konu ekle ya da Excel ile toplu yükle. Sütunlar: Ders, Konu, Alt konu, Kod.':
      'Add a topic or bulk upload from Excel. Columns: Subject, Topic, Subtopic, Code.',
  'Adı değiştir': 'Rename',
  'Kazanım silinsin mi?': 'Delete the outcome?',
  'Alt konuları da silinir. Sınavlardaki eşleştirmeler kaldırılır; geçmiş sonuçlardaki ad kalır.':
      'Its subtopics are deleted too. Links in exams are removed; the name stays in past results.',
  'Kazanım işlemleri': 'Outcome actions',
  'Alt konu ekle': 'Add subtopic',
  '{n} alt konu': '{n} subtopics',
  // Finans: hesaplar, indirim, kısmi ödeme, makbuz, iade, gelir, toplu ücret
  'Diğer gelir (₺)': 'Other income (₺)',
  'İade (₺)': 'Refund (₺)',
  'Net: tahsilat + gelir − iade − gider (₺)':
      'Net: collected + income − refunds − expenses (₺)',
  'Makbuz no': 'Receipt no.',
  'İade': 'Refund',
  'Diğer gelirler': 'Other income',
  'Öğrenci / ödeyen': 'Student / payer',
  'Kısmen ödendi': 'Partly paid',
  'İndirimsiz ücret (₺)': 'Fee before discount (₺)',
  'İndirim (₺)': 'Discount (₺)',
  'Kayıt iptal': 'Enrolment cancelled',
  'IBAN': 'IBAN',
  'Bakiye (₺)': 'Balance (₺)',
  'Hesap seçilmemiş': 'No account',
  'İndirim': 'Discount',
  'Burs': 'Scholarship',
  'Kardeş indirimi': 'Sibling discount',
  'Diğer indirim': 'Other discount',
  'Kasa': 'Cash box',
  'Banka': 'Bank',
  'POS / sanal pos': 'Card terminal / online',
  'Kitap / yayın': 'Books / publications',
  'Özel ders': 'Private lesson',
  'Materyal': 'Materials',
  'Etkinlik': 'Event',
  'Kalan borçtan fazla tutar girildi.':
      'The amount is more than the balance due.',
  'Tahsilatı olan ücret silinemez; kaydı iptal et.':
      'A fee with collections can\'t be deleted; cancel the enrolment instead.',
  'İade, tahsil edilen tutardan fazla olamaz.':
      'The refund can\'t be more than what was collected.',
  'İndirim kalan borçtan büyük olamaz.':
      'The discount can\'t be more than the balance due.',
  'Bu kayıt iptal edilmiş.': 'This enrolment was cancelled.',
  'Bu ad zaten kullanılıyor.': 'This name is already in use.',
  'Tahsilat kaydedildi ({no}). Kalan: {v}':
      'Collection saved ({no}). Remaining: {v}',
  'Ödeme al': 'Take payment',
  '{d} vadeli taksite {v}': '{v} to the instalment due {d}',
  'Makbuzlar': 'Receipts',
  'Eski kayıt': 'Earlier record',
  'İptal edildi': 'Voided',
  'Makbuz işlemleri': 'Receipt actions',
  'Makbuz iptal edilsin mi?': 'Void the receipt?',
  '{no} numaralı makbuzun tutarı taksitlerden geri alınır. Numara tekrar kullanılmaz.':
      'Receipt {no} is taken back from the instalments. The number isn\'t reused.',
  'Makbuzu paylaş (PDF)': 'Share receipt (PDF)',
  'Makbuzu iptal et': 'Void receipt',
  '{k} eklendi; son taksitlerden düşüldü.':
      '{k} added; taken off the last instalments.',
  'İndirim / burs': 'Discount / scholarship',
  'Yüzde': 'Percent',
  'Kayıt iptal edildi; {v} iade kaydedildi.':
      'Enrolment cancelled; refund of {v} recorded.',
  'Kayıt iptal edildi.': 'Enrolment cancelled.',
  'Kaydı iptal et': 'Cancel enrolment',
  'Ödenmemiş taksitler silinir, kısmen ödenen taksit ödenen tutara iner. Tahsil edilen: {v}.':
      'Unpaid instalments are removed and a partly paid one is reduced to what was paid. Collected: {v}.',
  'İade tutarı (yoksa boş)': 'Refund amount (leave empty if none)',
  'İade şekli': 'Refund method',
  'Sebep (isteğe bağlı)': 'Reason (optional)',
  'Başlık, tutar ve en az bir öğrenci seç.':
      'Choose a title, amount and at least one student.',
  'İndirim ücretten büyük olamaz.': 'The discount can\'t be more than the fee.',
  '{n} öğrenciye ücret açıldı; {s} öğrenci atlandı (aynı başlıkta kaydı var).':
      'Fee created for {n} students; {s} skipped (already have one with this title).',
  'Toplu ücret': 'Bulk fee',
  'İndirimsiz ücret': 'Fee before discount',
  'İndirim yok': 'No discount',
  'Öğrenciler ({n} seçili)': 'Students ({n} selected)',
  'Şablon olarak kaydet': 'Save as template',
  '{n} öğrenciye ücret aç': 'Create fee for {n} students',
  'Gelir ekle': 'Add income',
  'Henüz gelir yok': 'No income yet',
  'Kitap, özel ders, materyal gibi ücret dışı gelirleri buradan kaydet; makbuz no verilir.':
      'Record income other than fees here (books, private lessons, materials); a receipt number is given.',
  '{no} numaralı makbuz iptal edilir. Numara tekrar kullanılmaz.':
      'Receipt {no} is voided. The number isn\'t reused.',
  'Gelir kaydedildi ({no}).': 'Income saved ({no}).',
  'Öğrenci (isteğe bağlı)': 'Student (optional)',
  'Öğrenci yok': 'No student',
  'Ödeyen (isteğe bağlı)': 'Payer (optional)',
  'Virman': 'Transfer',
  'Hesap ekle': 'Add account',
  'Henüz hesap yok': 'No accounts yet',
  'Kasa ve banka hesaplarını ekle; tahsilat, gelir ve giderleri hesaba bağlayınca bakiyeler burada görünür.':
      'Add your cash box and bank accounts; link collections, income and expenses to see balances here.',
  'Kullanılmıyor': 'Not in use',
  'Hesap seçilmeyen hareketler': 'Entries without an account',
  'Virmanlar': 'Transfers',
  'Hesaplar arası aktarım': 'Transfer between accounts',
  'Çıkan hesap': 'From account',
  'Giren hesap': 'To account',
  'Farklı iki hesap ve tutar seç.':
      'Choose two different accounts and an amount.',
  'Hesabı düzenle': 'Edit account',
  'IBAN (isteğe bağlı)': 'IBAN (optional)',
  'IBAN TR ile başlayan 26 karakter olmalı.':
      'The IBAN must be 26 characters starting with TR.',
  'Açılış bakiyesi': 'Opening balance',
  'Ödeme kaydı yok': 'No fee records',
  'Kurum bu öğrenci için ücret kaydı girmemiş.':
      'The institution hasn\'t entered a fee for this student.',
  'Kayıt iptal edildi': 'Enrolment cancelled',
  'Ücret: {v}': 'Fee: {v}',
  'İndirim: {v}': 'Discount: {v}',
  'Ödenen: {v}': 'Paid: {v}',
  '{p} ödendi, {r} kaldı': '{p} paid, {r} left',
  'Gelirler': 'Income',
  'Diğer gelir': 'Other income',
  'İade: {v}': 'Refunds: {v}',
  'Tahsilat + gelir − iade − gider': 'Collected + income − refunds − expenses',
  'İndirimsiz ücret: {v}': 'Fee before discount: {v}',
  'Kaydı iptal et / iade': 'Cancel enrolment / refund',
  'Ödenecek: {v}': 'To pay: {v}',
  'Kayıt iptali iadesi': 'Cancellation refund',
  'Vade {d} taksidi': 'Instalment due {d}',
  'Makbuz': 'Receipt',
  'İade makbuzu': 'Refund receipt',
  'Tahsilat makbuzu': 'Collection receipt',
  'Ödeyen': 'Payer',
  'Kalem': 'Item',
  'Kalan borç: {v}': 'Balance due: {v}',
  'Bu belge tahsilat bilgisidir; fatura yerine geçmez.':
      'This is a record of collection, not an invoice.',
  'İmza / kaşe': 'Signature / stamp',
  'Veli nüshası': 'Parent copy',
  'Kurum nüshası': 'Institution copy',
  'Ödemeler': 'Payments',
  'Bu başlıkta ücreti var': 'Already has a fee with this title',
  'Aynı başlıkta ücreti olanlara da aç ({n})':
      'Also create for those with the same title ({n})',
  'Bu öğrencilere ikinci bir ücret açılır.':
      'A second fee is created for these students.',
  'Kapalıyken bu öğrenciler atlanır.': 'When off, these students are skipped.',
  '{n} öğrenciye ücret açıldı.': 'Fee created for {n} students.',
  'Yoklama ve ödeme hatırlatma mesajları bu numaraya gider.':
      'Attendance and payment reminder texts go to this number.',
  'Sınıf ataması, öğrenci numarası, veli telefonu ve kayıtlar':
      'Class assignment, student number, parent phone and records',
  'Sınıf, numara ve veli': 'Class, number and parent',
  // Müdür kokpiti (NOTLAR §59)
  '7 gün ya da daha uzun süredir girmeyenler':
      'Not signed in for 7 days or more',
  'Aktif davet yok. Koç ya da öğrenci daveti oluşturduğunda burada görünür.':
      'No active invites. Coach or student invites you create appear here.',
  'Arama başlatılamadı: {p}': 'Could not start the call: {p}',
  'Bildirim gönderilemedi. Tekrar dene.':
      'Could not send the notification. Try again.',
  'Bu bölüm yüklenemedi. Bağlantını kontrol et.':
      'This section could not be loaded. Check your connection.',
  'Bu grupta öğrenci yok.': 'No students in this group.',
  'Bu hafta aktif': 'Active this week',
  'Bu hafta çalışmayanları açar': 'Opens students who did not study this week',
  'Bu hafta çözülen soru': 'Questions solved this week',
  'Bu haftanın çalışması': 'This week of study',
  'Bu öğrenci için koça son 6 saat içinde zaten bildirim gönderildi.':
      'The coach was already notified about this student in the last 6 hours.',
  'Bugünden itibaren, en yakını önce': 'From today, nearest first',
  'Cep telefonu': 'Mobile phone',
  'Deneme adını yaz.': 'Enter the exam name.',
  'Deneme planla': 'Plan an exam',
  'Deneme takvime eklendi.': 'Exam added to the calendar.',
  'Deneme takvimi': 'Exam calendar',
  'Deneme takvimini açar': 'Opens the exam calendar',
  'Deneme trendleri': 'Exam trends',
  'Dikkat gerektirenler': 'Needs attention',
  'Geçen haftaya göre': 'Compared with last week',
  'Geçen haftaya göre {v} arttı': 'Up {v} from last week',
  'Geçen haftaya göre {v} azaldı': 'Down {v} from last week',
  'Geçen haftayla aynı': 'Same as last week',
  'Geçerli bir cep telefonu yaz.': 'Enter a valid mobile number.',
  'Giriş yok · {n}': 'Not signed in · {n}',
  'Görünüm': 'Appearance',
  'Görüşmeler pazartesiden bu yana; aktiflik son 7 gün':
      'Meetings since Monday; activity over the last 7 days',
  'Haftalık ayrıntı': 'Weekly detail',
  'Henüz koç yok. Kod oluştur ve koçuna gönder.':
      'No coaches yet. Create a code and send it to your coach.',
  'Henüz öğrenci yok. Bir koç için öğrenci davet kodu oluştur.':
      'No students yet. Create a student invite code for a coach.',
  'Her yeni öğrenci 1 kredi kullanır.': 'Each new student uses 1 credit.',
  'Herkes bu hafta çalışmış.': 'Everyone studied this week.',
  'Hesabı yeniden açmak için destek ekibiyle görüşün.':
      'Contact the support team to reopen the account.',
  'Hiç giriş yapmadı': 'Never signed in',
  'Kayıtlı öğrenci': 'Registered students',
  'Kokpitteki "Koçu ara" düğmesi bu numarayı arar.':
      'The "Call coach" button on the dashboard calls this number.',
  'Koç performansı': 'Coach performance',
  'Koça uygulama içinde ve telefonuna bildirim gider: "{name} ile ilgilenir misin?"':
      'The coach gets an in-app and phone notification: "Can you look into {name}?"',
  'Koçu ara': 'Call coach',
  'Koçu atanmamış': 'No coach assigned',
  'Koçu: {name}': 'Coach: {name}',
  'Koçuna bildir': 'Notify the coach',
  'Kredi yüklemek için destek ekibiyle görüşün.':
      'Contact the support team to top up credits.',
  'Kurum araçları': 'Institution tools',
  'Kurum ayarları': 'Institution settings',
  'Kurumda henüz koç yok.': 'The institution has no coaches yet.',
  'Kurumda henüz öğrenci yok.': 'The institution has no students yet.',
  'Kurumdaki hesaplar': 'Accounts in the institution',
  'Kurumun son TYT ortalaması: {v} net ({n} öğrenci)':
      'Institution latest TYT average: {v} net ({n} students)',
  'Lisans': 'Licence',
  'Lisans bugün bitiyor': 'The licence ends today',
  'Lisans süresi doldu ({date})': 'Licence expired ({date})',
  'Lisans {n} gün sonra bitiyor': 'The licence ends in {n} days',
  'Logo, renk ve yazı tipi': 'Logo, colour and font',
  'Net düşüşü · {n}': 'Net drop · {n}',
  'Plan silinsin mi?': 'Delete this plan?',
  'Planlı deneme yok.': 'No exams planned.',
  'Planlı deneme yok. Planla': 'No exams planned. Plan one',
  'Planlı denemeler': 'Planned exams',
  'Planı sil': 'Delete plan',
  'Risk listesi': 'Risk list',
  'Son 5 denemede en çok yükselen ve düşenler':
      'Biggest risers and fallers over the last 5 exams',
  'Son 7 gün · toplam {t} çalışma': 'Last 7 days · {t} of study in total',
  'Son 7 günde soru ya da çalışma kaydı olmayanlar':
      'No questions or study logged in the last 7 days',
  'Son iki denemesi arasında 3 ya da daha çok net düşenler':
      'Dropped 3 or more nets between their last two exams',
  'Soru sırası': 'By questions',
  'Telefon kaydedildi.': 'Phone saved.',
  'Telefon kaydedilemedi. Tekrar dene.': 'Could not save the phone. Try again.',
  'Telefon silindi.': 'Phone removed.',
  'Telefonu düzenle': 'Edit phone',
  'Tümünü gör ({n})': 'See all ({n})',
  'Vadesi geçmiş, ödenmemiş taksiti olanlar':
      'Have an unpaid, overdue instalment',
  'Yaklaşan deneme': 'Upcoming exam',
  'Yeni öğrenci eklenemez.': 'New students cannot be added.',
  'Yeni öğrenci eklenemez. Kredi yüklemek için destek ekibiyle görüşün.':
      'New students cannot be added. Contact the support team to top up credits.',
  'Yüklenemedi': 'Could not load',
  'Yüzde {p}': '{p} percent',
  'aktif öğrenci': 'active students',
  'aynı': 'same',
  'bugün': 'today',
  'görüşme yapıldı': 'meetings held',
  'gün sonra': 'days to go',
  'katılım %{p}': '{p}% participation',
  'planlı görüşme yok': 'no meetings planned',
  'yarın': 'tomorrow',
  '{coach} bilgilendirildi.': '{coach} was notified.',
  '{coach} bilgilendirilsin': 'Notify {coach}',
  '{date} tarihinden sonra öğrenci, koç ve veliler giriş yapamaz. Lisansı uzatmak için destek ekibiyle görüşün.':
      'After {date}, students, coaches and parents cannot sign in. Contact the support team to extend the licence.',
  '{date} tarihine kadar': 'Until {date}',
  '{d} gündür': 'for {d} days',
  '{name} ile ilgilenir misin?': 'Can you look into {name}?',
  '{name} yazdı': '{name} wrote',
  '{name} · telefon': '{name} · phone',
  '{n} gün sonra': 'in {n} days',
  '{n} gündür giriş yapmadı': 'Not signed in for {n} days',
  '{n} kaldı': '{n} left',
  '{n} taksit gecikti': '{n} instalments overdue',
  '{s} öğrenci · {c} koç · {p} veli':
      '{s} students · {c} coaches · {p} parents',
  '{type} neti {a} → {b} ({c})': '{type} net {a} → {b} ({c})',
  '{t} çalışma': '{t} of study',
  'Çalışmayanlar · {n}': 'Not studying · {n}',
  'Ödeme · {n}': 'Payment · {n}',
  'Önce öğrenciye koç ata': 'Assign a coach to the student first',
  'Öğrenci daveti oluştur': 'Create a student invite',
  'Öğrenci krediniz azaldı: {n} kaldı':
      'Your student credits are low: {n} left',
  'Öğrenci kredisi': 'Student credits',
  'Öğrenci listesini açar': 'Opens the student list',
  'Öğrenci, koç ve veliler giriş yapamıyor. Lisansı uzatmak için destek ekibiyle görüşün.':
      'Students, coaches and parents cannot sign in. Contact the support team to extend the licence.',
  'Öğrenciler kayıt olurken bu kodu yazar.':
      'Students enter this code when signing up.',
  'Öğrencileri soru sayısına göre sıralar': 'Sorts students by questions',
  'ör. TYT Genel Deneme 5': 'e.g. TYT General Exam 5',
  'öğrenci': 'students',
  'Şu an dikkat gerektiren öğrenci yok.':
      'No students need attention right now.',
  // Kokpit eğilimi ve koç paneli (NOTLAR §60)
  'Aktif öğrenci': 'Active students',
  'Açık: öğrenciler görüyor': 'On: students can see it',
  'Bekleyen görev': 'Pending tasks',
  'Haftalık aktif öğrenci': 'Active students per week',
  'Haftalık çözülen soru': 'Questions solved per week',
  'Henüz öğrencin yok. Bir davet kodu oluştur ve öğrencine gönder; kodla kayıt olan öğrenci otomatik olarak sana bağlanır.':
      'You have no students yet. Create an invite code and send it to your student; whoever signs up with it is linked to you automatically.',
  'Kapalı: yalnızca sen önizlersin': 'Off: only you can preview it',
  'Kısayollar': 'Shortcuts',
  'Son 8 hafta': 'Last 8 weeks',
  '{d}: {a} / {s} aktif': '{d}: {a} / {s} active',
  '{d}: {q} soru': '{d}: {q} questions',
  'Ödev verme ekranını açar': 'Opens the homework screen',
  'Öğrenci kaydı olunca haftalık eğilim burada görünür.':
      'The weekly trend appears here once students sign up.',
  'öğrencilerinde yapılmamış': 'not yet done by your students',
  // Kokpit hareket turu (NOTLAR §61)
  'Bu hafta {a} / {t} öğrenci aktif, katılım yüzde {p}':
      '{a} of {t} students active this week, {p} percent participation',
  'Giriş yok': 'Not signed in',
  'Net düşüşü': 'Net drop',
  'katılım': 'participation',
  'Ödeme': 'Payment',
  'öğrenci bu hafta çalıştı': 'students studied this week',
  'Hesap silme talepleri': 'Account deletion requests',
  'Öğrenci listesi': 'Student list',
  'Kurum hesabı': 'Institution account',
  'Bir öğrenci': 'A student',
  'KVKK gereği talep 30 gün içinde sonuçlanmalı; {n} gün kaldı.':
      'Under KVKK the request must be settled within 30 days; {n} days left.',
  'KVKK gereği 30 günlük cevap süresi doldu.':
      'The 30-day KVKK response period has passed.',
  'taksidin vadesi geçti': 'instalments are overdue',
  'Toplam {v} henüz tahsil edilmedi.':
      '{v} in total has not been collected yet.',
  'öğrencinin bugünkü yoklaması alınmadı':
      'students have no attendance taken today',
  'öğrenci bugünkü yoklamada işaretsiz':
      'students are unmarked in today’s attendance',
  'Gelmeyenlerin velisine SMS ancak yoklama kaydedilince gider.':
      'Parents of absent students get an SMS only after attendance is saved.',
  'kurum sınavının sonucu yayın bekliyor':
      'institution exams are waiting to be published',
  'Optikler yüklendi; yayınlanana kadar öğrenci ve veliler sonucu göremez.':
      'Answer sheets are uploaded; students and parents cannot see results until you publish.',
  'kitap talebi onay bekliyor': 'book requests await approval',
  'Onaylanınca kitap havuza girer ve öğrenciler seçebilir.':
      'Once approved, the book joins the pool and students can pick it.',
  'öğrencinin okul numarası şüpheli':
      'students have a suspicious school number',
  'Deneme sonuçları numarayla eşleştiği için yanlış öğrenciye gidebilir.':
      'Exam results are matched by number, so they may go to the wrong student.',
  'öğrencinin okul numarası eksik': 'students are missing a school number',
  'Deneme dosyaları numarayla eşleştirilir; numarasız öğrencinin sonucu eşleşmez.':
      'Exam files are matched by number; results of students without one will not match.',
  'öğrenci bir sınıfa atanmamış': 'students are not assigned to a class',
  'Sınıfsız öğrenci sınıf listelerinde ve ders programında yer almaz.':
      'Students without a class do not appear in class lists or the timetable.',
  'Bekleyen işler': 'Pending work',
  'Bekleyen işler: {n}': 'Pending work: {n}',
  'Bekleyen işler yüklenemedi. Bağlantını kontrol edip tekrar dene.':
      'Pending work could not be loaded. Check your connection and try again.',
  'Acil': 'Urgent',
  'Süre ya da para söz konusu; önce bunlar':
      'Deadlines or money involved; do these first',
  'Süre ya da para bekleyen iş yok':
      'Nothing with a deadline or money involved',
  'Yapılacak iş kalmadı': 'Nothing left to do',
  'Hepsi aşağıda, önce acil olanlar': 'All listed below, urgent ones first',
  'Bekleyen işin yok, her şey güncel.':
      'No pending work, everything is up to date.',
  'Yeni bir iş çıkınca burada ve üst çubuktaki rozette görünür.':
      'New work will show up here and on the badge in the top bar.',
  'Acil iş yok.': 'No urgent work.',
  'Diğer {n} bekleyen iş Tümü sekmesinde.':
      'The other {n} pending items are under All.',
  'Tümünü göster': 'Show all',
  'Gelen kaynaklarda bekleyen iş yok.':
      'No pending work in the sources that loaded.',
  '{source} bilgisi alınamadı': 'Could not load {source}',
  'Buradaki bekleyen işler listede eksik olabilir.':
      'Pending work from here may be missing from the list.',
  'Sınavlar': 'Exams',
  'İletişim': 'Messages',
  'Deneme sonuçları, kurum sınavları, optik okuma ve deneme planı':
      'Exam results, institution exams, answer sheet scanning and exam plan',
  'Deneme sonuçları, kurum sınavları, optik okuma ve trendler':
      'Exam results, institution exams, answer sheet scanning and trends',
  'Velilere SMS ve toplu duyurular': 'SMS to parents and bulk announcements',
  'Duyurular ve öğrenci daveti': 'Announcements and student invites',
  'Deneme sonuç dosyasını yükle, öğrencilere dağıt':
      'Upload an exam results file and share it with students',
  'Yüklenen denemeler': 'Uploaded exams',
  'Son 7 gündeki yüklemeler silinebilir':
      'Uploads from the last 7 days can be deleted',
  'Deneme planı': 'Exam plan',
  'Yaklaşan kurum denemelerini planla': 'Plan upcoming institution exams',
  'Toplu duyuru gönder, gelen duyuruları gör':
      'Send bulk announcements, see incoming ones',
  'Davet kodu oluştur ve öğrencine gönder':
      'Create an invite code and send it to your student',
  'Aktif davet kodları; kod oluştur ve paylaş':
      'Active invite codes; create and share a code',
  'Koçların öğrencileriyle görüşme düzeni':
      'How often coaches meet their students',
  'Öğrencilerine görev ve ödev ata':
      'Assign tasks and homework to your students',
};
