import 'package:flutter/material.dart';

class TagInputRow extends StatelessWidget {
  final String tagLabel;
  final String value;
  final String placeholder;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final bool isReorderable;
  final bool isLocked;
  final VoidCallback? onLockedTap;

  const TagInputRow({
    super.key,
    required this.tagLabel,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.onClear,
    this.isReorderable = true,
    this.isLocked = false,
    this.onLockedTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value.isNotEmpty;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveOnTap = isLocked ? onLockedTap : onTap;
    final borderColor = isLocked
        ? scheme.outlineVariant.withValues(alpha: 0.6)
        : hasValue
            ? scheme.primary
            : scheme.outlineVariant.withValues(alpha: 0.6);
    final backgroundColor = isLocked
        ? (isDark ? const Color(0xFF1F2A21) : scheme.surfaceContainerHighest)
        : isDark
            ? const Color(0xFF273429)
            : Colors.white;
    final textColor = isLocked
        ? scheme.onSurfaceVariant.withValues(alpha: 0.7)
        : hasValue
            ? scheme.primary
            : scheme.onSurfaceVariant;
    final indicatorColor = isLocked
        ? scheme.outlineVariant
        : hasValue
            ? scheme.primary
            : (isDark ? const Color(0xFF2C3A2F) : scheme.surfaceContainerHighest);
    final indicatorTextColor = isLocked
        ? scheme.onSurfaceVariant.withValues(alpha: 0.6)
        : hasValue
            ? scheme.onPrimary
            : scheme.onSurfaceVariant;
    final trailingIcon =
        isLocked ? Icons.lock_outline : Icons.arrow_drop_down;
    return Row(
      children: <Widget>[
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: indicatorColor,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            tagLabel,
            style: TextStyle(
              color: indicatorTextColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: effectiveOnTap,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: borderColor,
                  ),
                  color: backgroundColor,
                ),
                child: Row(
                  children: [
                    if (!isLocked && hasValue && onClear != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkResponse(
                          onTap: onClear,
                          radius: 16,
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.lightGreen.shade600,
                          ),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        hasValue ? value : placeholder,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: hasValue && !isLocked
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: textColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      trailingIcon,
                      color: textColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (isReorderable)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Icon(
              Icons.drag_handle,
              color: scheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
