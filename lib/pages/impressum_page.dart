import 'package:flutter/material.dart';

class ImpressumPage extends StatelessWidget {
  const ImpressumPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Impressum')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Prename-App',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Dies ist ein Platzhalter für rechtliche Angaben. '
                'Hier wird ein vollständiges Impressum mit Kontaktdaten, '
                'Verantwortlichen und sonstigen Pflichtangaben gemäß geltender Gesetze ergaenzt.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Kontakt'),
                    SizedBox(height: 8),
                    Text('E-Mail: kontakt@example.com'),
                    Text('Telefon: +49 123 4567890'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
