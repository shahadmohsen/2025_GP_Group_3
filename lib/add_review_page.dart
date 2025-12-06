import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'clinic_model.dart';

class AddReviewPage extends StatefulWidget {
  final Clinic clinic;

  const AddReviewPage({
    super.key,
    required this.clinic,
  });

  @override
  _AddReviewPageState createState() => _AddReviewPageState();
}

class _AddReviewPageState extends State<AddReviewPage> {
  final TextEditingController reviewController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;
  int selectedRating = 0; // Added rating state

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            'كتابة تقييم',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Clinic info card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          widget.clinic.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.clinic.category.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.clinic.category,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                        if (widget.clinic.address.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Flexible(
                                child: Text(
                                  widget.clinic.address,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.location_on,
                                color: Colors.grey,
                                size: 16,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Rating section
                  const Text(
                    'اختر تقييمك',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Star rating widget
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedRating = index + 1;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.star,
                            size: 40,
                            color: index < selectedRating
                                ? const Color(0xFFFFE399)
                                : Colors.grey.shade300,
                          ),
                        ),
                      );
                    }),
                  ),

                  // Rating description
                  Center(
                    child: Text(
                      _getRatingDescription(selectedRating),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Review text field
                  const Text(
                    'اكتب تقييمك',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  TextFormField(
                    controller: reviewController,
                    maxLines: 8,
                    textAlign: TextAlign.right,
                    validator: (value) {
                      if (selectedRating == 0) {
                        return 'الرجاء اختيار تقييم';
                      }
                      if (value == null || value.trim().isEmpty) {
                        return 'الرجاء كتابة التقييم';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      hintText: '...شاركنا تجربتك مع هذه العيادة',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFFFE399)),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Character counter
                  Row(
                    children: [
                      Text(
                        '${reviewController.text.length} حرف',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Submit button
                  Center(
                    child: isLoading
                        ? const CircularProgressIndicator(
                      color: Color(0xFFFFE399),
                    )
                        : ElevatedButton(
                      onPressed: _submitReview,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFE399),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        minimumSize: const Size(200, 54),
                      ),
                      child: const Text(
                        'نشر التقييم',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getRatingDescription(int rating) {
    switch (rating) {
      case 1:
        return 'سيء جداً';
      case 2:
        return 'سيء';
      case 3:
        return 'متوسط';
      case 4:
        return 'جيد';
      case 5:
        return 'ممتاز';
      default:
        return 'اختر تقييمك';
    }
  }

  void _submitReview() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if user is logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showErrorDialog('يجب تسجيل الدخول أولاً لكتابة تقييم');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Get user name from Firestore or use email
      String userName = 'مستخدم مجهول';

      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data();
          userName = userData?['name'] ?? userData?['displayName'] ?? user.email?.split('@')[0] ?? 'مستخدم مجهول';
        } else {
          userName = user.email?.split('@')[0] ?? 'مستخدم مجهول';
        }
      } catch (e) {
        userName = user.email?.split('@')[0] ?? 'مستخدم مجهول';
      }

      // Add review to Firestore with rating
      await FirebaseFirestore.instance.collection('reviews').add({
        'clinicId': widget.clinic.id,
        'clinicName': widget.clinic.name,
        'userId': user.uid,
        'userName': userName,
        'userEmail': user.email,
        'reviewText': reviewController.text.trim(),
        'rating': selectedRating, // Added rating field
        'timestamp': FieldValue.serverTimestamp(),
      });

      _showSuccessDialog();
    } catch (e) {
      _showErrorDialog('حدث خطأ أثناء نشر التقييم: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('تم نشر التقييم'),
          content: const Text('شكراً لك على تقييمك، سيساعد الآخرين في اتخاذ قرارهم.'),
          actions: [
            TextButton(
              child: const Text('حسناً'),
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(true); // Return to reviews page with result
              },
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('خطأ'),
          content: Text(message),
          actions: [
            TextButton(
              child: const Text('حسناً'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    reviewController.addListener(() {
      setState(() {}); // Update character counter
    });
  }

  @override
  void dispose() {
    reviewController.dispose();
    super.dispose();
  }
}