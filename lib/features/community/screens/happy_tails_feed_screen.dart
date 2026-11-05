import 'package:flutter/material.dart';
import '../../../core/models/community_post_model.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/app_network_image.dart';

class HappyTailsFeedScreen extends StatefulWidget {
  const HappyTailsFeedScreen({super.key});

  @override
  State<HappyTailsFeedScreen> createState() => _HappyTailsFeedScreenState();
}

class _HappyTailsFeedScreenState extends State<HappyTailsFeedScreen> {
  final List<CommunityPost> _posts = [
    const CommunityPost(
      id: 'p-1',
      authorName: 'Nadia Rahman',
      authorLocation: 'Gulshan, Dhaka',
      authorAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80',
      petName: 'Barnaby (now Simba)',
      title: '1 Year Since Adopting Our Gentle Senior!',
      story: 'Adopting a senior dog was the best decision our family ever made. Barnaby has brought endless joy, slow peaceful walks, and unconditional warmth to our home. Thank you AdoptMatch!',
      imageUrl: 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?auto=format&fit=crop&w=800&q=80',
      likesCount: 128,
      commentsCount: 24,
      isLiked: true,
      timeAgo: '2 hours ago',
      tags: ['SeniorRescue', 'AdoptDontShop', 'DhakaDogs'],
    ),
    const CommunityPost(
      id: 'p-2',
      authorName: 'Tanvir Hossain',
      authorLocation: 'Uttara, Dhaka',
      authorAvatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=200&q=80',
      petName: 'Luna & Leo',
      title: 'Double Trouble, Double Love!',
      story: 'Initially we only planned on fostering one kitten, but seeing how closely bonded they were with their brother, we adopted both! They sleep in sync every afternoon.',
      imageUrl: 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?auto=format&fit=crop&w=800&q=80',
      likesCount: 95,
      commentsCount: 16,
      isLiked: false,
      timeAgo: '1 day ago',
      tags: ['FosterFailure', 'CatLoversBD', 'BondedPair'],
    ),
  ];

  void _openCreatePostModal() {
    final petCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    final storyCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Share Your Happy Tail',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Inspire fellow community members with your rescue pet\'s journey.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: petCtrl,
                  decoration: const InputDecoration(labelText: 'Pet Name', hintText: 'e.g. Milo'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Post Title', hintText: 'Our first month together!'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: storyCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Your Story', hintText: 'Share a heartfelt memory...'),
                ),
                const SizedBox(height: 20),
                CustomButton(
                  text: 'Publish Story',
                  backgroundColor: const Color(0xFFE05626),
                  onPressed: () {
                    if (titleCtrl.text.isNotEmpty) {
                      setState(() {
                        _posts.insert(
                          0,
                          CommunityPost(
                            id: 'p-${DateTime.now().millisecondsSinceEpoch}',
                            authorName: 'Elias Ahmed',
                            authorLocation: 'Banani, Dhaka',
                            authorAvatar: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=200&q=80',
                            petName: petCtrl.text.isNotEmpty ? petCtrl.text : 'My Pet',
                            title: titleCtrl.text,
                            story: storyCtrl.text,
                            imageUrl: 'https://images.unsplash.com/photo-1552053831-71594a27632d?auto=format&fit=crop&w=800&q=80',
                            timeAgo: 'Just now',
                            tags: ['AdoptMatch', 'HappyTails'],
                          ),
                        );
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('🎉 Your Happy Tail was published!')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      petCtrl.dispose();
      titleCtrl.dispose();
      storyCtrl.dispose();
    });
  }

  void _showPetTagDetail(BuildContext context, String petName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.pets, color: Color(0xFFE05626), size: 22),
            SizedBox(width: 8),
            Text(
              'Adopted Pet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Full Registered Name & History:',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFEDD5)),
              ),
              child: Text(
                petName,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFE05626)),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This pet was successfully adopted and happily placed with their forever family through AdoptMatch.',
              style: TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close', style: TextStyle(color: Color(0xFFE05626), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const brandOrange = Color(0xFFE05626);
    const rose = Color(0xFFE11D48);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Happy Tails Community'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            onPressed: _openCreatePostModal,
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _posts.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final post = _posts[index];
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author row with safe badge overflow handling
                Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: NetworkImage(post.authorAvatar),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.authorName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Color(0xFF1E293B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${post.authorLocation} • ${post.timeAgo}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Tag/Badge Overflow Handling: max-width 130px, ellipsis & interactive tooltip/tap
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 130),
                        child: Tooltip(
                          message: 'Adopted Pet: ${post.petName}',
                          preferBelow: false,
                          triggerMode: TooltipTriggerMode.tap,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: InkWell(
                            onTap: () => _showPetTagDetail(context, post.petName),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFFFEDD5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.pets, size: 12, color: brandOrange),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      post.petName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      softWrap: false,
                                      style: const TextStyle(
                                        color: brandOrange,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Post Image
                SizedBox(
                  height: 240,
                  width: double.infinity,
                  child: AppNetworkImage(
                    imageUrl: post.imageUrl,
                    fit: BoxFit.cover,
                  ),
                ),

                // Post Content
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.title,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        post.story,
                        style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 12),

                      // Tags
                      Wrap(
                        spacing: 6,
                        children: post.tags.map((t) => Text('#$t', style: const TextStyle(color: Color(0xFF6366F1), fontSize: 12, fontWeight: FontWeight.w600))).toList(),
                      ),
                      const SizedBox(height: 12),

                      // Like & Comment buttons
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                final isLiked = !post.isLiked;
                                final newCount = isLiked ? post.likesCount + 1 : post.likesCount - 1;
                                _posts[index] = post.copyWith(isLiked: isLiked, likesCount: newCount);
                              });
                            },
                            child: Row(
                              children: [
                                Icon(
                                  post.isLiked ? Icons.favorite : Icons.favorite_border,
                                  color: post.isLiked ? rose : const Color(0xFF64748B),
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${post.likesCount}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: post.isLiked ? rose : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Row(
                            children: [
                              const Icon(Icons.chat_bubble_outline, size: 18, color: Color(0xFF64748B)),
                              const SizedBox(width: 6),
                              Text(
                                '${post.commentsCount}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.share_outlined, size: 20, color: Color(0xFF64748B)),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Story link copied!')),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
