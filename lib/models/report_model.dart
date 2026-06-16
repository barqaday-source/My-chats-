class ReportModel {
  final String id, reporterId, reporterName, reportedId, reason;
  final String status; // pending, replied
  final String? reply;
  final String? userId;
  final DateTime createdAt;
  ReportModel({required this.id, required this.reporterId, required this.reporterName, required this.reportedId, required this.reason, this.status = 'pending', this.reply, this.userId, required this.createdAt});
  factory ReportModel.fromJson(Map<String, dynamic> j) => ReportModel(id: j['id'], reporterId: j['reporter_id'], reporterName: j['reporter_name'] ?? '', reportedId: j['reported_id'] ?? '', reason: j['reason'] ?? '', status: j['status'] ?? 'pending', reply: j['reply'], userId: j['user_id'], createdAt: DateTime.parse(j['created_at']));
  Map<String, dynamic> toJson() => {'id': id, 'reporter_id': reporterId, 'reporter_name': reporterName, 'reported_id': reportedId, 'reason': reason, 'status': status, 'reply': reply, 'user_id': userId, 'created_at': createdAt.toIso8601String()};
}
