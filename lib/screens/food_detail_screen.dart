import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/constants/app_colors.dart';
import '../models/food_item.dart';
import '../models/meal_entry.dart';
import '../services/meal_journal_service.dart';

class FoodDetailScreen extends StatefulWidget {
  final FoodItem foodItem;
  final String mealType;

  const FoodDetailScreen({
    super.key,
    required this.foodItem,
    required this.mealType,
  });

  @override
  State<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends State<FoodDetailScreen> {
  static const double _minQuantity = 10.0;
  static const double _maxQuantity = 500.0;
  static const List<double> _presets = [50, 100, 150, 200, 300];

  double _quantity = 100.0;
  bool _isSaving = false;

  double get _calories => (widget.foodItem.caloriesPer100g * _quantity) / 100;
  double get _protein => (widget.foodItem.protein * _quantity) / 100;
  double get _carbs => (widget.foodItem.carbs * _quantity) / 100;
  double get _fats => (widget.foodItem.fats * _quantity) / 100;

  Future<void> _addToDiary() async {
    setState(() => _isSaving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final meal = MealEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: uid,
        date: today,
        foodName: widget.foodItem.name,
        quantity: _quantity,
        calories: _calories,
        protein: _protein,
        carbs: _carbs,
        fats: _fats,
        glycemicIndex: widget.foodItem.glycemicIndex,
        mealType: widget.mealType,
        inputMethod: 'manual',
        timestamp: DateTime.now(),
      );

      await MealJournalService().addMeal(uid, meal);

      if (!mounted) return;
      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('\u2713 ${widget.foodItem.name} added to ${widget.mealType}'),
          backgroundColor: AppColors.primary,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.foodItem.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_border, color: Colors.black),
            onPressed: () {},
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE0E0E0)),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Section 1: Serving Size
            _buildServingSection(),
            const Divider(height: 1),

            // Section 2: Calorie Display
            _buildCalorieDisplay(),
            const Divider(height: 1),

            // Section 3: Macro Pills
            _buildMacroPills(),
            const Divider(height: 1),

            // Section 4: Add to Diary Button
            _buildAddButton(),

            // Section 5: Nutritional Info Table
            _buildNutritionalInfo(),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildServingSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Serving Size',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const Spacer(),
              Text(
                '${_quantity.toInt()} g',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presets.map(_buildPresetChip).toList(),
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.primarySurface,
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.15),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 20),
            ),
            child: Slider(
              value: _quantity.clamp(_minQuantity, _maxQuantity),
              min: _minQuantity,
              max: _maxQuantity,
              divisions: ((_maxQuantity - _minQuantity) / 5).round(),
              onChanged: (value) {
                setState(() => _quantity = value);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_minQuantity.toInt()} g',
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                Text(
                  '${_maxQuantity.toInt()} g',
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(double value) {
    final isActive = (_quantity - value).abs() < 0.5;
    return GestureDetector(
      onTap: () => setState(() => _quantity = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.primarySurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.primaryBorder,
          ),
        ),
        child: Text(
          '${value.toInt()}g',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildCalorieDisplay() {
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: _calories, end: _calories),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            builder: (context, value, _) => Text(
              value.toInt().toString(),
              style: const TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const Text(
            'Calories',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroPills() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _macroPill(
            label: 'Carbs',
            value: _carbs,
            tintColor: const Color(0xFFE3F2FD),
            textColor: const Color(0xFF1565C0),
          ),
          _macroPill(
            label: 'Fat',
            value: _fats,
            tintColor: const Color(0xFFFFF8E1),
            textColor: const Color(0xFFE65100),
          ),
          _macroPill(
            label: 'Protein',
            value: _protein,
            tintColor: const Color(0xFFFCE4EC),
            textColor: const Color(0xFFB71C1C),
          ),
        ],
      ),
    );
  }

  Widget _macroPill({
    required String label,
    required double value,
    required Color tintColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: tintColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            '${value.toStringAsFixed(1)}g',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          onPressed: _isSaving ? null : _addToDiary,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'ADD TO DIARY',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 1.2,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildNutritionalInfo() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nutritional Information',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _nutritionRow('Calories', '${_calories.toInt()}'),
          _nutritionRow('Total Fat', '${_fats.toStringAsFixed(1)}g'),
          _nutritionRow('  Saturated Fat', '\u2014', indented: true),
          _nutritionRow('  Trans Fat', '\u2014', indented: true),
          _nutritionRow(
              'Total Carbohydrate', '${_carbs.toStringAsFixed(1)}g'),
          _nutritionRow('  Dietary Fiber', '\u2014', indented: true),
          _nutritionRow('  Sugars', '\u2014', indented: true),
          _nutritionRow('Protein', '${_protein.toStringAsFixed(1)}g'),
          _nutritionRow(
            'Glycemic Index',
            widget.foodItem.glycemicIndex == 0
                ? '\u2014'
                : '${widget.foodItem.glycemicIndex}',
          ),
        ],
      ),
    );
  }

  Widget _nutritionRow(String label, String value, {bool indented = false}) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: indented ? 16 : 0,
            top: 8,
            bottom: 8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label.trim(),
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 13, color: Colors.black),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: Colors.grey.shade200),
      ],
    );
  }
}
