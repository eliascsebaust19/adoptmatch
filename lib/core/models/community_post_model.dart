import 'package:equatable/equatable.dart';

class CommunityPost extends Equatable {
  final String id;
  final String authorName;
  final String authorLocation;
  final String authorAvatar;
  final String petName;
  final String title;
  final String story;
  final String imageUrl;
  final int likesCount;
  final int commentsCount;
  final bool isLiked;
  final String timeAgo;
  final List<String> tags;

  const CommunityPost({
    required this.id,
    required this.authorName,
    required this.authorLocation,
    required this.authorAvatar,
    required this.petName,
    required this.title,
    required this.story,
    required this.imageUrl,
    this.likesCount = 42,
    this.commentsCount = 8,
    this.isLiked = false,
    required this.timeAgo,
    this.tags = const [],
  });

  CommunityPost copyWith({
    String? id,
    String? authorName,
    String? authorLocation,
    String? authorAvatar,
    String? petName,
    String? title,
    String? story,
    String? imageUrl,
    int? likesCount,
    int? commentsCount,
    bool? isLiked,
    String? timeAgo,
    List<String>? tags,
  }) {
    return CommunityPost(
      id: id ?? this.id,
      authorName: authorName ?? this.authorName,
      authorLocation: authorLocation ?? this.authorLocation,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      petName: petName ?? this.petName,
      title: title ?? this.title,
      story: story ?? this.story,
      imageUrl: imageUrl ?? this.imageUrl,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isLiked: isLiked ?? this.isLiked,
      timeAgo: timeAgo ?? this.timeAgo,
      tags: tags ?? this.tags,
    );
  }

  @override
  List<Object?> get props => [
        id,
        authorName,
        authorLocation,
        authorAvatar,
        petName,
        title,
        story,
        imageUrl,
        likesCount,
        commentsCount,
        isLiked,
        timeAgo,
        tags,
      ];
}

