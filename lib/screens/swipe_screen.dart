import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../core/constants/app_colors.dart';
import '../models/meal.dart';
import '../services/food_scoring_service.dart';
import '../services/swipe_personalization_service.dart';

class SwipeScreen extends StatefulWidget {
  final bool isOnboarding;
  final VoidCallback? onComplete;

  const SwipeScreen({super.key, this.isOnboarding = false, this.onComplete});

  @override
  State<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends State<SwipeScreen>
    with TickerProviderStateMixin {
  final _scoringService = FoodScoringService();
  final _personalization = SwipePersonalizationService();
  final _db = FirebaseFirestore.instance;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  List<Meal> _meals = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isComplete = false;
  bool _stackAnimated = false;
  bool _isFloating = true;
  Timer? _floatResumeTimer;

  double _dragX = 0;
  double _dragY = 0;
  late AnimationController _returnController;
  late Animation<double> _returnAnimation;
  late AnimationController _exitController;
  late Animation<double> _exitAnimation;
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;
  bool _isAnimatingExit = false;
  bool _exitToRight = false;

  @override
  void initState() {
    super.initState();

    _returnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _returnAnimation = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _returnController, curve: Curves.easeOut),
    );
    _returnController.addListener(() {
      setState(() {
        _dragX *= _returnAnimation.value;
        _dragY *= _returnAnimation.value;
      });
    });

    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _exitAnimation = CurvedAnimation(
      parent: _exitController,
      curve: Curves.easeIn,
    );
    _exitController.addListener(() => setState(() {}));
    _exitController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onSwipeComplete(_exitToRight);
      }
    });

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _floatAnimation = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
    _floatController.repeat(reverse: true);

    _loadMeals();
  }

  @override
  void dispose() {
    _floatResumeTimer?.cancel();
    _returnController.dispose();
    _exitController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  Future<void> _loadMeals() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final existing = await _personalization.loadExistingBatch(_uid);
      List<Meal> meals;
      if (existing != null && existing.isNotEmpty) {
        meals = existing;
      } else {
        meals = await _generateFreshBatch();
      }

      if (mounted) {
        setState(() {
          _meals = meals;
          _currentIndex = 0;
          _isLoading = false;
          _stackAnimated = false;
          _isFloating = true;
          _isComplete = _meals.isEmpty;
        });
        Future.delayed(const Duration(milliseconds: 520), () {
          if (mounted) setState(() => _stackAnimated = true);
        });
        debugPrint('[SWIPE] loaded ${meals.length} meals');
      }
    } catch (e, st) {
      debugPrint('[SWIPE] _loadMeals FAILED: $e\n$st');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<List<Meal>> _generateFreshBatch() async {
    final profileDoc = await _db.collection('users').doc(_uid).get();
    final profile = Map<String, dynamic>.from(profileDoc.data() ?? const {});
    profile['uid'] = _uid;
    final swipedIds = await _loadSwipedIds(_uid);
    return _personalization.buildSwipeBatch(
      userProfile: profile,
      swipedMealIds: swipedIds,
      learnedPreferences: null,
    );
  }

  Future<Set<String>> _loadSwipedIds(String uid) async {
    try {
      final doc = await _db.collection('preferences').doc(uid).get();
      if (!doc.exists) return <String>{};
      final data = doc.data() ?? const {};
      return <String>{
        ...List<String>.from(data['likedFoodIds'] ?? const []),
        ...List<String>.from(data['dislikedFoodIds'] ?? const []),
      };
    } catch (_) {
      return <String>{};
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isAnimatingExit) return;
    _floatResumeTimer?.cancel();
    if (_isFloating) {
      setState(() => _isFloating = false);
    }
    setState(() {
      _dragX += details.delta.dx;
      _dragY += details.delta.dy;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isAnimatingExit) return;
    const threshold = 100.0;
    if (_dragX.abs() > threshold) {
      _triggerExit(_dragX > 0);
    } else {
      _returnController.forward(from: 0);
      _scheduleFloatResume();
    }
  }

  void _triggerExit(bool liked) {
    _floatResumeTimer?.cancel();
    if (_isFloating) setState(() => _isFloating = false);
    _exitToRight = liked;
    _isAnimatingExit = true;
    _exitController.forward(from: 0);
  }

  void _scheduleFloatResume() {
    _floatResumeTimer?.cancel();
    _floatResumeTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      if (_dragX == 0 && _dragY == 0 && !_isAnimatingExit) {
        setState(() => _isFloating = true);
      }
    });
  }

  void _onSwipeComplete(bool liked) {
    HapticFeedback.lightImpact();
    final meal = _meals[_currentIndex];

    // Existing preference learning — keep firing on every swipe.
    _scoringService
        .recordMealSwipe(uid: _uid, meal: meal, liked: liked)
        .catchError((_) {});
    // New batch lifecycle — note that this card has been seen.
    _personalization.markMealSeen(_uid, meal.id).catchError((_) {});

    setState(() {
      _dragX = 0;
      _dragY = 0;
      _isAnimatingExit = false;
      _exitController.reset();
      _currentIndex++;
      _isFloating = true;
      if (_currentIndex >= _meals.length) {
        _isComplete = true;
        _handleComplete();
      }
    });
  }

  void _handleComplete() {
    // Mark the batch complete and prepare the next one in the background.
    // The success/complete state stays visible until the user leaves.
    unawaited(_finalizeBatchAndPrepareNext());

    if (widget.isOnboarding && widget.onComplete != null) {
      debugPrint('[SWIPE] all done, navigating in 800ms');
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          debugPrint('[SWIPE] firing onComplete -> next onboarding step');
          widget.onComplete!();
        }
      });
    }
  }

  Future<void> _finalizeBatchAndPrepareNext() async {
    try {
      await _personalization.completeBatch(_uid);
      await _generateFreshBatch();
    } catch (e, st) {
      debugPrint('[SWIPE] _finalizeBatchAndPrepareNext FAILED: $e\n$st');
    }
  }

  void _onButtonSwipe(bool liked) {
    if (_isAnimatingExit || _currentIndex >= _meals.length) return;
    _triggerExit(liked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: _isLoading
              ? _buildLoading()
              : _hasError
              ? _buildError()
              : _isComplete
              ? _buildComplete()
              : _buildSwipeUI(),
        ),
      ),
    );
  }

  // ─── LOADING ──────────────────────────────────────────────

  Widget _buildLoading() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Shimmer.fromColors(
              baseColor: AppColors.border,
              highlightColor: AppColors.surfaceSoft,
              child: Container(
                width: 300,
                height: 480,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Loading meals...',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── ERROR ────────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              "Couldn't load meals. Please try again.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadMeals,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
              ),
              child: Text(
                'Retry',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── COMPLETE ─────────────────────────────────────────────

  Widget _buildComplete() {
    if (widget.isOnboarding) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: AppColors.primarySurface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 48,
                    color: AppColors.primary,
                  ),
                )
                .animate()
                .scale(
                  begin: const Offset(0, 0),
                  end: const Offset(1, 1),
                  duration: 500.ms,
                  curve: Curves.elasticOut,
                )
                .fadeIn(duration: 300.ms),
            const SizedBox(height: 24),
            Text(
              'Your taste profile is ready!',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ).animate().fadeIn(delay: 200.ms, duration: 300.ms),
            const SizedBox(height: 8),
            Text(
              'Creating your 7-day plan...',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ).animate().fadeIn(delay: 350.ms, duration: 300.ms),
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.thumb_up_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'All caught up!',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your preferences have been updated.\nCheck back when new meals are added.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
              ),
              child: Text(
                'Back to Dashboard',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── MAIN SWIPE UI ────────────────────────────────────────

  Widget _buildSwipeUI() {
    final total = _meals.length;
    final current = _currentIndex + 1;
    final progress = total > 0 ? current / total : 0.0;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            children: [
              Row(
                children: [
                  if (!widget.isOnboarding)
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: Icon(
                          Icons.arrow_back,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      'Discover your taste',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$current of $total',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                "Swipe right if you'd eat it, left if not",
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.border,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primary,
                  ),
                  minHeight: 4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(child: _buildCardStack()),
        _buildActionButtons(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _withEntranceAnimation({
    required Widget child,
    required int stackPosition,
  }) {
    if (_stackAnimated) return child;

    final delay = switch (stackPosition) {
      3 => 0.ms,
      2 => 100.ms,
      _ => 200.ms,
    };
    final beginX = switch (stackPosition) {
      3 => 80.0,
      2 => 50.0,
      _ => 30.0,
    };
    return child
        .animate()
        .fade(
          begin: 0,
          end: 1,
          delay: delay,
          duration: 300.ms,
          curve: Curves.easeOut,
        )
        .moveX(
          begin: beginX,
          end: 0,
          delay: delay,
          duration: 300.ms,
          curve: Curves.easeOut,
        );
  }

  Widget _buildCardStack() {
    if (_currentIndex >= _meals.length) return const SizedBox.shrink();

    return Stack(
      alignment: Alignment.center,
      children: [
        if (_currentIndex + 2 < _meals.length)
          _withEntranceAnimation(
            stackPosition: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Transform.translate(
                offset: const Offset(0, 22),
                child: Transform.scale(
                  scale: 0.9,
                  child: Opacity(
                    opacity: 0.6,
                    child: _buildMealCard(
                      _meals[_currentIndex + 2].toSwipeCardMap(),
                      isBackground: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (_currentIndex + 1 < _meals.length)
          _withEntranceAnimation(
            stackPosition: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Transform.translate(
                offset: const Offset(0, 12),
                child: Transform.scale(
                  scale: 0.95,
                  child: Opacity(
                    opacity: 0.8,
                    child: _buildMealCard(
                      _meals[_currentIndex + 1].toSwipeCardMap(),
                      isBackground: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        _withEntranceAnimation(
          stackPosition: 1,
          child: _buildDraggableCard(_meals[_currentIndex]),
        ),
      ],
    );
  }

  Widget _buildDraggableCard(Meal meal) {
    final screenWidth = MediaQuery.of(context).size.width;
    final swipeProgress = (_dragX / (screenWidth * 0.4)).clamp(-1.0, 1.0);

    double offsetX = _dragX;
    double offsetY = _dragY;
    if (_isAnimatingExit) {
      final exitDistance = screenWidth * 1.5;
      offsetX =
          (_exitToRight ? exitDistance : -exitDistance) * _exitAnimation.value;
      offsetY = _dragY * (1 - _exitAnimation.value);
    }

    // Max ~12 degrees rotation
    final rotation = swipeProgress * 0.21;
    final likeOpacity = swipeProgress.clamp(0.0, 1.0);
    final nopeOpacity = (-swipeProgress).clamp(0.0, 1.0);
    final shouldFloat =
        _isFloating && _dragX == 0 && _dragY == 0 && !_isAnimatingExit;

    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: AnimatedBuilder(
        animation: _floatAnimation,
        builder: (context, child) {
          final floatOffset = shouldFloat ? _floatAnimation.value : 0.0;
          return Transform.translate(
            offset: Offset(offsetX, offsetY + floatOffset),
            child: child,
          );
        },
        child: Transform.rotate(
          angle: rotation,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Stack(
              children: [
                _buildMealCard(meal.toSwipeCardMap()),
                if (likeOpacity > 0)
                  Positioned(
                    top: 24,
                    left: 24,
                    child: Opacity(
                      opacity: likeOpacity,
                      child: Transform.rotate(
                        angle: -0.2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppColors.primary,
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.favorite_rounded,
                                color: AppColors.primary,
                                size: 26,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'LIKE',
                                style: GoogleFonts.inter(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (nopeOpacity > 0)
                  Positioned(
                    top: 24,
                    right: 24,
                    child: Opacity(
                      opacity: nopeOpacity,
                      child: Transform.rotate(
                        angle: 0.2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppColors.error,
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.close_rounded,
                                color: AppColors.error,
                                size: 26,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'NOPE',
                                style: GoogleFonts.inter(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.error,
                                ),
                              ),
                            ],
                          ),
                        ),
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

  // ─── MEAL CARD ────────────────────────────────────────────

  Widget _buildMealCard(Map<String, dynamic> meal, {bool isBackground = false}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isBackground
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [_buildImageSection(meal), _buildContentSection(meal)],
        ),
      ),
    );
  }

  Widget _buildImageSection(Map<String, dynamic> meal) {
    final cuisine = (meal['cuisine'] as String?) ?? '';
    final calories = (meal['calories'] as num?) ?? 0;
    final name = (meal['name'] as String?) ?? '';

    return AspectRatio(
      aspectRatio: 16 / 12,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildImage(meal),
          // Dark gradient overlay at bottom
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Color(0xCC000000),
                ],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),
          // Top-right: calorie badge + cuisine pill
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _capitalize(cuisine),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${calories.toInt()}',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'cal',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Bottom: meal name
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: const [
                  Shadow(
                    color: Color(0x99000000),
                    blurRadius: 6,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(Map<String, dynamic> meal) {
    final isLocal = meal['isLocalImage'] == true;
    final imagePath = (meal['imagePath'] as String?) ?? '';
    if (isLocal) {
      return Image.asset(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _imageFallback(meal),
      );
    }
    return CachedNetworkImage(
      imageUrl: imagePath,
      fit: BoxFit.cover,
      placeholder: (_, _) => Container(
        color: AppColors.divider,
        child: Shimmer.fromColors(
          baseColor: AppColors.border,
          highlightColor: AppColors.surfaceSoft,
          child: Container(color: AppColors.surface),
        ),
      ),
      errorWidget: (_, _, _) => _buildCuisineAssetFallback(meal),
    );
  }

  Widget _buildCuisineAssetFallback(Map<String, dynamic> meal) {
    final cuisineAsset = (meal['cuisineAssetPath'] as String?) ?? '';
    if (cuisineAsset.isEmpty) return _imageFallback(meal);
    return Image.asset(
      cuisineAsset,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _imageFallback(meal),
    );
  }

  Widget _imageFallback(Map<String, dynamic> meal) {
    final cuisine = (meal['cuisine'] as String?) ?? '';
    final mealType = (meal['mealType'] as String?) ?? '';
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _cuisineGradient(cuisine),
        ),
      ),
      child: Center(
        child: Icon(
          _mealTypeIcon(mealType),
          size: 72,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }

  Widget _buildContentSection(Map<String, dynamic> meal) {
    final description = (meal['description'] as String?) ?? '';
    final prepTime = (meal['prepTime'] as String?) ?? '';
    final difficulty = (meal['difficulty'] as String?) ?? '';
    final protein = ((meal['protein'] as num?) ?? 0).toDouble();
    final carbs = ((meal['carbs'] as num?) ?? 0).toDouble();
    final fats = ((meal['fats'] as num?) ?? 0).toDouble();
    final mainIngredients =
        (meal['mainIngredients'] as List?)?.cast<String>() ?? const <String>[];
    final tags = (meal['tags'] as List?)?.cast<String>() ?? const <String>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _infoChip(Icons.schedule, prepTime),
              const SizedBox(width: 8),
              _infoChip(Icons.bar_chart_rounded, _capitalize(difficulty)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _macroPill(
                'P',
                protein,
                AppColors.infoSurface,
                AppColors.tealDark,
              ),
              const SizedBox(width: 8),
              _macroPill(
                'C',
                carbs,
                AppColors.amberSoft,
                AppColors.amberDark,
              ),
              const SizedBox(width: 8),
              _macroPill(
                'F',
                fats,
                AppColors.sageSoft,
                AppColors.sageDark,
              ),
            ],
          ),
          if (mainIngredients.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              mainIngredients.take(4).join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _pickDisplayTags(tags).map((tag) {
                final colors = _tagColors(tag);
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: colors.$1,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formatTag(tag),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colors.$2,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroPill(
    String label,
    double value,
    Color bgColor,
    Color textColor,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textColor.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${value.toStringAsFixed(0)}g',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── ACTION BUTTONS ───────────────────────────────────────

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 80),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Red outline X
          GestureDetector(
            onTap: () => _onButtonSwipe(false),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.error, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.error.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 28,
                color: AppColors.error,
              ),
            ),
          ),
          // Green filled heart
          GestureDetector(
            onTap: () => _onButtonSwipe(true),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.favorite_rounded,
                size: 28,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── HELPERS ──────────────────────────────────────────────

  List<Color> _cuisineGradient(String cuisine) {
    switch (_normalizeCuisineKey(cuisine)) {
      case 'tunisian':
        return const [AppColors.primaryLight, AppColors.primaryDark];
      case 'mediterranean':
        return const [AppColors.tealLight, AppColors.tealDark];
      case 'middle_eastern':
        return const [AppColors.amber, AppColors.amberDark];
      case 'french':
        return const [AppColors.sage, AppColors.tealDark];
      case 'italian':
        return const [AppColors.primary, AppColors.amberDark];
      case 'asian':
        return const [AppColors.teal, AppColors.sageDark];
      case 'mexican':
        return const [AppColors.amber, AppColors.primaryDark];
      case 'indian':
        return const [AppColors.amber, AppColors.tealDark];
      case 'international':
      default:
        return const [AppColors.sage, AppColors.textSecondary];
    }
  }

  IconData _mealTypeIcon(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return Icons.free_breakfast_rounded;
      case 'lunch':
        return Icons.lunch_dining_rounded;
      case 'dinner':
        return Icons.dinner_dining_rounded;
      case 'snack':
        return Icons.cookie_rounded;
      default:
        return Icons.restaurant_rounded;
    }
  }

  // Priority-based tag selection for display
  static const _tagPriority = [
    'tunisian',
    'mediterranean',
    'middle_eastern',
    'french',
    'italian',
    'asian',
    'mexican',
    'indian',
    'international',
    'high_protein',
    'low_gi',
    'low_carb',
    'quick_prep',
    'no_cook',
    'comfort_food',
    'spicy',
    'light',
    'filling',
    'plant_protein',
    'low_calorie',
  ];

  List<String> _pickDisplayTags(List<String> tags) {
    final picked = <String>[];
    for (final priority in _tagPriority) {
      if (tags.contains(priority) && picked.length < 4) {
        picked.add(priority);
      }
    }
    return picked;
  }

  (Color, Color) _tagColors(String tag) {
    final t = _normalizeCuisineKey(tag);
    if (t == 'tunisian') {
      return (AppColors.primarySurface, AppColors.primaryDark);
    }
    if (t == 'mediterranean') {
      return (AppColors.infoSurface, AppColors.tealDark);
    }
    if (t == 'middle_eastern') {
      return (AppColors.amberSoft, AppColors.amberDark);
    }
    if (t == 'french') {
      return (AppColors.sageSoft, AppColors.sageDark);
    }
    if (t == 'italian') {
      return (AppColors.primarySoft, AppColors.primaryDark);
    }
    if (t == 'asian') {
      return (AppColors.infoSurface, AppColors.tealDark);
    }
    if (t == 'mexican') {
      return (AppColors.amberSoft, AppColors.amberDark);
    }
    if (t == 'indian') {
      return (AppColors.amberSoft, AppColors.amberDark);
    }
    if (t == 'international') {
      return (AppColors.surfaceSoft, AppColors.textSecondary);
    }
    if (t.contains('protein')) {
      return (AppColors.infoSurface, AppColors.tealDark);
    }
    if (t.contains('quick') || t == 'no_cook') {
      return (AppColors.sageSoft, AppColors.sageDark);
    }
    if (t == 'comfort_food') {
      return (AppColors.amberSoft, AppColors.amberDark);
    }
    if (t == 'spicy') {
      return (AppColors.errorSurface, AppColors.error);
    }
    if (t.contains('low_gi') || t.contains('low_carb')) {
      return (AppColors.primarySurface, AppColors.primaryDark);
    }
    if (t == 'light' || t == 'low_calorie') {
      return (AppColors.sageSoft, AppColors.sageDark);
    }
    return (AppColors.surfaceSoft, AppColors.textSecondary);
  }

  String _formatTag(String tag) {
    return tag
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  String _capitalize(String s) {
    return _formatTag(_normalizeCuisineKey(s));
  }

  String _normalizeCuisineKey(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll('&', ' and ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    switch (normalized) {
      case 'middle eastern':
      case 'middle_eastern':
        return 'middle_eastern';
      case 'western':
        return 'international';
      default:
        return normalized.replaceAll(' ', '_');
    }
  }
}
