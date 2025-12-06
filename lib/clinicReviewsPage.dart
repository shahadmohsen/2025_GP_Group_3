import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'clinic_model.dart';
import 'add_review_page.dart';
import 'package:firebase_auth/firebase_auth.dart';


class ClinicReviewsPage extends StatefulWidget {
  final Clinic clinic;

  const ClinicReviewsPage({super.key, required this.clinic});

  @override
  _ClinicReviewsPageState createState() => _ClinicReviewsPageState();
}

class _ClinicReviewsPageState extends State<ClinicReviewsPage> {
  String sortBy = 'Date';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Column(
            children: [
              const Text(
                'التقييمات',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(
                widget.clinic.name,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
          actions: [
            IconButton(
              icon: const Icon(Icons.add, textDirection: TextDirection.ltr),
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;

                if (user == null) {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('تسجيل الدخول مطلوب'),
                      content: const Text('يرجى تسجيل الدخول لإضافة تقييم.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('حسنًا'),
                        ),
                      ],
                    ),
                  );
                  return;
                }


                final existingReview = await FirebaseFirestore.instance
                    .collection('reviews')
                    .where('clinicId', isEqualTo: widget.clinic.id)
                    .where('userId', isEqualTo: user.uid)
                    .limit(1)
                    .get();

                if (existingReview.docs.isNotEmpty) {

                  showDialog(
                    context: context,

                    builder: (_) => AlertDialog(
                      title: const Text('خطأ في اضافة تقييم'),
                      content: const Text(
                        'لقد قمت بإضافة تقييم لهذه العيادة مسبقًا.\nيمكنك تعديل تقييمك من الحساب "تقييمات" .',
                        textAlign: TextAlign.right,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('حسنًا'),
                        ),
                      ],
                    ),
                  );
                  return;
                }

                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddReviewPage(clinic: widget.clinic),
                  ),
                );

                if (result == true) {
                  setState(() {}); // تحديث التقييمات
                }
              },


            ),
          ],
        ),
        body: Column(
          children: [
            // Average rating summary
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reviews')
                  .where('clinicId', isEqualTo: widget.clinic.id)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox();
                }

                final reviews = snapshot.data!.docs;
                if (reviews.isEmpty) {
                  return const SizedBox();
                }

                double totalRating = 0;
                int ratingCount = 0;

                for (var review in reviews) {
                  final data = review.data() as Map<String, dynamic>;
                  if (data['rating'] != null) {
                    totalRating += (data['rating'] as num).toDouble();
                    ratingCount++;
                  }
                }

                final averageRating = ratingCount > 0
                    ? totalRating / ratingCount
                    : 0.0;

                return Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE399).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: const Color(0xFFFFE399).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        averageRating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          return Icon(
                            index < averageRating.round()
                                ? Icons.star
                                : Icons.star_border,
                            color: const Color(0xFFFFE399),
                            size: 24,
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$ratingCount ${ratingCount == 1
                            ? 'تقييم'
                            : ratingCount == 2
                            ? 'تقييمان'
                            : 'تقييمات'}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Sort dropdown + title
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'جميع التقييمات',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  DropdownButton<String>(
                    value: sortBy,
                    onChanged: (String? newValue) {
                      setState(() {
                        sortBy = newValue!;
                      });
                    },
                    items: <String>['التاريخ', 'التقييم']
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value == 'التاريخ' ? 'Date' : 'Rating',
                        child: Text('ترتيب بـ $value'),
                      );
                    })
                        .toList(),
                  ),

                ],
              ),
            ),

            // Reviews list
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('reviews')
                    .where('clinicId', isEqualTo: widget.clinic.id)
                    .orderBy(
                  sortBy == 'Date' ? 'timestamp' : 'rating',
                  descending: true,
                )
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('حدث خطأ: ${snapshot.error}'));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.rate_review_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'لا توجد تقييمات بعد',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'كن أول من يكتب تقييماً',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  final reviews = snapshot.data!.docs;

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: reviews.length,
                    itemBuilder: (context, index) {
                      final reviewData =
                      reviews[index].data() as Map<String, dynamic>;
                      final timestamp = reviewData['timestamp'] as Timestamp?;
                      final date = timestamp?.toDate();
                      final rating = reviewData['rating'] as int? ?? 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // User info and date
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Name + Avatar on the right
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: const Color(0xFFFFE399),
                                      radius: 16,
                                      child: Text(
                                        (reviewData['userName'] ?? 'م')[0],
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      reviewData['userName'] ?? 'مستخدم مجهول',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),

                                // Date on the left
                                if (date != null)
                                  Text(
                                    '${date.day}/${date.month}/${date.year}',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Review text with stars on the same line
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: List.generate(5, (starIndex) {
                                        return Icon(
                                          starIndex < rating
                                              ? Icons.star
                                              : Icons.star_border,
                                          color: const Color(0xFFFFE399),
                                          size: 18,
                                        );
                                      }),
                                    ),
                                const SizedBox(width: 12),
                                // Review text on the right

                                  Text(
                                    reviewData['reviewText'] ?? '',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.5,
                                    ),
                                  ),
                        ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  }
