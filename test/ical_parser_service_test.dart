import 'package:flutter_test/flutter_test.dart';
import 'package:carpool_coordinator/services/ical_parser_service.dart';

void main() {
  group('IcalParserService Tests', () {
    test('Parses VEVENT lines into LocalIcalEvents', () {
      const icalSample = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:evt_101
SUMMARY:U10 Soccer Practice
DTSTART:20231027T163000Z
DTEND:20231027T180000Z
END:VEVENT
END:VCALENDAR
''';

      final events = IcalParserService.parseIcalContent(icalSample, 'sched_soccer');

      expect(events.isNotEmpty, isTrue);
      expect(events.first.title, equals('U10 Soccer Practice'));
      expect(events.first.scheduleId, equals('sched_soccer'));
      expect(events.first.startTime, equals(DateTime.utc(2023, 10, 27, 16, 30).millisecondsSinceEpoch));
    });
  });
}
