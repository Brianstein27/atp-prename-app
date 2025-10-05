import 'package:flutter/material.dart';

class TagInputRow extends StatelessWidget {
  final String tagLabel;
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final bool isEditable;
  final bool isReorderable;

  const TagInputRow({
    super.key,
    required this.tagLabel,
    required this.controller,
    required this.onSubmitted,
    this.isEditable = true,
    this.isReorderable = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        // Tag-Label
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: isEditable
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

        // Tag-Eingabefeld
        Expanded(
          child: TextField(
            controller: controller,
            // Wenn nicht bearbeitbar, kann der Nutzer nichts tippen
            readOnly: !isEditable,
            style: TextStyle(
              fontWeight: isEditable ? FontWeight.normal : FontWeight.bold,
              color: isEditable ? Colors.black : Colors.blueGrey.shade700,
            ),
            decoration: InputDecoration(
              hintText: isEditable ? 'Tag $tagLabel eingeben' : '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isEditable
                      ? Colors.lightGreen.shade200
                      : Colors.grey.shade300,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Colors.lightGreen.shade400,
                  width: 2,
                ),
              ),
            ),
            onSubmitted: onSubmitted,
            onChanged: (value) {
              // Aktualisiert den Dateinamen sofort bei jeder Eingabe
              onSubmitted(value);
            },
          ),
        ),
        // Reorder-Handle (nur sichtbar, wenn verschiebbar)
        if (isReorderable)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Icon(Icons.drag_handle, color: Colors.grey.shade400),
          ),
      ],
    );
  }
}
