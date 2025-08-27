import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ad_model.dart';
import '../models/quiz_model.dart';
import '../services/app_state_service.dart';
import 'dart:io';

class QuizDisplayScreen extends StatefulWidget {
  const QuizDisplayScreen({super.key});

  @override
  State<QuizDisplayScreen> createState() => _QuizDisplayScreenState();
}

class _QuizDisplayScreenState extends State<QuizDisplayScreen>
    with TickerProviderStateMixin {
  int _currentQuestionIndex = 0;
  int? _selectedAnswer;
  List<QuizAnswer> _answers = [];
  Map<String, String> _persistentAnswers = {}; // question -> selected_option text
  String? _currentAdId;
  String? _logoUrl; // Cache for the ad logo
  late AnimationController _progressController;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _progressBarController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _progressBarAnimation;
  double _targetProgress = 0.0;
  
  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // Slide animation controller for question transitions
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // Progress bar animation controller
    _progressBarController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    // Initialize animations
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0), // Start from right
      end: Offset.zero, // End at center
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    ));
    
    _progressBarAnimation = Tween<double>(
      begin: 0.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _progressBarController,
      curve: Curves.easeInOut,
    ));
    
    // Initialize quiz data and load saved answers
    _initializeQuizData();
    
    // Initialize progress bar animation
    _initializeProgressBar();
    
    // Start the 15-second timer for first question
    _startQuestionTimer();
    
    // Start initial animations
    _fadeController.forward();
    _slideController.forward();
  }

  void _initializeQuizData() {
    final appState = context.read<AppStateService>();
    final currentAd = appState.currentAd;
    
    if (currentAd != null) {
      // Extract original ad ID from quiz ad ID
      _currentAdId = currentAd.id.replaceAll('_quiz', '');
      print('🧠 [QUIZ_UI] Initializing quiz for ad: $_currentAdId');
      
      // Load saved answers for this ad
      _persistentAnswers = appState.getQuizAnswersForAd(_currentAdId!);
      print('🧠 [QUIZ_UI] Loaded ${_persistentAnswers.length} saved answers');
      
      // Find the first unanswered question and start there
      _findFirstUnansweredQuestion();
      
      // Fetch the ad logo using the same API as QR code
      _fetchAdLogo();
      
      // Check if current question has a saved answer
      _loadCurrentQuestionAnswer();
    }
  }

  void _findFirstUnansweredQuestion() {
    final appState = context.read<AppStateService>();
    final quiz = appState.currentAd?.quiz;
    
    if (quiz != null) {
      for (int i = 0; i < quiz.questions.length; i++) {
        final question = quiz.questions[i];
        final isAnswered = _persistentAnswers.containsKey(question.question);
        
        if (!isAnswered) {
          print('🧠 [QUIZ_UI] Starting from first unanswered question: ${i + 1}');
          setState(() {
            _currentQuestionIndex = i;
          });
          return;
        }
      }
      
      // If we get here, all questions are answered (shouldn't happen due to app state check)
      print('🧠 [QUIZ_UI] ⚠️ All questions already answered - this should not happen');
    }
  }

  void _fetchAdLogo() async {
    if (_currentAdId == null) return;
    
    final appState = context.read<AppStateService>();
    try {
      print('🏷️ [QUIZ_LOGO] Fetching logo for ad: $_currentAdId');
      final logoUrl = await appState.apiService.getAdLogo(_currentAdId!);
      
      if (logoUrl != null && logoUrl.isNotEmpty) {
        setState(() {
          _logoUrl = logoUrl;
        });
        print('🏷️ [QUIZ_LOGO] ✅ Logo URL set: $logoUrl');
      } else {
        print('🏷️ [QUIZ_LOGO] ❌ No logo URL received');
      }
    } catch (e) {
      print('🏷️ [QUIZ_LOGO] ❌ Error fetching logo: $e');
    }
  }

  void _initializeProgressBar() {
    final appState = context.read<AppStateService>();
    final quiz = appState.currentAd?.quiz;
    
    if (quiz != null && quiz.questions.isNotEmpty) {
      _targetProgress = (_currentQuestionIndex + 1) / quiz.questions.length;
      _progressBarAnimation = Tween<double>(
        begin: 0.0,
        end: _targetProgress,
      ).animate(CurvedAnimation(
        parent: _progressBarController,
        curve: Curves.easeInOut,
      ));
      _progressBarController.forward();
    }
  }

  void _updateProgressBar() {
    final appState = context.read<AppStateService>();
    final quiz = appState.currentAd?.quiz;
    
    if (quiz != null && quiz.questions.isNotEmpty) {
      final currentProgress = _progressBarAnimation.value;
      _targetProgress = (_currentQuestionIndex + 1) / quiz.questions.length;
      
      _progressBarAnimation = Tween<double>(
        begin: currentProgress,
        end: _targetProgress,
      ).animate(CurvedAnimation(
        parent: _progressBarController,
        curve: Curves.easeInOut,
      ));
      
      _progressBarController.reset();
      _progressBarController.forward();
    }
  }

  void _loadCurrentQuestionAnswer() {
    final appState = context.read<AppStateService>();
    final quiz = appState.currentAd?.quiz;
    
    if (quiz != null && _currentQuestionIndex < quiz.questions.length) {
      final currentQuestion = quiz.questions[_currentQuestionIndex];
      final savedAnswer = _persistentAnswers[currentQuestion.question];
      
      if (savedAnswer != null) {
        // Find the index of the saved answer option
        final optionIndex = currentQuestion.options.indexOf(savedAnswer);
        if (optionIndex != -1) {
          setState(() {
            _selectedAnswer = optionIndex;
          });
          print('🧠 [QUIZ_UI] Loaded saved answer for "${currentQuestion.question}": $savedAnswer (index $optionIndex)');
        }
      }
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _progressBarController.dispose();
    super.dispose();
  }

  void _startQuestionTimer() {
    final appState = context.read<AppStateService>();
    final quiz = appState.currentAd?.quiz;
    
    if (quiz != null && _currentQuestionIndex < quiz.questions.length) {
      final currentQuestion = quiz.questions[_currentQuestionIndex];
      final duration = currentQuestion.duration;
      
      print('🧠 [QUIZ] Starting timer for question ${_currentQuestionIndex + 1}: ${duration}s');
      
      // Update the controller duration dynamically
      _progressController.dispose();
      _progressController = AnimationController(
        duration: Duration(seconds: duration),
        vsync: this,
      );
      
      _progressController.reset();
      _progressController.forward();
      _progressController.removeListener(_onTimerComplete);
      _progressController.addListener(_onTimerComplete);
    } else {
      // Fallback to default 15 seconds
      _progressController.reset();
      _progressController.forward();
      _progressController.removeListener(_onTimerComplete);
      _progressController.addListener(_onTimerComplete);
    }
  }

  void _onTimerComplete() {
    if (_progressController.isCompleted) {
      print('🧠 [QUIZ] ⏰ Timer expired for question ${_currentQuestionIndex + 1}');
      print('🧠 [QUIZ] Answer selected: ${_selectedAnswer != null ? _selectedAnswer! + 1 : "None"}');
      print('🧠 [QUIZ] Auto-advancing to next question/page');
      _nextQuestion();
    }
  }

  void _selectAnswer(int optionIndex) {
    setState(() {
      _selectedAnswer = optionIndex;
    });
    
    // Save answer immediately when selected
    _saveCurrentAnswer(optionIndex);
    
    print('🧠 [QUIZ] Answer selected: ${optionIndex + 1} - continuing timer until duration expires');
    
    // Don't stop the timer - let it continue until the full duration
    // This ensures consistent timing regardless of when the user answers
  }

  void _saveCurrentAnswer(int optionIndex) {
    final appState = context.read<AppStateService>();
    final quiz = appState.currentAd?.quiz;
    
    if (quiz != null && _currentQuestionIndex < quiz.questions.length && _currentAdId != null) {
      final currentQuestion = quiz.questions[_currentQuestionIndex];
      final selectedOptionText = currentQuestion.options[optionIndex];
      
      // Save to persistent storage
      _persistentAnswers[currentQuestion.question] = selectedOptionText;
      
      // Save to app state (async)
      appState.saveQuizAnswersForAd(_currentAdId!, _persistentAnswers);
      
      print('🧠 [QUIZ_UI] Saved answer for "${currentQuestion.question}": $selectedOptionText');
    }
  }

  void _nextQuestion() {
    final appState = context.read<AppStateService>();
    final currentAd = appState.currentAd;
    final quiz = currentAd?.quiz;
    
    if (quiz == null) return;

    final currentQuestion = quiz.questions[_currentQuestionIndex];

    // Save the answer only if one was selected
    if (_selectedAnswer != null) {
      print('🧠 [QUIZ] Saving answer ${_selectedAnswer! + 1} for question ${_currentQuestionIndex + 1}');
      _answers.add(QuizAnswer(
        quizId: quiz.id,
        questionId: currentQuestion.id,
        selectedOption: _selectedAnswer!,
        answeredAt: DateTime.now(),
      ));
    } else {
      print('🧠 [QUIZ] No answer selected for question ${_currentQuestionIndex + 1} - advancing anyway');
    }

    // Move to next question or finish
    if (_currentQuestionIndex < quiz.questions.length - 1) {
      // Find next unanswered question
      _findNextUnansweredQuestion();
    } else {
      _finishQuiz();
    }
  }

  void _findNextUnansweredQuestion() {
    final appState = context.read<AppStateService>();
    final quiz = appState.currentAd?.quiz;
    
    if (quiz != null) {
      // Look for next unanswered question starting from current index + 1
      for (int i = _currentQuestionIndex + 1; i < quiz.questions.length; i++) {
        final question = quiz.questions[i];
        final isAnswered = _persistentAnswers.containsKey(question.question);
        
        if (!isAnswered) {
          print('🧠 [QUIZ_UI] Moving to next unanswered question: ${i + 1}');
          setState(() {
            _currentQuestionIndex = i;
            _selectedAnswer = null;
          });
          
          // Load saved answer for new question
          _loadCurrentQuestionAnswer();
          
          // Update progress bar animation
          _updateProgressBar();
          
          // Reset and start slide animation for next question
          _slideController.reset();
          _slideController.forward();
          
          // Reset fade animation for next question
          _fadeController.reset();
          _fadeController.forward();
          
          // Start timer for new question
          _startQuestionTimer();
          return;
        } else {
          print('🧠 [QUIZ_UI] Skipping already answered question: ${i + 1}');
        }
      }
      
      // If no more unanswered questions, finish the quiz
      print('🧠 [QUIZ_UI] No more unanswered questions - finishing quiz');
      _finishQuiz();
    }
  }

  void _finishQuiz() {
    final appState = context.read<AppStateService>();
    final quiz = appState.currentAd?.quiz;
    
    if (quiz != null) {
      // Calculate actual quiz duration from individual question durations
      final actualQuizDuration = quiz.questions.fold<int>(0, (sum, question) => sum + question.duration);
      print('🧠 [QUIZ] Quiz completed with actual duration: ${actualQuizDuration}s');
      
      // Update video duration tracking for proper timing calculations
      appState.updateVideoActualDuration(actualQuizDuration);
    }
    
    // Save quiz answers to app state for later submission
    appState.saveQuizAnswers(_answers);
    
    // Move to next ad in cycle
    appState.onAdCompleted();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateService>(
      builder: (context, appState, child) {
        final currentAd = appState.currentAd;
        final quiz = currentAd?.quiz;
        
        if (quiz == null || quiz.questions.isEmpty) {
          return const Scaffold(
            backgroundColor: Color(0xFF2a2e6a),
            body: Center(
              child: Text(
                'Viktorina yüklənir...',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        }

        if (_currentQuestionIndex >= quiz.questions.length) {
          return const Scaffold(
            backgroundColor: Color(0xFF2a2e6a),
            body: Center(
              child: Text(
                'Viktorina tamamlandı!',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        }

        final currentQuestion = quiz.questions[_currentQuestionIndex];
        
        // Debug quiz logo information
        print('🏷️ [QUIZ_DEBUG] Quiz brand: ${quiz.brand}');
        print('🏷️ [QUIZ_DEBUG] Quiz logoUrl: ${quiz.logoUrl}');
        print('🏷️ [QUIZ_DEBUG] Current question: ${currentQuestion.question}');

        return Scaffold(
          backgroundColor: const Color(0xFF2a2e6a),
          body: SafeArea(
            child: Column(
              children: [
                // Animated Progress bar
                Container(
                  height: 4,
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: AnimatedBuilder(
                    animation: _progressBarAnimation,
                    builder: (context, child) {
                      return LinearProgressIndicator(
                        value: _progressBarAnimation.value,
                        backgroundColor: Colors.transparent,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFffc107)),
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 60),
                
                // Question and options
                Expanded(
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeController,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          // Question with company logo
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Question text (left side)
                              Expanded(
                                flex: 3,
                                child: Text(
                                  currentQuestion.question,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                  ),
                                  textAlign: TextAlign.left,
                                ),
                              ),
                              
                              const SizedBox(width: 24),
                              
                              // Company logo (right side) - Always show for debugging
                              Expanded(
                                  flex: 1,
                                  child: Builder(
                                    builder: (context) {
                                      print('🏷️ [QUIZ_LOGO] Logo URL from API: ${_logoUrl ?? "null"}');
                                      print('🏷️ [QUIZ_LOGO] Logo URL not empty: ${_logoUrl?.isNotEmpty ?? false}');
                                      
                                      return Container(
                                        constraints: const BoxConstraints(
                                          maxWidth: 120,
                                          maxHeight: 120,
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: _logoUrl != null && _logoUrl!.isNotEmpty
                                              ? Image.network(
                                                  _logoUrl!,
                                                  fit: BoxFit.contain,
                                                  loadingBuilder: (context, child, loadingProgress) {
                                                    if (loadingProgress == null) return child;
                                                    return const Center(
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFffc107)),
                                                      ),
                                                    );
                                                  },
                                                  errorBuilder: (context, error, stackTrace) {
                                                    print('❌ [QUIZ_LOGO] Failed to load company logo: $error');
                                                    print('❌ [QUIZ_LOGO] URL was: $_logoUrl');
                                                    return Container(
                                                      width: 80,
                                                      height: 80,
                                                      decoration: BoxDecoration(
                                                        color: Colors.white.withOpacity(0.1),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: const Icon(
                                                        Icons.business,
                                                        size: 40,
                                                        color: Colors.white60,
                                                      ),
                                                    );
                                                  },
                                                )
                                              : Container(
                                                  width: 80,
                                                  height: 80,
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      const Icon(
                                                        Icons.business,
                                                        size: 30,
                                                        color: Colors.white60,
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        quiz.brand.isNotEmpty ? quiz.brand : 'Logo',
                                                        style: const TextStyle(
                                                          color: Colors.white60,
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                        textAlign: TextAlign.center,
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
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
                          
                          const SizedBox(height: 32),
                          
                          // Options
                          Expanded(
                            child: ListView.builder(
                              itemCount: currentQuestion.options.length,
                              itemBuilder: (context, index) {
                                final isSelected = _selectedAnswer == index;
                                
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => _selectAnswer(index),
                                      borderRadius: BorderRadius.circular(16),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 300),
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: isSelected 
                                            ? const Color(0xFFffc107)
                                            : Colors.white.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: isSelected 
                                              ? const Color(0xFFffc107)
                                              : Colors.white.withOpacity(0.3),
                                            width: 2,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            // Option letter
                                            Container(
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: isSelected 
                                                  ? const Color(0xFF2a2e6a)
                                                  : const Color(0xFFffc107),
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  String.fromCharCode(65 + index), // A, B, C, D
                                                  style: TextStyle(
                                                    fontFamily: 'Poppins',
                                                    color: isSelected 
                                                      ? Colors.white
                                                      : const Color(0xFF2a2e6a),
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            
                                            const SizedBox(width: 16),
                                            
                                            // Option text
                                            Expanded(
                                              child: Text(
                                                currentQuestion.options[index],
                                                style: TextStyle(
                                                  fontFamily: 'Poppins',
                                                  color: isSelected 
                                                    ? const Color(0xFF2a2e6a)
                                                    : Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
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
                  ),
                ),
              ),
                
                // Footer info
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Cavabınızı seçin və davam edin',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}