import 'dart:math';
import 'dart:typed_data';

import 'constraints.dart';
import 'models.dart';

/// Haftalık ders programı üretici (saf Dart; arayüz ve veritabanından
/// bağımsız).
///
/// 1. Kilitli dersler yerine konur, kuralları bozanlar raporlanır.
/// 2. Öğretmeni seçilmemiş derslere branşı tutan, en çok boş kapasitesi
///    olan öğretmen verilir; talep / müsaitlik / üst sınır kontrol edilir.
/// 3. Ders saatleri MRV ile (en az seçeneği kalan ders önce) backtracking
///    ve forward checking ile yerleşir. Süre ya da düğüm sınırı dolarsa
///    açgözlü doldurma yapılır, yerleşemeyenler raporlanır (çökmez).
/// 4. Yumuşak kısıt puanı simulated annealing ile (taşıma ve aynı sınıfta
///    iki dersin yerini değiştirme) iyileştirilir.
class ScheduleGenerator {
  ScheduleGenerator._(this.input)
    : _rng = Random(input.seed),
      _model = ScoreModel(input);

  /// [input] için program üretir. Hiçbir durumda hata fırlatmaz; çözüm
  /// yoksa eksikler [GenerationResult.unassigned] ve nedenleri
  /// [GenerationResult.conflicts] içindedir.
  static GenerationResult generate(GenerationInput input) =>
      ScheduleGenerator._(input)._run();

  /// `compute()` / isolate için: JSON girdi → JSON sonuç.
  static Map<String, dynamic> generateJson(Map<String, dynamic> json) =>
      generate(GenerationInput.fromJson(json)).toJson();

  final GenerationInput input;
  final Random _rng;
  final ScoreModel _model;
  final _sw = Stopwatch();
  final _conflicts = <Conflict>[];

  late final int _nS = input.slots.length;
  late final int _nT = input.teachers.length;
  late final int _nC = input.classrooms.length;
  late final int _nR = input.rooms.length;

  // Müsaitlik ve doluluk (sayaç: kilitli derslerin çakışması da sayılır).
  late final List<Uint8List> _avail;
  late final List<Int32List> _tBusy;
  late final List<Int32List> _cBusy;
  late final List<Int32List> _rBusy;
  late final Int32List _tLoad;
  late final Int32List _tMax;
  late final Int32List _homeRoom;
  late final List<int> _floatingRooms;
  late final Int32List _prevSlot;
  late final Int32List _nextSlot;

  // Dersler.
  late final Int32List _lTeacher;
  late final Int32List _lClass;
  late final List<String> _lBranch;
  late final Int32List _need;
  late final List<Int32List> _lDay; // ders → gün → saat sayısı

  // Yerleşen dersler (kilitliler başta).
  final _eT = <int>[];
  final _eC = <int>[];
  final _eS = <int>[];
  final _eR = <int>[];
  final _eB = <String>[];
  final _eL = <int>[]; // ders dizini; kilitliyse -1
  int _lockedCount = 0;
  final _lockedEntries = <ScheduleEntry>[];

  int _nodes = 0;
  bool _aborted = false;
  late int _constructMs;
  static const _maxNodes = 40000;

  // Aramada en çok ders yerleştiren ara durum.
  int _bestPlaced = -1;
  List<int>? _bestSnapshot; // _eL, _eS, _eR üçlüleri

  GenerationResult _run() {
    _sw.start();
    _constructMs = (input.timeLimitMs * 0.4).round();
    _index();
    _placeLocked();
    _chooseTeachers();
    _diagnose();

    final start = _eT.length;
    final ok = _search();
    if (!ok) {
      // Aramanın en iyi ara durumu ile açgözlü doldurmayı kıyasla.
      final searched = _bestSnapshot;
      _resetTo(start);
      _greedy();
      final greedyPlaced = _eT.length - _lockedCount;
      if (searched != null && searched.length ~/ 3 > greedyPlaced) {
        _resetTo(start);
        _restore(searched);
      }
    }
    _explainUnassigned();
    _anneal();

    final entries = <ScheduleEntry>[
      ..._lockedEntries,
      for (var i = _lockedCount; i < _eT.length; i++)
        ScheduleEntry(
          teacherId: input.teachers[_eT[i]].id,
          classroomId: input.classrooms[_eC[i]].id,
          timeSlotId: input.slots[_eS[i]].id,
          branch: _eB[i],
          roomId: _eR[i] < 0 ? null : input.rooms[_eR[i]].id,
        ),
    ];
    final unassigned = <UnassignedLesson>[
      for (var l = 0; l < input.lessons.length; l++)
        if (_need[l] > 0)
          UnassignedLesson(
            lessonId: input.lessons[l].id,
            classroomId: input.lessons[l].classroomId,
            branch: input.lessons[l].branch,
            missingHours: _need[l],
          ),
    ];
    return GenerationResult(
      entries: entries,
      unassigned: unassigned,
      conflicts: _conflicts,
      softScore: _score(),
      durationMs: _sw.elapsedMilliseconds,
    );
  }

  // ---------------------------------------------------------------------
  // Hazırlık
  // ---------------------------------------------------------------------

  void _index() {
    _avail = [
      for (final t in input.teachers)
        Uint8List.fromList([
          for (final s in input.slots) t.availableAt(s) ? 1 : 0,
        ]),
    ];
    _tBusy = [for (var i = 0; i < _nT; i++) Int32List(_nS)];
    _cBusy = [for (var i = 0; i < _nC; i++) Int32List(_nS)];
    _rBusy = [for (var i = 0; i < _nR; i++) Int32List(_nS)];
    _tLoad = Int32List(_nT);
    _tMax = Int32List.fromList([
      for (final t in input.teachers) t.maxWeeklyHours,
    ]);
    final roomIndex = {for (var i = 0; i < _nR; i++) input.rooms[i].id: i};
    _homeRoom = Int32List.fromList([
      for (final c in input.classrooms) roomIndex[c.homeRoomId] ?? -1,
    ]);
    final homes = _homeRoom.where((r) => r >= 0).toSet();
    _floatingRooms = [
      for (var r = 0; r < _nR; r++)
        if (!homes.contains(r)) r,
    ];
    _prevSlot = Int32List(_nS)..fillRange(0, _nS, -1);
    _nextSlot = Int32List(_nS)..fillRange(0, _nS, -1);
    final byDay = <int, List<int>>{};
    for (var s = 0; s < _nS; s++) {
      byDay.putIfAbsent(input.slots[s].day, () => []).add(s);
    }
    for (final list in byDay.values) {
      list.sort((a, b) => _model.posOf(a).compareTo(_model.posOf(b)));
      for (var k = 0; k + 1 < list.length; k++) {
        _nextSlot[list[k]] = list[k + 1];
        _prevSlot[list[k + 1]] = list[k];
      }
    }

    final nL = input.lessons.length;
    _lTeacher = Int32List(nL)..fillRange(0, nL, -1);
    _lClass = Int32List(nL);
    _lBranch = [for (final l in input.lessons) l.branch];
    _need = Int32List(nL);
    _lDay = [for (var l = 0; l < nL; l++) Int32List(8)];
    for (var l = 0; l < nL; l++) {
      final lesson = input.lessons[l];
      _lClass[l] = _model.classIndex[lesson.classroomId] ?? -1;
      _need[l] = _lClass[l] < 0 ? 0 : lesson.weeklyHours;
      final t = lesson.teacherId;
      if (t != null) _lTeacher[l] = _model.teacherIndex[t] ?? -1;
    }
  }

  String _tName(int t) => input.teachers[t].name;
  String _cName(int c) => input.classrooms[c].name;

  void _placeLocked() {
    final lessonOf = <String, int>{
      for (var l = 0; l < input.lessons.length; l++)
        '${input.lessons[l].classroomId}|${input.lessons[l].branch}': l,
    };
    for (final e in input.locked) {
      final t = _model.teacherIndex[e.teacherId];
      final c = _model.classIndex[e.classroomId];
      final s = _model.slotIndex[e.timeSlotId];
      if (t == null || c == null || s == null) {
        // Silinmiş öğretmen / sınıf / saat: kilit tutulamaz.
        _conflicts.add(Conflict(ConflictKind.lockedInvalid, branch: e.branch));
        continue;
      }
      final r = e.roomId == null
          ? -1
          : input.rooms.indexWhere((x) => x.id == e.roomId);
      final clash =
          _tBusy[t][s] > 0 ||
          _cBusy[c][s] > 0 ||
          (r >= 0 && _rBusy[r][s] > 0) ||
          _avail[t][s] == 0;
      if (clash) {
        _conflicts.add(
          Conflict(
            ConflictKind.lockedInvalid,
            teacherName: _tName(t),
            classroomName: _cName(c),
            branch: e.branch,
          ),
        );
      }
      final l = lessonOf['${e.classroomId}|${e.branch}'] ?? -1;
      _push(t, c, s, r < 0 ? -1 : r, e.branch, -1);
      _lockedEntries.add(e);
      if (l >= 0) {
        _need[l]--;
        _lDay[l][input.slots[s].day]++;
        if (_lTeacher[l] < 0) _lTeacher[l] = t;
      }
    }
    _lockedCount = _eT.length;
    for (var l = 0; l < input.lessons.length; l++) {
      if (_need[l] < 0) {
        _conflicts.add(
          Conflict(
            ConflictKind.lockedOverHours,
            classroomName: _cName(_lClass[l]),
            branch: _lBranch[l],
            need: input.lessons[l].weeklyHours,
            have: input.lessons[l].weeklyHours - _need[l],
          ),
        );
        _need[l] = 0;
      }
    }
  }

  /// Öğretmeni boş derslere: branşı tutan, en çok boş kapasitesi olan.
  void _chooseTeachers() {
    final demand = Int32List(_nT);
    for (var l = 0; l < input.lessons.length; l++) {
      if (_lTeacher[l] >= 0) demand[_lTeacher[l]] += _need[l];
    }
    int capacity(int t) {
      var free = 0;
      for (var s = 0; s < _nS; s++) {
        if (_avail[t][s] == 1 && _tBusy[t][s] == 0) free++;
      }
      return min(_tMax[t] - _tLoad[t], free) - demand[t];
    }

    final open = [
      for (var l = 0; l < input.lessons.length; l++)
        if (_lTeacher[l] < 0 && _lClass[l] >= 0) l,
    ]..sort((a, b) => _need[b].compareTo(_need[a]));
    for (final l in open) {
      var best = -1, bestCap = -1 << 30;
      for (var t = 0; t < _nT; t++) {
        if (!input.teachers[t].branches.contains(_lBranch[l])) continue;
        final cap = capacity(t);
        if (cap > bestCap) {
          best = t;
          bestCap = cap;
        }
      }
      if (best < 0) {
        if (_need[l] > 0) {
          _conflicts.add(
            Conflict(
              ConflictKind.noTeacherForBranch,
              classroomName: _cName(_lClass[l]),
              branch: _lBranch[l],
              need: _need[l],
            ),
          );
        }
        continue;
      }
      _lTeacher[l] = best;
      demand[best] += _need[l];
    }
  }

  /// Talep > müsaitlik / üst sınır / şablon: aksiyon alınabilir rapor.
  void _diagnose() {
    final demand = Int32List(_nT);
    final classDemand = Int32List(_nC);
    for (var l = 0; l < input.lessons.length; l++) {
      if (_lClass[l] < 0) continue;
      classDemand[_lClass[l]] += input.lessons[l].weeklyHours;
      if (_lTeacher[l] >= 0) demand[_lTeacher[l]] += _need[l];
    }
    for (var t = 0; t < _nT; t++) {
      final total = demand[t] + _tLoad[t];
      if (total == 0) continue;
      var avail = 0;
      for (var s = 0; s < _nS; s++) {
        avail += _avail[t][s];
      }
      if (total > _tMax[t]) {
        _conflicts.add(
          Conflict(
            ConflictKind.teacherOverMax,
            teacherName: _tName(t),
            need: total,
            have: _tMax[t],
          ),
        );
      }
      if (total > avail) {
        _conflicts.add(
          Conflict(
            ConflictKind.teacherOverAvailability,
            teacherName: _tName(t),
            need: total,
            have: avail,
          ),
        );
      }
    }
    for (var c = 0; c < _nC; c++) {
      if (classDemand[c] > _nS) {
        _conflicts.add(
          Conflict(
            ConflictKind.classroomOverSlots,
            classroomName: _cName(c),
            need: classDemand[c],
            have: _nS,
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------
  // Yerleştirme
  // ---------------------------------------------------------------------

  void _push(int t, int c, int s, int r, String branch, int l) {
    _eT.add(t);
    _eC.add(c);
    _eS.add(s);
    _eR.add(r);
    _eB.add(branch);
    _eL.add(l);
    _tBusy[t][s]++;
    _cBusy[c][s]++;
    if (r >= 0) _rBusy[r][s]++;
    _tLoad[t]++;
  }

  void _pop() {
    final t = _eT.removeLast(), c = _eC.removeLast(), s = _eS.removeLast();
    final r = _eR.removeLast(), l = _eL.removeLast();
    _eB.removeLast();
    _tBusy[t][s]--;
    _cBusy[c][s]--;
    if (r >= 0) _rBusy[r][s]--;
    _tLoad[t]--;
    if (l >= 0) {
      _need[l]++;
      _lDay[l][input.slots[s].day]--;
    }
  }

  void _resetTo(int length) {
    while (_eT.length > length) {
      _pop();
    }
  }

  /// Sınıfın [s] saatinde kullanacağı derslik: kendi dersliği (doluysa
  /// -2 = olmaz), yoksa boş bir ortak derslik, o da yoksa -1 (dersliksiz).
  int _roomFor(int c, int s) {
    final home = _homeRoom[c];
    if (home >= 0) return _rBusy[home][s] == 0 ? home : -2;
    final size = input.classrooms[c].size;
    for (final r in _floatingRooms) {
      final cap = input.rooms[r].capacity;
      if (_rBusy[r][s] == 0 && (cap == null || size == 0 || cap >= size)) {
        return r;
      }
    }
    return -1;
  }

  bool _legal(int l, int s) {
    final t = _lTeacher[l], c = _lClass[l];
    return _avail[t][s] == 1 &&
        _tBusy[t][s] == 0 &&
        _cBusy[c][s] == 0 &&
        _tLoad[t] < _tMax[t] &&
        _roomFor(c, s) != -2;
  }

  int _legalCount(int l) {
    var n = 0;
    for (var s = 0; s < _nS; s++) {
      if (_legal(l, s)) n++;
    }
    return n;
  }

  /// Değer sıralaması: yumuşak kısıtlara göre ucuz saat önce.
  double _cost(int l, int s) {
    final t = _lTeacher[l];
    final d = input.slots[s].day;
    var cost = _lDay[l][d] * 2.0;
    if (_lDay[l][d] >= input.lessons[l].maxPerDay) cost += 10;
    if (input.slots[s].start >= 12 * 60 &&
        numericBranches.contains(_lBranch[l])) {
      cost += afternoonPenalty;
    }
    final p = _prevSlot[s], n = _nextSlot[s];
    final adjacent =
        (p >= 0 && _tBusy[t][p] > 0) || (n >= 0 && _tBusy[t][n] > 0);
    if (adjacent) {
      cost -= 3;
    } else {
      // Öğretmenin o gün başka dersi varsa pencere açılabilir.
      for (var x = 0; x < _nS; x++) {
        if (input.slots[x].day == d && _tBusy[t][x] > 0) {
          cost += 1;
          break;
        }
      }
    }
    return cost + _rng.nextDouble() * 0.5;
  }

  void _placeAt(int l, int s) {
    final c = _lClass[l];
    final r = _roomFor(c, s);
    _push(_lTeacher[l], c, s, r < 0 ? -1 : r, _lBranch[l], l);
    _need[l]--;
    _lDay[l][input.slots[s].day]++;
  }

  bool _search() {
    if (++_nodes > _maxNodes || _sw.elapsedMilliseconds > _constructMs) {
      _aborted = true;
      return false;
    }
    var pick = -1, pickSlack = 1 << 30;
    for (var l = 0; l < _need.length; l++) {
      if (_need[l] <= 0) continue;
      if (_lTeacher[l] < 0) continue; // öğretmensiz: raporlanır
      final cnt = _legalCount(l);
      if (cnt < _need[l]) return false; // forward checking
      final slack = cnt - _need[l];
      if (slack < pickSlack) {
        pick = l;
        pickSlack = slack;
      }
    }
    if (pick < 0) return true;

    final candidates = [
      for (var s = 0; s < _nS; s++)
        if (_legal(pick, s)) (s, _cost(pick, s)),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    for (final (s, _) in candidates) {
      _placeAt(pick, s);
      final placed = _eT.length - _lockedCount;
      if (placed > _bestPlaced) {
        _bestPlaced = placed;
        _bestSnapshot = _snapshot();
      }
      if (_search()) return true;
      _pop();
      if (_aborted) return false;
    }
    return false;
  }

  List<int> _snapshot() => [
    for (var i = _lockedCount; i < _eT.length; i++) ...[_eL[i], _eS[i], _eR[i]],
  ];

  void _restore(List<int> snap) {
    for (var k = 0; k < snap.length; k += 3) {
      final l = snap[k], s = snap[k + 1], r = snap[k + 2];
      _push(_lTeacher[l], _lClass[l], s, r, _lBranch[l], l);
      _need[l]--;
      _lDay[l][input.slots[s].day]++;
    }
  }

  /// Çözüm yoksa: MRV sırasıyla yerleşebilen her saati koy, kalanı bırak.
  void _greedy() {
    final dropped = <int>{};
    while (true) {
      var pick = -1, pickSlack = 1 << 30;
      for (var l = 0; l < _need.length; l++) {
        if (_need[l] <= 0 || _lTeacher[l] < 0 || dropped.contains(l)) continue;
        final cnt = _legalCount(l);
        if (cnt == 0) {
          dropped.add(l);
          continue;
        }
        final slack = cnt - _need[l];
        if (slack < pickSlack) {
          pick = l;
          pickSlack = slack;
        }
      }
      if (pick < 0) return;
      var best = -1;
      var bestCost = double.infinity;
      for (var s = 0; s < _nS; s++) {
        if (!_legal(pick, s)) continue;
        final c = _cost(pick, s);
        if (c < bestCost) {
          best = s;
          bestCost = c;
        }
      }
      _placeAt(pick, best);
    }
  }

  void _explainUnassigned() {
    for (var l = 0; l < _need.length; l++) {
      if (_need[l] <= 0 || _lTeacher[l] < 0) continue;
      final t = _lTeacher[l], c = _lClass[l];
      var common = 0;
      for (var s = 0; s < _nS; s++) {
        if (_avail[t][s] == 1 && _tBusy[t][s] == 0 && _cBusy[c][s] == 0) {
          common++;
        }
      }
      _conflicts.add(
        Conflict(
          ConflictKind.noCommonSlot,
          teacherName: _tName(t),
          classroomName: _cName(c),
          branch: _lBranch[l],
          need: _need[l],
          have: common,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------
  // İyileştirme (simulated annealing)
  // ---------------------------------------------------------------------

  int _score() => _model.score(_eT, _eC, _eS, _eB);

  void _move(int i, int s, int r) {
    final t = _eT[i], c = _eC[i], old = _eS[i], oldR = _eR[i];
    _tBusy[t][old]--;
    _cBusy[c][old]--;
    if (oldR >= 0) _rBusy[oldR][old]--;
    _tBusy[t][s]++;
    _cBusy[c][s]++;
    if (r >= 0) _rBusy[r][s]++;
    _eS[i] = s;
    _eR[i] = r;
  }

  /// [i] dersini [s] saatine taşımak mümkünse derslik (≥ -1), değilse -2.
  int _canMove(int i, int s) {
    final t = _eT[i], c = _eC[i];
    if (s == _eS[i] || _avail[t][s] == 0) return -2;
    if (_tBusy[t][s] > 0 || _cBusy[c][s] > 0) return -2;
    return _roomFor(c, s);
  }

  void _anneal() {
    final movable = _eT.length - _lockedCount;
    if (movable < 1 || _nS < 2) return;
    final maxIter = min(60000, 300 * movable);
    var cur = _score();
    var best = cur;
    var bestS = List<int>.of(_eS);
    var bestR = List<int>.of(_eR);
    const t0 = 2.0, t1 = 0.02;
    for (var it = 0; it < maxIter && cur > 0; it++) {
      if (_sw.elapsedMilliseconds > input.timeLimitMs) break;
      final temp = t0 * pow(t1 / t0, it / maxIter);
      final i = _lockedCount + _rng.nextInt(movable);
      if (_rng.nextBool()) {
        final s = _rng.nextInt(_nS);
        final r = _canMove(i, s);
        if (r == -2) continue;
        final oldS = _eS[i], oldR = _eR[i];
        _move(i, s, r);
        final next = _score();
        if (next <= cur || _rng.nextDouble() < exp((cur - next) / temp)) {
          cur = next;
        } else {
          _move(i, oldS, oldR);
        }
      } else {
        final j = _lockedCount + _rng.nextInt(movable);
        if (j == i || _eC[j] != _eC[i] || _eT[j] == _eT[i]) continue;
        final si = _eS[i], sj = _eS[j], ri = _eR[i], rj = _eR[j];
        final ti = _eT[i], tj = _eT[j];
        if (_avail[ti][sj] == 0 || _avail[tj][si] == 0) continue;
        if (_tBusy[ti][sj] > 0 || _tBusy[tj][si] > 0) continue;
        if (!_swap(i, j)) continue;
        final next = _score();
        if (next <= cur || _rng.nextDouble() < exp((cur - next) / temp)) {
          cur = next;
        } else {
          _setPair(i, j, si, sj, ri, rj);
        }
      }
      if (cur < best) {
        best = cur;
        bestS = List<int>.of(_eS);
        bestR = List<int>.of(_eR);
      }
    }
    // En iyi duruma dön.
    for (var i = _lockedCount; i < _eT.length; i++) {
      if (_eS[i] != bestS[i] || _eR[i] != bestR[i]) {
        _detach(i);
      }
    }
    for (var i = _lockedCount; i < _eT.length; i++) {
      if (_eS[i] == -1) {
        _eS[i] = bestS[i];
        _eR[i] = bestR[i];
        _attach(i);
      }
    }
  }

  void _detach(int i) {
    _tBusy[_eT[i]][_eS[i]]--;
    _cBusy[_eC[i]][_eS[i]]--;
    if (_eR[i] >= 0) _rBusy[_eR[i]][_eS[i]]--;
    _eS[i] = -1;
  }

  void _attach(int i) {
    _tBusy[_eT[i]][_eS[i]]++;
    _cBusy[_eC[i]][_eS[i]]++;
    if (_eR[i] >= 0) _rBusy[_eR[i]][_eS[i]]++;
  }

  /// Aynı sınıfın iki dersinin saatlerini değiştirir, derslikleri yeniden
  /// seçer. Olmuyorsa eski hâline döner ve false verir.
  bool _swap(int i, int j) {
    final si = _eS[i], sj = _eS[j], ri = _eR[i], rj = _eR[j];
    _setPair(i, j, sj, si, -1, -1);
    final nri = _roomFor(_eC[i], _eS[i]);
    if (nri != -2) _setRoom(i, nri);
    final nrj = nri == -2 ? -2 : _roomFor(_eC[j], _eS[j]);
    if (nrj != -2) _setRoom(j, nrj);
    if (nri == -2 || nrj == -2) {
      _setPair(i, j, si, sj, ri, rj);
      return false;
    }
    return true;
  }

  void _setPair(int i, int j, int si, int sj, int ri, int rj) {
    _detach(i);
    _detach(j);
    _eS[i] = si;
    _eS[j] = sj;
    _eR[i] = ri;
    _eR[j] = rj;
    _attach(i);
    _attach(j);
  }

  void _setRoom(int k, int r) {
    if (_eR[k] == r) return;
    if (_eR[k] >= 0) _rBusy[_eR[k]][_eS[k]]--;
    _eR[k] = r;
    if (r >= 0) _rBusy[r][_eS[k]]++;
  }
}
