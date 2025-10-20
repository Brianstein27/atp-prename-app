import 'package:flutter/material.dart';

class TagInputRow extends StatelessWidget {
  final String tagLabel;
  final String value;
  final String placeholder;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final bool isReorderable;

  const TagInputRow({
    super.key,
    required this.tagLabel,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.onClear,
    this.isReorderable = true,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value.isNotEmpty;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: <Widget>[
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: hasValue
                ? scheme.primary
                : (isDark
                    ? const Color(0xFF2C3A2F)
                    : scheme.surfaceVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            tagLabel,
            style: TextStyle(
              color: hasValue
                  ? scheme.onPrimary
                  : scheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasValue
                        ? scheme.primary
                        : scheme.outlineVariant.withOpacity(0.6),
                  ),
                  color: isDark
                      ? const Color(0xFF273429)
                      : Colors.white,
                ),
                child: Row(
                  children: [
                    if (hasValue && onClear != null)
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
                          fontWeight:
                              hasValue ? FontWeight.w600 : FontWeight.normal,
                          color: hasValue
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_drop_down,
                      color: scheme.onSurfaceVariant,
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
