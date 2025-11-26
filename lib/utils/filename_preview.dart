import 'package:flutter/material.dart';
import '../l10n/localization_helper.dart';

class PreviewSegment {
  final String label;
  final String value;

  const PreviewSegment({required this.label, required this.value});
}

class FilenamePreview extends StatelessWidget {
  final String filename;
  final List<PreviewSegment> segments;
  final String separator;

  const FilenamePreview({
    super.key,
    required this.filename,
    this.segments = const [],
    this.separator = '-',
  });

  String _stripExtension(String name) {
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex <= 0) return name;
    return name.substring(0, dotIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(
            de: 'Aktueller Dateiname',
            en: 'Current file name',
          ),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        if (segments.isNotEmpty)
          Wrap(
            spacing: 4,
            runSpacing: 6,
            alignment: WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              for (var i = 0; i < segments.length; i++) ...[
                _SegmentChip(segment: segments[i]),
                if (i != segments.length - 1)
                  _SeparatorColumn(separator: separator),
              ],
            ],
          )
        else
          Text(
            _stripExtension(filename),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
      ],
    );
  }
}

class _SegmentChip extends StatelessWidget {
  final PreviewSegment segment;

  const _SegmentChip({required this.segment});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const baseStyle = TextStyle(
      fontFamily: 'monospace',
      fontWeight: FontWeight.w600,
      fontSize: 16,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            segment.value,
            style: baseStyle.copyWith(
              color: scheme.onSurface,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            segment.label,
            style: TextStyle(
              fontSize: 14,
              color: scheme.secondary,
              letterSpacing: 0.3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SeparatorColumn extends StatelessWidget {
  final String separator;

  const _SeparatorColumn({required this.separator});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const baseStyle = TextStyle(
      fontFamily: 'monospace',
      fontWeight: FontWeight.w600,
      fontSize: 16,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            separator,
            style: baseStyle.copyWith(
              color: scheme.onSurfaceVariant,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}
