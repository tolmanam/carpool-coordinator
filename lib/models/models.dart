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
  final String matrixId; // Family matrix_id link
  final String name;
  final String role; // 'parent', 'child', 'helper'
  final bool isAdult;
  final bool canDrive;
  final String memberMatrixId; // Private individual Matrix ID
  final String email;
  final String avatarUrl;
  final String phone;
  final String emergencyContact;
  final bool requiresBoosterSeat;
  final String medicalNotes;
  final String custodyScheduleJson; // JSON string mapping dayOfWeek (1=Mon..7=Sun) to {latitude, longitude, address}
  final bool isDelegatedHelper;
  final String licenseNumber;
  final bool insuranceAttestation;
  final bool liabilityConfirmed;
  final int maxDetourMinutes;
  final bool supportsBoosterSeats;
  final int boosterCapacity;

  FamilyMember({
    required this.memberId,
    required this.matrixId,
    required this.name,
    required this.role,
    this.isAdult = true,
    this.canDrive = false,
    this.memberMatrixId = '',
    this.email = '',
    this.avatarUrl = '',
    this.phone = '',
    this.emergencyContact = '',
    this.requiresBoosterSeat = false,
    this.medicalNotes = '',
    this.custodyScheduleJson = '',
    this.isDelegatedHelper = false,
    this.licenseNumber = '',
    this.insuranceAttestation = false,
    this.liabilityConfirmed = false,
    this.maxDetourMinutes = 15,
    this.supportsBoosterSeats = true,
    this.boosterCapacity = 2,
  });

  Map<String, dynamic> toMap() => {
        'member_id': memberId,
        'matrix_id': matrixId,
        'name': name,
        'role': role,
        'is_adult': isAdult ? 1 : 0,
        'can_drive': canDrive ? 1 : 0,
        'member_matrix_id': memberMatrixId,
        'email': email,
        'avatar_url': avatarUrl,
        'phone': phone,
        'emergency_contact': emergencyContact,
        'requires_booster_seat': requiresBoosterSeat ? 1 : 0,
        'medical_notes': medicalNotes,
        'custody_schedule_json': custodyScheduleJson,
        'is_delegated_helper': isDelegatedHelper ? 1 : 0,
        'license_number': licenseNumber,
        'insurance_attestation': insuranceAttestation ? 1 : 0,
        'liability_confirmed': liabilityConfirmed ? 1 : 0,
        'max_detour_minutes': maxDetourMinutes,
        'supports_booster_seats': supportsBoosterSeats ? 1 : 0,
        'booster_capacity': boosterCapacity,
      };

  factory FamilyMember.fromMap(Map<String, dynamic> map) => FamilyMember(
        memberId: map['member_id'] as String,
        matrixId: map['matrix_id'] as String,
        name: map['name'] as String,
        role: map['role'] as String,
        isAdult: map['is_adult'] == 1 || map['is_adult'] == true || map['role'] == 'parent' || map['role'] == 'helper',
        canDrive: map['can_drive'] == 1 || map['can_drive'] == true,
        memberMatrixId: map['member_matrix_id'] as String? ?? '',
        email: map['email'] as String? ?? '',
        avatarUrl: map['avatar_url'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
        emergencyContact: map['emergency_contact'] as String? ?? '',
        requiresBoosterSeat: map['requires_booster_seat'] == 1 || map['requires_booster_seat'] == true,
        medicalNotes: map['medical_notes'] as String? ?? '',
        custodyScheduleJson: map['custody_schedule_json'] as String? ?? '',
        isDelegatedHelper: map['is_delegated_helper'] == 1 || map['is_delegated_helper'] == true || map['role'] == 'helper',
        licenseNumber: map['license_number'] as String? ?? '',
        insuranceAttestation: map['insurance_attestation'] == 1 || map['insurance_attestation'] == true,
        liabilityConfirmed: map['liability_confirmed'] == 1 || map['liability_confirmed'] == true,
        maxDetourMinutes: map['max_detour_minutes'] as int? ?? 15,
        supportsBoosterSeats: map['supports_booster_seats'] == null ? true : (map['supports_booster_seats'] == 1 || map['supports_booster_seats'] == true),
        boosterCapacity: map['booster_capacity'] as int? ?? 2,
      );
}

class Organization {
  final String orgId;
  final String name;
  final String icalFeedUrl;
  final String matrixSpaceId;
  final String homeserverUrl;
  final bool locationPrivacyEnforced;
  final String additionalIcalFeedsJson;

  Organization({
    required this.orgId,
    required this.name,
    required this.icalFeedUrl,
    this.matrixSpaceId = '',
    this.homeserverUrl = 'https://matrix.org',
    this.locationPrivacyEnforced = false,
    this.additionalIcalFeedsJson = '',
  });

  Map<String, dynamic> toMap() => {
        'org_id': orgId,
        'name': name,
        'ical_feed_url': icalFeedUrl,
        'matrix_space_id': matrixSpaceId,
        'homeserver_url': homeserverUrl,
        'location_privacy_enforced': locationPrivacyEnforced ? 1 : 0,
        'additional_ical_feeds_json': additionalIcalFeedsJson,
      };

  factory Organization.fromMap(Map<String, dynamic> map) => Organization(
        orgId: map['org_id'] as String,
        name: map['name'] as String,
        icalFeedUrl: map['ical_feed_url'] as String? ?? '',
        matrixSpaceId: map['matrix_space_id'] as String? ?? '',
        homeserverUrl: map['homeserver_url'] as String? ?? 'https://matrix.org',
        locationPrivacyEnforced: map['location_privacy_enforced'] == 1 || map['location_privacy_enforced'] == true,
        additionalIcalFeedsJson: map['additional_ical_feeds_json'] as String? ?? '',
      );
}

class CarpoolCircle {
  final String circleId;
  final String orgId;
  final String name;
  final String matrixRoomId;
  final String pickupAddress;

  CarpoolCircle({
    required this.circleId,
    required this.orgId,
    required this.name,
    this.matrixRoomId = '',
    this.pickupAddress = '',
  });

  Map<String, dynamic> toMap() => {
        'circle_id': circleId,
        'org_id': orgId,
        'name': name,
        'matrix_room_id': matrixRoomId,
        'pickup_address': pickupAddress,
      };

  factory CarpoolCircle.fromMap(Map<String, dynamic> map) => CarpoolCircle(
        circleId: map['circle_id'] as String,
        orgId: map['org_id'] as String,
        name: map['name'] as String,
        matrixRoomId: map['matrix_room_id'] as String? ?? '',
        pickupAddress: map['pickup_address'] as String? ?? '',
      );
}

class OrganizationParticipant {
  final String id;
  final String orgId;
  final String memberId;
  final String circleId;

  OrganizationParticipant({
    required this.id,
    required this.orgId,
    required this.memberId,
    this.circleId = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'org_id': orgId,
        'member_id': memberId,
        'circle_id': circleId,
      };

  factory OrganizationParticipant.fromMap(Map<String, dynamic> map) => OrganizationParticipant(
        id: map['id'] as String,
        orgId: map['org_id'] as String,
        memberId: map['member_id'] as String,
        circleId: map['circle_id'] as String? ?? '',
      );
}

class ChatMessage {
  final String id;
  final String roomId;
  final String senderId;
  final String senderName;
  final String content;
  final int timestamp;

  ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'room_id': roomId,
        'sender_id': senderId,
        'sender_name': senderName,
        'content': content,
        'timestamp': timestamp,
      };

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
        id: map['id'] as String,
        roomId: map['room_id'] as String,
        senderId: map['sender_id'] as String,
        senderName: map['sender_name'] as String,
        content: map['content'] as String,
        timestamp: map['timestamp'] as int,
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
  final String status; // 'scheduled' | 'canceled' | 'requested' | 'claimed'
  final int seatCapacity;
  final String equipmentTags;
  final int boosterCount;
  final String claimedByDriverId;
  final bool handoffPinRequired;
  final String handoffPin;
  final String transferredFromDriverId;

  Signup({
    required this.id,
    required this.scheduleId,
    required this.eventTimestamp,
    required this.memberId,
    required this.role,
    required this.status,
    this.seatCapacity = 4,
    this.equipmentTags = '',
    this.boosterCount = 0,
    this.claimedByDriverId = '',
    this.handoffPinRequired = false,
    this.handoffPin = '',
    this.transferredFromDriverId = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'schedule_id': scheduleId,
        'event_timestamp': eventTimestamp,
        'member_id': memberId,
        'role': role,
        'status': status,
        'seat_capacity': seatCapacity,
        'equipment_tags': equipmentTags,
        'booster_count': boosterCount,
        'claimed_by_driver_id': claimedByDriverId,
        'handoff_pin_required': handoffPinRequired ? 1 : 0,
        'handoff_pin': handoffPin,
        'transferred_from_driver_id': transferredFromDriverId,
      };

  factory Signup.fromMap(Map<String, dynamic> map) => Signup(
        id: map['id'] as String,
        scheduleId: map['schedule_id'] as String,
        eventTimestamp: map['event_timestamp'] as int,
        memberId: map['member_id'] as String,
        role: map['role'] as String,
        status: map['status'] as String,
        seatCapacity: map['seat_capacity'] as int? ?? 4,
        equipmentTags: map['equipment_tags'] as String? ?? '',
        boosterCount: map['booster_count'] as int? ?? 0,
        claimedByDriverId: map['claimed_by_driver_id'] as String? ?? '',
        handoffPinRequired: map['handoff_pin_required'] == 1 || map['handoff_pin_required'] == true,
        handoffPin: map['handoff_pin'] as String? ?? '',
        transferredFromDriverId: map['transferred_from_driver_id'] as String? ?? '',
      );
}

class AttendanceRecord {
  final String id;
  final String scheduleId;
  final int eventTimestamp;
  final String memberId;
  final String checkInType; // 'pickup' | 'dropoff'
  final int timestamp;
  final String driverId;

  AttendanceRecord({
    required this.id,
    required this.scheduleId,
    required this.eventTimestamp,
    required this.memberId,
    required this.checkInType,
    required this.timestamp,
    required this.driverId,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'schedule_id': scheduleId,
        'event_timestamp': eventTimestamp,
        'member_id': memberId,
        'check_in_type': checkInType,
        'timestamp': timestamp,
        'driver_id': driverId,
      };

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) => AttendanceRecord(
        id: map['id'] as String,
        scheduleId: map['schedule_id'] as String,
        eventTimestamp: map['event_timestamp'] as int,
        memberId: map['member_id'] as String,
        checkInType: map['check_in_type'] as String,
        timestamp: map['timestamp'] as int,
        driverId: map['driver_id'] as String? ?? '',
      );
}

class Announcement {
  final String id;
  final String scheduleId;
  final String title;
  final String message;
  final bool isUrgent;
  final int timestamp;

  Announcement({
    required this.id,
    required this.scheduleId,
    required this.title,
    required this.message,
    this.isUrgent = false,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'schedule_id': scheduleId,
        'title': title,
        'message': message,
        'is_urgent': isUrgent ? 1 : 0,
        'timestamp': timestamp,
      };

  factory Announcement.fromMap(Map<String, dynamic> map) => Announcement(
        id: map['id'] as String,
        scheduleId: map['schedule_id'] as String,
        title: map['title'] as String,
        message: map['message'] as String,
        isUrgent: map['is_urgent'] == 1 || map['is_urgent'] == true,
        timestamp: map['timestamp'] as int,
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

class MatrixDevice {
  final String deviceId;
  final String displayName;
  final String lastSeenIp;
  final int lastSeenTs;
  final String verificationStatus; // 'Verified' | 'Unverified' | 'Blocked'

  MatrixDevice({
    required this.deviceId,
    required this.displayName,
    this.lastSeenIp = '',
    this.lastSeenTs = 0,
    this.verificationStatus = 'Unverified',
  });

  MatrixDevice copyWith({
    String? deviceId,
    String? displayName,
    String? lastSeenIp,
    int? lastSeenTs,
    String? verificationStatus,
  }) {
    return MatrixDevice(
      deviceId: deviceId ?? this.deviceId,
      displayName: displayName ?? this.displayName,
      lastSeenIp: lastSeenIp ?? this.lastSeenIp,
      lastSeenTs: lastSeenTs ?? this.lastSeenTs,
      verificationStatus: verificationStatus ?? this.verificationStatus,
    );
  }

  Map<String, dynamic> toMap() => {
        'device_id': deviceId,
        'display_name': displayName,
        'last_seen_ip': lastSeenIp,
        'last_seen_ts': lastSeenTs,
        'verification_status': verificationStatus,
      };

  factory MatrixDevice.fromMap(Map<String, dynamic> map) => MatrixDevice(
        deviceId: map['device_id'] as String? ?? '',
        displayName: map['display_name'] as String? ?? map['device_id'] as String? ?? 'Unknown Device',
        lastSeenIp: map['last_seen_ip'] as String? ?? '',
        lastSeenTs: map['last_seen_ts'] as int? ?? 0,
        verificationStatus: map['verification_status'] as String? ?? 'Unverified',
      );
}
