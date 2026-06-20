import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String id;
  final String username;
  final String? email;
  final String? avatarUrl;
  final String? bio;
  final String? whatsapp;
  final DateTime? birthDate;
  final String? zodiac;
  final String role;
  final bool isOnline;
  final bool isBlocked;
  final DateTime? lastSeen;
  final DateTime createdAt;

  // legacy - للتوافق فقط
  final bool isMod;
  final int followersCount;
  final int followingCount;
  final int postsCount;

  const UserModel({
    required this.id,
    required this.username,
    this.email,
    this.avatarUrl,
    this.bio,
    this.whatsapp,
    this.birthDate,
    this.zodiac,
    this.role = 'user',
    this.isOnline = false,
    this.isBlocked = false,
    this.lastSeen,
    required this.createdAt,
    this.isMod = false,
    this.followersCount = 0,
    this.followingCount = 0,
    this.postsCount = 0,
  });

  bool get isAdmin => role == 'admin';

  int? get age {
    final b = birthDate;
    if (b == null) return null;
    final now = DateTime.now();
    int a = now.year - b.year;
    if (now.month < b.month || (now.month == b.month && now.day < b.day)) a--;
    return a;
  }

  String? get zodiacResolved {
    if (zodiac != null && zodiac!.isNotEmpty) return zodiac;
    final b = birthDate;
    if (b == null) return null;
    final d = b.day; final m = b.month;
    if ((m == 3 && d >= 21) || (m == 4 && d <= 19)) return 'الحمل';
    if ((m == 4 && d >= 20) || (m == 5 && d <= 20)) return 'الثور';
    if ((m == 5 && d >= 21) || (m == 6 && d <= 20)) return 'الجوزاء';
    if ((m == 6 && d >= 21) || (m == 7 && d <= 22)) return 'السرطان';
    if ((m == 7 && d >= 23) || (m == 8 && d <= 22)) return 'الأسد';
    if ((m == 8 && d >= 23) || (m == 9 && d <= 22)) return 'العذراء';
    if ((m == 9 && d >= 23) || (m == 10 && d <= 22)) return 'الميزان';
    if ((m == 10 && d >= 23) || (m == 11 && d <= 21)) return 'العقرب';
    if ((m == 11 && d >= 22) || (m == 12 && d <= 21)) return 'القوس';
    if ((m == 12 && d >= 22) || (m == 1 && d <= 19)) return 'الجدي';
    if ((m == 1 && d >= 20) || (m == 2 && d <= 18)) return 'الدلو';
    return 'الحوت';
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
    return null;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? 'مستخدم',
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      whatsapp: json['whatsapp'] as String?,
      birthDate: _parseDate(json['birth_date']),
      zodiac: json['zodiac'] as String?,
      role: json['role'] as String? ?? 'user',
      isOnline: json['is_online'] as bool? ?? false,
      isBlocked: json['is_blocked'] as bool? ?? false,
      lastSeen: _parseDate(json['last_seen']),
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      isMod: json['is_mod'] as bool? ?? false,
      followersCount: (json['followers_count'] as num?)?.toInt() ?? 0,
      followingCount: (json['following_count'] as num?)?.toInt() ?? 0,
      postsCount: (json['posts_count'] as num?)?.toInt() ?? 0,
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel.fromJson(map);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'avatar_url': avatarUrl,
      'bio': bio,
      'whatsapp': whatsapp,
      'birth_date': birthDate?.toIso8601String().split('T').first,
      'zodiac': zodiac,
      'role': role,
      'is_online': isOnline,
      'is_blocked': isBlocked,
      'last_seen': lastSeen?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? username,
    String? email,
    bool clearEmail = false,
    String? avatarUrl,
    bool clearAvatar = false,
    String? bio,
    bool clearBio = false,
    String? whatsapp,
    bool clearWhatsapp = false,
    DateTime? birthDate,
    bool clearBirthDate = false,
    String? zodiac,
    bool clearZodiac = false,
    String? role,
    bool? isOnline,
    bool? isBlocked,
    DateTime? lastSeen,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      email: clearEmail ? null : email ?? this.email,
      avatarUrl: clearAvatar ? null : avatarUrl ?? this.avatarUrl,
      bio: clearBio ? null : bio ?? this.bio,
      whatsapp: clearWhatsapp ? null : whatsapp ?? this.whatsapp,
      birthDate: clearBirthDate ? null : birthDate ?? this.birthDate,
      zodiac: clearZodiac ? null : zodiac ?? this.zodiac,
      role: role ?? this.role,
      isOnline: isOnline ?? this.isOnline,
      isBlocked: isBlocked ?? this.isBlocked,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt ?? this.createdAt,
      isMod: isMod,
      followersCount: followersCount,
      followingCount: followingCount,
      postsCount: postsCount,
    );
  }

  @override
  List<Object?> get props => [
    id, username, email, avatarUrl, bio, whatsapp,
    birthDate, zodiac, role, isOnline, isBlocked, lastSeen, createdAt
  ];

  @override
  String toString() => 'UserModel(id: $id, username: $username, role: $role)';
}
