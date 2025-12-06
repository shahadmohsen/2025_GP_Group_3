// reviews_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReviewsPage extends StatelessWidget {
  const ReviewsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7ECCA),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF7ECCA),
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'التقييمات',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFFFEFBFA),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(40),
              topRight: Radius.circular(40),
            ),
          ),
          child: user == null
              ? const _NotLoggedIn()
              : _UserReviewsList(userId: user.uid),
        ),
      ),
    );
  }
}

class _UserReviewsList extends StatefulWidget {
  final String userId;
  const _UserReviewsList({required this.userId});

  @override
  State<_UserReviewsList> createState() => _UserReviewsListState();
}

class _UserReviewsListState extends State<_UserReviewsList> {
  Future<void> _deleteReview(String docId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف التقييم'),
        content: const Text('هل أنت متأكد من حذف هذا التقييم؟ لا يمكن التراجع.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('reviews')
          .doc(docId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تم حذف التقييم')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل حذف التقييم: $e')),
        );
      }
    }
  }

  Future<void> _editReview(
      String docId, String currentText, int currentRating) async {
    final controller = TextEditingController(text: currentText);
    final formKey = GlobalKey<FormState>();
    int selectedRating = currentRating;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Form(
            key: formKey,
            child: StatefulBuilder(
              builder: (context, setModalState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'تعديل التقييم',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 20),

                    // التقييم
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'التقييم',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: List.generate(5, (index) {
                        return GestureDetector(
                          onTap: () {
                            setModalState(() {
                              selectedRating = index + 1;
                            });
                          },
                          child: Icon(
                            index < selectedRating
                                ? Icons.star
                                : Icons.star_border,
                            color: const Color(0xFFFFE399),
                            size: 32,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),

                    // نص التعليق
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'التعليق',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Column(
                      children: [
                        TextFormField(
                          controller: controller,
                          maxLines: 6,
                          textAlign: TextAlign.right,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'الرجاء كتابة التقييم'
                              : null,
                          onChanged: (_) => setModalState(() {}),
                          decoration: InputDecoration(
                            hintText: 'اكتب التقييم المحدث...',
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12)),
                              borderSide:
                                  BorderSide(color: Color(0xFFFFE399)),
                            ),
                            contentPadding: const EdgeInsets.all(16),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${controller.text.length} حرف',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Spacer(),
                        ElevatedButton(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            try {
                              await FirebaseFirestore.instance
                                  .collection('reviews')
                                  .doc(docId)
                                  .update({
                                'reviewText': controller.text.trim(),
                                'rating': selectedRating,
                                'timestamp': FieldValue.serverTimestamp(),
                              });
                              if (context.mounted) Navigator.pop(ctx, true);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text('فشل تعديل التقييم: $e')),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFE399),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('حفظ',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم تعديل التقييم')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('reviews')
        .where('userId', isEqualTo: widget.userId);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFFE399)),
          );
        }

        if (snapshot.hasError) {
          debugPrint('ReviewsPage error: ${snapshot.error}');
          return const _ErrorState(message: 'حدث خطأ أثناء جلب التقييمات');
        }

        final docs = (snapshot.data?.docs ?? []).toList()
          ..sort((a, b) {
            final ma = a.data() as Map<String, dynamic>? ?? {};
            final mb = b.data() as Map<String, dynamic>? ?? {};
            final ta = ma['timestamp'];
            final tb = mb['timestamp'];
            final da = (ta is Timestamp)
                ? ta.toDate()
                : DateTime.fromMillisecondsSinceEpoch(0);
            final db = (tb is Timestamp)
                ? tb.toDate()
                : DateTime.fromMillisecondsSinceEpoch(0);
            return db.compareTo(da);
          });

        if (docs.isEmpty) {
          return const _EmptyState();
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>? ?? {};
            final clinicName = (data['clinicName'] ?? 'عيادة').toString();
            final reviewText = (data['reviewText'] ?? '').toString();
            final rating = (data['rating'] ?? 0) as int;
            final ts = data['timestamp'];
            final dt = (ts is Timestamp)
                ? ts.toDate()
                : DateTime.fromMillisecondsSinceEpoch(0);

            return _ReviewCard(
              clinicName: clinicName,
              reviewText: reviewText,
              rating: rating,
              dateTime: dt,
              onEdit: () => _editReview(doc.id, reviewText, rating),
              onDelete: () => _deleteReview(doc.id),
            );
          },
        );
      },
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final String clinicName;
  final String reviewText;
  final int rating;
  final DateTime dateTime;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _ReviewCard({
    required this.clinicName,
    required this.reviewText,
    required this.rating,
    required this.dateTime,
    this.onEdit,
    this.onDelete,
  });

  String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    return '$d/$m/$y';
  }

  @override
  Widget build(BuildContext context) {
    final hasRealDate = dateTime.millisecondsSinceEpoch > 0;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F0)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 6,
            offset: Offset(0, 2),
            color: Color(0x1A000000),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // العنوان: اسم العيادة + التاريخ يمين، والنقاط يسار
          Row(
            textDirection: TextDirection.ltr, // نخلي أول عنصر يروح يسار
            children: [
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit' && onEdit != null) onEdit!();
                  if (value == 'delete' && onDelete != null) onDelete!();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit),
                      title: Text('تعديل'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete),
                      title: Text('حذف'),
                    ),
                  ),
                ],
                child: const Icon(Icons.more_vert, color: Colors.grey),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    clinicName,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black,
                    ),
                  ),
                  if (hasRealDate)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _formatDate(dateTime),
                        textAlign: TextAlign.right,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // النجوم يمين
          Row(
            textDirection: TextDirection.ltr,
            mainAxisAlignment: MainAxisAlignment.end,
            children: List.generate(5, (index) {
              return Icon(
                index < rating ? Icons.star : Icons.star_border,
                color: const Color(0xFFFFE399),
                size: 20,
              );
            }),
          ),

          const SizedBox(height: 10),

          // نص التقييم يمين
          SizedBox(
            width: double.infinity,
            child: Text(
              reviewText,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.rate_review, size: 48, color: Color(0xFFFFE399)),
            SizedBox(height: 12),
            Text(
              'لا توجد تقييمات لك حتى الآن',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: const TextStyle(color: Colors.red),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _NotLoggedIn extends StatelessWidget {
  const _NotLoggedIn();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'يرجى تسجيل الدخول لعرض تقييماتك',
        style: TextStyle(color: Colors.grey, fontSize: 16),
      ),
    );
  }
}
