import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../agent/agent_scheduler.dart';
import '../agent/core/agent_event.dart';
import '../agent/orchestrator.dart';
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
              AgentOrchestrator().handle(AgentEvent.now(
                type: AgentEventType.onboardingComplete,
                uid: uid,
              ));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF4CAF50),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.eco, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              'FitAI Coach',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade300),
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
              color: Color(0xFF4CAF50),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Building your 30-day plan...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Personalizing meals based on your preferences',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
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
          color: msg.isUser ? const Color(0xFF4CAF50) : Colors.white,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: msg.isUser ? const Radius.circular(4) : null,
            bottomLeft: !msg.isUser ? const Radius.circular(4) : null,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
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
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
            Text(
              msg.text,
              style: TextStyle(
                fontSize: 14,
                color: msg.isUser ? Colors.white : Colors.black87,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    if (_currentQuestion >= _questions.length) return const SizedBox.shrink();

    final question = _questions[
        _currentQuestion >= 7 && _isDiabetic ? 7 : _currentQuestion.clamp(0, _questions.length - 1)];

    // Time picker question
    if (question.type == _QType.timePicker) {
      return _buildTimePickerInput();
    }

    // Button options
    if (question.type == _QType.buttons && question.options != null) {
      return _buildButtonsInput(question.options!);
    }

    // Free text
    return _buildTextInput();
  }

  Widget _buildTextInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: 'Type your answer...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                color: Color(0xFF4CAF50),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      color: Colors.white,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((option) {
          return ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF4CAF50),
              side: const BorderSide(color: Color(0xFF4CAF50)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => _handleAnswer(option),
            child: Text(option, style: const TextStyle(fontSize: 13)),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimePickerInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.wb_sunny_outlined),
                  label: Text('Wake: $_wakeTime'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4CAF50),
                    side: const BorderSide(color: Color(0xFF4CAF50)),
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
                  label: Text('Sleep: $_sleepTime'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1565C0),
                    side: const BorderSide(color: Color(0xFF1565C0)),
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
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _handleTimePicked,
              child: const Text('Confirm times',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
  _Question(
    "How comfortable are you with cooking?",
    _QType.buttons,
    ["I don't cook", "Basic meals only", "Comfortable", "I love cooking"],
  ),
  _Question(
    "How many meals do you typically eat per day?",
    _QType.buttons,
    ["2 meals", "3 meals", "4 meals", "5+ meals"],
  ),
  _Question(
    "How would you describe your weekly food budget?",
    _QType.buttons,
    ["Low \u2014 simple affordable foods", "Medium \u2014 balanced", "High \u2014 no restrictions"],
  ),
  _Question(
    "Which meal do you struggle with the most?",
    _QType.buttons,
    ["Breakfast", "Lunch", "Dinner", "Snacks"],
  ),
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
