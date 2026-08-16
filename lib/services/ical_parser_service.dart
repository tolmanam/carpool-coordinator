import '../models/models.dart';

class IcalParserService {
  static List<LocalIcalEvent> parseIcalContent(String icalString, String scheduleId) {
    final List<LocalIcalEvent> events = [];
    final lines = icalString.split(RegExp(r'\r?\n'));

    String? uid;
    String? summary;
    DateTime? dtStart;
    DateTime? dtEnd;

    bool inEvent = false;

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim();
      if (line.isEmpty) continue;

      if (line == 'BEGIN:VEVENT') {
        inEvent = true;
        uid = null;
        summary = null;
        dtStart = null;
        dtEnd = null;
      } else if (line == 'END:VEVENT') {
        inEvent = false;
        if (summary != null && dtStart != null) {
          final startTime = dtStart.millisecondsSinceEpoch;
          final endTime = dtEnd?.millisecondsSinceEpoch ?? (startTime + 3600000);
          final eventId = uid ?? '${scheduleId}_$startTime';

          events.add(LocalIcalEvent(
            id: eventId,
            scheduleId: scheduleId,
            title: summary,
            startTime: startTime,
            endTime: endTime,
          ));

          for (var week = 1; week <= 3; week++) {
            final nextStart = dtStart.add(Duration(days: 7 * week));
            final nextEnd = dtEnd != null ? dtEnd.add(Duration(days: 7 * week)) : nextStart.add(const Duration(hours: 1));
            events.add(LocalIcalEvent(
              id: '${eventId}_wk$week',
              scheduleId: scheduleId,
              title: summary,
              startTime: nextStart.millisecondsSinceEpoch,
              endTime: nextEnd.millisecondsSinceEpoch,
            ));
          }
        }
      } else if (inEvent) {
        if (line.startsWith('UID:')) {
          uid = line.substring(4).trim();
        } else if (line.startsWith('SUMMARY:')) {
          summary = line.substring(8).trim();
        } else if (line.startsWith('DTSTART')) {
          dtStart = _parseIcalDateTime(line);
        } else if (line.startsWith('DTEND')) {
          dtEnd = _parseIcalDateTime(line);
        }
      }
    }

    return events;
  }

  static DateTime? _parseIcalDateTime(String line) {
    final parts = line.split(':');
    if (parts.length < 2) return null;
    final val = parts.last.trim();

    try {
      if (val.length >= 15) {
        final year = int.parse(val.substring(0, 4));
        final month = int.parse(val.substring(4, 6));
        final day = int.parse(val.substring(6, 8));
        final hour = int.parse(val.substring(9, 11));
        final minute = int.parse(val.substring(11, 13));
        final second = int.parse(val.substring(13, 15));
        return DateTime.utc(year, month, day, hour, minute, second);
      } else if (val.length >= 8) {
        final year = int.parse(val.substring(0, 4));
        final month = int.parse(val.substring(4, 6));
        final day = int.parse(val.substring(6, 8));
        return DateTime.utc(year, month, day);
      }
    } catch (_) {}
    return null;
  }
}
