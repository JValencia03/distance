import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:distance/data/models.dart';
import 'package:distance/features/plans/create_plan_screen.dart';
import 'package:distance/l10n/app_localizations.dart';
import 'package:distance/shared/formatting.dart';

import '../fake_api.dart';

void main() {
  final es = lookupAppLocalizations(const Locale('es'));
  final en = lookupAppLocalizations(const Locale('en'));
  // English times use the CLDR narrow no-break space before AM/PM.
  final narrowSpace = String.fromCharCode(0x202F);
  // Distances join number and unit with no-break spaces.
  final nbsp = String.fromCharCode(0xA0);

  // In the app, flutter_localizations loads the date symbols; plain unit
  // tests must do it themselves.
  setUpAll(initializeDateFormatting);

  group('formatPlanDate', () {
    final now = DateTime(2026, 10, 9, 12);

    test('uses relative names for today and tomorrow', () {
      expect(
        formatPlanDate(DateTime(2026, 10, 9, 17), now: now, l10n: es),
        'Hoy · 17:00',
      );
      expect(
        formatPlanDate(DateTime(2026, 10, 10, 8, 5), now: now, l10n: en),
        'Tomorrow · 8:05${narrowSpace}AM',
      );
    });

    test('uses the locale date and clock format for later dates', () {
      final date = DateTime(2026, 10, 17, 21, 30);
      expect(formatPlanDate(date, now: now, l10n: es), 'sáb, 17 oct · 21:30');
      expect(
        formatPlanDate(date, now: now, l10n: en),
        'Sat, Oct 17 · 9:30${narrowSpace}PM',
      );
    });
  });

  test('formatParticipants pluralizes and shows the limit', () {
    final one = Plan.fromJson(planJson());
    final limited = Plan.fromJson(
      planJson(participantCount: 3, maxParticipants: 4),
    );
    expect(formatParticipants(one, es), '1 participante');
    expect(formatParticipants(one, en), '1 participant');
    expect(formatParticipants(limited, es), '3/4 participantes');
    expect(formatParticipants(limited, en), '3/4 participants');
  });

  test('formatDistance uses the locale decimal separator', () {
    expect(formatDistance(0, es), 'En tu zona');
    expect(formatDistance(3.25, es), 'A 3,3${nbsp}km');
    expect(formatDistance(3.25, en), '3.3${nbsp}km${nbsp}away');
  });

  group('plan form validators', () {
    test('participant limit is optional and bounded', () {
      expect(validateMaxParticipants('', es), isNull);
      expect(validateMaxParticipants('2', es), isNull);
      expect(validateMaxParticipants('50', es), isNull);
      expect(
        validateMaxParticipants('1', es),
        'Escribe un número entre 2 y 50.',
      );
      expect(
        validateMaxParticipants('51', en),
        'Enter a number between 2 and 50.',
      );
      expect(validateMaxParticipants('dos', es), isNotNull);
    });

    test('start time must be chosen and in the future', () {
      final now = DateTime(2026, 10, 9, 12);
      expect(
        validateStartsAt(null, now: now, l10n: es),
        es.errorStartsAtRequired,
      );
      expect(validateStartsAt(now, now: now, l10n: en), en.errorStartsAtPast);
      expect(
        validateStartsAt(
          now.subtract(const Duration(minutes: 1)),
          now: now,
          l10n: es,
        ),
        es.errorStartsAtPast,
      );
      expect(
        validateStartsAt(
          now.add(const Duration(minutes: 1)),
          now: now,
          l10n: es,
        ),
        isNull,
      );
    });

    test('required fields reject blank text', () {
      expect(validateRequired('   ', 'x'), 'x');
      expect(validateRequired('Café', 'x'), isNull);
    });
  });
}
