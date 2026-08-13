export interface IcalOccurrence {
  id: string;
  scheduleId: string;
  title: string;
  startTime: number; // ms
  endTime: number;   // ms
}

/**
 * Custom parser to extract standard single and recurring occurrences from an iCal (.ics) string.
 * This client-side RFC 5545 string-to-JSON parser avoids external runtime dependencies.
 */
export function parseIcalString(icsContent: string, scheduleId: string): IcalOccurrence[] {
  const lines = icsContent.split(/\r?\n/);
  const occurrences: IcalOccurrence[] = [];

  let inEvent = false;
  let currentEvent: {
    uid?: string;
    summary?: string;
    dtstart?: string;
    dtend?: string;
    rrule?: string;
  } = {};

  for (let i = 0; i < lines.length; i++) {
    let line = lines[i];

    // Handle line folding: if next line starts with space or tab, unfold it
    while (i + 1 < lines.length && (lines[i + 1].startsWith(' ') || lines[i + 1].startsWith('\t'))) {
      line += lines[i + 1].slice(1);
      i++;
    }

    const trimmed = line.trim();
    if (trimmed === 'BEGIN:VEVENT') {
      inEvent = true;
      currentEvent = {};
    } else if (trimmed === 'END:VEVENT') {
      inEvent = false;
      if (currentEvent.uid && currentEvent.dtstart) {
        processEvent(currentEvent, scheduleId, occurrences);
      }
    } else if (inEvent) {
      const colonIdx = trimmed.indexOf(':');
      if (colonIdx !== -1) {
        const keyPart = trimmed.slice(0, colonIdx);
        const value = trimmed.slice(colonIdx + 1);
        const cleanKey = keyPart.split(';')[0].toUpperCase();

        if (cleanKey === 'UID') {
          currentEvent.uid = value;
        } else if (cleanKey === 'SUMMARY') {
          currentEvent.summary = value;
        } else if (cleanKey === 'DTSTART') {
          currentEvent.dtstart = value;
        } else if (cleanKey === 'DTEND') {
          currentEvent.dtend = value;
        } else if (cleanKey === 'RRULE') {
          currentEvent.rrule = value;
        }
      }
    }
  }

  return occurrences;
}

function parseIcalDate(dateStr: string): Date {
  // Format examples:
  // 20231024T180000Z (UTC)
  // 20231024T180000 (Local floating)
  // 20231024 (Date only)
  const cleanStr = dateStr.replace(/[^0-9TZ]/g, '');

  if (cleanStr.length >= 8) {
    const year = parseInt(cleanStr.slice(0, 4), 10);
    const month = parseInt(cleanStr.slice(4, 6), 10) - 1;
    const day = parseInt(cleanStr.slice(6, 8), 10);

    if (cleanStr.includes('T')) {
      const tIdx = cleanStr.indexOf('T');
      const hour = parseInt(cleanStr.slice(tIdx + 1, tIdx + 3), 10) || 0;
      const min = parseInt(cleanStr.slice(tIdx + 3, tIdx + 5), 10) || 0;
      const sec = parseInt(cleanStr.slice(tIdx + 5, tIdx + 7), 10) || 0;

      if (cleanStr.endsWith('Z')) {
        return new Date(Date.UTC(year, month, day, hour, min, sec));
      } else {
        return new Date(year, month, day, hour, min, sec);
      }
    } else {
      return new Date(year, month, day);
    }
  }
  return new Date();
}

function processEvent(
  event: { uid?: string; summary?: string; dtstart?: string; dtend?: string; rrule?: string },
  scheduleId: string,
  occurrences: IcalOccurrence[]
) {
  const startDt = parseIcalDate(event.dtstart!);
  const endDt = event.dtend ? parseIcalDate(event.dtend) : new Date(startDt.getTime() + 60 * 60 * 1000); // Default 1 hour duration
  const durationMs = endDt.getTime() - startDt.getTime();

  const title = event.summary || 'Carpool Event';
  const uid = event.uid!;

  if (!event.rrule) {
    // Single instance event
    occurrences.push({
      id: `${uid}_${startDt.getTime()}`,
      scheduleId,
      title,
      startTime: startDt.getTime(),
      endTime: endDt.getTime(),
    });
    return;
  }

  // Parse basic Recurrence Rule (RRULE)
  // Example: FREQ=WEEKLY;BYDAY=TU,TH;UNTIL=20231231T235959Z
  const rruleParts = event.rrule.split(';');
  let freq = '';
  let until: Date | null = null;
  let count = 10; // Avoid infinite loops, default limit lookahead
  let byday: string[] = [];

  for (const part of rruleParts) {
    const [k, v] = part.split('=');
    if (!k || !v) continue;
    const key = k.toUpperCase();
    if (key === 'FREQ') {
      freq = v.toUpperCase();
    } else if (key === 'UNTIL') {
      until = parseIcalDate(v);
    } else if (key === 'COUNT') {
      count = parseInt(v, 10);
    } else if (key === 'BYDAY') {
      byday = v.toUpperCase().split(',');
    }
  }

  // Generate lookahead occurrences for up to 3 months or until UNTIL date
  const maxLookaheadDate = new Date();
  maxLookaheadDate.setMonth(maxLookaheadDate.getMonth() + 3);
  const endLimit = until ? (until.getTime() < maxLookaheadDate.getTime() ? until : maxLookaheadDate) : maxLookaheadDate;

  let currentStart = new Date(startDt.getTime());
  let generatedCount = 0;

  // Day mapping for BYDAY (e.g., TU -> 2, TH -> 4)
  const dayMap: { [key: string]: number } = {
    SU: 0, MO: 1, TU: 2, WE: 3, TH: 4, FR: 5, SA: 6
  };

  while (currentStart.getTime() <= endLimit.getTime() && generatedCount < count) {
    if (freq === 'DAILY') {
      occurrences.push({
        id: `${uid}_${currentStart.getTime()}`,
        scheduleId,
        title,
        startTime: currentStart.getTime(),
        endTime: currentStart.getTime() + durationMs,
      });
      generatedCount++;
      currentStart.setDate(currentStart.getDate() + 1);
    } else if (freq === 'WEEKLY') {
      if (byday.length > 0) {
        // Expand events for matching days in the week
        for (let d = 0; d < 7; d++) {
          const tempDate = new Date(currentStart.getTime());
          tempDate.setDate(currentStart.getDate() - currentStart.getDay() + d);

          // Verify day of the week matches BYDAY criteria
          const dayName = Object.keys(dayMap).find(k => dayMap[k] === d);
          if (dayName && byday.includes(dayName) && tempDate.getTime() >= startDt.getTime() && tempDate.getTime() <= endLimit.getTime()) {
            occurrences.push({
              id: `${uid}_${tempDate.getTime()}`,
              scheduleId,
              title,
              startTime: tempDate.getTime(),
              endTime: tempDate.getTime() + durationMs,
            });
            generatedCount++;
          }
        }
        currentStart.setDate(currentStart.getDate() + 7);
      } else {
        // Simple weekly interval matching startDt's day of week
        occurrences.push({
          id: `${uid}_${currentStart.getTime()}`,
          scheduleId,
          title,
          startTime: currentStart.getTime(),
          endTime: currentStart.getTime() + durationMs,
        });
        generatedCount++;
        currentStart.setDate(currentStart.getDate() + 7);
      }
    } else {
      // Non-supported frequency or fallback
      occurrences.push({
        id: `${uid}_${currentStart.getTime()}`,
        scheduleId,
        title,
        startTime: currentStart.getTime(),
        endTime: currentStart.getTime() + durationMs,
      });
      break;
    }
  }
}
