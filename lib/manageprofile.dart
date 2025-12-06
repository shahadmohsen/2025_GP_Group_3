import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'edit_profile.dart';
import 'help_center_page.dart';
import 'login.dart';
import 'reviews_page.dart';
import 'manage_posts.dart';

// Initialize the notifications plugin globally
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

class ManageProfile extends StatefulWidget {
  const ManageProfile({super.key});

  @override
  State<ManageProfile> createState() => _ManageProfileState();
}

class _ManageProfileState extends State<ManageProfile> {
  bool _notificationsEnabled = true;
  String _userName = "";

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadNotificationSettings();
  }

  Future<void> _loadUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          setState(() {
            _userName = userDoc['name'] ?? "User";
          });
        }
      } catch (e) {
        print("Error loading user data: $e");
        setState(() {
          _userName = "User";
        });
      }
    }
  }

  // تحميل إعدادات الإشعارات
  Future<void> _loadNotificationSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      });
    } catch (e) {
      print("Error loading notification settings: $e");
    }
  }

  // حفظ إعدادات الإشعارات
  Future<void> _saveNotificationSettings(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', enabled);
    } catch (e) {
      print("Error saving notification settings: $e");
    }
  }

  // إلغاء جميع الإشعارات المجدولة
  Future<void> _cancelAllNotifications() async {
    try {
      await flutterLocalNotificationsPlugin.cancelAll();
      print("✅ All notifications cancelled");
    } catch (e) {
      print("❌ Error cancelling notifications: $e");
    }
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
            (Route<dynamic> route) => false,
      );
    } catch (e) {
      print("Logout error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء تسجيل الخروج')),
      );
    }
  }

  void _navigateToEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EditProfilePage(),
      ),
    );

    if (result != null && result is String) {
      setState(() {
        _userName = result;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم تحديث الاسم بنجاح')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
        body: Container(
        decoration: const BoxDecoration(
        gradient: LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
        Color(0xFFEBF4FF),
    Color(0xFFFFF9E6),
    Color(0xFFF5F0FF),
    ],
    ),
    ),
    child: Stack(
    children: [
    Positioned(
    top: 150,
    left: 0,
    right: 0,
    child: Container(
    width: double.infinity,
    height: MediaQuery.of(context).size.height - 150,
    decoration: const BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.only(
    topLeft: Radius.circular(40),
    topRight: Radius.circular(40),
    ),
    ),
    ),
    ),





          Positioned(
            top: 200,
            left: 0,
            right: 0,
            bottom: 0,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Text(
                    _userName,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF000000),
                    ),
                  ),
                  const SizedBox(height: 40),

                  profileOption(Icons.person, 'تعديل الحساب', _navigateToEditProfile),

                  profileOption(Icons.article, 'إدارة المنشورات', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ManagePostsPage(),
                      ),
                    );
                  }),

                  profileOption(Icons.star_rate, 'التقييمات', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ReviewsPage(),
                      ),
                    );
                  }),

                  profileOption(Icons.help_outline, 'مساعدة', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HelpCenterPage(),
                      ),
                    );
                  }),

                  profileOption(Icons.exit_to_app, 'تسجيل الخروج', () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('تسجيل الخروج'),
                        content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('إلغاء'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _logout();
                            },
                            child: const Text('تأكيد'),
                          ),
                        ],
                      ),
                    );
                  }),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: Divider(
                      color: Colors.grey[300],
                      thickness: 1,
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Switch(
                          value: _notificationsEnabled,
                          onChanged: (bool value) async {
                            setState(() {
                              _notificationsEnabled = value;
                            });

                            // حفظ الإعدادات
                            await _saveNotificationSettings(value);

                            if (value) {
                              // تم تفعيل الإشعارات
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('تم تفعيل الإشعارات'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } else {
                              // تم إيقاف الإشعارات - إلغاء جميع الإشعارات
                              await _cancelAllNotifications();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('تم إيقاف الإشعارات وإلغاء جميع التذكيرات'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                          },
                          activeColor: Colors.green,
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            const Text(
                              'الإشعارات',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFE399),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _notificationsEnabled
                                    ? Icons.notifications
                                    : Icons.notifications_off,
                                size: 22,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget profileOption(IconData icon, String title, VoidCallback onTap) {

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, color: Colors.black),
            ),
            const SizedBox(width: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFFFFE399),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
} 