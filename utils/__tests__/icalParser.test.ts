import { parseIcalString } from '../icalParser';

describe('Client-Side iCal Parser Tests', () => {
  const scheduleId = 'sched_soccer_2023';

  it('correctly parses standard single events without recurrence', () => {
    const singleEventIcs = `BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Carpool Coordinator//NONSGML v1.0//EN
BEGIN:VEVENT
UID:single-event-id-123
DTSTART:20231024T180000Z
DTEND:20231024T193000Z
SUMMARY:U10 Soccer Practice
END:VEVENT
END:VCALENDAR`;

    const occurrences = parseIcalString(singleEventIcs, scheduleId);
    expect(occurrences.length).toBe(1);
    expect(occurrences[0].title).toBe('U10 Soccer Practice');
    expect(occurrences[0].id).toBe('single-event-id-123_1698170400000');
    expect(occurrences[0].startTime).toBe(Date.UTC(2023, 9, 24, 18, 0, 0));
    expect(occurrences[0].endTime).toBe(Date.UTC(2023, 9, 24, 19, 30, 0));
  });

  it('correctly parses and expands basic WEEKLY recurrence rules', () => {
    const recurringEventIcs = `BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:recurring-event-id-456
DTSTART:20231024T150000Z
DTEND:20231024T160000Z
SUMMARY:Westside Math Tutoring
RRULE:FREQ=WEEKLY;BYDAY=TU,TH;UNTIL=20231110T235959Z
END:VEVENT
END:VCALENDAR`;

    const occurrences = parseIcalString(recurringEventIcs, scheduleId);
    // 2023-10-24 is a Tuesday.
    // Tuesdays/Thursdays between Oct 24 and Nov 10:
    // Oct 24 (TU), Oct 26 (TH), Oct 31 (TU), Nov 2 (TH), Nov 7 (TU), Nov 9 (TH). Total: 6 occurrences.
    expect(occurrences.length).toBe(6);
    expect(occurrences[0].title).toBe('Westside Math Tutoring');
    expect(occurrences.map(o => new Date(o.startTime).getUTCDate())).toEqual([24, 26, 31, 2, 7, 9]);
  });
});
