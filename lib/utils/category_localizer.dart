import 'package:flutter/material.dart';
import 'package:ideai/l10n/app_localizations.dart';

String localizeCategory(String categoryKey, BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  switch (categoryKey) {
    case 'Tutti': return l10n.categoryAll;
    case 'Marketing': return l10n.categoryMarketing;
    case 'Coding': return l10n.categoryCoding;
    case 'Immagini': return l10n.categoryImages;
    case 'Email': return l10n.categoryEmail;
    case 'Social Media': return l10n.categorySocial;
    case 'Analisi': return l10n.categoryAnalytics;
    case 'Studio': return l10n.categoryStudy;
    case 'Scrittura': return l10n.categoryWriting;
    default: return categoryKey;
  }
}

String localizeSectionTitle(String titolo, BuildContext context) {
  final lang = Localizations.localeOf(context).languageCode;
  if (lang == 'it') return titolo;
  switch (titolo) {
    case 'Ruolo': return 'Role';
    case 'Contesto': return 'Context';
    case 'Istruzioni': return 'Instructions';
    case 'Formato output': return 'Format';
    case 'Vincoli': return 'Constraints';
    default: return titolo;
  }
}

String localizeAIOption(String optionKey, BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  switch (optionKey) {
    case 'Generico': return l10n.aiOptionGeneric;
    default: return optionKey;
  }
}
