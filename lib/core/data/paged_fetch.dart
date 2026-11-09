/// Sunucunun tek cevapta verdiği en çok satır (Supabase `max_rows` varsayılanı).
const maxRowsPerResponse = 1000;

/// Bir listeyi sayfa sayfa sonuna kadar çeker.
///
/// Sunucu sınırı aşan cevabı hata vermeden kırpar; büyük kurumda liste ve
/// toplamlar sessizce eksik çıkardı. [page] verilen aralığı istemeli ve
/// sıralaması kesin olmalı (son sıra ölçütü benzersiz bir sütun): yoksa aynı
/// değerli satırlar sayfalar arasında kayar ya da iki kez gelir.
///
/// Tek sayfaya sığan listede fazladan istek gitmez. [maxRows] verilirse o kadar
/// satıra ulaşınca durur (sonuç en fazla bir sayfa aşabileceği için kırpılır).
Future<List<T>> fetchAllPages<T>(
  Future<List<T>> Function(int from, int to) page, {
  int pageSize = maxRowsPerResponse,
  int? maxRows,
}) async {
  final rows = <T>[];
  while (maxRows == null || rows.length < maxRows) {
    final batch = await page(rows.length, rows.length + pageSize - 1);
    rows.addAll(batch);
    if (batch.length < pageSize) break;
  }
  return maxRows != null && rows.length > maxRows
      ? rows.sublist(0, maxRows)
      : rows;
}
