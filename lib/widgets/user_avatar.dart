import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/constants/app_colors.dart';

class UserAvatar extends StatelessWidget {
  final String? url;
  final String name;
  final double size;
  final bool isOnline;

  const UserAvatar({
    super.key,
    this.url,
    required this.name,
    this.size = 40,
    this.isOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CircleAvatar(
          radius: size / 2,
          backgroundColor: AppColors.primary.withOpacity(0.2),
          child: url!= null && url!.isNotEmpty
             ? ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: url!,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => _buildInitial(),
                    errorWidget: (context, url, error) => _buildInitial(),
                  ),
                )
              : _buildInitial(),
        ),
        if (isOnline)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: size * 0.25,
              height: size * 0.25,
              decoration: BoxDecoration(
                color: AppColors.online,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.bgCard, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInitial() {
    return Text(
      name.isNotEmpty? name[0].toUpperCase() : '?',
      style: TextStyle(
        fontFamily: 'Tajawal',
        color: AppColors.primary,
        fontSize: size * 0.4,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
