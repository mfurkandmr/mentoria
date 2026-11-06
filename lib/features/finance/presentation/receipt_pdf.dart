import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:share_plus/share_plus.dart';

import '../../../core/i18n/i18n.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/common.dart';
import '../../schedule_generator/presentation/schedule_export.dart'
    show jpegPagesToPdf;
import '../data/finance_repository.dart';

/// Makbuzda gösterilenler.
class ReceiptDoc {
  const ReceiptDoc({
    required this.number,
    required this.date,
    required this.amount,
    required this.lines,
    this.isRefund = false,
    this.orgName,
    this.payer,
    this.studentName,
    this.title,
    this.method,
    this.accountName,
    this.remaining,
    this.note,
  });

  final String? number;
  final DateTime date;
  final double amount;
  final bool isRefund;
  final String? orgName;
  final String? payer;
  final String? studentName;

  /// Ücret kalemi ya da gelir türü.
  final String? title;
  final PaymentMethod? method;
  final String? accountName;

  /// Satırlar: açıklama → tutar (ör. "Vade 5 Kasım 2026" → 4.000).
  final List<(String, double)> lines;

  /// Bu makbuzdan sonra kalan borç.
  final double? remaining;
  final String? note;
}

/// Ücret makbuzu (tahsilat ya da iade).
ReceiptDoc feeReceiptDoc(
  StudentFee fee,
  Receipt r, {
  String? orgName,
  String? accountName,
}) {
  final due = {for (final i in fee.installments) i.id: i.dueOn};
  return ReceiptDoc(
    number: r.number,
    date: r.date,
    amount: r.amount,
    isRefund: r.isRefund,
    orgName: orgName,
    payer: fee.payerName,
    studentName: fee.studentName,
    title: fee.title,
    method: r.method,
    accountName: accountName,
    remaining: fee.remaining,
    note: r.note,
    lines: [
      for (final p in r.lines)
        (
          r.isRefund
              ? tr('Kayıt iptali iadesi')
              : due[p.installmentId] == null
              ? tr('Taksit')
              : tr('Vade {d} taksidi', {
                  'd': formatLongDate(due[p.installmentId]!),
                }),
          p.amount,
        ),
    ],
  );
}

ReceiptDoc incomeReceiptDoc(
  FinanceIncome i, {
  String? orgName,
  String? accountName,
}) => ReceiptDoc(
  number: i.receiptNo,
  date: i.receivedOn,
  amount: i.amount,
  orgName: orgName,
  payer: i.payerName,
  studentName: i.studentName,
  title: i.category.label,
  method: i.method,
  accountName: accountName,
  note: i.note,
  lines: [(i.note ?? i.category.label, i.amount)],
);

Future<void> shareReceipt(BuildContext context, ReceiptDoc doc) async {
  final messenger = ScaffoldMessenger.of(context);
  final font = Theme.of(context).textTheme.bodyMedium?.fontFamily;
  try {
    final pdf = await renderReceiptPdf(doc, fontFamily: font);
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            pdf,
            mimeType: 'application/pdf',
            name: 'makbuz-${doc.number ?? 'kayit'}.pdf',
          ),
        ],
      ),
    );
  } catch (_) {
    messenger.showSnackBar(
      SnackBar(content: Text(tr('Dosya hazırlanamadı. Tekrar dene.'))),
    );
  }
}

/// Snackbar'da "Makbuz" düğmesi.
void offerReceipt(BuildContext context, String message, ReceiptDoc? doc) {
  final messenger = ScaffoldMessenger.of(context);
  if (doc == null) {
    showMessage(context, message);
    return;
  }
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      action: SnackBarAction(
        label: tr('Makbuz'),
        onPressed: () => shareReceipt(context, doc),
      ),
    ),
  );
}

/// A4 dikey sayfanın üst yarısına makbuz (alt yarı kurum kopyası).
Future<Uint8List> renderReceiptPdf(ReceiptDoc d, {String? fontFamily}) async {
  const w = 1240, h = 1754;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, w + 0.0, h + 0.0),
    Paint()..color = Colors.white,
  );
  double text(
    String s,
    Offset at, {
    double size = 22,
    FontWeight weight = FontWeight.w500,
    double width = 1100,
    Color color = Colors.black87,
    TextAlign align = TextAlign.left,
  }) {
    final p = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: size,
          fontWeight: weight,
          color: color,
          fontFamily: fontFamily,
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
      maxLines: 3,
      ellipsis: '…',
    )..layout(minWidth: width, maxWidth: width);
    p.paint(canvas, at);
    return p.height;
  }

  void copy(double top, String label) {
    const m = 80.0;
    var y = top;
    if (d.orgName != null) {
      text(d.orgName!, Offset(m, y), size: 30, weight: FontWeight.w800);
    }
    text(
      label,
      Offset(m, y + 6),
      size: 18,
      color: Colors.black45,
      align: TextAlign.right,
      width: w - 2 * m,
    );
    y += 56;
    text(
      d.isRefund ? tr('İade makbuzu') : tr('Tahsilat makbuzu'),
      Offset(m, y),
      size: 36,
      weight: FontWeight.w800,
    );
    text(
      '${tr('No')}: ${d.number ?? '—'}\n${formatLongDate(d.date)}',
      Offset(m, y),
      size: 22,
      align: TextAlign.right,
      width: w - 2 * m,
    );
    y += 80;
    final who = [
      if (d.payer != null) '${tr('Ödeyen')}: ${d.payer}',
      if (d.studentName != null) '${tr('Öğrenci')}: ${d.studentName}',
      if (d.title != null) '${tr('Kalem')}: ${d.title}',
    ];
    for (final l in who) {
      text(l, Offset(m, y));
      y += 34;
    }
    y += 10;
    final line = Paint()..color = const Color(0xFFCCCCCC);
    canvas.drawLine(Offset(m, y), Offset(w - m, y), line);
    y += 12;
    for (final (label, amount) in d.lines.take(8)) {
      text(label, Offset(m, y), width: 800);
      text(
        formatMoney(amount),
        Offset(m, y),
        align: TextAlign.right,
        width: w - 2 * m,
      );
      y += 34;
    }
    canvas.drawLine(Offset(m, y + 4), Offset(w - m, y + 4), line);
    y += 16;
    text(tr('Toplam'), Offset(m, y), size: 28, weight: FontWeight.w800);
    text(
      formatMoney(d.amount),
      Offset(m, y),
      size: 28,
      weight: FontWeight.w800,
      align: TextAlign.right,
      width: w - 2 * m,
    );
    y += 50;
    text(
      [
        if (d.method != null) d.method!.label,
        if (d.accountName != null) d.accountName!,
        if (d.remaining != null)
          tr('Kalan borç: {v}', {'v': formatMoney(d.remaining!)}),
      ].join('  ·  '),
      Offset(m, y),
      size: 20,
    );
    y += 40;
    if (d.note != null && d.note!.isNotEmpty) {
      text(d.note!, Offset(m, y), size: 18, color: Colors.black54);
      y += 34;
    }
    text(
      tr('Bu belge tahsilat bilgisidir; fatura yerine geçmez.'),
      Offset(m, top + 700),
      size: 16,
      color: Colors.black45,
    );
    text(
      tr('İmza / kaşe'),
      Offset(m, top + 700),
      size: 16,
      color: Colors.black45,
      align: TextAlign.right,
      width: w - 2 * m,
    );
  }

  copy(60, tr('Veli nüshası'));
  // Kesme çizgisi.
  final dash = Paint()
    ..color = const Color(0xFFAAAAAA)
    ..strokeWidth = 2;
  for (var x = 40.0; x < w - 40; x += 24) {
    canvas.drawLine(Offset(x, h / 2), Offset(x + 12, h / 2), dash);
  }
  copy(h / 2 + 60, tr('Kurum nüshası'));

  final image = await recorder.endRecording().toImage(w, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  final rgba = img.Image.fromBytes(
    width: w,
    height: h,
    bytes: data!.buffer,
    numChannels: 4,
  );
  return jpegPagesToPdf([(img.encodeJpg(rgba, quality: 88), w, h)]);
}
