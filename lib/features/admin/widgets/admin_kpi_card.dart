import 'package:flutter/material.dart';

/// Reusable, interactive KPI metric card for the AdoptMatch Admin & Shelter Dashboard.
/// Supports selection state, hover/splash effects, action indicators, and responsive constraints.
class AdminKpiCard extends StatefulWidget {
  final String title;
  final String count;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onTap;
  final bool isSelected;
  final String? badgeText;
  final String? subtitle;
  final double minWidth;

  const AdminKpiCard({
    super.key,
    required this.title,
    required this.count,
    required this.icon,
    required this.accentColor,
    this.onTap,
    this.isSelected = false,
    this.badgeText,
    this.subtitle,
    this.minWidth = 160,
  });

  @override
  State<AdminKpiCard> createState() => _AdminKpiCardState();
}

class _AdminKpiCardState extends State<AdminKpiCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final hasAction = widget.onTap != null;
    final isSelected = widget.isSelected;

    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: widget.minWidth,
        maxWidth: 240,
      ),
      child: MouseRegion(
        onEnter: (_) {
          if (mounted) setState(() => _isHovered = true);
        },
        onExit: (_) {
          if (mounted) setState(() => _isHovered = false);
        },
        cursor: hasAction ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          transform: Matrix4.identity()..translate(0.0, _isHovered ? -2.0 : 0.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? widget.accentColor
                  : (_isHovered
                      ? widget.accentColor.withOpacity(0.5)
                      : const Color(0xFFE2E8F0)),
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? widget.accentColor.withOpacity(0.18)
                    : (_isHovered
                        ? Colors.black.withOpacity(0.08)
                        : Colors.black.withOpacity(0.03)),
                blurRadius: isSelected ? 12 : (_isHovered ? 10 : 6),
                offset: Offset(0, isSelected ? 4 : (_isHovered ? 4 : 2)),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(16),
              splashColor: widget.accentColor.withOpacity(0.12),
              highlightColor: widget.accentColor.withOpacity(0.06),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top row: Icon container + Badge / Filter indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: widget.accentColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            widget.icon,
                            color: widget.accentColor,
                            size: 20,
                          ),
                        ),
                        if (widget.badgeText != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: widget.accentColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              widget.badgeText!,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: widget.accentColor,
                              ),
                            ),
                          )
                        else if (hasAction)
                          AnimatedOpacity(
                            opacity: isSelected || _isHovered ? 1.0 : 0.4,
                            duration: const Duration(milliseconds: 150),
                            child: Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 12,
                              color: isSelected ? widget.accentColor : const Color(0xFF94A3B8),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Metric Count
                    Text(
                      widget.count,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? widget.accentColor : const Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 3),

                    // Metric Title
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Subtitle / Action hint if provided
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.subtitle!,
                        style: TextStyle(
                          fontSize: 10,
                          color: widget.accentColor.withOpacity(0.85),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

