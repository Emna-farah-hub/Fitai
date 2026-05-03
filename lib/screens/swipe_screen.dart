import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../core/constants/app_colors.dart';
import '../models/swipe_meal.dart';
import '../services/food_scoring_service.dart';
import '../services/swipe_meal_service.dart';

class SwipeScreen extends StatefulWidget {
  final bool isOnboarding;
  final VoidCallback? onComplete;

  const SwipeScreen({
    super.key,
    this.isOnboarding = false,
    this.onComplete,
  });

  @override
  State<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends State<SwipeScreen>
    with TickerProviderStateMixin {
  final _scoringService = FoodScoringService();
  final _mealService = SwipeMealService();

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  List<SwipeMeal> _meals = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isComplete = false;

  double _dragX = 0;
  double _dragY = 0;
  late AnimationController _returnController;
  late Animation<double> _returnAnimation;
  late AnimationController _exitController;
  late Animation<double> _exitAnimation;
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
    _exitAnimation =
        CurvedAnimation(parent: _exitController, curve: Curves.easeIn);
    _exitController.addListener(() => setState(() {}));
    _exitController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onSwipeComplete(_exitToRight);
      }
    });

    _loadMeals();
  }

  @override
  void dispose() {
    _returnController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  Future<void> _loadMeals() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final meals = await _mealService.getUnswipedMeals(
        uid: _uid,
        limit: widget.isOnboarding ? 15 : null,
      );

      if (mounted) {
        setState(() {
          _meals = meals;
          _isLoading = false;
          if (_meals.isEmpty) _isComplete = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isAnimatingExit) return;
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
    }
  }

  void _triggerExit(bool liked) {
    _exitToRight = liked;
    _isAnimatingExit = true;
    _exitController.forward(from: 0);
  }

  void _onSwipeComplete(bool liked) {
    final meal = _meals[_currentIndex];

    // Fire and forget — update preferences + mark meal as shown
    _scoringService
        .recordMealSwipe(uid: _uid, meal: meal, liked: liked)
        .catchError((_) {});
    _mealService.markMealAsSwiped(_uid, meal.id).catchError((_) {});

    setState(() {
      _dragX = 0;
      _dragY = 0;
      _isAnimatingExit = false;
      _exitController.reset();
      _currentIndex++;
      if (_currentIndex >= _meals.length) {
        _isComplete = true;
        _handleComplete();
      }
    });
  }

  void _handleComplete() {
    if (widget.isOnboarding && widget.onComplete != null) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) widget.onComplete!();
      });
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
              baseColor: Colors.grey.shade300,
              highlightColor: Colors.grey.shade100,
              child: Container(
                width: 300,
                height: 480,
                decoration: BoxDecoration(
                  color: Colors.white,
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
            Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
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
              child: const Icon(Icons.check_rounded,
                  size: 48, color: AppColors.primary),
            )
                .animate()
                .scale(
                    begin: const Offset(0, 0),
                    end: const Offset(1, 1),
                    duration: 500.ms,
                    curve: Curves.elasticOut)
                .fadeIn(duration: 300.ms),
            const SizedBox(height: 24),
            Text(
              'Your taste profile is ready!',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
            const SizedBox(height: 8),
            Text(
              'Generating your personalized plan...',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ).animate().fadeIn(delay: 500.ms, duration: 400.ms),
            const SizedBox(height: 32),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 3),
            ).animate().fadeIn(delay: 700.ms, duration: 300.ms),
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
              child: const Icon(Icons.thumb_up_rounded,
                  size: 40, color: AppColors.primary),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
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
                        child: Icon(Icons.arrow_back,
                            color: AppColors.textPrimary),
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
                        horizontal: 10, vertical: 5),
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
                      AppColors.primary),
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

  Widget _buildCardStack() {
    if (_currentIndex >= _meals.length) return const SizedBox.shrink();

    return Stack(
      alignment: Alignment.center,
      children: [
        if (_currentIndex + 1 < _meals.length)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Transform.scale(
              scale: 0.95,
              child: Opacity(
                opacity: 0.6,
                child:
                    _buildMealCard(_meals[_currentIndex + 1], isBackground: true),
              ),
            ),
          ),
        _buildDraggableCard(_meals[_currentIndex]),
      ],
    );
  }

  Widget _buildDraggableCard(SwipeMeal meal) {
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

    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Transform.translate(
        offset: Offset(offsetX, offsetY),
        child: Transform.rotate(
          angle: rotation,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Stack(
              children: [
                _buildMealCard(meal),
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
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: AppColors.primary, width: 3),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.favorite_rounded,
                                  color: AppColors.primary, size: 26),
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
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            border:
                                Border.all(color: AppColors.error, width: 3),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.close_rounded,
                                  color: AppColors.error, size: 26),
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

  Widget _buildMealCard(SwipeMeal meal, {bool isBackground = false}) {
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
          children: [
            _buildImageSection(meal),
            _buildContentSection(meal),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection(SwipeMeal meal) {
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
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _capitalize(meal.cuisine),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${meal.calories.toInt()}',
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
              meal.name,
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

  Widget _buildImage(SwipeMeal meal) {
    if (meal.isLocalImage) {
      return Image.asset(
        meal.imagePath,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _imageFallback(meal),
      );
    }
    return CachedNetworkImage(
      imageUrl: meal.imagePath,
      fit: BoxFit.cover,
      placeholder: (_, _) => Container(
        color: Colors.grey.shade200,
        child: Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(color: Colors.white),
        ),
      ),
      errorWidget: (_, _, _) => _imageFallback(meal),
    );
  }

  Widget _imageFallback(SwipeMeal meal) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _cuisineGradient(meal.cuisine),
        ),
      ),
      child: Center(
        child: Icon(
          _mealTypeIcon(meal.mealType),
          size: 72,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }

  Widget _buildContentSection(SwipeMeal meal) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            meal.description,
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
              _infoChip(Icons.schedule, meal.prepTime),
              const SizedBox(width: 8),
              _infoChip(Icons.bar_chart_rounded, _capitalize(meal.difficulty)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _macroPill('P', meal.protein, const Color(0xFFEDE7F6),
                  const Color(0xFF5E35B1)),
              const SizedBox(width: 8),
              _macroPill('C', meal.carbs, const Color(0xFFFFF3E0),
                  const Color(0xFFE65100)),
              const SizedBox(width: 8),
              _macroPill('F', meal.fats, const Color(0xFFFFFDE7),
                  const Color(0xFFF9A825)),
            ],
          ),
          if (meal.mainIngredients.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              meal.mainIngredients.take(4).join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (meal.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _pickDisplayTags(meal.tags).map((tag) {
                final colors = _tagColors(tag);
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
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
        color: const Color(0xFFF5F5F5),
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
      String label, double value, Color bgColor, Color textColor) {
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
              child: const Icon(Icons.close_rounded,
                  size: 28, color: AppColors.error),
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
              child: const Icon(Icons.favorite_rounded,
                  size: 28, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ─── HELPERS ──────────────────────────────────────────────

  List<Color> _cuisineGradient(String cuisine) {
    switch (cuisine.toLowerCase()) {
      case 'tunisian':
        return const [Color(0xFF81C784), Color(0xFF2E7D32)];
      case 'western':
      default:
        return const [Color(0xFF64B5F6), Color(0xFF1565C0)];
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
    final t = tag.toLowerCase();
    if (t == 'tunisian') {
      return (const Color(0xFFFFEBEE), const Color(0xFFC62828));
    }
    if (t == 'mediterranean') {
      return (const Color(0xFFE0F2F1), const Color(0xFF00695C));
    }
    if (t.contains('protein')) {
      return (const Color(0xFFE8EAF6), const Color(0xFF3949AB));
    }
    if (t.contains('quick') || t == 'no_cook') {
      return (const Color(0xFFF3E5F5), const Color(0xFF7B1FA2));
    }
    if (t == 'comfort_food') {
      return (const Color(0xFFFFF8E1), const Color(0xFFFF8F00));
    }
    if (t == 'spicy') {
      return (const Color(0xFFFFEBEE), const Color(0xFFC62828));
    }
    if (t.contains('low_gi') || t.contains('low_carb')) {
      return (const Color(0xFFE0F2F1), const Color(0xFF00695C));
    }
    if (t == 'light' || t == 'low_calorie') {
      return (const Color(0xFFE8F5E9), const Color(0xFF2E7D32));
    }
    return (const Color(0xFFF5F5F5), const Color(0xFF616161));
  }

  String _formatTag(String tag) {
    return tag
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}';
  }
}
