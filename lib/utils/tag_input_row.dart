import 'package:flutter/material.dart';

class TagInputRow extends StatelessWidget {
  final String tagLabel;
  final TextEditingController controller;
  final ValueChanged<String>? onSubmitted;
  final bool isEditable;
  final bool isReorderable;

  const TagInputRow({
    super.key,
    required this.tagLabel,
    required this.controller,
    this.onSubmitted,
    this.isEditable = true,
    this.isReorderable = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: <Widget>[
          Container(
            width: 30,
            alignment: Alignment.center,
            child: Text(
              tagLabel,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: Colors.blueGrey,
              ),
            ),
          ),
          const SizedBox(width: 8),

          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: (value) {
                FocusScope.of(context).unfocus();
                onSubmitted?.call(value);
              },
              enabled: isEditable,
              style: const TextStyle(fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                border: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blueGrey),
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                hintText: isEditable ? 'Tag ${tagLabel} eingeben' : '',
                fillColor: isEditable ? Colors.white : Colors.grey.shade200,
                filled: true,
              ),
            ),
          ),

          if (isReorderable)
            const Padding(
              padding: EdgeInsets.only(right: 8.0),
              child: Icon(Icons.drag_handle, color: Colors.grey, size: 24),
            ),
        ],
      ),
    );
  }
}
