import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

class ManagePostsPage extends StatefulWidget {
  const ManagePostsPage({super.key});

  @override
  State<ManagePostsPage> createState() => _ManagePostsPageState();
}

class _ManagePostsPageState extends State<ManagePostsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // الحصول على ID المستخدم الحالي
  String get currentUserId {
    return _auth.currentUser?.uid ?? '';
  }

  // حذف البوست مع تأكيد
  Future<void> _deletePost(String postId) async {
    // عرض dialog للتأكيد
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تأكيد الحذف'),
            content: const Text('هل أنت متأكد من حذف هذا المنشور؟\nلن تتمكن من استعادته بعد الحذف.'),
            actions: <Widget>[
              TextButton(
                child: const Text('إلغاء'),
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
              ),
              TextButton(
                child: const Text(
                  'حذف',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
              ),
            ],
          ),
        );
      },
    );

    // إذا وافق المستخدم، احذف المنشور
    if (confirm == true) {
      try {
        // حذف المنشور من Firestore
        await _firestore.collection('posts').doc(postId).delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅تم حذف المنشور بنجاح '),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        print('Error deleting post: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('حدث خطأ في حذف المنشور'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
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
          backgroundColor: const Color(0xFFF7ECCA),
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'إدارة المنشورات',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFEFBFA),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(40),
              topRight: Radius.circular(40),
            ),
          ),
          child: StreamBuilder<QuerySnapshot>(
            
            stream: _firestore
                .collection('posts')
                .where('authorId', isEqualTo: currentUserId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFF7ECCA),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.article_outlined,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'لا توجد منشورات',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ابدأ بنشر منشوراتك من الصفحة الرئيسية',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                );
              }

              // ✅ ترتيب البوستات في Flutter بدلاً من Firestore
              var sortedDocs = snapshot.data!.docs.toList();
              sortedDocs.sort((a, b) {
                var aData = a.data() as Map<String, dynamic>;
                var bData = b.data() as Map<String, dynamic>;
                Timestamp? aTime = aData['timestamp'] as Timestamp?;
                Timestamp? bTime = bData['timestamp'] as Timestamp?;
                
                if (aTime == null && bTime == null) return 0;
                if (aTime == null) return 1;
                if (bTime == null) return -1;
                
                return bTime.compareTo(aTime); // من الأحدث للأقدم
              });

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: sortedDocs.length,
                itemBuilder: (context, index) {
                  var post = sortedDocs[index];
                  var data = post.data() as Map<String, dynamic>;
                  
                  Timestamp? timestamp = data['timestamp'] as Timestamp?;
                  String timeAgo = timestamp != null
                      ? _getTimeAgo(timestamp.toDate())
                      : 'الآن';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF7ECCA), width: 2),
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
                        // Header with delete button
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['author'] ?? 'مستخدم',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      timeAgo,
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
                                  Icons.delete_outline,
                                  color: Colors.red,
                                  size: 24,
                                ),
                                onPressed: () => _deletePost(post.id),
                              ),
                            ],
                          ),
                        ),
                        
                        // Content
                        if (data['content'] != null && data['content'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              data['content'],
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 14, height: 1.5),
                            ),
                          ),
                        
                        const SizedBox(height: 12),
                        
                        // Image
                        if (data['imageBase64'] != null)
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(14),
                            ),
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
                        
                        // Stats
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
                                .doc(post.id)
                                .collection('comments')
                                .snapshots(),
                            builder: (context, commentSnapshot) {
                              int commentCount = commentSnapshot.data?.docs.length ?? 0;
                              return Row(
                                children: [
                                  const Icon(
                                    Icons.chat_bubble_outline,
                                    color: Colors.grey,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$commentCount تعليق',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
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
      ),
    );
  }
}