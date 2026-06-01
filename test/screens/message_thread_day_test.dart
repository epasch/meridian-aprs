import 'package:flutter_test/flutter_test.dart';
import 'package:meridian_aprs/screens/message_thread_screen.dart';

void main() {
  group('localDayKey', () {
    test('strips the clock and returns local midnight', () {
      final dt = DateTime(2026, 5, 31, 22, 48, 17);
      expect(localDayKey(dt), DateTime(2026, 5, 31));
    });

    test('keys off the LOCAL calendar day, not the raw (UTC) fields', () {
      // The bug was reading .year/.month/.day off a UTC-flagged instant, which
      // yields the UTC calendar day. localDayKey must convert to local first.
      final instant = DateTime.utc(2026, 6, 1, 2, 48);
      final local = instant.toLocal();
      expect(
        localDayKey(instant),
        DateTime(local.year, local.month, local.day),
      );
    });

    // Timezone-independent invariant: the same absolute instant, whether held
    // as a local or a UTC DateTime, must produce one day key. This is exactly
    // what the reported bug violated — an outgoing send (local) and the reply
    // (received as a UTC instant) split across two day dividers.
    test('is invariant across the same instant expressed in either flag', () {
      final sentLocal = DateTime(2026, 5, 31, 22, 48);
      expect(localDayKey(sentLocal), localDayKey(sentLocal.toUtc()));

      final receivedUtc = DateTime.utc(2026, 6, 1, 2, 48);
      expect(localDayKey(receivedUtc), localDayKey(receivedUtc.toLocal()));
    });
  });

  group('dayDividerLabel', () {
    final now = DateTime(2026, 5, 31, 22, 48);

    test('today / yesterday', () {
      expect(dayDividerLabel(DateTime(2026, 5, 31), now: now), 'Today');
      expect(dayDividerLabel(DateTime(2026, 5, 30), now: now), 'Yesterday');
    });

    test('a future/other day in the same year is dated without a year', () {
      expect(dayDividerLabel(DateTime(2026, 6, 1), now: now), 'Mon, Jun 1');
    });

    test('a different year includes the year', () {
      expect(
        dayDividerLabel(DateTime(2025, 12, 25), now: now),
        'Thu, Dec 25, 2025',
      );
    });
  });
}
