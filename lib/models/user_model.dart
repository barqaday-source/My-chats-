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
  final bool isMod;
  final DateTime? lastSeen;
  final DateTime createdAt;

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
    this.isMod = false,
    this.lastSeen,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?? '',
      username: json['username']?? 'مستخدم',
      email: json['email'],
      avatarUrl: json['avatar_url'],
      bio: json['bio'],
      whatsapp: json['whatsapp'],
      birthDate: json['birth_date']!= null? DateTime.parse(json['birth_date']) : null,
      zodiac: json['zodiac'],
      role: json['role']?? 'user',
      isOnline: json['is_online']?? false,
      isBlocked: json['is_blocked']?? false,
      isMod: json['is_mod']?? false,
      lastSeen: json['last_seen']!= null? DateTime.parse(json['last_seen']) : null,
      createdAt: DateTime.parse(json['created_at']),
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
      'birth_date': birthDate?.toIso8601String(),
      'zodiac': zodiac,
      'role': role,
      'is_online': isOnline,
      'is_blocked': isBlocked,
      'is_mod': isMod,
      'last_seen': lastSeen?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? username,
    String? email,
    String? avatarUrl,
    String? bio,
    String? whatsapp,
    DateTime? birthDate,
    String? zodiac,
    String? role,
    bool? isOnline,
    bool? isBlocked,
    bool? isMod,
    DateTime? lastSeen,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id?? this.id,
      username: username?? this.username,
      email: email?? this.email,
      avatarUrl: avatarUrl?? this.avatarUrl,
      bio: bio?? this.bio,
      whatsapp: whatsapp?? this.whatsapp,
      birthDate: birthDate?? this.birthDate,
      zodiac: zodiac?? this.zodiac,
      role: role?? this.role,
      isOnline: isOnline?? this.isOnline,
      isBlocked: isBlocked?? this.isBlocked,
      isMod: isMod?? this.isMod,
      lastSeen: lastSeen?? this.lastSeen,
      createdAt: createdAt?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id, username, email, avatarUrl, bio, whatsapp, 
    birthDate, zodiac, role, isOnline, isBlocked, isMod, lastSeen, createdAt
  ];
}
