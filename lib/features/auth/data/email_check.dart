/// Kayıt formundaki e-posta denetimi. Adresin gerçekten kullanıcıya ait
/// olduğunu e-postaya giden doğrulama kodu kanıtlar; bu yalnızca biçimi ve
/// sık yapılan yazım hatalarını yakalar.
library;

final _emailPattern = RegExp(
  r"^[a-z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)*\.[a-z]{2,}$",
);

/// Biçimce geçerli bir e-posta mı (ör. `ali@gmail.com`).
bool isValidEmail(String email) {
  final e = email.trim().toLowerCase();
  return e.length <= 254 && !e.contains('..') && _emailPattern.hasMatch(e);
}

const _domainTypos = {
  'gmial.com': 'gmail.com',
  'gmai.com': 'gmail.com',
  'gmal.com': 'gmail.com',
  'gamil.com': 'gmail.com',
  'gnail.com': 'gmail.com',
  'gmail.co': 'gmail.com',
  'gmail.con': 'gmail.com',
  'gmail.com.tr': 'gmail.com',
  'hotmial.com': 'hotmail.com',
  'hotmal.com': 'hotmail.com',
  'hotmail.co': 'hotmail.com',
  'hotmail.con': 'hotmail.com',
  'outlok.com': 'outlook.com',
  'outlook.con': 'outlook.com',
  'yahoo.con': 'yahoo.com',
  'yaho.com': 'yahoo.com',
  'icloud.con': 'icloud.com',
};

/// Alan adında bilinen bir yazım hatası varsa düzeltilmiş adres, yoksa `null`.
String? suggestEmail(String email) {
  final e = email.trim().toLowerCase();
  final at = e.lastIndexOf('@');
  if (at < 1) return null;
  final fixed = _domainTypos[e.substring(at + 1)];
  return fixed == null ? null : '${e.substring(0, at)}@$fixed';
}
