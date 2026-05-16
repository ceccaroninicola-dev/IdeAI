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
