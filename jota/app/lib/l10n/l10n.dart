// ============================================================================
//  Jota — the one import for translated strings
//
//  `context.l10n.searchNotes` instead of the AppLocalizations.of() mouthful.
//  Everything user-facing goes through here; figures and identifiers
//  (N-015, 00:15, JOTA-5848) never do — mono figures are the brand's own
//  script in every language.
// ============================================================================
import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
