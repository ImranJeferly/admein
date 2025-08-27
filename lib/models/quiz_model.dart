class QuizModel {
  final String id;
  final String brand;
  final String? logoUrl;
  final List<QuizQuestion> questions;
  final DateTime createdAt;

  QuizModel({
    required this.id,
    required this.brand,
    this.logoUrl,
    required this.questions,
    required this.createdAt,
  });

  factory QuizModel.fromJson(Map<String, dynamic> json) {
    print('🧠 [QUIZ_MODEL] Parsing QuizModel from JSON: $json');
    List<QuizQuestion> questions = [];
    
    // Handle the API format with numbered keys
    if (json['data'] != null) {
      final data = json['data'];
      print('🧠 [QUIZ_MODEL] Found data section: $data');
      final questionCount = data['question_count'] ?? 0;
      print('🧠 [QUIZ_MODEL] Question count: $questionCount');
      
      // NEW API FORMAT: questions are under ad ID, then numbered 0, 1, 2...
      String? adId = json['id']?.toString();
      if (adId != null && data[adId] != null) {
        print('🧠 [QUIZ_MODEL] Found quiz data under ad ID key: $adId');
        final adData = data[adId] as Map<String, dynamic>?;
        
        if (adData != null) {
          final questionCount = adData['question_count'] ?? 0;
          print('🧠 [QUIZ_MODEL] Question count from ad data: $questionCount');
          
          // Extract questions from numbered keys (0, 1, 2, etc.)
          for (int i = 0; i < questionCount; i++) {
            final questionData = adData[i.toString()];
            print('🧠 [QUIZ_MODEL] Question $i data: $questionData');
            
            if (questionData != null) {
              questions.add(QuizQuestion.fromApiJsonWithDuration(questionData, '$adId-$i'));
            }
          }
        }
      } else {
        print('🧠 [QUIZ_MODEL] ⚠️ Could not find quiz data for ad ID: $adId');
        print('🧠 [QUIZ_MODEL] Available keys in data: ${data.keys.toList()}');
        
        // Fallback: try old format or any list in the data
        for (final entry in data.entries) {
          if (entry.value is List && entry.key != 'question_count') {
            print('🧠 [QUIZ_MODEL] Found fallback questions in key: ${entry.key}');
            final questionsList = entry.value as List;
            for (var questionJson in questionsList) {
              questions.add(QuizQuestion.fromApiJson(questionJson, entry.key));
            }
            break;
          }
        }
      }
      print('🧠 [QUIZ_MODEL] Total questions parsed: ${questions.length}');
    } else {
      print('🧠 [QUIZ_MODEL] No data section - trying fallback format');
      // Fallback to old format
      final questionsJson = json['questions'] as List? ?? [];
      print('🧠 [QUIZ_MODEL] Fallback questions JSON: $questionsJson');
      questions = questionsJson
          .map((questionJson) => QuizQuestion.fromJson(questionJson))
          .toList();
      print('🧠 [QUIZ_MODEL] Fallback questions parsed: ${questions.length}');
    }

    return QuizModel(
      id: json['id']?.toString() ?? 'unknown',
      brand: json['brand'] ?? '',
      logoUrl: json['logo_url'],
      questions: questions,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'brand': brand,
      'logo_url': logoUrl,
      'questions': questions.map((q) => q.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class QuizQuestion {
  final String id;
  final String question;
  final List<String> options;
  final int? correctAnswer; // Index of correct answer (optional for analytics)
  final int duration; // Duration in seconds for this question

  QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    this.correctAnswer,
    this.duration = 15, // Default 15 seconds
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    final optionsJson = json['options'] as List? ?? [];
    final options = optionsJson.map((option) => option.toString()).toList();

    return QuizQuestion(
      id: json['id']?.toString() ?? 'unknown',
      question: json['question'] ?? '',
      options: options,
      correctAnswer: json['correct_answer'],
    );
  }

  factory QuizQuestion.fromApiJson(Map<String, dynamic> json, String groupId) {
    // Handle both List and Map formats for options
    List<String> options = [];
    if (json['option'] is List) {
      final optionsJson = json['option'] as List? ?? [];
      options = optionsJson.map((option) => option.toString()).toList();
    } else if (json['option'] is Map) {
      // If option is a Map, extract values
      final optionsMap = json['option'] as Map<String, dynamic>? ?? {};
      options = optionsMap.values.map((option) => option.toString()).toList();
    }

    return QuizQuestion(
      id: '${groupId}_${json.hashCode}',
      question: json['question'] ?? '',
      options: options,
      correctAnswer: null, // API doesn't provide correct answer
      duration: 15, // Default duration for old format
    );
  }

  // New method for parsing with individual durations
  factory QuizQuestion.fromApiJsonWithDuration(Map<String, dynamic> json, String questionId) {
    // Handle both List and Map formats for options
    List<String> options = [];
    if (json['option'] is List) {
      final optionsJson = json['option'] as List? ?? [];
      options = optionsJson.map((option) => option.toString()).toList();
    } else if (json['option'] is Map) {
      // If option is a Map, extract values
      final optionsMap = json['option'] as Map<String, dynamic>? ?? {};
      options = optionsMap.values.map((option) => option.toString()).toList();
    }
    
    final duration = json['duration'] ?? 15; // Use API duration or default to 15

    print('🧠 [QUIZ_QUESTION] Parsing question with duration: ${duration}s');
    print('🧠 [QUIZ_QUESTION] Options parsed: $options');

    return QuizQuestion(
      id: questionId,
      question: json['question'] ?? '',
      options: options,
      correctAnswer: null, // API doesn't provide correct answer
      duration: duration,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'options': options,
      'correct_answer': correctAnswer,
    };
  }
}

class QuizAnswer {
  final String quizId;
  final String questionId;
  final int selectedOption;
  final DateTime answeredAt;

  QuizAnswer({
    required this.quizId,
    required this.questionId,
    required this.selectedOption,
    required this.answeredAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'quiz_id': quizId,
      'question_id': questionId,
      'selected_option': selectedOption,
      'answered_at': answeredAt.toIso8601String(),
    };
  }
}