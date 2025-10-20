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
    return Row(
      children: <Widget>[
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: hasValue
                ? Colors.lightGreen.shade400
                : Colors.blueGrey.shade400,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            tagLabel,
            style: const TextStyle(
              color: Colors.white,
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
                        ? Colors.lightGreen.shade400
                        : Colors.grey.shade300,
                  ),
                  color: hasValue
                      ? Colors.lightGreen.shade50
                      : Colors.grey.shade100,
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
                              ? Colors.lightGreen.shade700
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_drop_down,
                      color: hasValue
                          ? Colors.lightGreen.shade600
                          : Colors.grey.shade500,
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
            child: Icon(Icons.drag_handle, color: Colors.grey.shade400),
          ),
      ],
    );
  }
}
