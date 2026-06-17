import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/constants.dart';
import '../../domain/entities/entities.dart';

// ─────────────────────────────────────────────────────────────
//  DATA SOURCE — confirmed against live schema 2026-03-09
//
//  REAL COLUMN NAMES:
//    drivers      : driver_id, name, phone, email, password_hash,
//                   current_bus_id, wallet_id, license_no, avatar_url
//    trips        : trip_id, bus_id, driver_id, active, start_time,
//                   end_time, list_passengers (jsonb), passenger_count,
//                   km_per_fare (NOT NULL), location_start (NOT NULL PostGIS)
//    buses        : bus_id, number_bus, number_line, status (enum),
//                   gps_lat, gps_lng, gps_updated_at, count_today_trips
//    wallets      : wallet_id, balance, currency (CHAR — trim!), driver_id
//    bus_incidents: incident_id, bus_id, by_reported, severity_level (enum),
//                   description, ts (NOT NULL), reported_at, status
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
      try {
        final res = await _api.rpc('driver_login', {
          'p_email':    email.trim().toLowerCase(),
          'p_password': pw,
        });
        final j = Map<String, dynamic>.from(res as Map);
        final driver = _driverFromRpc(j);
        _api.setSession(driver.driverId);
        await _persist(driver);
        return driver;
      } catch (e) { lastErr = e as Exception?; }
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
    final rows = await _api.get('drivers', p: {
      'driver_id': 'eq.$driverId',
      'select':    'driver_id,name,email,phone,license_no,current_bus_id,wallet_id,avatar_url',
    }) as List?;
    if (rows == null || rows.isEmpty) throw const ApiEx('Driver not found');
    final j = Map<String, dynamic>.from(rows.first as Map);

    final rawBusId    = j['current_bus_id'] as int?;
    final rawWalletId = j['wallet_id']      as int?;

    final results = await Future.wait([
      rawBusId != null
          ? _api.get('buses', p: {
              'bus_id': 'eq.$rawBusId',
              'select': 'bus_id,number_bus,number_line,status',
            }).catchError((_) => null)
          : Future.value(null),
      rawWalletId != null
          ? _api.get('wallets', p: {
              'wallet_id': 'eq.$rawWalletId',
              'select':    'wallet_id,balance,currency',
            }).catchError((_) => null)
          : Future.value(null),
      _api.get('wallets', p: {
        'driver_id': 'eq.$driverId',
        'select':    'wallet_id,balance,currency',
        'limit':     '1',
      }).catchError((_) => null),
    ]);

    Map<String, dynamic>? bus;
    final bRes = results[0];
    if (bRes is List && bRes.isNotEmpty) {
      bus = Map<String, dynamic>.from(bRes.first as Map);
    }

    Map<String, dynamic>? wallet;
    final wRes = results[1];
    if (wRes is List && wRes.isNotEmpty) {
      wallet = Map<String, dynamic>.from(wRes.first as Map);
    } else {
      final wRes2 = results[2];
      if (wRes2 is List && wRes2.isNotEmpty) {
        wallet = Map<String, dynamic>.from(wRes2.first as Map);
      }
    }

    final driver = Driver(
      driverId:   j['driver_id']  as int,
      name:       (j['name']      as String?) ?? '',
      email:      (j['email']     as String?) ?? '',
      phone:      (j['phone']     as String?) ?? '',
      licenseNo:  j['license_no'] as String?,
      busId:      bus?['bus_id']       as int?   ?? rawBusId,
      busNumber:  bus?['number_bus']?.toString(),
      lineNumber: bus?['number_line']?.toString(),
      walletId:   wallet?['wallet_id'] as int?  ?? rawWalletId,
      balance:    double.tryParse((wallet?['balance'] ?? '0').toString()) ?? 0.0,
      currency:   (wallet?['currency'] as String?)?.trim() ?? 'EGP',
      avatarUrl:  j['avatar_url'] as String?,
    );
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
    // Update DB — verify the row was actually updated
    final result = await _api.patch(
      'drivers',
      {'driver_id': 'eq.$driverId'},
      {'avatar_url': url},
    );
    // If Supabase returned 204 (null) or empty list, patch may not have matched
    if (result is List && result.isEmpty) {
      throw const ApiEx('Avatar URL not saved — driver row not found in DB');
    }
    await _s.write(key: SK.avatarUrl, value: url);
    return url;
  }

  // ══════════════════════════════════════════════════════════
  //  TRIPS
  //  IMPORTANT:

  //    - passenger_count derived from list_passengers (jsonb) OR column
  // ══════════════════════════════════════════════════════════

  Future<Trip?> activeTrip(int busId) async {
    final rows = await _api.get('trips', p: {
      'bus_id': 'eq.$busId',
      'active': 'eq.true',
      'order':  'trip_id.desc',
      'limit':  '1',
      'select': 'trip_id,bus_id,driver_id,active,start_time,end_time,'
                'list_passengers,passenger_count',
    }) as List?;
    if (rows == null || rows.isEmpty) return null;
    return _tripFromJson(Map<String, dynamic>.from(rows.first as Map));
  }

 Future<Trip> startTrip({
  required int busId,
  required int driverId,
  required Position position,
}) async {

  final location =
      'SRID=4326;POINT(${position.longitude} ${position.latitude})';


  final payload = {
    'bus_id': busId,
    'driver_id': driverId,
    'active': true,
   'start_time': DateTime.now().toUtc().toIso8601String(), 
    'passenger_count': 0,
    'location_start': location,
  };


  final rows = await _api.post('trips', payload) as List?;

  

  if (rows == null || rows.isEmpty) {
    throw const ApiEx('Failed to start trip');
  }

  final map = Map<String, dynamic>.from(rows.first as Map);



  final t = _tripFromJson(map);


  await _s.write(key: SK.tripId, value: t.tripId.toString());


  return t;
}
  Future<Trip> endTrip(int tripId) async {
    final rows = await _api.patch(
      'trips',
      {'trip_id': 'eq.$tripId'},
      {'active': false, 'end_time': DateTime.now().toUtc().toIso8601String()},
    ) as List?;
    await _s.delete(key: SK.tripId);
    if (rows == null || rows.isEmpty) {
      return Trip(tripId: tripId, busId: 0, active: false, startTime: DateTime.now());
    }
    return _tripFromJson(Map<String, dynamic>.from(rows.first as Map));
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
      'select':    'trip_id,bus_id,driver_id,active,start_time,end_time,'
                   'list_passengers,passenger_count',
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
        passengerCount: _paxCount(j),
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
      'select':     'trip_id,list_passengers,passenger_count',
    }) as List? ?? [];

    int pax = 0;
    double collected = 0.0;
    for (final r in rows) {
      final j = Map<String, dynamic>.from(r as Map);
      pax += _paxCount(j);
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
      'select':     'trip_id,start_time,list_passengers,passenger_count',
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
    final rows = await _api.get('buses', p: {
      'bus_id': 'eq.$busId',
      'select': 'bus_id,number_bus,number_line,status,'
                'gps_lat,gps_lng,gps_updated_at,count_today_trips',
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
  //  severity_level is a Postgres enum — cast to TEXT on insert
  //  'ts' is NOT NULL; 'reported_at' nullable
  // ══════════════════════════════════════════════════════════

  Future<void> reportIncident({
    required int    busId,
    required int    driverId,
    required String severity,
    required String description,
  }) async {
    await _api.post('bus_incidents', {
      'bus_id':         busId,
      'by_reported':    'driver:$driverId',
      'severity_level': severity,
      'description':    description,
    });

    if (severity == 'HIGH') await setBusStatus(busId, 'BROKEN');
  }

  Future<List<Incident>> myIncidents(int driverId, int busId) async {
    try {
      final rows = await _api.get('bus_incidents', p: {
        'bus_id': 'eq.$busId',
        'order':  'ts.desc',
        'limit':  '20',
        'select': 'incident_id,bus_id,severity_level,description,ts,reported_at,status',
      }) as List? ?? [];
      return rows.map((r) {
        final j     = Map<String, dynamic>.from(r as Map);
        final tsStr = j['ts']?.toString() ?? j['reported_at']?.toString();
        return Incident(
          incidentId:  j['incident_id'] as int,
          busId:       j['bus_id']      as int,
          severity:    _severityFromStr(j['severity_level']?.toString() ?? 'LOW'),
          description: (j['description'] as String?) ?? '',
          reportedAt:  DateTime.tryParse(tsStr ?? '') ?? DateTime.now(),
          status:      (j['status'] as String?) ?? 'OPEN',
        );
      }).toList();
    } catch (_) { return []; }
  }

  // ══════════════════════════════════════════════════════════
  //  NFC / CARD
  // ══════════════════════════════════════════════════════════

  Future<ScannedPassenger?> lookupCard(String uid) async {
    final cards = await _api.get('cards', p: {
      'uid': 'eq.$uid', 'select': 'uid,blocked,user_id',
    }) as List?;
    if (cards == null || cards.isEmpty) return null;
    final card   = Map<String, dynamic>.from(cards.first as Map);
    final userId = card['user_id'] as int?;
    if (userId == null) return null;

    final users = await _api.get('users', p: {
      'user_id': 'eq.$userId',
      'select':  'user_id,name,phone,wallets(wallet_id,balance,currency)',
    }) as List?;
    if (users == null || users.isEmpty) return null;
    final u  = Map<String, dynamic>.from(users.first as Map);
    final wl = u['wallets'] as List?;
    if (wl == null || wl.isEmpty) return null;
    final w  = Map<String, dynamic>.from(wl.first as Map);
    return ScannedPassenger(
      userId:      u['user_id']   as int,
      name:        u['name']      as String,
      phone:       u['phone']     as String?,
      walletId:    w['wallet_id'] as int,
      balance:     double.tryParse(w['balance']?.toString() ?? '0') ?? 0.0,
      currency:    (w['currency'] as String?)?.trim() ?? 'EGP',
      cardUid:     card['uid']    as String,
      cardBlocked: card['blocked'] == true,
    );
  }

  Future<void> deductFare({
    required int    walletId,
    required double currentBalance,
    required double fare,
    required int    tripId,
  }) async {
    if (currentBalance < fare) throw const ApiEx('Insufficient balance');
    await _api.patch('wallets', {'wallet_id': 'eq.$walletId'}, {'balance': currentBalance - fare});
    await _api.post('transactions', {
      'wallet_id': walletId, 'fare': fare,
      'type': 'DEBIT', 'method_payment': 'NFC',
      'trip_id': tripId, 'ts': DateTime.now().toIso8601String(),
    });
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
  passengerCount: _paxCount(j),
);

  BusInfo _busFromJson(Map<String, dynamic> j) => BusInfo(
    busId:          j['bus_id']     as int,
    busNumber:      j['number_bus']?.toString()  ?? '',
    lineNumber:     j['number_line']?.toString(),
    status:         BusStatusX.fromString(j['status']?.toString() ?? 'IDLE'),
    gpsLat:         j['gps_lat']   != null ? double.tryParse(j['gps_lat'].toString()) : null,
    gpsLng:         j['gps_lng']   != null ? double.tryParse(j['gps_lng'].toString()) : null,
    gpsUpdatedAt:   j['gps_updated_at'] != null ? DateTime.tryParse(j['gps_updated_at'].toString()) : null,
    countTodayTrips: (j['count_today_trips'] as int?) ?? 0,
  );

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

  // Passenger count — prefers integer column, falls back to jsonb array length
  int _paxCount(Map<String, dynamic> j) {
    final fromCol = j['passenger_count'] as int?;
    if (fromCol != null && fromCol > 0) return fromCol;
    final list = j['list_passengers'];
    if (list is List) return list.length;
    return 0;
  }
}
