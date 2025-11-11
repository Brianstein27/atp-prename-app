import 'package:flutter/material.dart';
import '../l10n/localization_helper.dart';

class ImpressumPage extends StatelessWidget {
  const ImpressumPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(de: 'Impressum', en: 'Imprint')),
      ),
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
                context.tr(
                  de:
                      'Dies ist ein Platzhalter für rechtliche Angaben. Hier wird ein vollständiges Impressum mit Kontaktdaten, Verantwortlichen und sonstigen Pflichtangaben gemäß geltender Gesetze ergänzt.',
                  en:
                      'This is a placeholder for legal information. A complete imprint with contact details, persons in charge, and all mandatory notices required by law will appear here.',
                ),
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
                  children: [
                    Text(
                      context.tr(de: 'Kontakt', en: 'Contact'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr(
                        de: 'E-Mail: kontakt@example.com',
                        en: 'Email: contact@example.com',
                      ),
                    ),
                    Text(
                      context.tr(
                        de: 'Telefon: +49 123 4567890',
                        en: 'Phone: +49 123 4567890',
                      ),
                    ),
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
