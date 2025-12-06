import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

// Initialize the notifications plugin globally
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

class Appointment {
  final String id;
  final String type;
  final String title;
  final int date;
  final int month;
  final int year;
  final String time;
  final String? location;
  final String? dosage;
  final String? notes;

  Appointment({
    required this.id,
    required this.type,
    required this.title,
    required this.date,
    required this.month,
    required this.year,
    required this.time,
    this.location,
    this.dosage,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'date': date,
      'month': month,
      'year': year,
      'time': time,
      'location': location,
      'dosage': dosage,
      'notes': notes,
    };
  }

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'],
      type: json['type'],
      title: json['title'],
      date: json['date'],
      month: json['month'],
      year: json['year'],
      time: json['time'],
      location: json['location'],
      dosage: json['dosage'],
      notes: json['notes'],
    );
  }
}

class Calendar extends StatefulWidget {
  const Calendar({Key? key}) : super(key: key);

  @override
  State<Calendar> createState() => _CalendarState();
}

class _CalendarState extends State<Calendar> {
  int? selectedDate;
  DateTime currentMonth = DateTime.now();
  List<Appointment> appointments = [];
  bool _notificationsInitialized = false;

  final List<String> monthNames = [
    'يناير', 'فبراير', 'مارس', 'إبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
  ];

  final List<String> weekDays = [
    'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'
  ];

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _loadAppointments();
  }

  // التحقق من إعدادات الإشعارات
  Future<bool> _areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_enabled') ?? true;
  }

  // Initialize notifications
  Future<void> _initializeNotifications() async {
    try {
      debugPrint('🔄 Starting notifications initialization...');

      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Riyadh'));

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'appointment_channel',
        'المواعيد الطبية',
        description: 'إشعارات المواعيد الطبية والأدوية',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
        ledColor: Color(0xFF81d0f0),
      );

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings =
      InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification tapped: ${response.payload}');
        },
      );

      await _requestNotificationPermissions();

      setState(() {
        _notificationsInitialized = true;
      });

      debugPrint('✅ Notifications fully initialized and ready');

    } catch (e) {
      debugPrint('❌ Error initializing notifications: $e');
    }
  }

  // Request notification permissions
  Future<void> _requestNotificationPermissions() async {
    try {
      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
        await androidPlugin.requestExactAlarmsPermission();
      }

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );

    } catch (e) {
      debugPrint('❌ Error requesting permissions: $e');
    }
  }

  // تحويل الوقت من نص إلى DateTime
  tz.TZDateTime _parseTimeToDateTime(Appointment appointment) {
    String timeString = appointment.time.trim();
    final parts = timeString.split(' ');

    final hourMinute = parts[0].split(':');
    int hour = int.parse(hourMinute[0].trim());
    int minute = int.parse(hourMinute[1].trim());
    String period = parts[1].trim();

    // Convert to 24-hour format
    if (period == 'م' && hour != 12) {
      hour += 12;
    } else if (period == 'ص' && hour == 12) {
      hour = 0;
    }

    return tz.TZDateTime(
      tz.local,
      appointment.year,
      appointment.month,
      appointment.date,
      hour,
      minute,
    );
  }

  // Schedule multiple notifications for an appointment - UPDATED VERSION
  Future<void> _scheduleNotification(Appointment appointment) async {
    try {
      // التحقق أولاً من إعدادات الإشعارات
      final notificationsEnabled = await _areNotificationsEnabled();
      if (!notificationsEnabled) {
        debugPrint('⚠️ Notifications are disabled, skipping scheduling');
        return;
      }

      // الحصول على وقت الموعد الأساسي
      final appointmentTime = _parseTimeToDateTime(appointment);
      final now = tz.TZDateTime.now(tz.local);

      // Only schedule if the time is in the future
      if (appointmentTime.isAfter(now)) {

        // جدولة 3 إشعارات لكل موعد:

        // 1. إشعار قبل الموعد بيوم كامل
        final dayBeforeTime = appointmentTime.subtract(const Duration(days: 1));
        if (dayBeforeTime.isAfter(now)) {
          await _scheduleSingleNotification(
            appointment: appointment,
            scheduledTime: dayBeforeTime,
            isReminder: true,
            reminderType: 'يوم',
          );
        }

        // 2. إشعار قبل الموعد بنصف ساعة
        final halfHourBeforeTime = appointmentTime.subtract(const Duration(minutes: 30));
        if (halfHourBeforeTime.isAfter(now)) {
          await _scheduleSingleNotification(
            appointment: appointment,
            scheduledTime: halfHourBeforeTime,
            isReminder: true,
            reminderType: 'نصف ساعة',
          );
        }

        // 3. إشعار في وقت الموعد نفسه
        await _scheduleSingleNotification(
          appointment: appointment,
          scheduledTime: appointmentTime,
          isReminder: false,
          reminderType: '',
        );

        debugPrint('✅ All notifications scheduled successfully for appointment: ${appointment.title}');
        _showSnackBar('تم جدولة التذكيرات لموعد ${appointment.title} 🔔', true);
      } else {
        debugPrint('⚠️ Appointment time is in the past, notifications not scheduled');
      }
    } catch (e) {
      debugPrint('❌ Error scheduling notifications: $e');
      _showSnackBar('خطأ في جدولة التذكيرات: $e', false);
    }
  }

  // جدولة إشعار فردي
  Future<void> _scheduleSingleNotification({
    required Appointment appointment,
    required tz.TZDateTime scheduledTime,
    required bool isReminder,
    required String reminderType,
  }) async {
    try {
      String notificationTitle = '';
      String notificationBody = '';

      if (isReminder) {
        // إشعار تذكير مسبق
        notificationTitle = '⏰ تذكير: ${appointment.title}';
        notificationBody = '''
🕒 الموعد بعد $reminderType
📅 التاريخ: ${appointment.date}/${appointment.month}/${appointment.year}
⏰ الوقت: ${appointment.time}
${appointment.type == 'hospital' && appointment.location != null ? '📍 المكان: ${appointment.location}' : ''}
${appointment.type == 'medicine' && appointment.dosage != null ? '💊 الجرعة: ${appointment.dosage}' : ''}
        ''';
      } else {
        // إشعار في وقت الموعد
        switch (appointment.type) {
          case 'hospital':
            notificationTitle = '🏥 لديك موعد طبي الآن: ${appointment.title}';
            notificationBody = '''
📍 المكان: ${appointment.location ?? 'غير محدد'}
${appointment.notes != null ? '📝 ملاحظات: ${appointment.notes}' : ''}
            ''';
            break;
          case 'medicine':
            notificationTitle = '💊 موعد دواء الآن: ${appointment.title}';
            notificationBody = '''
💊 الجرعة: ${appointment.dosage ?? 'غير محدد'}
${appointment.notes != null ? '📝 ملاحظات: ${appointment.notes}' : ''}
            ''';
            break;
          case 'reminder':
            notificationTitle = '🔔 تذكير الآن: ${appointment.title}';
            notificationBody = '''
${appointment.notes != null ? '📝 ملاحظات: ${appointment.notes}' : 'حان وقت التذكير'}
            ''';
            break;
        }
      }

      const AndroidNotificationDetails androidDetails =
      AndroidNotificationDetails(
        'appointment_channel',
        'المواعيد الطبية',
        channelDescription: 'إشعارات المواعيد الطبية والأدوية',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'تذكير بموعد',
        playSound: true,
        enableVibration: true,
        color: Color(0xFF81d0f0),
        ledColor: Color(0xFF81d0f0),
        ledOnMs: 1000,
        ledOffMs: 500,
        autoCancel: true,
        timeoutAfter: 60000,
        showWhen: true,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // إنشاء ID فريد لكل إشعار بناءً على وقت الجدولة
      final notificationId = int.parse('${appointment.id}${scheduledTime.millisecondsSinceEpoch}'.hashCode.toString().replaceAll('-', '').substring(0, 8)) % 2147483647;

      await flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        notificationTitle,
        notificationBody.trim(),
        scheduledTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        payload: '${appointment.id}_${isReminder ? 'reminder' : 'appointment'}',
      );

      debugPrint('✅ ${isReminder ? 'Reminder' : 'Appointment'} notification scheduled for: $scheduledTime');

    } catch (e) {
      debugPrint('❌ Error scheduling single notification: $e');
    }
  }

  // Cancel all notifications for an appointment
  Future<void> _cancelNotification(String appointmentId) async {
    try {
      // إلغاء جميع الإشعارات المرتبطة بهذا الموعد
      // نستخدم cancelAll ثم نعيد جدولة باقي المواعيد
      await flutterLocalNotificationsPlugin.cancelAll();

      // إعادة جدولة جميع المواعيد المتبقية
      for (final apt in appointments) {
        if (apt.id != appointmentId) {
          await _scheduleNotification(apt);
        }
      }

      debugPrint('✅ All notifications cancelled and rescheduled for appointment: $appointmentId');
    } catch (e) {
      debugPrint('❌ Error cancelling notifications: $e');
    }
  }

  String? get currentUserId {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid;
  }

  Future<void> _loadAppointments() async {
    if (currentUserId == null) {
      setState(() {
        appointments = [];
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final String? appointmentsJson = prefs.getString('appointments_$currentUserId');

    if (appointmentsJson != null) {
      final List<dynamic> decoded = json.decode(appointmentsJson);
      setState(() {
        appointments = decoded.map((item) => Appointment.fromJson(item)).toList();
      });
    }
  }

  Future<void> _saveAppointments() async {
    if (currentUserId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final String encoded = json.encode(
      appointments.map((apt) => apt.toJson()).toList(),
    );
    await prefs.setString('appointments_$currentUserId', encoded);
  }

  Future<void> _addAppointment(Appointment appointment) async {
    setState(() {
      appointments.add(appointment);
    });
    await _saveAppointments();

    // Schedule notifications for the new appointment
    await _scheduleNotification(appointment);
  }

  Future<void> _updateAppointment(Appointment updatedAppointment) async {
    setState(() {
      final index = appointments.indexWhere((apt) => apt.id == updatedAppointment.id);
      if (index != -1) {
        appointments[index] = updatedAppointment;
      }
    });
    await _saveAppointments();

    // Cancel old notifications and schedule new ones
    await _cancelNotification(updatedAppointment.id);
    await _scheduleNotification(updatedAppointment);
  }

  Future<void> _deleteAppointment(String id) async {
    setState(() {
      appointments.removeWhere((apt) => apt.id == id);
    });
    await _saveAppointments();

    // Cancel notifications for deleted appointment
    await _cancelNotification(id);
  }

  // باقي الدوال تبقى كما هي...
  List<int?> getDaysInMonth(DateTime date) {
    final year = date.year;
    final month = date.month;
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final daysInMonth = lastDay.day;
    final startingDayOfWeek = firstDay.weekday % 7;

    final List<int?> days = [];

    for (int i = 0; i < startingDayOfWeek; i++) {
      days.add(null);
    }

    for (int day = 1; day <= daysInMonth; day++) {
      days.add(day);
    }

    return days;
  }

  void goToPreviousMonth() {
    setState(() {
      currentMonth = DateTime(currentMonth.year, currentMonth.month - 1);
    });
  }

  void goToNextMonth() {
    setState(() {
      currentMonth = DateTime(currentMonth.year, currentMonth.month + 1);
    });
  }

  bool hasAppointment(int? day) {
    if (day == null) return false;
    return appointments.any((apt) =>
    apt.date == day &&
        apt.month == currentMonth.month &&
        apt.year == currentMonth.year
    );
  }

  List<Appointment> getAppointmentsForCurrentMonth() {
    return appointments.where((apt) =>
    apt.month == currentMonth.month &&
        apt.year == currentMonth.year
    ).toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Widget build(BuildContext context) {
    final days = getDaysInMonth(currentMonth);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
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
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth > 900) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildCalendarCard(days),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 1,
                              child: _buildAppointmentsList(),
                            ),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            _buildCalendarCard(days),
                            const SizedBox(height: 16),
                            _buildAppointmentsList(),
                          ],
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFF81d0f0), Color(0xFFecc471), Color(0xFFe05650)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.calendar_today, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              'تقويم المواعيد',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'نظم مواعيدك الطبية بسهولة مع التذكيرات التلقائية',
          style: TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 16),

        // مؤشر حالة الإشعارات - تم تبسيطه


      ],
    );
  }

  // باقي الـ widgets تبقى كما هي...
  Widget _buildCalendarCard(List<int?> days) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNavButton(Icons.chevron_right, goToPreviousMonth),
              Text(
                '${monthNames[currentMonth.month - 1]} ${currentMonth.year}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              _buildNavButton(Icons.chevron_left, goToNextMonth),
            ],
          ),
          const SizedBox(height: 24),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 2.0,
            ),
            itemCount: 7,
            itemBuilder: (context, index) {
              return Center(
                child: Text(
                  weekDays[index],
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final day = days[index];
              if (day == null) return const SizedBox.shrink();

              final isSelected = selectedDate == day;
              final hasAppt = hasAppointment(day);

              return InkWell(
                onTap: () {
                  setState(() => selectedDate = day);
                },
                onLongPress: () {
                  _showAddAppointmentDialog(preSelectedDay: day);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: isSelected
                        ? const LinearGradient(
                      colors: [Color(0xFF81d0f0), Color(0xFFecc471)],
                    )
                        : null,
                    color: isSelected ? null : const Color(0xFFF9FAFB),
                    border: hasAppt && !isSelected
                        ? Border.all(color: const Color(0xFFecc471), width: 2)
                        : null,
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? Colors.white : const Color(0xFF374151),
                          ),
                        ),
                      ),
                      if (hasAppt)
                        Positioned(
                          bottom: 4,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFFe05650),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          InkWell(
            onTap: () => _showAddAppointmentDialog(preSelectedDay: selectedDate),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF81d0f0), Color(0xFFecc471), Color(0xFFe05650)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'إضافة موعد جديد',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(IconData icon, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFecc471).withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: const Color(0xFFecc471),
          size: 20,
        ),
      ),
    );
  }

  Widget _buildAppointmentsList() {
    final monthAppointments = getAppointmentsForCurrentMonth();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.notifications_active, color: Color(0xFFecc471), size: 20),
              SizedBox(width: 8),
              Text(
                'المواعيد القادمة',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (monthAppointments.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  'لا توجد مواعيد في هذا الشهر',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else
            ...monthAppointments.map((apt) => _buildAppointmentCard(apt)),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(Appointment apt) {
    final isHospital = apt.type == 'hospital';
    final isMedicine = apt.type == 'medicine';

    Color bgColor;
    Color borderColor;
    Color iconBg;
    IconData icon;

    if (isHospital) {
      bgColor = const Color(0xFF81d0f0).withOpacity(0.12);
      borderColor = const Color(0xFF81d0f0);
      iconBg = const Color(0xFF81d0f0);
      icon = Icons.local_hospital;
    } else if (isMedicine) {
      bgColor = const Color(0xFF9b81e6).withOpacity(0.12);
      borderColor = const Color(0xFF9b81e6);
      iconBg = const Color(0xFF9b81e6);
      icon = Icons.medication;
    } else {
      bgColor = const Color(0xFFe05650).withOpacity(0.12);
      borderColor = const Color(0xFFe05650);
      iconBg = const Color(0xFFe05650);
      icon = Icons.notifications;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  apt.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 12, color: Color(0xFF6B7280)),
                    const SizedBox(width: 4),
                    Text(
                      '${apt.date} ${monthNames[apt.month - 1]} • ${apt.time}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
                if (apt.location != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    apt.location!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
                if (apt.dosage != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    apt.dosage!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFF6B7280)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              if (value == 'edit') {
                _showEditAppointmentDialog(apt);
              } else if (value == 'delete') {
                _showDeleteConfirmation(apt);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 18, color: Color(0xFF6B7280)),
                    SizedBox(width: 8),
                    Text('تعديل'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 18, color: Color(0xFFe05650)),
                    SizedBox(width: 8),
                    Text('حذف', style: TextStyle(color: Color(0xFFe05650))),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddAppointmentDialog({int? preSelectedDay}) {
    _showAppointmentDialog(null, preSelectedDay: preSelectedDay);
  }

  void _showEditAppointmentDialog(Appointment apt) {
    _showAppointmentDialog(apt);
  }

  void _showAppointmentDialog(Appointment? existingAppointment, {int? preSelectedDay}) {
    final isEditing = existingAppointment != null;

    final titleController = TextEditingController(text: existingAppointment?.title ?? '');
    final locationController = TextEditingController(text: existingAppointment?.location ?? '');
    final dosageController = TextEditingController(text: existingAppointment?.dosage ?? '');
    final notesController = TextEditingController(text: existingAppointment?.notes ?? '');
    final timeController = TextEditingController(text: existingAppointment?.time ?? '10:00 ص');

    String selectedType = existingAppointment?.type ?? 'hospital';
    int selectedDay = existingAppointment?.date ?? preSelectedDay ?? DateTime.now().day;
    String selectedTime = existingAppointment?.time ?? '10:00 ص';

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? 'تعديل الموعد' : 'إضافة موعد جديد',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.9,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Notification info banner - تم تحديث النص
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF81d0f0).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF81d0f0).withOpacity(0.3),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.notifications_active,
                                color: Color(0xFF81d0f0), size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                ' لتفعيل زر الإشعارات، انتقل إلى "الحساب" ثم اضغط على زر الإشعارات',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF374151),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // نوع الموعد
                      const Text(
                        'نوع الموعد',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildTypeChip(
                            'hospital',
                            'طبي',
                            Icons.local_hospital,
                            selectedType == 'hospital',
                                () => setDialogState(() => selectedType = 'hospital'),
                          ),
                          _buildTypeChip(
                            'medicine',
                            'دواء',
                            Icons.medication,
                            selectedType == 'medicine',
                                () => setDialogState(() => selectedType = 'medicine'),
                          ),
                          _buildTypeChip(
                            'reminder',
                            'تذكير',
                            Icons.notifications,
                            selectedType == 'reminder',
                                () => setDialogState(() => selectedType = 'reminder'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // عنوان الموعد
                      _buildTextField(
                        controller: titleController,
                        label: 'عنوان الموعد',
                        hint: 'مثال: موعد مع د. أحمد',
                        icon: Icons.title,
                      ),
                      const SizedBox(height: 16),

                      // اليوم
                      const Text(
                        'اليوم',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: DropdownButton<int>(
                          value: selectedDay,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: List.generate(
                            DateTime(currentMonth.year, currentMonth.month + 1, 0).day,
                                (index) => DropdownMenuItem(
                              value: index + 1,
                              child: Text('${index + 1}'),
                            ),
                          ),
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => selectedDay = value);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // الوقت
                      const Text(
                        'الوقت',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () {
                          _showTimePicker(context, timeController, (newTime) {
                            setDialogState(() {
                              selectedTime = newTime;
                              timeController.text = newTime;
                            });
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time, color: Color(0xFFecc471)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  timeController.text.isEmpty ? 'اختر الوقت' : timeController.text,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: timeController.text.isEmpty
                                        ? const Color(0xFF9CA3AF)
                                        : const Color(0xFF374151),
                                  ),
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down, color: Color(0xFF6B7280)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // المكان (للمواعيد الطبية)
                      if (selectedType == 'hospital') ...[
                        _buildTextField(
                          controller: locationController,
                          label: 'المكان',
                          hint: 'مثال: مستشفى الملك فيصل',
                          icon: Icons.location_on,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // الجرعة (للأدوية)
                      if (selectedType == 'medicine') ...[
                        _buildTextField(
                          controller: dosageController,
                          label: 'الجرعة',
                          hint: 'مثال: مرة يومياً',
                          icon: Icons.medical_services,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ملاحظات
                      _buildTextField(
                        controller: notesController,
                        label: 'ملاحظات (اختياري)',
                        hint: 'أضف ملاحظات إضافية...',
                        icon: Icons.notes,
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'إلغاء',
                    style: TextStyle(color: Color(0xFF6B7280)),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (titleController.text.isEmpty) {
                      // Show warning dialog instead of snackbar
                      showDialog(
                        context: context,
                        builder: (context) => Directionality(
                          textDirection: TextDirection.rtl,
                          child: AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            title: const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    color: Color(0xFFe05650), size: 28),
                                SizedBox(width: 8),
                                Text(
                                  'عنوان الموعد مطلوب',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFe05650).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFe05650).withOpacity(0.3),
                                    ),
                                  ),
                                  child: const Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '⚠️ يجب إدخال عنوان للموعد',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF374151),
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'العنوان مهم لتمييز الموعد وظهوره بشكل واضح في التذكيرات',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              ],
                            ),
                            actions: [
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF81d0f0),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                                child: const Text(
                                  'فهمت',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                      return;
                    }
                    final appointment = Appointment(
                      id: existingAppointment?.id ??
                          DateTime.now().millisecondsSinceEpoch.toString(),
                      type: selectedType,
                      title: titleController.text,
                      date: selectedDay,
                      month: currentMonth.month,
                      year: currentMonth.year,
                      time: selectedTime,
                      location: locationController.text.isEmpty ? null : locationController.text,
                      dosage: dosageController.text.isEmpty ? null : dosageController.text,
                      notes: notesController.text.isEmpty ? null : notesController.text,
                    );

                    if (isEditing) {
                      _updateAppointment(appointment);
                    } else {
                      _addAppointment(appointment);
                    }

                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              isEditing
                                  ? 'تم تعديل الموعد وجدولة التذكيرات'
                                  : 'تم إضافة الموعد وجدولة التذكيرات',
                            ),
                          ],
                        ),
                        backgroundColor: const Color(0xFF81d0f0),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF81d0f0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: Text(
                    isEditing ? 'تحديث' : 'إضافة',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTypeChip(
      String type,
      String label,
      IconData icon,
      bool isSelected,
      VoidCallback onTap,
      ) {
    Color color;
    if (type == 'hospital') {
      color = const Color(0xFF81d0f0);
    } else if (type == 'medicine') {
      color = const Color(0xFF9b81e6);
    } else {
      color = const Color(0xFFe05650);
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : color,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: const Color(0xFFecc471)),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFecc471), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  void _showTimePicker(BuildContext context, TextEditingController controller, Function(String) onTimeSelected) {
    // استخراج القيم الحالية أو استخدام القيم الافتراضية
    int selectedHour = 10;
    int selectedMinute = 0;
    String selectedPeriod = 'ص';

    if (controller.text.isNotEmpty) {
      try {
        final parts = controller.text.split(' ');
        final timeParts = parts[0].split(':');
        selectedHour = int.parse(timeParts[0]);
        selectedMinute = int.parse(timeParts[1]);
        selectedPeriod = parts[1];
      } catch (e) {
        debugPrint('Error parsing time: $e');
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setPickerState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.5,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'اختر الوقت',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Time Picker Wheels
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // الساعة
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListWheelScrollView.useDelegate(
                              itemExtent: 50,
                              diameterRatio: 1.5,
                              physics: const FixedExtentScrollPhysics(),
                              onSelectedItemChanged: (index) {
                                setPickerState(() {
                                  selectedHour = index + 1;
                                });
                              },
                              controller: FixedExtentScrollController(
                                initialItem: selectedHour - 1,
                              ),
                              childDelegate: ListWheelChildBuilderDelegate(
                                builder: (context, index) {
                                  final hour = index + 1;
                                  final isSelected = hour == selectedHour;
                                  return Center(
                                    child: Text(
                                      hour.toString().padLeft(2, '0'),
                                      style: TextStyle(
                                        fontSize: isSelected ? 32 : 24,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        color: isSelected ? const Color(0xFF81d0f0) : const Color(0xFF6B7280),
                                      ),
                                    ),
                                  );
                                },
                                childCount: 12,
                              ),
                            ),
                          ),
                        ),

                        // النقطتين
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            ':',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF374151),
                            ),
                          ),
                        ),

                        // الدقائق
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListWheelScrollView.useDelegate(
                              itemExtent: 50,
                              diameterRatio: 1.5,
                              physics: const FixedExtentScrollPhysics(),
                              onSelectedItemChanged: (index) {
                                setPickerState(() {
                                  selectedMinute = index;
                                });
                              },
                              controller: FixedExtentScrollController(
                                initialItem: selectedMinute,
                              ),
                              childDelegate: ListWheelChildBuilderDelegate(
                                builder: (context, index) {
                                  final isSelected = index == selectedMinute;
                                  return Center(
                                    child: Text(
                                      index.toString().padLeft(2, '0'),
                                      style: TextStyle(
                                        fontSize: isSelected ? 32 : 24,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        color: isSelected ? const Color(0xFF81d0f0) : const Color(0xFF6B7280),
                                      ),
                                    ),
                                  );
                                },
                                childCount: 60,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 16),

                        // صباح/مساء
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          width: 80,
                          child: ListWheelScrollView(
                            itemExtent: 50,
                            diameterRatio: 1.5,
                            physics: const FixedExtentScrollPhysics(),
                            onSelectedItemChanged: (index) {
                              setPickerState(() {
                                selectedPeriod = index == 0 ? 'ص' : 'م';
                              });
                            },
                            controller: FixedExtentScrollController(
                              initialItem: selectedPeriod == 'ص' ? 0 : 1,
                            ),
                            children: ['ص', 'م'].map((period) {
                              final isSelected = period == selectedPeriod;
                              return Center(
                                child: Text(
                                  period,
                                  style: TextStyle(
                                    fontSize: isSelected ? 32 : 24,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? const Color(0xFF81d0f0) : const Color(0xFF6B7280),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // عرض الوقت المختار
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF81d0f0).withOpacity(0.1),
                          const Color(0xFFecc471).withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF81d0f0).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.access_time, color: Color(0xFF81d0f0)),
                        const SizedBox(width: 8),
                        Text(
                          'الوقت المختار: ${selectedHour.toString().padLeft(2, '0')}:${selectedMinute.toString().padLeft(2, '0')} $selectedPeriod',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // زر التأكيد
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final formattedTime = '${selectedHour.toString().padLeft(2, '0')}:${selectedMinute.toString().padLeft(2, '0')} $selectedPeriod';
                        onTimeSelected(formattedTime);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF81d0f0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                      ),
                      child: const Text(
                        'تأكيد الوقت',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Appointment apt) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFe05650)),
              SizedBox(width: 8),
              Text(
                'تأكيد الحذف',
                style: TextStyle(fontSize: 20),
              ),
            ],
          ),
          content: Text(
            'هل أنت متأكد من حذف الموعد "${apt.title}"؟\n\nسيتم إلغاء جميع التذكيرات المجدولة.',
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'إلغاء',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                _deleteAppointment(apt.id);
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 8),
                        Text('تم حذف الموعد وإلغاء التذكيرات'),
                      ],
                    ),
                    backgroundColor: Color(0xFFe05650),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFe05650),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'حذف',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // دالة مساعدة لعرض SnackBar
  void _showSnackBar(String message, bool isSuccess) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isSuccess ? Icons.check_circle : Icons.error,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: isSuccess ? const Color(0xFF81d0f0) : const Color(0xFFe05650),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}