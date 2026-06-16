/// تنسيق الوقت للرسائل بدون ثواني نهائياً
/// يحل مشكلة "منذ 5205- ثانية"
String formatMessageTime(DateTime date) {
  final localDate = date.toLocal();
  final now = DateTime.now();
  final diff = now.difference(localDate);

  if (diff.inMinutes < 1) {
    return 'الآن';
  } else if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    if (m == 1) return 'منذ دقيقة';
    if (m == 2) return 'منذ دقيقتين';
    if (m <= 10) return 'منذ $m دقائق';
    return 'منذ $m دقيقة';
  } else if (diff.inHours < 24) {
    final h = diff.inHours;
    if (h == 1) return 'منذ ساعة';
    if (h == 2) return 'منذ ساعتين';
    if (h <= 10) return 'منذ $h ساعات';
    return 'منذ $h ساعة';
  } else if (diff.inDays < 7) {
    final d = diff.inDays;
    if (d == 1) return 'منذ يوم';
    if (d == 2) return 'منذ يومين';
    if (d <= 10) return 'منذ $d أيام';
    return 'منذ $d يوم';
  } else if (diff.inDays < 30) {
    final w = (diff.inDays / 7).floor();
    if (w == 1) return 'منذ أسبوع';
    if (w == 2) return 'منذ أسبوعين';
    if (w <= 10) return 'منذ $w أسابيع';
    return 'منذ $w أسبوع';
  } else if (diff.inDays < 365) {
    final mo = (diff.inDays / 30).floor();
    if (mo == 1) return 'منذ شهر';
    if (mo == 2) return 'منذ شهرين';
    if (mo <= 10) return 'منذ $mo أشهر';
    return 'منذ $mo شهر';
  } else {
    final y = (diff.inDays / 365).floor();
    if (y == 1) return 'منذ سنة';
    if (y == 2) return 'منذ سنتين';
    if (y <= 10) return 'منذ $y سنوات';
    return 'منذ $y سنة';
  }
}
