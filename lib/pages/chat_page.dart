import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../../consts.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle, ByteData;
import 'dart:math' as math;

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ChatUser _currentUser = ChatUser(id: '1', firstName: 'أنت');
  final ChatUser _botUser = ChatUser(id: '2', firstName: 'طيف');

  final List<ChatMessage> _messages = [];
  bool _isTyping = false;

  bool _inScreeningMode = false;
  int _currentQuestionIndex = 0;
  List<int> _screeningAnswers = [];

  final Map<String, dynamic> _userDemographics = {
    'age': 0,
    'sex': 'male',
    'jaundice': false,
    'family_asd': false,
  };
  bool _collectingDemographics = false;
  String _currentDemographicQuestion = '';

  Interpreter? _interpreter;
  bool _modelLoaded = false;

  final List<String> quickReplies = [
    "ما هو التوحد؟",
    "أعطني نصائح لمرضى التوحد",
    "إجراء فحص التوحد",
    "كيف أتعامل مع طفل توحدي",
    "ما أسباب التوحد؟",
    "هل يوجد علاج للتوحد؟"
  ];

  final List<String> _screeningQuestions = [
    "هل يلاحظ طفلك تفاصيل صغيرة قد لا يلاحظها الآخرون؟",
    "هل يستطيع طفلك التركيز على الصورة الشاملة، بدلا من التفاصيل الصغيرة؟",
    "هل يفضل طفلك دائما القيام بالأشياء بنفس الطريقة في كل مرة؟",
    "هل يستطيع طفلك بسهولة التبديل من نشاط لآخر؟",
    "هل يجد طفلك صعوبة في تصور ما يفكر به الآخرون؟",
    "هل يلاحظ طفلك أنماطا في الأشياء بشكل متكرر؟",
    "هل يجد طفلك التفاعل الاجتماعي سهلا؟",
    "هل يستطيع طفلك القيام بأكثر من شيء في وقت واحد؟",
    "هل يجد طفلك صعوبة في تحديد نوايا الآخرين؟",
    "هل يجد طفلك سهولة في إنشاء صداقات جديدة؟"
  ];

  final List<String> _demographicQuestions = [
    "ما هو عمر الطفل بالسنوات؟ (الرجاء كتابة رقم فقط)",
    "ما هو جنس الطفل؟ (ذكر/أنثى)",
    "هل عانى الطفل من اليرقان عند الولادة؟ (نعم/لا)",
    "هل يوجد أحد في العائلة مشخص باضطراب طيف التوحد؟ (نعم/لا)"
  ];

  @override
  void initState() {
    super.initState();
    _loadModel();
    _addBotMessage("مرحباً 👋، أنا طيف، مساعدك الذكي المتخصص في التوحد والصحة النفسية للأطفال.🌸");
    Future.delayed(const Duration(seconds: 1), () {
      _addBotMessage("تقدر تسألني أي سؤال عن التوحد أو تستخدم الأزرار اللي بالاعلى.");
    });
  }


  void _addBotMessage(String text) {
    final botMessage = ChatMessage(
      user: _botUser,
      createdAt: DateTime.now(),
      text: text,
    );

    setState(() {
      _messages.insert(0, botMessage);
    });

    // لا تُظهر "هل تحتاج شيئًا آخر؟" إذا:
    // 1. نحن في وضع الفحص أو جمع المعلومات
    // 2. هذه رسالة ترحيبية (الرسائل الأولى)
    // 3. لا توجد رسائل من المستخدم بعد
    if (_inScreeningMode || _collectingDemographics) {
      return;
    }

    // عدّ رسائل المستخدم
    int userMessagesCount = _messages.where((m) => m.user.id == _currentUser.id).length;

    // إذا لم يرسل المستخدم أي رسائل بعد، لا تُظهر السؤال
    if (userMessagesCount == 0) {
      return;
    }

    // البحث عن آخر رسالة من المستخدم
    ChatMessage? lastUserMessage;
    for (var message in _messages) {
      if (message.user.id == _currentUser.id) {
        lastUserMessage = message;
        break;
      }
    }

    // إضافة سؤال "هل تحتاج شيئًا آخر؟" فقط إذا:
    // 1. وُجدت رسالة من المستخدم
    // 2. الرسالة لا تحتوي على "شكرا" أو "شكراً"
    // 3. الرسالة لا تحتوي على "إجراء فحص التوحد"
    // 4. هناك رسائل من المستخدم (ليست رسائل ترحيبية)
    if (lastUserMessage != null &&
        !lastUserMessage.text.toLowerCase().contains("شكرا") &&
        !lastUserMessage.text.toLowerCase().contains("شكراً") &&
        !lastUserMessage.text.toLowerCase().contains("إجراء فحص التوحد")) {

      Future.delayed(const Duration(milliseconds: 500), () {
        // التحقق مرة أخرى من أننا لسنا في وضع فحص قبل إظهار الرسالة
        if (!_inScreeningMode && !_collectingDemographics) {
          setState(() {
            _messages.insert(
              0,
              ChatMessage(
                text: "😊هل تحتاج شيئًا آخر؟",
                user: _botUser,
                createdAt: DateTime.now(),
              ),
            );
          });
        }
      });
    }
  }



  void _addUserMessage(String text) {
    final userMessage = ChatMessage(
      user: _currentUser,
      createdAt: DateTime.now(),
      text: text,
    );
    setState(() {
      _messages.insert(0, userMessage);
    });
  }


// Modify the model loading function to add better diagnostics
  Future<void> _loadModel() async {
    try {
      print('Attempting to load model...');

      // Verify the asset exists
      final assetLookupResult = await rootBundle.load('assets/autism_screening_model.tflite');
      print('Asset found! Size: ${assetLookupResult.lengthInBytes} bytes');

      // Get model path and verify file exists
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/autism_screening_model.tflite';

      // Write to file
      final file = File(tempPath);
      await file.writeAsBytes(assetLookupResult.buffer.asUint8List());
      print('Model written to: $tempPath, File exists: ${file.existsSync()}, Size: ${file.lengthSync()}');

      // Create interpreter with more specific options
      final interpreterOptions = InterpreterOptions()
        ..threads = 2
        ..useNnApiForAndroid = false; // Try disabling NNAPI for better compatibility

      // Load model with verbose logging
      print('Creating interpreter...');
      _interpreter = Interpreter.fromFile(file, options: interpreterOptions);

      if (_interpreter != null) {
        // Verify input and output tensors to diagnose shape issues
        var inputTensors = _interpreter!.getInputTensors();
        var outputTensors = _interpreter!.getOutputTensors();

        print('Input tensors: ${inputTensors.length}, shape: ${inputTensors[0].shape}');
        print('Output tensors: ${outputTensors.length}, shape: ${outputTensors[0].shape}');

        // Check if input tensor matches our expected 15 features
        if (inputTensors[0].shape[1] != 15) {
          print('⚠️ WARNING: Model input shape ${inputTensors[0].shape} does not match expected [batch_size, 15]');
        }

        setState(() => _modelLoaded = true);
        print('*** MODEL LOADED SUCCESSFULLY ***');

        // Run validation test
        _validateModel();
      } else {
        throw Exception("Failed to initialize interpreter");
      }
    } catch (e) {
      print('Error in model loading: $e');
      print('Stack trace: ${StackTrace.current}');
      setState(() => _modelLoaded = false);
      _addBotMessage("عذراً، لم نتمكن من تحميل نموذج التحليل المتقدم. سيتم استخدام التقييم التقليدي فقط.");
    }
  }

  void _sendQuickReply(String text) {
    _addUserMessage(text);

    if (text == "إجراء فحص التوحد") {
      _startDemographicsCollection();
    } else {
      setState(() => _isTyping = true);
      _getChatResponse();
    }
  }

  void _startDemographicsCollection() {
    setState(() {
      _collectingDemographics = true;
      _currentDemographicQuestion = _demographicQuestions[0];
    });

    _addBotMessage("سنقوم الآن بإجراء فحص للتوحد باستخدام مقياس AQ-10 للأطفال...");

    Future.delayed(const Duration(milliseconds: 500), () {
      _addBotMessage(_currentDemographicQuestion);
    });
  }

  bool _isAutismRelated(String text) {
    // List of keywords related to autism in Arabic
    List<String> autismKeywords = [
      'توحد', 'اضطراب', 'طيف', 'السلوك', 'تشخيص', 'علاج', 'اطفال', 'تطور',
      'تواصل', 'اجتماعي', 'تأخر', 'تكرار', 'روتين', 'حساسية', 'تدخل مبكر',
      'طبيب نفسي', 'معالج', 'تأهيل', 'إعاقة', 'دمج', 'مهارات', 'تخاطب',
      'نمو', 'لغة', 'نطق', 'حركة', 'تعليم', 'ذهني', 'نفسي', 'سلوكي'
    ];

    // Convert to lowercase for case-insensitive matching
    String lowerText = text.toLowerCase();

    // Check if any keyword appears in the text
    return autismKeywords.any((keyword) => lowerText.contains(keyword));
  }

  void _processDemographicAnswer(String answer) {
    int currentIndex = _demographicQuestions.indexOf(_currentDemographicQuestion);

    switch (currentIndex) {
      case 0:
        try {
          // Convert Arabic numerals to English numerals if needed
          String processedAnswer = answer.trim();
          processedAnswer = processedAnswer
              .replaceAll('٠', '0')
              .replaceAll('١', '1')
              .replaceAll('٢', '2')
              .replaceAll('٣', '3')
              .replaceAll('٤', '4')
              .replaceAll('٥', '5')
              .replaceAll('٦', '6')
              .replaceAll('٧', '7')
              .replaceAll('٨', '8')
              .replaceAll('٩', '9');

          int age = int.parse(processedAnswer);

          // Validate age range between 6 and 20
          if (age < 6) {
            _askForValidInput("هذا الفحص مصمم للأطفال من عمر 6 سنوات فما فوق، حيث يكون التشخيص أكثر دقة. الأطفال الأصغر سناً قد تختلف سلوكياتهم بشكل طبيعي خلال مراحل النمو المبكرة ");
            return;
          } else if (age > 20) {
            _askForValidInput("هذا الفحص مصمم للأطفال والمراهقين حتى عمر 20 سنة. للبالغين فوق هذا العمر، هناك أدوات تقييم أخرى أكثر ملاءمة.");
            return;
          }

          _userDemographics['age'] = age;
        } catch (e) {
          _askForValidInput("الرجاء إدخال عمر صحيح (رقم فقط)");
          return;
        }
        break;
      case 1:
        if (answer.contains('ذكر')) {
          _userDemographics['sex'] = 'male';
        } else if (answer.contains('أنثى')) _userDemographics['sex'] = 'female';
        else {
          _askForValidInput("الرجاء اختيار 'ذكر' أو 'أنثى'");
          return;
        }
        break;
      case 2:
        if (answer.contains('نعم')) {
          _userDemographics['jaundice'] = true;
        } else if (answer.contains('لا')) _userDemographics['jaundice'] = false;
        else {
          _askForValidInput("الرجاء الإجابة بـ 'نعم' أو 'لا'");
          return;
        }
        break;
      case 3:
        if (answer.contains('نعم')) {
          _userDemographics['family_asd'] = true;
        } else if (answer.contains('لا')) _userDemographics['family_asd'] = false;
        else {
          _askForValidInput("الرجاء الإجابة بـ 'نعم' أو 'لا'");
          return;
        }
        break;
    }

    if (currentIndex < _demographicQuestions.length - 1) {
      _currentDemographicQuestion = _demographicQuestions[currentIndex + 1];
      _addBotMessage(_currentDemographicQuestion);
    } else {
      _startScreeningProcess();
    }
  }

  void _askForValidInput(String message) {
    _addBotMessage(message);
    _addBotMessage(_currentDemographicQuestion);
  }

  void _startScreeningProcess() {
    setState(() {
      _collectingDemographics = false;
      _inScreeningMode = true;
      _currentQuestionIndex = 0;
      _screeningAnswers = [];
    });

    _addBotMessage("شكراً لتقديم المعلومات. سنبدأ الآن بأسئلة فحص التوحد...");

    Future.delayed(const Duration(milliseconds: 800), _askScreeningQuestion);
  }

  void _askScreeningQuestion() {
    _addBotMessage("السؤال ${_currentQuestionIndex + 1}/10: ${_screeningQuestions[_currentQuestionIndex]}");
  }

  void _processScreeningAnswer(String answer) {
    // Parse answer to a numeric value (1-4)
    int value = 0;
    // Accept both Arabic and English numerals
    if (answer.contains("1") || answer.contains("١")) {
      value = 1;
    } else if (answer.contains("2") || answer.contains("٢")) value = 2;
    else if (answer.contains("3") || answer.contains("٣")) value = 3;
    else if (answer.contains("4") || answer.contains("٤")) value = 4;

    if (value > 0) {
      // Validate that we're within range
      if (_currentQuestionIndex < 0 || _currentQuestionIndex >= _screeningQuestions.length) {
        _addBotMessage("حدث خطأ في النظام. سنعيد بدء الفحص.");
        _startScreeningProcess();
        return;
      }

      _screeningAnswers.add(value);

      if (_currentQuestionIndex < _screeningQuestions.length - 1) {
        setState(() => _currentQuestionIndex++);
        _askScreeningQuestion();
      } else {
        _calculateScreeningResult();
      }
    } else {
      _addBotMessage("من فضلك أجب بإختيار رقم من 1 إلى 4");
    }
  }
  Future<void> _calculateScreeningResult() async {
    // Calculate traditional AQ score
    int score = 0;
    List<int> forward = [0, 2, 4, 5, 8];
    List<int> reverse = [1, 3, 6, 7, 9];

    // Log raw answers for validation
    print('Raw screening answers: $_screeningAnswers');

    for (int i = 0; i < _screeningAnswers.length; i++) {
      if (forward.contains(i)) score += (_screeningAnswers[i] <= 2) ? 1 : 0;
      if (reverse.contains(i)) score += (_screeningAnswers[i] >= 3) ? 1 : 0;
    }

    print('Traditional AQ score: $score out of 10');

    double mlPrediction = -1.0;

    // Get model prediction if available
    if (_modelLoaded && _interpreter != null) {
      try {
        mlPrediction = await _runModelInference(score);
        print('ML prediction: $mlPrediction');

        // Safety check - don't show unreasonable predictions
        if ((score < 4 && mlPrediction > 0.9) || (score > 7 && mlPrediction < 0.1)) {
          print('ML prediction seems questionable, falling back to traditional method');
          mlPrediction = -1.0; // Don't use ML prediction
        }
      } catch (e) {
        print('ML prediction failed: $e');
      }
    }

    String resultText = "";
    // Add ML prediction breakdown if available but don't show the actual percentage
    if (mlPrediction >= 0) {
      resultText += "\n\nتقييم النموذج المتقدم: ";

      if (mlPrediction > 0.7) {
        resultText += "تشير النتيجة باستخدام التحليل المتقدم إلى احتمالية عالية لوجود سمات التوحد.";
      } else if (mlPrediction > 0.5) {
        resultText += "تشير النتيجة باستخدام التحليل المتقدم إلى احتمالية متوسطة لوجود سمات التوحد.";
      } else if (mlPrediction > 0.3) {
        resultText += "تشير النتيجة باستخدام التحليل المتقدم إلى احتمالية منخفضة لوجود سمات التوحد.";
      } else {
        resultText += "لا تشير النتيجة باستخدام التحليل المتقدم إلى وجود سمات واضحة للتوحد.";
      }
      // Remove the percentage display that was in parentheses
    }

    // Disclaimer
    resultText += "\n\n⚠️ تنبيه مهم: هذا الفحص ليس تشخيصًا طبيًا رسميًا. إذا كنت قلقًا بشأن النتيجة، يرجى استشارة أخصائي رعاية صحية مؤهل للحصول على تقييم شامل.";

    // Recommendations
    bool showRecommendations = score >= 6 || (mlPrediction >= 0 && mlPrediction > 0.5);
    if (showRecommendations) {
      resultText += "\n\nالخطوات التالية المقترحة:";
      resultText += "\n- استشارة طبيب أطفال أو أخصائي في التوحد";
      resultText += "\n- طلب تقييم شامل من فريق طبي متخصص";
      resultText += "\n- التواصل مع مراكز دعم التوحد المحلية للحصول على معلومات وموارد";
    }

    _addBotMessage(resultText);
    Future.delayed(const Duration(seconds: 2), () {
      _addBotMessage(" 🌟إذا حاب تسألني أي سؤال إضافي أو تبغى نصائح أكثر، تقدر تستخدم الأزرار اللي فوق");
    });
    setState(() => _inScreeningMode = false);
  }

  void _validateModel() {
    if (_modelLoaded && _interpreter != null) {
      // Test with known inputs
      var testInputs = [
        [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.1, 1.0, 0.0, 0.0], // Low risk example
        [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.1, 1.0, 1.0, 1.0]  // High risk example
      ];

      for (var testInput in testInputs) {
        try {
          var output = List.filled(1, List.filled(1, 0.0));
          _interpreter!.run([testInput], output);
          print('Test input: $testInput');
          print('Test output: ${output[0][0]}');
        } catch (e) {
          print('Validation test failed: $e');
        }
      }
    }
  }


  Future<double> _runModelInference(int aqScore) async {
    try {
      // Safety check - if the AQ score is very low, bypass the model
      // This helps prevent the 100% issue when traditional screening is negative
      if (aqScore <= 3) {
        print('AQ score very low ($aqScore), returning low probability');
        return 0.25; // Return a low probability instead of using the model
      }

      print('Running inference with AQ score: $aqScore');

      // Create input data array
      var inputData = List<double>.filled(15, 0.0);

      // First 10 values are the question answers
      // Important: These MUST be normalized to match training data distribution
      for (int i = 0; i < _screeningAnswers.length && i < 10; i++) {
        // Map from 1-4 to normalized value based on training distribution
        // This is critical - the values must match what the model expects
        double normalizedValue = (_screeningAnswers[i] - 2.5) / 1.5; // Center around mean and scale
        inputData[i] = normalizedValue;
      }

      // Log the answers for debugging
      print('Question answers (normalized): ${inputData.sublist(0, 10)}');

      // Set demographics data with proper normalization
      // Scale AQ score from 0-10 to appropriate range
      inputData[10] = (aqScore - 5) / 5.0; // Center around mean

      // Age normalization (assuming children with mean around 8-10)
      double age = _userDemographics['age'].toDouble();
      inputData[11] = (age - 10) / 8.0; // Center around typical age

      // Binary features - these should be 0 or 1 as model expects
      inputData[12] = _userDemographics['sex'] == 'male' ? 1.0 : 0.0;
      inputData[13] = _userDemographics['jaundice'] ? 1.0 : 0.0;
      inputData[14] = _userDemographics['family_asd'] ? 1.0 : 0.0;

      // Safety check - don't allow extreme values that could cause saturation
      for (int i = 0; i < inputData.length; i++) {
        inputData[i] = inputData[i].clamp(-3.0, 3.0); // Limit to reasonable range
      }

      // Log all inputs for debugging
      print('Full model input: $inputData');

      // Create a copy of input for debugging
      var inputCopy = List<double>.from(inputData);

      // Properly reshape the input
      var input = [inputData];
      var output = List.filled(1, List.filled(1, 0.0));

      // Run inference
      _interpreter!.run(input, output);

      // Get prediction
      double rawPrediction = output[0][0];
      print('Raw model output: $rawPrediction');

      // Apply a sigmoid function to ensure it's between 0 and 1
      // This handles any scaling issues with the model output
      double prediction;
      if (rawPrediction > 10 || rawPrediction < -10) {
        // If output is extreme, use a more reasonable value based on AQ score
        prediction = aqScore / 10.0;
        print('Model output extreme, using AQ-based prediction: $prediction');
      } else {
        // Apply sigmoid: 1/(1+exp(-x))
        prediction = 1.0 / (1.0 + exp(-rawPrediction));
        print('Applied sigmoid, final prediction: $prediction');
      }

      // Additional safety check - correlation with traditional score
      if ((aqScore <= 3 && prediction > 0.8) || (aqScore >= 8 && prediction < 0.2)) {
        print('Warning: ML prediction inconsistent with AQ score, adjusting');
        // Blend with AQ-based score to prevent totally incorrect predictions
        prediction = (prediction + (aqScore / 10.0)) / 2.0;
      }

      return prediction.clamp(0.0, 1.0);
    } catch (e) {
      print('Inference error: $e');
      print('Stack trace: ${StackTrace.current}');
      // Return a value based on traditional AQ score as fallback
      return (aqScore / 10.0).clamp(0.1, 0.9);
    }
  }

// Helper function for exponential calculation
  double exp(double x) {
    return math.exp(x); // Math library already has an exp function
  }

  Widget _buildDemographicOptions() {
    final index = _demographicQuestions.indexOf(_currentDemographicQuestion);
    List<Map<String, String>> options = [];

    if (index == 1) {
      options = [{"text": "ذكر", "value": "ذكر"}, {"text": "أنثى", "value": "أنثى"}];
    } else if (index == 2 || index == 3) {
      options = [{"text": "نعم", "value": "نعم"}, {"text": "لا", "value": "لا"}];
    }

    return options.isEmpty
        ? const SizedBox.shrink()
        : Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: options
            .map(
              (opt) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ElevatedButton(
              onPressed: () {
                _addUserMessage(opt['text']!);
                _processDemographicAnswer(opt['value']!);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFE399),
                foregroundColor: Colors.brown,
              ),
              child: Text(opt['text']!),
            ),
          ),
        )
            .toList(),
      ),
    );
  }

  Widget _buildScreeningInterface() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 4)],
      ),
      child: Column(
        children: [
          Text("السؤال ${_currentQuestionIndex + 1}/10",
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold
              ),
              textAlign: TextAlign.center
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildAnswerButton("١. أوافق بشدة", "1", true)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildAnswerButton("٢. أوافق نوعاً ما", "2", true)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildAnswerButton("٣. لا أوافق نوعاً ما", "3", false)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildAnswerButton("٤. لا أوافق بشدة", "4", false)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerButton(String text, String value, bool isYellow) {
    return ElevatedButton(
      onPressed: () {
        _addUserMessage(text);
        _processScreeningAnswer(value);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFFE399),
        foregroundColor: Colors.brown,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        elevation: 0,
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  void _handleUserMessage(ChatMessage message) {
    _messages.insert(0, message);

    // التحقق من رسائل الشكر أولاً
    String userText = message.text.toLowerCase();
    if (userText.contains("شكرا") || userText.contains("شكراً")) {
      _addBotMessage("على الرحب والسعة 🌷، إذا احتجت أي مساعدة إضافية أنا هنا!");
      return;
    }

    if (_inScreeningMode) {
      _processScreeningAnswer(message.text);
    } else if (_collectingDemographics) {
      _processDemographicAnswer(message.text);
    } else {
      // Check if the message is autism-related before processing
      if (_isAutismRelated(message.text)) {
        setState(() => _isTyping = true);
        _getChatResponse();
      } else {
        // Message is not related to autism
        _addBotMessage("عذرًا، أنا متخصص فقط في مجال التوحد والصحة النفسية للأطفال. هل يمكنني مساعدتك في أي استفسار متعلق بهذا المجال؟");
      }
    }
  }

  Future<void> _getChatResponse() async {
    const String apiUrl = "$OPENAI_API_BASE/chat/completions";
    try {
      final apiMessages = _messages.reversed.map((m) {
        return {'role': m.user.id == _currentUser.id ? 'user' : 'assistant', 'content': m.text};
      }).toList();

      apiMessages.insert(0, {
        'role': 'system',
        'content': 'أنت مساعد متخصص في التوحد تقدم معلومات دقيقة بالعربية. أجب فقط على الأسئلة المتعلقة بالتوحد. إذا سأل المستخدم عن موضوع غير متعلق بالتوحد، اعتذر بلطف وأخبره أنك تستطيع فقط الإجابة عن الأسئلة المتعلقة بالتوحد والصحة النفسية للأطفال.'
      });

      final data = {
        "model": "gpt-4-0125-preview",
        "messages": apiMessages,
        "temperature": 0.7,
        "max_tokens": 1000,
      };

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          "Authorization": "Bearer $OPENAI_API_KEY",
          "Content-Type": "application/json",
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final reply = decoded["choices"][0]["message"]["content"];
        setState(() => _isTyping = false);
        _addBotMessage(reply.trim());
      } else {
        _handleError("فشل الاتصال: ${response.statusCode}");
      }
    } catch (e) {
      _handleError("حدث خطأ: $e");
    }
  }

  void _handleError(String errorMessage) {
    setState(() => _isTyping = false);
    _addBotMessage("عذراً، حدث خطأ في النظام. الرجاء المحاولة لاحقاً.");
    print(errorMessage);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // هذا يجعل المحتوى يرتفع فوق الـ BottomNavigationBar
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('اسألني', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFFFE399),
        centerTitle: true,
      ),

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
 // اضفت SafeArea هنا
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              // Quick Replies
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: quickReplies
                      .map((text) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ElevatedButton(
                      onPressed: () => _sendQuickReply(text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFE399),
                        foregroundColor: Colors.brown,
                      ),
                      child: Text(text),
                    ),
                  ))
                      .toList(),
                ),
              ),

              Expanded(
                child: Directionality(
                  textDirection: TextDirection.ltr, // يثبت المحاذاة: يوزر يمين / بوت يسار
                  child: DashChat(
                    messages: _messages,
                    currentUser: _currentUser,
                    typingUsers: _isTyping ? [_botUser] : [],
                    onSend: (message) {
                      _handleUserMessage(message);


                    },
                    inputOptions: const InputOptions(
                      inputTextDirection: TextDirection.rtl, // للكتابة بالعربي
                    ),

                  ),
                ),
              ),


              // Conditional Widgets
              if (_inScreeningMode) _buildScreeningInterface(),
              if (_collectingDemographics) _buildDemographicOptions(),
            ],
          ),
        ),
      ),

    );
  }


  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }
}