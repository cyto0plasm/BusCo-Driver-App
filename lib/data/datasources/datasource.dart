import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/constants.dart';
import '../../domain/entities/entities.dart';

// ─────────────────────────────────────────────────────────────
//  DATA SOURCE — rewritten against confirmed live schema 2026-06-30
//
//  REAL COLUMN NAMES:
//    drivers      : driver_id, name, phone, email, password_hash,
//                   count_trips_daily, wallet_id, card_uid, license_no,
//                   avatar_url   (NO current_bus_id — bus link is
//                   buses.id_driver -> drivers.driver_id)
//    trips        : trip_id, bus_id, driver_id, active, start_time,
//                   end_time, fare (flat fare, copied from routes.fare
//                   at trip start), passenger_count, location_start,
//                   location_end, distance_total   (NO list_passengers,
//                   NO km_per_fare, NO route_id)
//    buses        : bus_id, number_bus, id_driver, route_id, status (enum),
//                   gps_lat, gps_lng, gps_updated_at, count_today_trips,
//                   current_trip_id   (NO number_line — that's on routes,
//                   joined via route_id)
//    routes       : route_id, name, number_line, fare (route base fare —
//                   copied into trips.fare at trip start, NOT per-km)
//    wallets      : wallet_id, balance, currency (CHAR — trim!), driver_id,
//                   profile_id, shipper_id
//    bus_incidents: incident_id, bus_id, trip_id, by_reported,
//                   severity_level (enum incident_severity), description,
//                   reported_at (NOT ts), status, resolved_at
//    cards/NFC    : not implemented for driver app yet — passenger
//                   payment is QR + profiles/wallets, no cards path.
//
//  RPCs used (all confirmed live + schema-correct as of this rewrite):
//    driver_login_email(p_email, p_password)
//    sp_get_driver_home(p_driver_id)
//    sp_start_trip(p_bus_id, p_driver_id, p_lat_start, p_lng_start)
//    sp_end_trip(p_trip_id, p_lat_end, p_lng_end, p_distance_km)
//    sp_report_incident(p_driver_id, p_severity, p_description)
//    sp_get_driver_incidents(p_driver_id, p_limit, p_offset)
// ─────────────────────────────────────────────────────────────
class DS {
  static final DS _i = DS._();
  factory DS() => _i;
  DS._() : _api = Api(), _s = const FlutterSecureStorage();

  final Api                  _api;
  final FlutterSecureStorage _s;

  // ══════════════════════════════════════════════════════════
  //  AUTH
  // ══════════════════════════════════════════════════════════

  Future<Driver> login(String email, String password) async {
    Exception? lastErr;
    for (final pw in [Api.sha256hex(password), password.trim(), password]) {
        print("EMAIL  : '${email.trim().toLowerCase()}'");
  print("PASS   : '$pw'");
  print("LENGTH : ${pw.length}");
  print(password.codeUnits);
      try {
        final res = await _api.rpc('driver_login_email', {
          'p_email':    email.trim().toLowerCase(),
          'p_password': pw,
        });
        final j = Map<String, dynamic>.from(res as Map);
        final driver = _driverFromRpc(j);
        _api.setSession(driver.driverId);
        await _persist(driver);
        return driver;
      } catch (e, st) {
  print("========== LOGIN ERROR ==========");
  print(e);
  print(st);

  if (e is Exception) {
    lastErr = e;
  } else {
    lastErr = Exception(e.toString());
  }
}
    }
    throw lastErr ?? const ApiEx('Login failed');
  }

  Future<Driver?> session() async {
    final ok = await _s.read(key: SK.loggedIn);
    if (ok != 'true') return null;
    final m = await _s.readAll();
    if (m[SK.driverId] == null) return null;
    final driver = _driverFromStorage(m);
    _api.setSession(driver.driverId);
    return driver;
  }

  Future<void> logout() async {
    _api.clearSession();
    await _s.deleteAll();
  }

  // ══════════════════════════════════════════════════════════
  //  DRIVER REFRESH
  // ══════════════════════════════════════════════════════════

  Future<Driver> refreshDriver(int driverId) async {
    final res = await _api.rpc('sp_get_driver_home', {'p_driver_id': driverId});
    final j = Map<String, dynamic>.from(res as Map);
    final driver = _driverFromRpc(j);
    await _persist(driver);
    return driver;
  }

  // ══════════════════════════════════════════════════════════
  //  PROFILE
  // ══════════════════════════════════════════════════════════

  Future<void> updateProfile(int driverId, {
    String? name, String? phone, String? licenseNo,
  }) async {
    final data = <String, dynamic>{};
    if (name      != null && name.isNotEmpty)      data['name']       = name.trim();
    if (phone     != null && phone.isNotEmpty)     data['phone']      = phone.trim();
    if (licenseNo != null && licenseNo.isNotEmpty) data['license_no'] = licenseNo.trim();
    if (data.isEmpty) return;
    await _api.patch('drivers', {'driver_id': 'eq.$driverId'}, data);
    if (name      != null) await _s.write(key: SK.name,      value: name.trim());
    if (phone     != null) await _s.write(key: SK.phone,     value: phone.trim());
    if (licenseNo != null) await _s.write(key: SK.licenseNo, value: licenseNo.trim());
  }

  Future<String> uploadAvatar(int driverId, File file) async {
    final url = await _api.uploadImage(file);
    final result = await _api.patch(
      'drivers',
      {'driver_id': 'eq.$driverId'},
      {'avatar_url': url},
    );
    if (result is List && result.isEmpty) {
      throw const ApiEx('Avatar URL not saved — driver row not found in DB');
    }
    await _s.write(key: SK.avatarUrl, value: url);
    return url;
  }

  // ══════════════════════════════════════════════════════════
  //  TRIPS
  // ══════════════════════════════════════════════════════════

  Future<Trip?> activeTrip(int busId) async {
    final rows = await _api.get('trips', p: {
      'bus_id': 'eq.$busId',
      'active': 'eq.true',
      'order':  'trip_id.desc',
      'limit':  '1',
      'select': 'trip_id,bus_id,driver_id,active,start_time,end_time,fare,passenger_count',
    }) as List?;
    if (rows == null || rows.isEmpty) return null;
    return _tripFromJson(Map<String, dynamic>.from(rows.first as Map));
  }

  Future<Trip> startTrip({
    required int busId,
    required int driverId,
    required Position position,
  }) async {
    final res = await _api.rpc('sp_start_trip', {
      'p_bus_id':    busId,
      'p_driver_id': driverId,
      'p_lat_start': position.latitude,
      'p_lng_start': position.longitude,
    });
    final j = Map<String, dynamic>.from(res as Map);
    if (j['success'] != true) {
      throw ApiEx((j['message'] as String?) ?? 'Failed to start trip');
    }
    final t = Trip(
      tripId:         j['trip_id'] as int,
      busId:          busId,
      driverId:       driverId,
      active:         true,
      startTime:      DateTime.now(),
      passengerCount: 0,
    );
    await _s.write(key: SK.tripId, value: t.tripId.toString());
    return t;
  }

  // NOTE: no distance-tracking accumulator exists yet anywhere in this app —
  // distance_km is sent as 0.0 until that's built. sp_end_trip stores it on
  // trips.distance_total either way.
  Future<Trip> endTrip(int tripId) async {
    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation);
    } catch (_) { /* fall through with null position */ }

    final res = await _api.rpc('sp_end_trip', {
      'p_trip_id':     tripId,
      'p_lat_end':     pos?.latitude  ?? 0.0,
      'p_lng_end':     pos?.longitude ?? 0.0,
      'p_distance_km': 0.0,
    });

    // sp_end_trip has an OUT param (p_status) — PostgREST shape can vary
    // (object, single-key map, or list-of-one). Parse defensively.
    String status = 'UNKNOWN';
    if (res is Map) {
      status = (res['p_status'] ?? res['status'] ?? res.values.first ?? 'UNKNOWN').toString();
    } else if (res is List && res.isNotEmpty && res.first is Map) {
      final m = Map<String, dynamic>.from(res.first as Map);
      status = (m['p_status'] ?? m['status'] ?? m.values.first ?? 'UNKNOWN').toString();
    } else if (res is String) {
      status = res;
    }
    if (status != 'SUCCESS') {
      throw ApiEx('Failed to end trip: $status');
    }

    await _s.delete(key: SK.tripId);
    return Trip(tripId: tripId, busId: 0, active: false, startTime: DateTime.now());
  }

  Future<int?> storedTripId() async =>
      int.tryParse((await _s.read(key: SK.tripId)) ?? '');

  // ══════════════════════════════════════════════════════════
  //  HISTORY & STATS
  // ══════════════════════════════════════════════════════════

  Future<List<TripSummary>> tripHistory(int driverId, {int limit = 100}) async {
    final rows = await _api.get('trips', p: {
      'driver_id': 'eq.$driverId',
      'order':     'trip_id.desc',
      'limit':     '$limit',
      'select':    'trip_id,bus_id,driver_id,active,start_time,end_time,passenger_count',
    }) as List? ?? [];

    final summaries = <TripSummary>[];
    for (final r in rows) {
      final j   = Map<String, dynamic>.from(r as Map);
      final tid = j['trip_id'] as int;
      double total = 0.0;
      try {
        final txns = await _api.get('transactions', p: {
          'trip_id': 'eq.$tid', 'type': 'eq.DEBIT', 'select': 'fare',
        }) as List? ?? [];
        total = txns.fold(0.0, (s, tx) =>
            s + (double.tryParse((tx as Map)['fare']?.toString() ?? '0') ?? 0.0));
      } catch (_) {}
      summaries.add(TripSummary(
        tripId:         tid,
        busId:          j['bus_id'] as int,
        startTime:      DateTime.tryParse(j['start_time']?.toString() ?? '') ?? DateTime.now(),
        endTime:        j['end_time'] != null ? DateTime.tryParse(j['end_time'].toString()) : null,
        passengerCount: (j['passenger_count'] as int?) ?? 0,
        totalCollected: total,
        active:         j['active'] == true,
      ));
    }
    return summaries;
  }

  Future<DailyStats> dailyStats(int driverId) async {
    final start = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)
        .toIso8601String();
    final rows = await _api.get('trips', p: {
      'driver_id':  'eq.$driverId',
      'start_time': 'gte.$start',
      'select':     'trip_id,passenger_count',
    }) as List? ?? [];

    int pax = 0;
    double collected = 0.0;
    for (final r in rows) {
      final j = Map<String, dynamic>.from(r as Map);
      pax += (j['passenger_count'] as int?) ?? 0;
      try {
        final txns = await _api.get('transactions', p: {
          'trip_id': 'eq.${j['trip_id']}', 'type': 'eq.DEBIT', 'select': 'fare',
        }) as List? ?? [];
        collected += txns.fold(0.0, (s, tx) =>
            s + (double.tryParse((tx as Map)['fare']?.toString() ?? '0') ?? 0.0));
      } catch (_) {}
    }
    return DailyStats(tripsToday: rows.length, passengersToday: pax, collectedToday: collected);
  }

  Future<List<DayStats>> weeklyStats(int driverId, {int days = 7}) async {
    final now   = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
    final rows = await _api.get('trips', p: {
      'driver_id':  'eq.$driverId',
      'start_time': 'gte.${start.toIso8601String()}',
      'order':      'start_time.asc',
      'select':     'trip_id,start_time,passenger_count',
    }) as List? ?? [];

    final Map<String, List<Map>> grouped = {};
    for (final r in rows) {
      final j    = Map<String, dynamic>.from(r as Map);
      final date = DateTime.tryParse(j['start_time']?.toString() ?? '');
      if (date == null) continue;
      final key = '${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';
      grouped.putIfAbsent(key, () => []).add(j);
    }

    final result = <DayStats>[];
    for (int i = 0; i < days; i++) {
      final d   = DateTime(start.year, start.month, start.day + i);
      final key = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
      final dayTrips = grouped[key] ?? [];
      double collected = 0;
      for (final t in dayTrips) {
        try {
          final txns = await _api.get('transactions', p: {
            'trip_id': 'eq.${t['trip_id']}', 'type': 'eq.DEBIT', 'select': 'fare',
          }) as List? ?? [];
          collected += txns.fold(0.0, (s, tx) =>
              s + (double.tryParse((tx as Map)['fare']?.toString() ?? '0') ?? 0.0));
        } catch (_) {}
      }
      result.add(DayStats(date: d, trips: dayTrips.length, collected: collected));
    }
    return result;
  }

  // ══════════════════════════════════════════════════════════
  //  BUS
  // ══════════════════════════════════════════════════════════

  Future<BusInfo?> busInfo(int busId) async {
    // number_line lives on routes, not buses — use PostgREST resource
    // embedding via the buses.route_id -> routes.route_id FK.
    final rows = await _api.get('buses', p: {
      'bus_id': 'eq.$busId',
      'select': 'bus_id,number_bus,status,gps_lat,gps_lng,gps_updated_at,'
                'count_today_trips,routes(number_line)',
    }) as List?;
    if (rows == null || rows.isEmpty) return null;
    return _busFromJson(Map<String, dynamic>.from(rows.first as Map));
  }

  Future<void> setBusStatus(int busId, String status) =>
      _api.patch('buses', {'bus_id': 'eq.$busId'}, {'status': status});

  Future<void> pushGps(int busId, double lat, double lng) =>
      _api.patch('buses', {'bus_id': 'eq.$busId'}, {
        'gps_lat': lat, 'gps_lng': lng,
        'gps_updated_at': DateTime.now().toIso8601String(),
      });

  // ══════════════════════════════════════════════════════════
  //  WALLET
  // ══════════════════════════════════════════════════════════

  Future<double> fetchBalance(int walletId) async {
    final rows = await _api.get('wallets', p: {
      'wallet_id': 'eq.$walletId', 'select': 'balance',
    }) as List?;
    if (rows == null || rows.isEmpty) throw const ApiEx('Wallet not found');
    final bal = double.tryParse((rows.first as Map)['balance']?.toString() ?? '0') ?? 0.0;
    await _s.write(key: SK.balance, value: bal.toString());
    return bal;
  }

  Future<List<WalletTx>> transactions(int walletId, {int limit = 100}) async {
    final rows = await _api.get('transactions', p: {
      'wallet_id': 'eq.$walletId',
      'order':     'ts.desc',
      'limit':     '$limit',
      'select':    'transaction_id,wallet_id,fare,type,method_payment,trip_id,ts',
    }) as List? ?? [];
    return rows.map((r) => _txFromJson(Map<String, dynamic>.from(r as Map))).toList();
  }

  // ══════════════════════════════════════════════════════════
  //  INCIDENTS
  // ══════════════════════════════════════════════════════════

  Future<void> reportIncident({
    required int    busId, // kept for call-site compat; sp_report_incident
                            // derives the bus from the driver server-side
    required int    driverId,
    required String severity,
    required String description,
  }) async {
    final res = await _api.rpc('sp_report_incident', {
      'p_driver_id':   driverId,
      'p_severity':    severity,
      'p_description': description,
    });
    final j = Map<String, dynamic>.from(res as Map);
    if (j['success'] != true) {
      throw ApiEx((j['error'] as String?) ?? 'Failed to report incident');
    }
  }

  Future<List<Incident>> myIncidents(int driverId, int busId) async {
    try {
      final res = await _api.rpc('sp_get_driver_incidents', {
        'p_driver_id': driverId,
        'p_limit':     20,
        'p_offset':    0,
      });
      final j = Map<String, dynamic>.from(res as Map);
      final rows = (j['incidents'] as List?) ?? [];
      return rows.map((r) {
        final m = Map<String, dynamic>.from(r as Map);
        return Incident(
          incidentId:  m['incident_id'] as int,
          busId:       m['bus_id']      as int,
          severity:    _severityFromStr((m['severity'] as String?) ?? 'LOW'),
          description: (m['description'] as String?) ?? '',
          reportedAt:  DateTime.tryParse(m['reported_at']?.toString() ?? '') ?? DateTime.now(),
          status:      (m['status'] as String?) ?? 'OPEN',
        );
      }).toList();
    } catch (_) { return []; }
  }

  // ══════════════════════════════════════════════════════════
  //  PRIVATE HELPERS
  // ══════════════════════════════════════════════════════════

  Driver _driverFromRpc(Map<String, dynamic> j) {
    final bus    = j['bus']    as Map<String, dynamic>?;
    final wallet = j['wallet'] as Map<String, dynamic>?;
    return Driver(
      driverId:   j['driver_id']  as int,
      name:       (j['name']      as String?) ?? '',
      email:      (j['email']     as String?) ?? '',
      phone:      (j['phone']     as String?) ?? '',
      licenseNo:  j['license_no'] as String?,
      busId:      bus?['bus_id']       as int?,
      busNumber:  bus?['number_bus']?.toString(),
      lineNumber: bus?['number_line']?.toString(),
      walletId:   wallet?['wallet_id'] as int?,
      balance:    double.tryParse((wallet?['balance'] ?? '0').toString()) ?? 0.0,
      currency:   (wallet?['currency'] as String?)?.trim() ?? 'EGP',
      avatarUrl:  j['avatar_url'] as String?,
    );
  }

  Driver _driverFromStorage(Map<String, String?> m) => Driver(
    driverId:   int.parse(m[SK.driverId]    ?? '0'),
    name:       m[SK.name]                  ?? '',
    email:      m[SK.email]                 ?? '',
    phone:      m[SK.phone]                 ?? '',
    licenseNo:  m[SK.licenseNo],
    busId:      int.tryParse(m[SK.busId]    ?? ''),
    busNumber:  m[SK.busNumber],
    lineNumber: m[SK.lineNumber],
    walletId:   int.tryParse(m[SK.walletId] ?? ''),
    balance:    double.tryParse(m[SK.balance] ?? '0') ?? 0.0,
    currency:   m[SK.currency]              ?? 'EGP',
    avatarUrl:  m[SK.avatarUrl],
  );

  Future<void> _persist(Driver d) async {
    final data = <String, String>{
      SK.loggedIn: 'true',
      SK.driverId: d.driverId.toString(),
      SK.name:     d.name,
      SK.email:    d.email,
      SK.phone:    d.phone,
      SK.balance:  d.balance.toString(),
      SK.currency: d.currency,
    };
    if (d.licenseNo  != null) data[SK.licenseNo]  = d.licenseNo!;
    if (d.busId      != null) data[SK.busId]       = d.busId!.toString();
    if (d.busNumber  != null) data[SK.busNumber]   = d.busNumber!;
    if (d.lineNumber != null) data[SK.lineNumber]  = d.lineNumber!;
    if (d.walletId   != null) data[SK.walletId]    = d.walletId!.toString();
    if (d.avatarUrl  != null) data[SK.avatarUrl]   = d.avatarUrl!;
    for (final e in data.entries) {
      await _s.write(key: e.key, value: e.value);
    }
  }

  Trip _tripFromJson(Map<String, dynamic> j) => Trip(
    tripId:         j['trip_id']   as int,
    busId:          j['bus_id']    as int,
    driverId:       j['driver_id'] as int?,
    active:         j['active'] == true,
    startTime:      DateTime.tryParse(j['start_time']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
    endTime:        j['end_time'] != null ? DateTime.tryParse(j['end_time'].toString())?.toLocal() : null,
    passengerCount: (j['passenger_count'] as int?) ?? 0,
  );

  BusInfo _busFromJson(Map<String, dynamic> j) {
    final route = j['routes'] as Map<String, dynamic>?;
    return BusInfo(
      busId:          j['bus_id']     as int,
      busNumber:      j['number_bus']?.toString()  ?? '',
      lineNumber:     route?['number_line']?.toString(),
      status:         BusStatusX.fromString(j['status']?.toString() ?? 'IDLE'),
      gpsLat:         j['gps_lat']   != null ? double.tryParse(j['gps_lat'].toString()) : null,
      gpsLng:         j['gps_lng']   != null ? double.tryParse(j['gps_lng'].toString()) : null,
      gpsUpdatedAt:   j['gps_updated_at'] != null ? DateTime.tryParse(j['gps_updated_at'].toString()) : null,
      countTodayTrips: (j['count_today_trips'] as int?) ?? 0,
    );
  }

  WalletTx _txFromJson(Map<String, dynamic> j) {
    final typeStr = (j['type'] as String? ?? '').toUpperCase();
    return WalletTx(
      txId:      j['transaction_id'] as int,
      walletId:  j['wallet_id']      as int,
      amount:    double.tryParse(j['fare']?.toString() ?? '0') ?? 0.0,
      type:      switch (typeStr) {
        'DEBIT'    => TxType.debit,
        'RECHARGE' => TxType.recharge,
        'TRANSFER' => TxType.transfer,
        _          => TxType.debit,
      },
      method:    j['method_payment'] as String?,
      tripId:    j['trip_id']        as int?,
      timestamp: DateTime.tryParse(j['ts']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  IncidentSeverity _severityFromStr(String s) => switch (s.toUpperCase()) {
    'HIGH'   => IncidentSeverity.high,
    'MEDIUM' => IncidentSeverity.medium,
    _        => IncidentSeverity.low,
  };
}