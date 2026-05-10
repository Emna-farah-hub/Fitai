git commit -m "backup before onboarding redesign"import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../agent/agent_scheduler.dart';
import '../agent/core/agent_event.dart';
import '../agent/orchestrator.dart';
import '../core/constants/app_colors.dart';
import '../presentation/widgets/ai_avatar.dart';
import '../presentation/widgets/mascot_bubble.dart';
import 'swipe_screen.dart';

/// Chat-style onboarding where the agent asks deeper questions
/// to build a rich profile before generating the 30-day plan.
class AgentOnboardingScreen extends StatefulWidget {
  const AgentOnboardingScreen({super.key});

  @override
  State<AgentOnboardingScreen> createState() => _AgentOnboardingScreenState();
}

class _AgentOnboardingScreenState extends State<AgentOnboardingScreen> {
  final _scrollController = ScrollController();
  final _textController = TextEditingController();
  final _db = FirebaseFirestore.instance;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  int _currentQuestion = 0;
  bool _isGeneratingPlan = false;
  bool _isDiabetic = false;

  // Collected answers
  String _preferredFoods = '';
  String _avoidedFoods = '';
  String _cookingLevel = '';
  String _mealsPerDay = '';
  String _budget = '';
  String _problemMeal = '';
  String _wakeTime = '07:00';
  String _sleepTime = '23:00';
  String _diabetesDetails = '';

  // Chat messages for display
  final List<_ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _checkDiabetes();
    _addAgentMessage(_questions[0].text);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _checkDiabetes() async {
    try {
      final doc = await _db.collection('users').doc(_uid).get();
      if (doc.exists) {
        final goals = List<String>.from(doc.data()?['goals'] ?? []);
        final conditions = List<String>.from(doc.data()?['conditions'] ?? []);
        _isDiabetic =
            goals.any((g) => g.toLowerCase().contains('diabetes')) ||
            conditions.any((c) => c.toLowerCase().contains('diabetes'));
      }
    } catch (_) {}
  }

  void _addAgentMessage(String text) {
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: false));
    });
    _scrollToBottom();
  }

  void _addUserMessage(String text) {
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleAnswer(String answer) {
    _addUserMessage(answer);

    // Store the answer
    switch (_currentQuestion) {
      case 0:
        _preferredFoods = answer;
      case 1:
        _avoidedFoods = answer;
      case 2:
        _cookingLevel = answer;
      case 3:
        _mealsPerDay = answer;
      case 4:
        _budget = answer;
      case 5:
        _problemMeal = answer;
      case 6:
        // Time pickers handled separately
        break;
      case 7:
        _diabetesDetails = answer;
    }

    // Move to next question
    _currentQuestion++;

    // Skip diabetes question if not diabetic
    if (_currentQuestion == 7 && !_isDiabetic) {
      _currentQuestion = 8;
    }

    // Check if we're done
    final totalQuestions = _isDiabetic ? 8 : 7;
    if (_currentQuestion >= totalQuestions) {
      _finishOnboarding();
      return;
    }

    // Adjust question index for the questions list
    final qIndex = _currentQuestion >= 7 && _isDiabetic ? 7 : _currentQuestion;
    if (qIndex < _questions.length) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _addAgentMessage(_questions[qIndex].text);
      });
    }
  }

  void _handleTimePicked() {
    _addUserMessage('Wake: $_wakeTime, Sleep: $_sleepTime');
    _currentQuestion++;

    if (_currentQuestion == 7 && !_isDiabetic) {
      _currentQuestion = 8;
    }

    final totalQuestions = _isDiabetic ? 8 : 7;
    if (_currentQuestion >= totalQuestions) {
      _finishOnboarding();
      return;
    }

    final qIndex = _currentQuestion >= 7 && _isDiabetic ? 7 : _currentQuestion;
    if (qIndex < _questions.length) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _addAgentMessage(_questions[qIndex].text);
      });
    }
  }

  Future<void> _finishOnboarding() async {
    _addAgentMessage(
      "Perfect! Now let's learn your food preferences.\nSwipe right on foods you like, left on foods you don't.",
    );

    setState(() => _isGeneratingPlan = true);

    // Save agent profile to Firestore
    final agentProfile = {
      'preferredFoods': _preferredFoods,
      'avoidedFoods': _avoidedFoods,
      'cookingLevel': _cookingLevel,
      'mealsPerDay': _mealsPerDay,
      'budget': _budget,
      'problemMeal': _problemMeal,
      'wakeTime': _wakeTime,
      'sleepTime': _sleepTime,
      if (_isDiabetic) 'diabetesDetails': _diabetesDetails,
      'agentOnboardingComplete': true,
    };

    await _db.collection('users').doc(_uid).update({
      'agentProfile': agentProfile,
      'agentOnboardingComplete': true,
    });

    // Wait briefly for UX, then navigate to swipe screen
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      final uid = _uid;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SwipeScreen(
            isOnboarding: true,
            onComplete: () {
              // After swipes are done, generate plan and go to dashboard
              AgentOrchestrator().handle(
                AgentEvent.now(
                  type: AgentEventType.onboardingComplete,
                  uid: uid,
                ),
              );
              try {
                AgentScheduler().start(uid);
              } catch (_) {}
              if (mounted) context.go('/dashboard');
            },
          ),
        ),
      );
    }
  }

  Future<void> _showTimePicker(bool isWake) async {
    final initial = isWake
        ? const TimeOfDay(hour: 7, minute: 0)
        : const TimeOfDay(hour: 23, minute: 0);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      final formatted =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        if (isWake) {
          _wakeTime = formatted;
        } else {
          _sleepTime = formatted;
        }
      });
    }
  }

  double _progressValue() {
    final total = (_isDiabetic ? 8 : 7).toDouble();
    return (_currentQuestion / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            const AiAvatar(size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'FitAI Coach',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Personalizing your plan',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: _progressValue()),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            builder: (context, value, _) => SizedBox(
              height: 4,
              child: LinearProgressIndicator(
                value: value,
                backgroundColor: AppColors.surfaceVariant,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
                minHeight: 4,
              ),
            ),
          ),
        ),
      ),
      body: _isGeneratingPlan ? _buildGeneratingScreen() : _buildChat(),
    );
  }

  Widget _buildGeneratingScreen() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Building your 30-day plan...',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Personalizing meals based on your preferences',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChat() {
    return Column(
      children: [
        // Messages
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              return _buildBubble(msg);
            },
          ),
        ),
        // Input area
        _buildInputArea(),
      ],
    );
  }

  Widget _buildBubble(_ChatMessage msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 12,
          left: msg.isUser ? 48 : 0,
          right: msg.isUser ? 0 : 48,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: msg.isUser ? AppColors.primaryGradient : null,
          color: msg.isUser ? null : AppColors.surface,
          border: msg.isUser
              ? null
              : Border.all(color: AppColors.border, width: 0.5),
          borderRadius: BorderRadius.circular(18).copyWith(
            bottomRight: msg.isUser ? const Radius.circular(4) : null,
            topLeft: !msg.isUser ? const Radius.circular(4) : null,
          ),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!msg.isUser)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'FitAI',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            Text(
              msg.text,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: msg.isUser ? Colors.white : AppColors.textPrimary,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    if (_currentQuestion >= _questions.length) return const SizedBox.shrink();

    final question =
        _questions[_currentQuestion >= 7 && _isDiabetic
            ? 7
            : _currentQuestion.clamp(0, _questions.length - 1)];

    late final Widget input;
    // Time picker question
    if (question.type == _QType.timePicker) {
      input = _buildTimePickerInput();
    } else if (question.type == _QType.buttons && question.options != null) {
      input = _buildButtonsInput(question.options!);
    } else {
      input = _buildTextInput();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: MascotBubble(explanation: _questionExplanation(question)),
        ),
        input,
      ],
    );
  }

  String _questionExplanation(_Question question) {
    final index = _questions.indexOf(question);
    return switch (index) {
      0 =>
        'Your favorite foods help me build a plan you actually want to follow.',
      1 =>
        'Avoids and allergies keep your plan comfortable, safe, and realistic.',
      2 =>
        'Cooking comfort changes how simple or adventurous your meals should be.',
      3 =>
        'Meal frequency helps me distribute calories and macros across your day.',
      4 =>
        'Budget keeps suggestions practical with ingredients that fit your routine.',
      5 => 'Your hardest meal is where a small plan upgrade can help the most.',
      6 => 'Your wake and sleep rhythm helps time meals around your real day.',
      7 =>
        'Blood sugar context helps me tune meal choices for steadier energy.',
      _ => 'This helps me personalize your nutrition plan with better context.',
    };
  }

  Widget _buildTextInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Type your answer...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textMuted,
                ),
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              final text = _textController.text.trim();
              if (text.isNotEmpty) {
                _textController.clear();
                _handleAnswer(text);
              }
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtonsInput(List<String> options) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((option) {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _handleAnswer(option),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primaryBorder),
                ),
                child: Text(
                  option,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimePickerInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.wb_sunny_outlined),
                  label: Text(
                    'Wake: $_wakeTime',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primaryBorder),
                    backgroundColor: AppColors.primarySurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => _showTimePicker(true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.nightlight_outlined),
                  label: Text(
                    'Sleep: $_sleepTime',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.chartBlue,
                    side: const BorderSide(color: AppColors.chartBlue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => _showTimePicker(false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _handleTimePicked,
                child: Text(
                  'Confirm times',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── DATA ──────────────────────────────────────────────────

enum _QType { freeText, buttons, timePicker }

class _Question {
  final String text;
  final _QType type;
  final List<String>? options;

  const _Question(this.text, this.type, [this.options]);
}

const _questions = [
  _Question(
    "Before I build your 30-day plan, I need to know you better.\nWhat foods do you genuinely enjoy eating?",
    _QType.freeText,
  ),
  _Question(
    "Are there any foods you dislike, are allergic to, or want to avoid completely?",
    _QType.freeText,
  ),
  _Question("How comfortable are you with cooking?", _QType.buttons, [
    "I don't cook",
    "Basic meals only",
    "Comfortable",
    "I love cooking",
  ]),
  _Question("How many meals do you typically eat per day?", _QType.buttons, [
    "2 meals",
    "3 meals",
    "4 meals",
    "5+ meals",
  ]),
  _Question("How would you describe your weekly food budget?", _QType.buttons, [
    "Low \u2014 simple affordable foods",
    "Medium \u2014 balanced",
    "High \u2014 no restrictions",
  ]),
  _Question("Which meal do you struggle with the most?", _QType.buttons, [
    "Breakfast",
    "Lunch",
    "Dinner",
    "Snacks",
  ]),
  _Question(
    "What time do you usually wake up and go to sleep?",
    _QType.timePicker,
  ),
  // Question 8 — diabetes only
  _Question(
    "Since you are managing diabetes, do you know your average blood sugar level or HbA1c?",
    _QType.freeText,
    ["I don't know"],
  ),
];

class _ChatMessage {
  final String text;
  final bool isUser;

  const _ChatMessage({required this.text, required this.isUser});
}
