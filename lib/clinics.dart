import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'clinic_model.dart';
import 'AddClinic.dart';
import 'suggestclinic.dart';
import 'clinicReviewsPage.dart';

class ListOfClinicsWidget extends StatefulWidget {
  final Function(Clinic)? onClinicTap;
  final bool
  isInAdminPanel; // New property to check if widget is used in admin panel

  const ListOfClinicsWidget({
    super.key,
    this.onClinicTap,
    this.isInAdminPanel = false, // Default to false (user context)
  });

  @override
  State<ListOfClinicsWidget> createState() => _ListOfClinicsWidgetState();
}

class _ListOfClinicsWidgetState extends State<ListOfClinicsWidget> {
  final TextEditingController searchController = TextEditingController();
  final ClinicService _clinicService = ClinicService();
  bool _isLoading = true;
  bool _isAdmin = false;

  List<Clinic> clinics = [];
  List<Clinic> filteredClinics = [];

  // متغيرات الفلترة مع الأنواع الجديدة
  String selectedFilter = 'الكل'; // القيمة الافتراضية
  final List<String> filterOptions = [
    'الكل',
    'عيادة',
    'مستشفى',
    'مركز طبي',
    'عيادة مختصة',
    'مدرسة',
    'أخرى'
  ];

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _fetchClinics();
  }

  Future<void> _checkAdminStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _isAdmin = user.email == "admin4@gmail.com";
      });
    }
  }

  void _fetchClinics() {
    setState(() {
      _isLoading = true;
    });

    _clinicService.getClinics().listen(
          (fetchedClinics) {
        setState(() {
          clinics = fetchedClinics;
          filteredClinics = List.from(clinics);
          _isLoading = false;
        });
        _applyFilters(); // تطبيق الفلاتر بعد تحميل البيانات
      },
      onError: (error) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تحميل العيادات: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      },
    );
  }

  void filterClinics(String query) {
    setState(() {
      if (query.isEmpty) {
        _applyFilters(); // إعادة تطبيق الفلاتر عند مسح البحث
      } else {
        filteredClinics = clinics
            .where(
              (clinic) =>
          (clinic.name.toLowerCase().contains(query.toLowerCase()) ||
              clinic.category.toLowerCase().contains(
                query.toLowerCase(),
              )) &&
              _matchesFilter(clinic),
        )
            .toList();
      }
    });
  }

  // دالة للتحقق من تطابق العيادة مع الفلتر المحدد
  bool _matchesFilter(Clinic clinic) {
    switch (selectedFilter) {
      case 'عيادة':
        return clinic.category.toLowerCase().contains('عيادة') &&
            !clinic.category.toLowerCase().contains('مختصة');
      case 'مستشفى':
        return clinic.category.toLowerCase().contains('مستشفى');
      case 'مركز طبي':
        return clinic.category.toLowerCase().contains('مركز طبي');
      case 'عيادة مختصة':
        return clinic.category.toLowerCase().contains('عيادة مختصة') ||
            clinic.category.toLowerCase().contains('عيادة متخصصة');
      case 'مدرسة':
        return clinic.category.toLowerCase().contains('مدرسة') ||
            clinic.category.toLowerCase().contains('school') ||
            clinic.category.toLowerCase().contains('معهد') ||
            clinic.category.toLowerCase().contains('مركز تعليمي');
      case 'أخرى':
        return !clinic.category.toLowerCase().contains('عيادة') &&
            !clinic.category.toLowerCase().contains('مستشفى') &&
            !clinic.category.toLowerCase().contains('مركز طبي') &&
            !clinic.category.toLowerCase().contains('مدرسة') &&
            !clinic.category.toLowerCase().contains('school') &&
            !clinic.category.toLowerCase().contains('معهد') &&
            !clinic.category.toLowerCase().contains('مركز تعليمي');
      case 'الكل':
      default:
        return true;
    }
  }

  // دالة تطبيق الفلاتر
  void _applyFilters() {
    setState(() {
      if (selectedFilter == 'الكل') {
        filteredClinics = List.from(clinics);
      } else {
        filteredClinics = clinics
            .where((clinic) => _matchesFilter(clinic))
            .toList();
      }

      // تطبيق فلتر البحث إذا كان موجود
      String searchQuery = searchController.text;
      if (searchQuery.isNotEmpty) {
        filteredClinics = filteredClinics
            .where(
              (clinic) =>
          clinic.name.toLowerCase().contains(
            searchQuery.toLowerCase(),
          ) ||
              clinic.category.toLowerCase().contains(
                searchQuery.toLowerCase(),
              ),
        )
            .toList();
      }
    });
  }

  // دالة تغيير الفلتر
  void _changeFilter(String filter) {
    setState(() {
      selectedFilter = filter;
    });
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,

        body: Container(
          padding: const EdgeInsets.all(16.0),
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
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // شريط البحث مع زر الاقتراح
                Row(
                  children: [

                    Expanded(
                      child: TextField(
                        controller: searchController,
                        textAlign: TextAlign.right,
                        onChanged: filterClinics,
                        decoration: InputDecoration(
                          hintText: 'البحث عن عيادة أو مدرسة',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ),
                    // Only show suggest button if not in admin panel
                    if (!widget.isInAdminPanel) ...[
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SuggestClinicPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.lightbulb_outline),
                        label: const Text('اقتراح عيادة'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFE399),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 16),

                // أزرار الفلترة
                SizedBox(
                  height: 50,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: filterOptions.map((filterName) {
                        int index = filterOptions.indexOf(filterName);
                        return Padding(
                          padding: EdgeInsets.only(
                            left: index == filterOptions.length - 1 ? 0 : 8,
                          ),
                          child: _buildFilterButton(filterName),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : filteredClinics.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          selectedFilter == 'الكل'
                              ? 'لا توجد نتائج'
                              : 'لا توجد ${selectedFilter == 'أخرى' ? 'عناصر أخرى' : selectedFilter} متطابقة مع البحث',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                      : ListView.builder(
                    itemCount: filteredClinics.length,
                    itemBuilder: (context, index) {
                      final clinic = filteredClinics[index];
                      return Card(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 4,
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            // إذا كان widget.onClinicTap موجود، استخدمه (للـ admin panel)
                            if (widget.onClinicTap != null) {
                              widget.onClinicTap!(clinic);
                            } else {
                              // وإلا انتقل لصفحة التقييمات
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ClinicReviewsPage(clinic: clinic),
                                ),
                              );
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header row with clinic name and delete button
                                Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Delete button (only for admin)
                                    if (_isAdmin && !widget.isInAdminPanel)
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        onPressed: () async {
                                          // Show confirmation dialog
                                          bool confirm =
                                              await showDialog(
                                                context: context,
                                                builder: (BuildContext context) {
                                                  return AlertDialog(
                                                    title: const Text(
                                                      'تأكيد الحذف',
                                                    ),
                                                    content: const Text(
                                                      'هل أنت متأكد من حذف هذه العيادة؟',
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.of(
                                                              context,
                                                            ).pop(false),
                                                        child: const Text(
                                                          'إلغاء',
                                                        ),
                                                      ),
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.of(
                                                              context,
                                                            ).pop(true),
                                                        child: const Text(
                                                          'حذف',
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              ) ??
                                                  false;

                                          if (confirm) {
                                            try {
                                              await _clinicService
                                                  .deleteClinic(clinic.id);
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'تم حذف العيادة بنجاح',
                                                  ),
                                                  backgroundColor:
                                                  Colors.green,
                                                ),
                                              );
                                            } catch (e) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'حدث خطأ أثناء الحذف: ${e.toString()}',
                                                  ),
                                                  backgroundColor:
                                                  Colors.red,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                      ),

                                    // اسم العيادة والفئة
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                        children: [
                                          Align(
                                            alignment:
                                            Alignment.centerRight,
                                            child: Text(
                                              clinic.name.isNotEmpty
                                                  ? clinic.name
                                                  : 'غير محدد',
                                              textAlign: TextAlign.right,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          if (clinic.category.isNotEmpty)
                                            Padding(
                                              padding:
                                              const EdgeInsets.only(
                                                top: 4,
                                              ),
                                              child: Align(
                                                alignment:
                                                Alignment.centerRight,
                                                child: Container(
                                                  padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: _getTypeColor(
                                                      clinic.category,
                                                    ),
                                                    borderRadius:
                                                    BorderRadius.circular(
                                                      12,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    clinic.category,
                                                    textAlign:
                                                    TextAlign.right,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.white,
                                                      fontWeight:
                                                      FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Description
                                if (clinic.description != null &&
                                    clinic.description!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 12,
                                    ),
                                    child: Text(
                                      clinic.description!,
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade700,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),

                                // Clinic details in rows - Icons on the right
                                // Address
                                if (clinic.address.isNotEmpty)
                                  _buildDetailRow(
                                    Icons.location_on,
                                    clinic.address,
                                  ),
                                // Phone
                                if (clinic.phone.isNotEmpty)
                                  _buildDetailRow(
                                    Icons.phone,
                                    clinic.phone,
                                  ),
                                // Email
                                if (clinic.email.isNotEmpty)
                                  _buildDetailRow(
                                    Icons.email,
                                    clinic.email,
                                  ),
                                // Working hours
                                if (clinic.workingHours.isNotEmpty)
                                  _buildDetailRow(
                                    Icons.access_time,
                                    clinic.workingHours,
                                  ),

                                const SizedBox(height: 8),

                                // Reviews count and average rating
                                StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('reviews')
                                      .where(
                                    'clinicId',
                                    isEqualTo: clinic.id,
                                  )
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    int reviewCount = 0;
                                    double totalRating = 0;
                                    double averageRating = 0;

                                    if (snapshot.hasData) {
                                      final reviews = snapshot.data!.docs;
                                      reviewCount = reviews.length;

                                      for (var review in reviews) {
                                        final data =
                                        review.data()
                                        as Map<String, dynamic>;
                                        if (data['rating'] != null) {
                                          totalRating +=
                                              (data['rating'] as num)
                                                  .toDouble();
                                        }
                                      }

                                      if (reviewCount > 0) {
                                        averageRating =
                                            totalRating / reviewCount;
                                      }
                                    }

                                    return Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.end,
                                      children: [
                                        // Average rating
                                        if (reviewCount > 0)
                                          Container(
                                            padding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFFFFE399,
                                              ).withOpacity(0.2),
                                              borderRadius:
                                              BorderRadius.circular(20),
                                              border: Border.all(
                                                color: const Color(
                                                  0xFFFFE399,
                                                ).withOpacity(0.3),
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize:
                                              MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.star,
                                                  color: Color(0xFFFFE399),
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  averageRating
                                                      .toStringAsFixed(1),
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.black87,
                                                    fontWeight:
                                                    FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        const SizedBox(width: 8),
                                        // Review count
                                        Container(
                                          padding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFFFFE399,
                                            ).withOpacity(0.2),
                                            borderRadius:
                                            BorderRadius.circular(20),
                                            border: Border.all(
                                              color: const Color(
                                                0xFFFFE399,
                                              ).withOpacity(0.3),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.star_border,
                                                color: Color(0xFFFFE399),
                                                size: 16,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                reviewCount == 0
                                                    ? 'لا توجد تقييمات'
                                                    : reviewCount == 1
                                                    ? 'تقييم واحد'
                                                    : reviewCount == 2
                                                    ? 'تقييمان'
                                                    : '$reviewCount تقييمات',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color.fromARGB(
                                                    255,
                                                    17,
                                                    17,
                                                    17,
                                                  ),
                                                  fontWeight:
                                                  FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),        // Only show the Add Clinic button if user is admin and not in admin panel
        floatingActionButton: (_isAdmin && !widget.isInAdminPanel)
            ? FloatingActionButton(
          onPressed: () async {
            // Navigate to AddClinicPage and wait for result
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AddClinicPage(),
              ),
            );

            // Refresh the list if a clinic was added
            if (result == true) {
              _fetchClinics();
            }
          },
          backgroundColor: const Color(0xFFFFE399),
          child: const Icon(Icons.add, color: Colors.white),
        )
            : null,
      ),
    );
  }

  // A helper method to build the detail rows
  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blue.shade600, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  // دالة إنشاء أزرار الفلترة
  Widget _buildFilterButton(String filterName) {
    final bool isSelected = selectedFilter == filterName;

    return GestureDetector(
      onTap: () => _changeFilter(filterName),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFE399) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFFE399)
                : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            filterName,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }

  // دالة لإرجاع لون حسب نوع العيادة/المدرسة
  Color _getTypeColor(String category) {
    switch (category.toLowerCase()) {
      case 'عيادة':
        return Colors.blue.shade600;
      case 'مستشفى':
        return Colors.blue.shade600;
      case 'مركز طبي':
        return Colors.blue.shade600;
      case 'عيادة مختصة':
        return Colors.blue.shade600;
      case 'مدرسة':
        return Colors.blue.shade600;
      default: // أخرى
        return Colors.blue.shade600;
    }
  }
}