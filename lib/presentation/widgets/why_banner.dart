import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Expandable info banner that explains why the current onboarding question
/// is being asked. Tap to toggle between a 2-line clamp and the full text.
class WhyBanner extends StatefulWidget {
  final String explanation;
  final Color accentColor;

  const WhyBanner({
    super.key,
    required this.explanation,
    required this.accentColor,
  });

  @override
  State<WhyBanner> createState() => _WhyBannerState();
}

class _WhyBannerState extends State<WhyBanner> {
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  bool _bodyOverflows(BoxConstraints constraints) {
    final span = TextSpan(text: widget.explanation, style: _bodyStyle);
    final tp = TextPainter(
      text: span,
      maxLines: 2,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: constraints.maxWidth);
    return tp.didExceedMaxLines;
  }

  TextStyle get _bodyStyle => GoogleFonts.nunito(
    fontSize: 12,
    color: Colors.white.withValues(alpha: 0.82),
    height: 1.35,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: widget.accentColor,
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.eco, size: 18, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final overflows = _bodyOverflows(constraints);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Why this question?',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.explanation,
                            maxLines: _expanded ? null : 2,
                            overflow: _expanded
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                            style: _bodyStyle,
                          ),
                          if (overflows) ...[
                            const SizedBox(height: 4),
                            Text(
                              _expanded ? 'Less' : 'More',
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                color: Colors.white,
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
