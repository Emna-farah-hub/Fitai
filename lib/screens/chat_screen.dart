import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../agent/core/agent_event.dart';
import '../agent/orchestrator.dart';
import '../models/meal_entry.dart';
import '../services/meal_journal_service.dart';
import 'plan_screen.dart';

/// Premium AI chat screen — users talk directly to the FitAI coach agent.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _db = FirebaseFirestore.instance;
  final _orchestrator = AgentOrchestrator();

  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  bool _isThinking = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      final hasText = _textController.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
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

  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _textController.clear();

    try {
      await _db.collection('chat').doc(_uid).collection('messages').add({
        'role': 'user',
        'content': trimmed,
        'timestamp': FieldValue.serverTimestamp(),
        'suggestionCard': null,
      });
    } catch (_) {}

    setState(() => _isThinking = true);
    _scrollToBottom();

    try {
      await _orchestrator.handle(AgentEvent.now(
        type: AgentEventType.userMessage,
        uid: _uid,
        payload: {'message': trimmed},
      ));
    } catch (_) {}

    if (mounted) setState(() => _isThinking = false);
    _scrollToBottom();
  }

  Future<void> _addSuggestionToDiary(Map<String, dynamic> suggestion) async {
    try {
      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);
      final hour = now.hour;
      String mealType = 'Snack';
      if (hour < 10) {
        mealType = 'Breakfast';
      } else if (hour < 14) {
        mealType = 'Lunch';
      } else if (hour < 20) {
        mealType = 'Dinner';
      }

      final meal = MealEntry(
        id: _db.collection('_').doc().id,
        userId: _uid,
        date: dateStr,
        foodName: suggestion['foodName'] ?? '',
        quantity: (suggestion['portion'] ?? 100).toDouble(),
        calories: (suggestion['calories'] ?? 0).toDouble(),
        protein: (suggestion['protein'] ?? 0).toDouble(),
        carbs: (suggestion['carbs'] ?? 0).toDouble(),
        fats: (suggestion['fats'] ?? 0).toDouble(),
        glycemicIndex: (suggestion['gi'] ?? 0).toInt(),
        mealType: mealType,
        inputMethod: 'agent_suggestion',
        timestamp: now,
      );

      await MealJournalService().addMeal(_uid, meal);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('\u2713 ${meal.foodName} added to your diary'),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add meal')),
        );
      }
    }
  }

  Future<void> _clearChat() async {
    try {
      final batch = _db.batch();
      final snap =
          await _db.collection('chat').doc(_uid).collection('messages').get();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (_) {}
  }

  void _showOptionsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Clear chat history'),
              onTap: () {
                Navigator.pop(ctx);
                _clearChat();
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.calendar_month, color: Color(0xFF2E7D32)),
              title: const Text('View my plan'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PlanScreen()),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ─── BUILD ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBF8),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('chat')
                  .doc(_uid)
                  .collection('messages')
                  .orderBy('timestamp')
                  .snapshots(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty && !_isThinking) {
                  return _buildWelcomeState();
                }

                _scrollToBottom();

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
                  itemCount: docs.length + (_isThinking ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == docs.length) {
                      return _buildThinkingIndicator();
                    }

                    final data = docs[index].data() as Map<String, dynamic>;
                    final isUser = data['role'] == 'user';
                    final content = data['content'] as String? ?? '';
                    final suggestion =
                        data['suggestionCard'] as Map<String, dynamic>?;
                    final ts = data['timestamp'] as Timestamp?;

                    if (isUser) {
                      return _buildUserBubble(content, ts);
                    } else {
                      return _buildAgentBubble(content, ts, suggestion);
                    }
                  },
                );
              },
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  // ─── GRADIENT HEADER ──────────────────────────────────

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.eco_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FitAI Coach',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Always here for you',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onPressed: _showOptionsSheet,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── WELCOME STATE ────────────────────────────────────

  Widget _buildWelcomeState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE8F5E9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline,
                color: Color(0xFF4CAF50), size: 48),
            const SizedBox(height: 16),
            const Text(
              'Chat with your AI coach',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask me anything about your nutrition,\n'
              'get meal suggestions, or let me\n'
              'analyze your day.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _suggestionChip('What should I eat for lunch?'),
                _suggestionChip('How am I doing today?'),
                _suggestionChip('Suggest a healthy snack'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _suggestionChip(String text) {
    return GestureDetector(
      onTap: () => _sendMessage(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF4CAF50)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF2E7D32),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ─── USER BUBBLE ──────────────────────────────────────

  Widget _buildUserBubble(String content, Timestamp? ts) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(left: 72, right: 16, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(4),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                content,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
            if (ts != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 4),
                child: Text(
                  DateFormat('h:mm a').format(ts.toDate()),
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideX(begin: 0.3, end: 0, duration: 300.ms, curve: Curves.easeOut);
  }

  // ─── AGENT BUBBLE ─────────────────────────────────────

  Widget _buildAgentBubble(
      String content, Timestamp? ts, Map<String, dynamic>? suggestion) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 16, right: 72, bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Agent avatar
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.eco_rounded,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'FitAI',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(18),
                      ),
                      border: Border.all(color: const Color(0xFFE8F5E9)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          content,
                          style: const TextStyle(
                            color: Color(0xFF1A1A1A),
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        // Inline suggestion card
                        if (suggestion != null) ...[
                          const SizedBox(height: 10),
                          Divider(
                              height: 1, color: const Color(0xFFE8F5E9)),
                          const SizedBox(height: 8),
                          _buildInlineSuggestion(suggestion),
                        ],
                      ],
                    ),
                  ),
                  if (ts != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: Text(
                        DateFormat('h:mm a').format(ts.toDate()),
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade500),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideX(
            begin: -0.3, end: 0, duration: 300.ms, curve: Curves.easeOut);
  }

  // ─── INLINE SUGGESTION CARD ───────────────────────────

  Widget _buildInlineSuggestion(Map<String, dynamic> suggestion) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.restaurant_outlined,
                  color: Color(0xFF2E7D32), size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion['foodName'] ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  Text(
                    '${(suggestion['calories'] ?? 0).toInt()} kcal \u00b7 '
                    'P:${(suggestion['protein'] ?? 0).toInt()}g '
                    'C:${(suggestion['carbs'] ?? 0).toInt()}g '
                    'F:${(suggestion['fats'] ?? 0).toInt()}g',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 38,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            onPressed: () => _addSuggestionToDiary(suggestion),
            child: const Text(
              'Add to diary',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── THINKING INDICATOR ───────────────────────────────

  Widget _buildThinkingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 16, right: 72, bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.eco_rounded,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                border: Border.all(color: const Color(0xFFE8F5E9)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ThinkingDot(delay: Duration.zero),
                  const SizedBox(width: 4),
                  _ThinkingDot(delay: const Duration(milliseconds: 200)),
                  const SizedBox(width: 4),
                  _ThinkingDot(delay: const Duration(milliseconds: 400)),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  // ─── INPUT BAR ────────────────────────────────────────

  Widget _buildInputBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 0.5),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
          8, 8, 8, MediaQuery.of(context).viewInsets.bottom + 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              minLines: 1,
              maxLines: 4,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Ask your coach...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              onSubmitted: _sendMessage,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _sendMessage(_textController.text),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: _hasText
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
                      )
                    : null,
                color: _hasText ? null : Colors.grey.shade300,
                shape: BoxShape.circle,
                boxShadow: _hasText
                    ? [
                        BoxShadow(
                          color: const Color(0xFF4CAF50)
                              .withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                Icons.send_rounded,
                color: _hasText ? Colors.white : Colors.grey.shade500,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── THINKING DOT ─────────────────────────────────────────

class _ThinkingDot extends StatefulWidget {
  final Duration delay;
  const _ThinkingDot({required this.delay});

  @override
  State<_ThinkingDot> createState() => _ThinkingDotState();
}

class _ThinkingDotState extends State<_ThinkingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _opacity = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) => Opacity(
        opacity: _opacity.value,
        child: child,
      ),
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Color(0xFF4CAF50),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
