import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SuggestClinicPage extends StatefulWidget {
  const SuggestClinicPage({super.key});

  @override
  _SuggestClinicPageState createState() => _SuggestClinicPageState();
}

class _SuggestClinicPageState extends State<SuggestClinicPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController workingHoursController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  bool isLoading = false;
  String? selectedCategory;

  final _formKey = GlobalKey<FormState>();

  final List<String> categories = [
    'عيادة',
    'مستشفى',
    'مركز طبي',
    'عيادة مختصة',
    'مدرسة',
    'أخرى',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'اقتراح عيادة',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
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
                const Text(
                  'يرجى تقديم المعلومات الأساسية حول العيادة',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.black),
                ),
                const SizedBox(height: 20),
                _buildInputField(
                  'إسم المكان',
                  nameController,
                  validator: (val) {
                    if (val == null || val.isEmpty)
                      return 'الرجاء إدخال اسم المكان';
                    return null;
                  },
                ),

                // Dropdown menu
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                      ),
                      isExpanded: true,
                      hint: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'الفئة',
                          textAlign: TextAlign.right,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedCategory = newValue;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'الرجاء اختيار الفئة';
                        }
                        return null;
                      },
                      items: categories.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(value, textAlign: TextAlign.right),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                _buildInputField(
                  'العنوان',
                  addressController,
                  validator: (val) {
                    if (val == null || val.isEmpty)
                      return 'الرجاء إدخال العنوان';
                    return null;
                  },
                ),
                _buildInputField(
                  'ساعات العمل',
                  workingHoursController,
                  validator: (val) {
                    if (val == null || val.isEmpty)
                      return 'الرجاء إدخال ساعات العمل';
                    return null;
                  },
                ),
                _buildInputField(
                  'رقم الهاتف',
                  phoneController,
                  keyboardType: TextInputType.phone,
                  validator: (val) {
                    if (val == null || val.isEmpty)
                      return 'الرجاء إدخال رقم الهاتف';
                    if (!RegExp(r'^[0-9]{8,15}$').hasMatch(val))
                      return 'رقم الهاتف غير صحيح';
                    return null;
                  },
                ),
                _buildInputField(
                  'البريد الإلكتروني (اختياري)',
                  emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) {
                    if (val != null && val.isNotEmpty) {
                      if (!RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      ).hasMatch(val)) {
                        return 'صيغة البريد الإلكتروني غير صحيحة';
                      }
                    }
                    return null; // يعني لو فاضي مافي مشكلة
                  },
                ),
                _buildInputField(
                  'وصف العيادة (اختياري)',
                  descriptionController,
                  maxLines: 3,
                ),

                const SizedBox(height: 30),
                Center(
                  child: isLoading
                      ? const CircularProgressIndicator(
                          color: Color(0xFFFFE399),
                        )
                      : ElevatedButton(
                          onPressed: _submitSuggestion,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFE399),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            minimumSize: const Size(260, 54),
                          ),
                          child: const Text(
                            'إرسال',
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextFormField(
        controller: controller,
        textAlign: TextAlign.right,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          hintText: label,
          filled: true,
          fillColor: Colors.grey.shade200,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
        ),
      ),
    );
  }

  void _submitSuggestion() async {
    if (!_formKey.currentState!.validate()) {
      return; // stop if not valid
    }

    setState(() {
      isLoading = true;
    });

    try {
      await FirebaseFirestore.instance.collection('clinic_suggestions').add({
        'name': nameController.text,
        'category': selectedCategory!,
        'address': addressController.text,
        'workingHours': workingHoursController.text,
        'phone': phoneController.text,
        'email': emailController.text.isEmpty ? null : emailController.text,
        'description': descriptionController.text.isEmpty
            ? null
            : descriptionController.text,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
        'contactInfo': '',
      });

      _showSuccessDialog();
    } catch (e) {
      _showErrorDialog('حدث خطأ: $e');
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
          title: const Text('تم الإرسال بنجاح'),
          content: const Text(
            'شكراً لك على اقتراح عيادة جديدة. سنراجع المعلومات قريباً.',
          ),
          actions: [
            TextButton(
              child: const Text('حسناً'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
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
}
