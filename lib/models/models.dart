class Family {
  final String matrixId;
  final String familyName;
  final double latitude;
  final double longitude;
  final String addressText;
  final int lastUpdated;

  Family({
    required this.matrixId,
    required this.familyName,
    required this.latitude,
    required this.longitude,
    required this.addressText,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() => {
        'matrix_id': matrixId,
        'family_name': familyName,
        'latitude': latitude,
        'longitude': longitude,
        'address_text': addressText,
        'last_updated': lastUpdated,
      };

  factory Family.fromMap(Map<String, dynamic> map) => Family(
        matrixId: map['matrix_id'] as String,
        familyName: map['family_name'] as String,
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        addressText: map['address_text'] as String? ?? '',
        lastUpdated: map['last_updated'] as int? ?? 0,
      );
}

class FamilyMember {
  final String memberId;
  final String matrixId;
  final String name;
  final String role; // 'parent', 'child', or JSON array string

  FamilyMember({
    required this.memberId,
    required this.matrixId,
    required this.name,
    required this.role,
  });

  Map<String, dynamic> toMap() => {
        'member_id': memberId,
        'matrix_id': matrixId,
        'name': name,
        'role': role,
      };

  factory FamilyMember.fromMap(Map<String, dynamic> map) => FamilyMember(
        memberId: map['member_id'] as String,
        matrixId: map['matrix_id'] as String,
        name: map['name'] as String,
        role: map['role'] as String,
      );
}

class Schedule {
  final String scheduleId;
  final String title;
  final String icalFeedUrl;
  final double latitude;
  final double longitude;
  final String addressText;
  final String homeserverUrl;

  Schedule({
    required this.scheduleId,
    required this.title,
    required this.icalFeedUrl,
    required this.latitude,
    required this.longitude,
    required this.addressText,
    this.homeserverUrl = 'https://matrix.org',
  });

  Map<String, dynamic> toMap() => {
        'schedule_id': scheduleId,
        'title': title,
        'ical_feed_url': icalFeedUrl,
        'latitude': latitude,
        'longitude': longitude,
        'address_text': addressText,
        'homeserver_url': homeserverUrl,
      };

  factory Schedule.fromMap(Map<String, dynamic> map) => Schedule(
        scheduleId: map['schedule_id'] as String,
        title: map['title'] as String,
        icalFeedUrl: map['ical_feed_url'] as String? ?? '',
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        addressText: map['address_text'] as String? ?? '',
        homeserverUrl: map['homeserver_url'] as String? ?? 'https://matrix.org',
      );
}

class LocalIcalEvent {
  final String id;
  final String scheduleId;
  final String title;
  final int startTime; // Epoch milliseconds
  final int endTime;   // Epoch milliseconds

  LocalIcalEvent({
    required this.id,
    required this.scheduleId,
    required this.title,
    required this.startTime,
    required this.endTime,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'schedule_id': scheduleId,
        'title': title,
        'start_time': startTime,
        'end_time': endTime,
      };

  factory LocalIcalEvent.fromMap(Map<String, dynamic> map) => LocalIcalEvent(
        id: map['id'] as String,
        scheduleId: map['schedule_id'] as String,
        title: map['title'] as String,
        startTime: map['start_time'] as int,
        endTime: map['end_time'] as int,
      );
}

class Signup {
  final String id;
  final String scheduleId;
  final int eventTimestamp;
  final String memberId;
  final String role;   // 'rider' | 'driver'
  final String status; // 'scheduled' | 'canceled'

  Signup({
    required this.id,
    required this.scheduleId,
    required this.eventTimestamp,
    required this.memberId,
    required this.role,
    required this.status,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'schedule_id': scheduleId,
        'event_timestamp': eventTimestamp,
        'member_id': memberId,
        'role': role,
        'status': status,
      };

  factory Signup.fromMap(Map<String, dynamic> map) => Signup(
        id: map['id'] as String,
        scheduleId: map['schedule_id'] as String,
        eventTimestamp: map['event_timestamp'] as int,
        memberId: map['member_id'] as String,
        role: map['role'] as String,
        status: map['status'] as String,
      );
}

class RouteWaypoint {
  final String memberId;
  final String type; // 'driver_start' | 'pickup' | 'destination'
  final double latitude;
  final double longitude;
  final int estimatedTime;

  RouteWaypoint({
    required this.memberId,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.estimatedTime,
  });

  Map<String, dynamic> toMap() => {
        'member_id': memberId,
        'type': type,
        'latitude': latitude,
        'longitude': longitude,
        'estimated_time': estimatedTime,
      };

  factory RouteWaypoint.fromMap(Map<String, dynamic> map) => RouteWaypoint(
        memberId: map['member_id'] as String? ?? '',
        type: map['type'] as String,
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        estimatedTime: map['estimated_time'] as int? ?? 0,
      );
}
