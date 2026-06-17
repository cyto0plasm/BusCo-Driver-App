// ─────────────────────────────────────────────────────────────
//  DOMAIN ENTITIES — pure Dart, no framework dependencies
// ─────────────────────────────────────────────────────────────

// ── ENUMS ────────────────────────────────────────────────────
enum TxType { debit, recharge, transfer }
extension TxTypeX on TxType {
  bool   get isCredit => this == TxType.recharge || this == TxType.transfer;
  String get label => switch (this) {
    TxType.debit    => 'Fare',
    TxType.recharge => 'Recharge',
    TxType.transfer => 'Transfer',
  };
}

enum BusStatusEnum { active, idle, broken }
extension BusStatusX on BusStatusEnum {
  String get label => switch (this) {
    BusStatusEnum.active => 'ACTIVE',
    BusStatusEnum.idle   => 'IDLE',
    BusStatusEnum.broken => 'BROKEN',
  };
  static BusStatusEnum fromString(String s) => switch (s.toUpperCase()) {
    'ACTIVE' => BusStatusEnum.active,
    'BROKEN' => BusStatusEnum.broken,
    _        => BusStatusEnum.idle,
  };
}

enum IncidentSeverity { low, medium, high }
extension IncidentSeverityX on IncidentSeverity {
  String get label => switch (this) {
    IncidentSeverity.low    => 'LOW',
    IncidentSeverity.medium => 'MEDIUM',
    IncidentSeverity.high   => 'HIGH',
  };
}

// ── DRIVER ───────────────────────────────────────────────────
class Driver {
  final int     driverId;
  final String  name;
  final String  email;
  final String  phone;
  final String? licenseNo;
  final int?    busId;
  final String? busNumber;
  final String? lineNumber;
  final int?    walletId;
  final double  balance;
  final String  currency;
  final String? avatarUrl;

  const Driver({
    required this.driverId,
    required this.name,
    required this.email,
    required this.phone,
    this.licenseNo,
    this.busId,
    this.busNumber,
    this.lineNumber,
    this.walletId,
    this.balance = 0.0,
    this.currency = 'EGP',
    this.avatarUrl,
  });

  Driver copyWith({
    String? name, String? phone, String? licenseNo,
    int? busId, String? busNumber, String? lineNumber,
    int? walletId, double? balance, String? currency, String? avatarUrl,
  }) => Driver(
    driverId: driverId, email: email,
    name:       name       ?? this.name,
    phone:      phone      ?? this.phone,
    licenseNo:  licenseNo  ?? this.licenseNo,
    busId:      busId      ?? this.busId,
    busNumber:  busNumber  ?? this.busNumber,
    lineNumber: lineNumber ?? this.lineNumber,
    walletId:   walletId   ?? this.walletId,
    balance:    balance    ?? this.balance,
    currency:   currency   ?? this.currency,
    avatarUrl:  avatarUrl  ?? this.avatarUrl,
  );
}

// ── TRIP ─────────────────────────────────────────────────────
class Trip {
  final int      tripId;
  final int      busId;
  final int?     driverId;
  final bool     active;
  final DateTime startTime;
  final DateTime? endTime;
  final int      passengerCount;

  const Trip({
    required this.tripId, required this.busId, this.driverId,
    required this.active, required this.startTime,
    this.endTime, this.passengerCount = 0,
  });

  Duration get elapsed => DateTime.now().difference(startTime);

  Trip copyWith({int? passengerCount, bool? active, DateTime? endTime}) => Trip(
    tripId: tripId, busId: busId, driverId: driverId,
    active:         active         ?? this.active,
    startTime:      startTime,
    endTime:        endTime        ?? this.endTime,
    passengerCount: passengerCount ?? this.passengerCount,
  );
}

// ── TRIP SUMMARY ─────────────────────────────────────────────
class TripSummary {
  final int      tripId;
  final int      busId;
  final String?  busNumber;
  final String?  lineNumber;
  final DateTime startTime;
  final DateTime? endTime;
  final int      passengerCount;
  final double   totalCollected;
  final String   currency;
  final bool     active;

  const TripSummary({
    required this.tripId, required this.busId,
    this.busNumber, this.lineNumber,
    required this.startTime, this.endTime,
    required this.passengerCount,
    required this.totalCollected,
    this.currency = 'EGP', this.active = false,
  });

  Duration get duration => (endTime ?? DateTime.now()).difference(startTime);
}

// ── DAILY STATS ──────────────────────────────────────────────
class DailyStats {
  final int    tripsToday;
  final int    passengersToday;
  final double collectedToday;
  const DailyStats({
    required this.tripsToday,
    required this.passengersToday,
    required this.collectedToday,
  });
}

// ── DAILY BREAKDOWN (for chart) ──────────────────────────────
class DayStats {
  final DateTime date;
  final int      trips;
  final double   collected;
  const DayStats({required this.date, required this.trips, required this.collected});
}

// ── BUS STATUS ───────────────────────────────────────────────
class BusInfo {
  final int           busId;
  final String        busNumber;
  final String?       lineNumber;
  final BusStatusEnum status;
  final double?       gpsLat;
  final double?       gpsLng;
  final DateTime?     gpsUpdatedAt;
  final int           countTodayTrips;

  const BusInfo({
    required this.busId, required this.busNumber,
    this.lineNumber, required this.status,
    this.gpsLat, this.gpsLng, this.gpsUpdatedAt,
    this.countTodayTrips = 0,
  });

  BusInfo copyWith({BusStatusEnum? status}) => BusInfo(
    busId:           busId,
    busNumber:       busNumber,
    lineNumber:      lineNumber,
    status:          status ?? this.status,
    gpsLat:          gpsLat,
    gpsLng:          gpsLng,
    gpsUpdatedAt:    gpsUpdatedAt,
    countTodayTrips: countTodayTrips,
  );
}

// ── GPS POINT ────────────────────────────────────────────────
class GpsPoint {
  final double lat, lng;
  final DateTime timestamp;
  const GpsPoint({required this.lat, required this.lng, required this.timestamp});
}

// ── WALLET TRANSACTION ───────────────────────────────────────
class WalletTx {
  final int      txId;
  final int      walletId;
  final double   amount;
  final TxType   type;
  final String?  method;
  final int?     tripId;
  final DateTime timestamp;

  const WalletTx({
    required this.txId, required this.walletId,
    required this.amount, required this.type,
    this.method, this.tripId, required this.timestamp,
  });
}

// ── INCIDENT ─────────────────────────────────────────────────
class Incident {
  final int              incidentId;
  final int              busId;
  final String?          busNumber;
  final IncidentSeverity severity;
  final String           description;
  final DateTime         reportedAt;
  final String           status; // 'OPEN', 'RESOLVED'

  const Incident({
    required this.incidentId,
    required this.busId,
    this.busNumber,
    required this.severity,
    required this.description,
    required this.reportedAt,
    this.status = 'OPEN',
  });
}

// ── SCANNED PASSENGER ────────────────────────────────────────
class ScannedPassenger {
  final int     userId;
  final String  name;
  final String? phone;
  final int     walletId;
  final double  balance;
  final String  currency;
  final String  cardUid;
  final bool    cardBlocked;

  const ScannedPassenger({
    required this.userId, required this.name, this.phone,
    required this.walletId, required this.balance,
    required this.currency, required this.cardUid,
    required this.cardBlocked,
  });
}
