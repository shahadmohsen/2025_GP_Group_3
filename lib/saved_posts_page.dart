import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SavedPostsPage extends StatefulWidget {
  const SavedPostsPage({super.key});

  @override
  State<SavedPostsPage> createState() => _SavedPostsPageState();
}

class _SavedPostsPageState extends State<SavedPostsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<String> _savedPostIds = [];
  bool _isLoading = true;

  String get currentUserId {
    return _auth.currentUser?.uid ?? '';
  }

  @override
  void initState() {
    super.initState();
    _loadSavedPosts();
  }

  Future<void> _loadSavedPosts() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String key = 'saved_posts_$currentUserId';
      List<String>? saved = prefs.getStringList(key);
      setState(() {
        _savedPostIds = saved ?? [];
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading saved posts: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _unsavePost(String postId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String key = 'saved_posts_$currentUserId';
      
      _savedPostIds.remove(postId);
      await prefs.setStringList(key, _savedPostIds);
      
      setState(() {});
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إلغاء الحفظ')),
      );
    } catch (e) {
      print('Error unsaving post: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ في إلغاء الحفظ')),
      );
    }
  }

  Future<Map<String, dynamic>?> _getPostData(String postId) async {
    try {
      DocumentSnapshot postDoc = await _firestore
          .collection('posts')
          .doc(postId)
          .get();

      if (postDoc.exists) {
        return {
          'id': postDoc.id,
          ...postDoc.data() as Map<String, dynamic>,
        };
      }
    } catch (e) {
      print('Error getting post data: $e');
    }
    return null;
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return 'منذ ${difference.inDays} ${difference.inDays == 1 ? 'يوم' : 'أيام'}';
    } else if (difference.inHours > 0) {
      return 'منذ ${difference.inHours} ${difference.inHours == 1 ? 'ساعة' : 'ساعات'}';
    } else if (difference.inMinutes > 0) {
      return 'منذ ${difference.inMinutes} ${difference.inMinutes == 1 ? 'دقيقة' : 'دقائق'}';
    } else {
      return 'الآن';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7ECCA),
        appBar: AppBar(
          title: const Text(
            'المنشورات المحفوظة',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Colors.amberAccent,
          elevation: 0,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _savedPostIds.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bookmark_border,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'لا توجد منشورات محفوظة',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'احفظ المنشورات المفضلة لديك لتظهر هنا',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _savedPostIds.length,
                    itemBuilder: (context, index) {
                      String postId = _savedPostIds[index];

                      return FutureBuilder<Map<String, dynamic>?>(
                        future: _getPostData(postId),
                        builder: (context, postSnapshot) {
                          if (postSnapshot.connectionState == ConnectionState.waiting) {
                            return const Card(
                              margin: EdgeInsets.only(bottom: 16),
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: CircularProgressIndicator()),
                              ),
                            );
                          }

                          if (!postSnapshot.hasData || postSnapshot.data == null) {
                            return const SizedBox.shrink();
                          }

                          var data = postSnapshot.data!;
                          Timestamp? timestamp = data['timestamp'] as Timestamp?;
                          String timeAgo = timestamp != null
                              ? _getTimeAgo(timestamp.toDate())
                              : 'الآن';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFFFF59D),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  data['author'] ?? 'مجهول',
                                                  textAlign: TextAlign.right,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  timeAgo,
                                                  textAlign: TextAlign.right,
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.bookmark,
                                              color: Colors.amberAccent,
                                            ),
                                            onPressed: () {
                                              _unsavePost(postId);
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        data['content'] ?? '',
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (data['imageBase64'] != null)
                                  ClipRRect(
                                    child: Image.memory(
                                      base64Decode(data['imageBase64']),
                                      width: double.infinity,
                                      height: 250,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          height: 250,
                                          color: Colors.grey[300],
                                          child: const Center(
                                            child: Icon(Icons.error),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      top: BorderSide(color: Colors.grey[200]!),
                                    ),
                                  ),
                                  child: StreamBuilder<QuerySnapshot>(
                                    stream: _firestore
                                        .collection('posts')
                                        .doc(postId)
                                        .collection('comments')
                                        .snapshots(),
                                    builder: (context, snapshot) {
                                      int commentCount = snapshot.data?.docs.length ?? 0;
                                      return Row(
                                        children: [
                                          const Icon(
                                            Icons.chat_bubble_outline,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '$commentCount تعليق',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
      ),
    );
  }
}