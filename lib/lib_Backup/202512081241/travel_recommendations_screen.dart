import 'package:flutter/material.dart';
import 'theme.dart';
import 'settings_screen.dart';
import 'help_screen.dart';

// مدل پست تور (بیرون از کلاس)
class TravelPost {
  final String imageUrl;
  final String title;
  final String description;
  final String price;
  int likes;
  int comments;
  bool isLiked;

  TravelPost({
    required this.imageUrl,
    required this.title,
    required this.description,
    required this.price,
    required this.likes,
    required this.comments,
    required this.isLiked,
  });
}

// صفحه کامنت‌ها (بیرون از کلاس)
class CommentsScreen extends StatelessWidget {
  final int postId;
  const CommentsScreen({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.cardTheme.color;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Comments'),
        backgroundColor: theme.appBarTheme.backgroundColor,
      ),
      body: ListView.builder(
        itemCount: 5,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: cardColor,
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text('User $index', style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: const Text('Great recommendation! I\'ll book this tour.'),
              trailing: GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Replied!')),
                  );
                },
                child: const Icon(Icons.reply, color: Colors.grey),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              const Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Add a comment...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: AppTheme.primary),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Comment sent!')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// صفحه اصلی فید
class TravelRecommendationsScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onThemeChanged;

  const TravelRecommendationsScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<TravelRecommendationsScreen> createState() => _TravelRecommendationsScreenState();
}

class _TravelRecommendationsScreenState extends State<TravelRecommendationsScreen>
    with TickerProviderStateMixin {
  final List<TravelPost> _posts = [
    TravelPost(
      imageUrl: 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=80',
      title: 'Paris Dream Tour - Limited Time!',
      description: 'Explore the City of Love with 20% off. Only 5 spots left!',
      price: '\$299',
      likes: 120,
      comments: 45,
      isLiked: false,
    ),
    TravelPost(
      imageUrl: 'https://images.unsplash.com/photo-1523906834658-6e24ef2386f9?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=80',
      title: 'Tokyo Adventure - Flash Sale!',
      description: 'Discover cherry blossoms and sushi tours. Book now for exclusive deal!',
      price: '\$499',
      likes: 89,
      comments: 23,
      isLiked: false,
    ),
    TravelPost(
      imageUrl: 'https://images.unsplash.com/photo-1558618047-3c8c76b1e1c0?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=80',
      title: 'New York Lights - Weekend Getaway',
      description: 'Broadway shows and skyline views. Limited weekend availability!',
      price: '\$399',
      likes: 156,
      comments: 67,
      isLiked: true,
    ),
    TravelPost(
      imageUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=80',
      title: 'Rome Eternal - Cultural Escape',
      description: 'Colosseum and pasta classes. 15% off for first 10 bookings!',
      price: '\$450',
      likes: 78,
      comments: 34,
      isLiked: false,
    ),
    TravelPost(
      imageUrl: 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=80',
      title: 'Bali Paradise - Honeymoon Special',
      description: 'Private villas and spa retreats. Time-sensitive offer!',
      price: '\$699',
      likes: 201,
      comments: 89,
      isLiked: false,
    ),
  ];

  late AnimationController _likeController;
  late AnimationController _commentController;

  @override
  void initState() {
    super.initState();
    _likeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _commentController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _likeController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final hintColor = theme.hintColor;
    final cardColor = theme.cardTheme.color;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.appBarTheme.foregroundColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Travel Recommendations',
          style: TextStyle(
            color: theme.appBarTheme.foregroundColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: theme.appBarTheme.foregroundColor),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            offset: const Offset(0, 56),
            onSelected: (value) {
              switch (value) {
                case 'settings':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SettingsScreen(
                        isDarkMode: widget.isDarkMode,
                        onThemeChanged: widget.onThemeChanged,
                      ),
                    ),
                  );
                  break;
                case 'help':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HelpScreen()),
                  );
                  break;
                case 'logout':
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: cardColor,
                      title: Text('Logout', style: TextStyle(color: textColor)),
                      content: Text('Are you sure you want to logout?', style: TextStyle(color: textColor)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Logged out!'), backgroundColor: Colors.red),
                            );
                          },
                          child: const Text('Logout', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 20, color: theme.appBarTheme.foregroundColor),
                    const SizedBox(width: 12),
                    const Text('Settings'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'help',
                child: Row(
                  children: [
                    Icon(Icons.help, size: 20, color: theme.appBarTheme.foregroundColor),
                    const SizedBox(width: 12),
                    const Text('Help'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(Icons.logout, size: 20, color: Colors.red),
                    const SizedBox(width: 12),
                    const Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _posts.length,
        itemBuilder: (context, index) {
          final post = _posts[index];
          return _buildPostCard(post, context, theme, textColor, hintColor, cardColor);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('New recommendation added!')),
          );
        },
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildPostCard(
    TravelPost post,
    BuildContext context,
    ThemeData theme,
    Color? textColor,
    Color? hintColor,
    Color? cardColor,
  ) {
    return Card(
      margin: const EdgeInsets.all(8),
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // تصویر پست
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Stack(
              children: [
                Image.network(
                  post.imageUrl,
                  height: 250,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Limited Time Offer!',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.title,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(height: 4),
                Text(
                  post.description,
                  style: TextStyle(fontSize: 14, color: hintColor),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      post.price,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                    const Spacer(),
                    Text(
                      'Book Now',
                      style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // آیکون‌های تعاملی
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        // فقط این قسمت از _buildPostCard رو جایگزین کن
                        GestureDetector(
                          onTap: () {
                            _commentController.forward().then((_) => _commentController.reverse());
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CommentsScreen(postId: _posts.indexOf(post)),
                              ),
                            );
                          },
                          child: AnimatedBuilder(
                            animation: _commentController,
                            builder: (context, child) {
                              return Row(
                                children: [
                                  const Icon(Icons.comment, color: Colors.grey, size: 24),
                                  const SizedBox(width: 4),
                                  Text('${post.comments} comments'),
                                ],
                              );
                            },
                          ),                        
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Reply added!')),
                        );
                      },
                      child: const Icon(Icons.reply, color: Colors.grey, size: 20),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}