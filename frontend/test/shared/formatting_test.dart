import 'package:flutter_test/flutter_test.dart';

import 'package:distance/data/models.dart';
import 'package:distance/features/plans/create_plan_screen.dart';
import 'package:distance/shared/formatting.dart';

import '../fake_api.dart';

void main() {
  group('formatPlanDate', () {
    final now = DateTime(2026, 10, 9, 12);

    test('uses relative names for today and tomorrow', () {
      expect(
        formatPlanDate(DateTime(2026, 10, 9, 17), now: now),
        'Hoy · 17:00',
      );
      expect(
        formatPlanDate(DateTime(2026, 10, 10, 8, 5), now: now),
        'Mañana · 08:05',
      );
    });

    test('uses weekday, day and month for later dates', () {
      expect(
        formatPlanDate(DateTime(2026, 10, 17, 9, 30), now: now),
        'sáb 17 oct · 09:30',
      );
    });
  });

  test('formatParticipants shows the limit when there is one', () {
    expect(formatParticipants(Plan.fromJson(planJson())), '1 participante');
    expect(
      formatParticipants(
        Plan.fromJson(planJson(participantCount: 1, maxParticipants: 4)),
      ),
      '1/4 participantes',
    );
  });

  test('formatDistance', () {
    expect(formatDistance(0), 'En tu zona');
    expect(formatDistance(3.25), 'A 3.3 km');
  });

  group('plan form validators', () {
    test('participant limit is optional and bounded', () {
      expect(validateMaxParticipants(''), isNull);
      expect(validateMaxParticipants('2'), isNull);
      expect(validateMaxParticipants('50'), isNull);
      expect(validateMaxParticipants('1'), isNotNull);
      expect(validateMaxParticipants('51'), isNotNull);
      expect(validateMaxParticipants('dos'), isNotNull);
    });

    test('start time must be chosen and in the future', () {
      final now = DateTime(2026, 10, 9, 12);
      expect(validateStartsAt(null, now: now), isNotNull);
      expect(validateStartsAt(now, now: now), isNotNull);
      expect(
        validateStartsAt(now.subtract(const Duration(minutes: 1)), now: now),
        isNotNull,
      );
      expect(
        validateStartsAt(now.add(const Duration(minutes: 1)), now: now),
        isNull,
      );
    });

    test('required fields reject blank text', () {
      expect(validateRequired('   ', 'x'), 'x');
      expect(validateRequired('Café', 'x'), isNull);
    });
  });
}
