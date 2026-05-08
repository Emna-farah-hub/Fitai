import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/app_assets.dart';
import '../core/constants/app_colors.dart';
import '../presentation/widgets/illustration_widget.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final _db = FirebaseFirestore.instance;
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  bool _isLoading = true;
  Map<String, List<_Ingredient>> _grouped = {};
  final Set<String> _checked = <String>{};

  static const List<String> _categoryOrder = [
    'Meat & Fish',
    'Dairy & Eggs',
    'Vegetables & Fruits',
    'Grains & Carbs',
    'Sauces & Condiments',
    'Other',
  ];

  static const Map<String, _CategoryStyle> _styles = {
    'Meat & Fish': _CategoryStyle(
      emoji: '🥩',
      bg: Color(0xFFFEE2E2),
      accent: Color(0xFF991B1B),
    ),
    'Dairy & Eggs': _CategoryStyle(
      emoji: '🥚',
      bg: Color(0xFFFEF3C7),
      accent: Color(0xFF92400E),
    ),
    'Vegetables & Fruits': _CategoryStyle(
      emoji: '🥬',
      bg: Color(0xFFDCFCE7),
      accent: Color(0xFF15803D),
    ),
    'Grains & Carbs': _CategoryStyle(
      emoji: '🌾',
      bg: Color(0xFFFEF9C3),
      accent: Color(0xFF854D0E),
    ),
    'Sauces & Condiments': _CategoryStyle(
      emoji: '🧂',
      bg: Color(0xFFF3E8FF),
      accent: Color(0xFF6B21A8),
    ),
    'Other': _CategoryStyle(
      emoji: '🛒',
      bg: Color(0xFFF1F5F9),
      accent: Color(0xFF475569),
    ),
  };

  static const Map<String, List<String>> _keywordMap = {
    'Meat & Fish': [
      'poulet', 'chicken', 'boeuf', 'beef', 'agneau', 'lamb', 'merguez',
      'thon', 'tuna', 'fish', 'poisson', 'sardine', 'viande', 'meat',
      'dinde', 'turkey', 'saumon', 'salmon',
    ],
    'Dairy & Eggs': [
      'lait', 'milk', 'fromage', 'cheese', 'yaourt', 'yogurt', 'oeuf',
      'egg', 'beurre', 'butter', 'crème', 'cream', 'ricotta', 'feta',
      'mozzarella',
    ],
    'Grains & Carbs': [
      'pain', 'bread', 'riz', 'rice', 'pâtes', 'pasta', 'couscous',
      'semoule', 'farine', 'flour', 'avoine', 'oat', 'quinoa',
      'pomme de terre', 'potato',
    ],
    'Sauces & Condiments': [
      'huile', 'oil', 'vinaigre', 'vinegar', 'sauce', 'harissa',
      'concentré', 'moutarde', 'mustard', 'sel', 'salt', 'poivre',
      'pepper', 'cumin', 'paprika', 'curcuma', 'safran', 'menthe',
      'mint', 'épice', 'spice',
    ],
    'Vegetables & Fruits': [
      'tomate', 'tomato', 'oignon', 'onion', 'ail', 'garlic', 'carotte',
      'courgette', 'poivron', 'salade', 'laitue', 'lettuce', 'pomme',
      'apple', 'orange', 'banane', 'banana', 'légume', 'concombre',
      'cucumber', 'pois chiche', 'chickpea', 'haricot', 'bean',
      'lentille', 'lentil', 'persil', 'parsley', 'coriandre', 'cilantro',
      'olive', 'citron', 'lemon', 'aubergine', 'eggplant',
    ],
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final doc = await _db.collection('meal_plan').doc(_uid).get();
      if (!doc.exists) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final days = doc.data()?['days'] as Map<String, dynamic>? ?? {};
      final aggregate = <String, _Ingredient>{};

      for (final dayData in days.values) {
        final day = dayData as Map<String, dynamic>;
        for (final mt in const ['breakfast', 'lunch', 'dinner', 'snack']) {
          final meal = day[mt] as Map<String, dynamic>?;
          if (meal == null) continue;
          final ingredients = meal['ingredients'] as List? ?? const [];
          for (final raw in ingredients) {
            if (raw is! Map) continue;
            final name = raw['name']?.toString().trim() ?? '';
            if (name.isEmpty) continue;
            final qty = (raw['quantity'] as num?)?.toDouble() ?? 0;
            final unit = raw['unit']?.toString() ?? '';
            final key = name.toLowerCase();
            final existing = aggregate[key];
            if (existing == null) {
              aggregate[key] = _Ingredient(
                name: name,
                quantity: qty,
                unit: unit,
              );
            } else {
              aggregate[key] = existing.copyWith(
                quantity: existing.quantity + qty,
              );
            }
          }
        }
      }

      final grouped = <String, List<_Ingredient>>{};
      for (final ingredient in aggregate.values) {
        final cat = _categorize(ingredient.name);
        grouped.putIfAbsent(cat, () => []).add(ingredient);
      }
      for (final list in grouped.values) {
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      }

      if (!mounted) return;
      setState(() {
        _grouped = grouped;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _categorize(String name) {
    final lower = name.toLowerCase();
    for (final entry in _keywordMap.entries) {
      for (final keyword in entry.value) {
        if (lower.contains(keyword)) return entry.key;
      }
    }
    return 'Other';
  }

  String _formatQty(double qty) {
    if (qty == qty.roundToDouble()) return qty.toInt().toString();
    return qty.toStringAsFixed(1);
  }

  int get _totalCount =>
      _grouped.values.fold<int>(0, (acc, list) => acc + list.length);

  int get _checkedCount => _checked.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary),
                    )
                  : _totalCount == 0
                      ? _buildEmpty()
                      : (_checkedCount == _totalCount
                          ? _buildAllDone()
                          : _buildList()),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final total = _totalCount;
    final progress = total == 0 ? 0.0 : _checkedCount / total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back,
                    color: AppColors.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: AppColors.surfaceVariant,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$_checkedCount/$total',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Say hello to your\nsmart shopping list',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                height: 1.15,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Aggregated from your 7-day plan',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.primarySurface,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.shopping_basket_outlined,
                color: AppColors.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No ingredients yet',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Generate a meal plan to see your aggregated weekly shopping list here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllDone() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const IllustrationWidget(
              assetPath: AppAssets.celebrationIllustration,
              fallbackIcon: Icons.celebration_rounded,
              height: 200,
            )
                .animate()
                .scale(
                  begin: const Offset(0.6, 0.6),
                  end: const Offset(1, 1),
                  curve: Curves.elasticOut,
                  duration: 700.ms,
                )
                .fadeIn(duration: 400.ms),
            const SizedBox(height: 24),
            Text(
              'All done! 🛒 ✓',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms, delay: 200.ms)
                .slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
            const SizedBox(height: 8),
            Text(
              'You have everything for your 7-day meal plan',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms, delay: 350.ms)
                .slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => setState(_checked.clear),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                child: Text(
                  'Clear all & start over',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.primary,
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 500.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    final sections = <Widget>[];
    var categoryIndex = 0;
    for (final cat in _categoryOrder) {
      final list = _grouped[cat];
      if (list == null || list.isEmpty) continue;
      final style = _styles[cat]!;
      sections.add(
        _buildSectionHeader(cat, list.length, style)
            .animate()
            .fadeIn(
              duration: 350.ms,
              delay: (categoryIndex * 60).ms,
            )
            .slideY(
              begin: 0.12,
              end: 0,
              duration: 350.ms,
              delay: (categoryIndex * 60).ms,
              curve: Curves.easeOut,
            ),
      );
      for (var i = 0; i < list.length; i++) {
        final ingredient = list[i];
        final delay = (categoryIndex * 60 + i * 30).ms;
        sections.add(
          _buildItemRow(ingredient, style)
              .animate()
              .fadeIn(delay: delay, duration: 280.ms)
              .slideX(begin: 0.05, end: 0),
        );
      }
      sections.add(const SizedBox(height: 14));
      categoryIndex++;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: sections,
    );
  }

  Widget _buildSectionHeader(
      String name, int count, _CategoryStyle style) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
      child: Row(
        children: [
          Text(style.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Text(
            name,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: style.bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: style.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(_Ingredient ingredient, _CategoryStyle style) {
    final id = ingredient.name.toLowerCase();
    final isChecked = _checked.contains(id);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() {
        if (isChecked) {
          _checked.remove(id);
        } else {
          _checked.add(id);
        }
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: style.bg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(style.emoji, style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: isChecked
                        ? AppColors.textMuted
                        : AppColors.textPrimary,
                    decoration: isChecked
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    decorationColor: AppColors.textMuted,
                  ),
                  children: [
                    TextSpan(
                      text:
                          '${_formatQty(ingredient.quantity)}${ingredient.unit}',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isChecked
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                        decoration: isChecked
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                    const TextSpan(text: ' '),
                    TextSpan(text: ingredient.name),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isChecked ? AppColors.primary : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isChecked ? AppColors.primary : AppColors.border,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: isChecked
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Continue',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _Ingredient {
  const _Ingredient({
    required this.name,
    required this.quantity,
    required this.unit,
  });

  final String name;
  final double quantity;
  final String unit;

  _Ingredient copyWith({double? quantity}) {
    return _Ingredient(
      name: name,
      quantity: quantity ?? this.quantity,
      unit: unit,
    );
  }
}

class _CategoryStyle {
  const _CategoryStyle({
    required this.emoji,
    required this.bg,
    required this.accent,
  });

  final String emoji;
  final Color bg;
  final Color accent;
}
