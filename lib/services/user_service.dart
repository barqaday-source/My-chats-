import 'package:supabase_flutter/supabase_flutter.dart';

class UserService {
  final _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> getUserById(String userId) async {
    final response = await _supabase
       .from('profiles')
       .select()
       .eq('id', userId)
       .single();
    return response;
  }

  Future<bool> isFollowing(String followerId, String followingId) async {
    final response = await _supabase
       .from('follows')
       .select()
       .eq('follower_id', followerId)
       .eq('following_id', followingId)
       .maybeSingle();
    return response!= null;
  }

  Future<void> followUser(String followerId, String followingId) async {
    await _supabase.from('follows').insert({
      'follower_id': followerId,
      'following_id': followingId,
    });
  }

  Future<void> unfollowUser(String followerId, String followingId) async {
    await _supabase
       .from('follows')
       .delete()
       .eq('follower_id', followerId)
       .eq('following_id', followingId);
  }
}
