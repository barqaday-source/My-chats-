class RoomModel {
  final String id;
  final String name;
  final String? description;
  final String? bio;
  final String? backgroundUrl;
  final String? imageUrl;
  final String ownerId;
  final String ownerName;
  final String? ownerAvatar;
  final List<String> members;
  final bool isOfficial;
  final bool isLocked;
  final bool isApproved;
  final bool isFollowEnabled;
  final int onlineCount;
  final int memberCount;
  final int followersCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  RoomModel({
    required this.id,
    required this.name,
    this.description,
    this.bio,
    this.backgroundUrl,
    this.imageUrl,
    required this.ownerId,
    required this.ownerName,
    this.ownerAvatar,
    this.members = const [],
    this.isOfficial = false,
    this.isLocked = false,
    this.isApproved = true,
    this.isFollowEnabled = true,
    this.onlineCount = 0,
    this.memberCount = 0,
    this.followersCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    return RoomModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      bio: json['bio'] as String?,
      backgroundUrl: json['background_url'] as String?,
      imageUrl: json['image_url'] as String?,
      ownerId: json['owner_id'] as String,
      ownerName: json['owner_name'] as String,
      ownerAvatar: json['owner_avatar'] as String?,
      members: json['members']!= null
        ? List<String>.from(json['members'] as List)
          : [],
      isOfficial: json['is_official'] as bool?? false,
      isLocked: json['is_locked'] as bool?? false,
      isApproved: json['is_approved'] as bool?? true,
      isFollowEnabled: json['is_follow_enabled'] as bool?? true,
      onlineCount: json['online_count'] as int?? 0,
      memberCount: json['member_count'] as int?? 0,
      followersCount: json['followers_count'] as int?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  // التعديل: لا نرسل الحقول اللي Supabase يولدها
  Map<String, dynamic> toJson() {
    return {
      // 'id': id, // محذوف
      'name': name,
      'description': description,
      'bio': bio,
      'background_url': backgroundUrl,
      'image_url': imageUrl,
      'owner_id': ownerId,
      'owner_name': ownerName,
      'owner_avatar': ownerAvatar,
      'members': members,
      'is_official': isOfficial,
      'is_locked': isLocked,
      // 'is_approved': isApproved, // محذوف - default false
      'is_follow_enabled': isFollowEnabled,
      // 'online_count': onlineCount, // محذوف - default 0
      // 'member_count': memberCount, // محذوف - default 1
      'followers_count': followersCount,
      // 'created_at': createdAt.toIso8601String(), // محذوف
      // 'updated_at': updatedAt.toIso8601String(), // محذوف
    };
  }

  RoomModel copyWith({
    String? id,
    String? name,
    String? description,
    String? bio,
    String? backgroundUrl,
    String? imageUrl,
    String? ownerId,
    String? ownerName,
    String? ownerAvatar,
    List<String>? members,
    bool? isOfficial,
    bool? isLocked,
    bool? isApproved,
    bool? isFollowEnabled,
    int? onlineCount,
    int? memberCount,
    int? followersCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RoomModel(
      id: id?? this.id,
      name: name?? this.name,
      description: description?? this.description,
      bio: bio?? this.bio,
      backgroundUrl: backgroundUrl?? this.backgroundUrl,
      imageUrl: imageUrl?? this.imageUrl,
      ownerId: ownerId?? this.ownerId,
      ownerName: ownerName?? this.ownerName,
      ownerAvatar: ownerAvatar?? this.ownerAvatar,
      members: members?? this.members,
      isOfficial: isOfficial?? this.isOfficial,
      isLocked: isLocked?? this.isLocked,
      isApproved: isApproved?? this.isApproved,
      isFollowEnabled: isFollowEnabled?? this.isFollowEnabled,
      onlineCount: onlineCount?? this.onlineCount,
      memberCount: memberCount?? this.memberCount,
      followersCount: followersCount?? this.followersCount,
      createdAt: createdAt?? this.createdAt,
      updatedAt: updatedAt?? this.updatedAt,
    );
  }
}
