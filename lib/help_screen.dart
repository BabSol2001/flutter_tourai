import 'package:flutter/material.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F7F8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111618)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Help Center',
          style: TextStyle(color: Color(0xFF111618), fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFF111618)),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Menu opened')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search for help...',
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF617c89)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Color(0xFF617c89)),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Quick Actions
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111618)),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildQuickAction(
                  icon: Icons.chat_bubble_outline,
                  title: 'Chat with us',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Opening chat support')),
                    );
                  },
                ),
                _buildQuickAction(
                  icon: Icons.phone,
                  title: 'Call support',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Calling support')),
                    );
                  },
                ),
                _buildQuickAction(
                  icon: Icons.email,
                  title: 'Email us',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Opening email')),
                    );
                  },
                ),
                _buildQuickAction(
                  icon: Icons.help_outline,
                  title: 'FAQ',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Opening FAQ')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Popular Topics
            const Text(
              'Popular Topics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111618)),
            ),
            const SizedBox(height: 16),
            ..._buildTopicTiles(),
            const SizedBox(height: 24),

            // Contact Info
            const Text(
              'Contact Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111618)),
            ),
            const SizedBox(height: 16),
            _buildContactTile(
              icon: Icons.phone,
              title: 'Phone',
              subtitle: '+1 (555) 123-4567',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Calling...')),
                );
              },
            ),
            _buildContactTile(
              icon: Icons.email,
              title: 'Email',
              subtitle: 'support@tourai.com',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening email...')),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF13a4ec).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF13a4ec), size: 28),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTopicTiles() {
    return [
      _buildTopicTile(
        icon: Icons.account_circle,
        title: 'Account & Profile',
        subtitle: 'Manage your account settings',
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account help')),
          );
        },
      ),
      _buildTopicTile(
        icon: Icons.payment,
        title: 'Billing & Payments',
        subtitle: 'Payment methods and invoices',
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Billing help')),
          );
        },
      ),
      _buildTopicTile(
        icon: Icons.security,
        title: 'Privacy & Security',
        subtitle: 'Protect your data',
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Privacy help')),
          );
        },
      ),
      _buildTopicTile(
        icon: Icons.contact_support,
        title: 'Technical Support',
        subtitle: 'App issues and bugs',
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tech support')),
          );
        },
      ),
    ];
  }

  Widget _buildTopicTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF13a4ec).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF13a4ec), size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 14, color: Color(0xFF617c89)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF617c89)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF13a4ec), size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 14, color: Color(0xFF617c89)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF617c89)),
            ],
          ),
        ),
      ),
    );
  }
}