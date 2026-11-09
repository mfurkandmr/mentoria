import 'package:flutter_test/flutter_test.dart';
import 'package:mentoria/core/data/paged_fetch.dart';

void main() {
  /// Sunucu gibi davranır: istenen aralığı, [total] satırı aşmadan döner.
  Future<List<int>> Function(int, int) server(int total, List<int> calls) =>
      (from, to) async {
        calls.add(from);
        final end = [to + 1, total].reduce((a, b) => a < b ? a : b);
        return from >= end
            ? <int>[]
            : List.generate(end - from, (i) => from + i);
      };

  test('sınırı aşan liste eksiksiz ve sırasıyla gelir', () async {
    final calls = <int>[];
    final rows = await fetchAllPages(server(2500, calls));
    expect(rows, List.generate(2500, (i) => i));
    expect(calls, [0, 1000, 2000]);
  });

  test('tek sayfaya sığan liste fazladan istek atmaz', () async {
    final calls = <int>[];
    expect(await fetchAllPages(server(40, calls)), hasLength(40));
    expect(calls, [0]);
  });

  test('tam sayfa katında son boş sayfayla biter', () async {
    final calls = <int>[];
    expect(await fetchAllPages(server(2000, calls)), hasLength(2000));
    expect(calls, [0, 1000, 2000]);
  });

  test('boş liste', () async {
    expect(await fetchAllPages(server(0, [])), isEmpty);
  });

  test('maxRows: üst sınırda durur ve kırpar', () async {
    final calls = <int>[];
    final rows = await fetchAllPages(server(9000, calls), maxRows: 2500);
    expect(rows, hasLength(2500));
    expect(calls, [0, 1000, 2000]);
  });

  test('sayfa hatası yutulmaz (eksik liste dönmez)', () async {
    var n = 0;
    expect(
      fetchAllPages<int>((from, to) async {
        if (n++ == 1) throw StateError('ağ');
        return List.filled(1000, 0);
      }),
      throwsStateError,
    );
  });
}
