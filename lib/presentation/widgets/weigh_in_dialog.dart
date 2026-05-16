import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../services/weight_service.dart';

/// Modal dialog that prompts the user to log today's weight.
///
/// Usage:
/// ```dart
/// final logged = await showDialog<bool>(
///   context: context,
///   builder: (_) => WeighInDialog(uid: uid, initialWeightKg: profile.weight),
/// );
/// ```
class WeighInDialog extends StatefulWidget {
  final String uid;
  final double initialWeightKg;

  const WeighInDialog({
    super.key,
    required this.uid,
    required this.initialWeightKg,
  });

  @override
  State<WeighInDialog> createState() => _WeighInDialogState();
}

class _WeighInDialogState extends State<WeighInDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialWeightKg > 0
        ? widget.initialWeightKg.toStringAsFixed(1)
        : '',
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim().replaceAll(',', '.');
    final value = double.tryParse(text);
    if (value == null || value < 30 || value > 300) {
      setState(() => _error = 'Enter a weight between 30 and 300 kg.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await WeightService().logWeight(uid: widget.uid, weightKg: value);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not save: $e';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Log today\'s weight',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Weekly check-ins help the AI agent adapt your plan and recalibrate your daily calorie target.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d{1,3}([.,]\d{0,2})?')),
              ],
              decoration: InputDecoration(
                labelText: 'Weight (kg)',
                errorText: _error,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
