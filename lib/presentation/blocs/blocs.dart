import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';
import '../../data/datasources/datasource.dart';
import '../../domain/entities/entities.dart';

// ══════════════════════════════════════════════════════════════
//  AUTH BLOC
// ══════════════════════════════════════════════════════════════
abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AuthCheck extends AuthEvent {
  const AuthCheck();
}

class AuthLogin extends AuthEvent {
  final String email, password;
  const AuthLogin(this.email, this.password);
  @override
  List<Object?> get props => [email];
}

class AuthLogout extends AuthEvent {
  const AuthLogout();
}

class AuthUpdateDriver extends AuthEvent {
  final Driver driver;
  const AuthUpdateDriver(this.driver);
  @override
  List<Object?> get props => [driver.driverId];
}

class AuthRefresh extends AuthEvent {
  const AuthRefresh();
}

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthUnauthenticated extends AuthState {}

class AuthAuthenticated extends AuthState {
  final Driver driver;
  const AuthAuthenticated(this.driver);
  @override
  List<Object?> get props =>
      [driver.driverId, driver.balance, driver.avatarUrl];
}

class AuthError extends AuthState {
  final String msg;
  const AuthError(this.msg);
  @override
  List<Object?> get props => [msg];
}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final DS _ds;
  AuthBloc(this._ds) : super(AuthInitial()) {
    on<AuthCheck>((_, emit) async {
      emit(AuthLoading());
      try {
        final d = await _ds.session();
        if (d != null) {
          // Refresh in background
          emit(AuthAuthenticated(d));
          _ds.refreshDriver(d.driverId).then((fresh) {
            if (!isClosed) add(AuthUpdateDriver(fresh));
          }).catchError((_) {});
        } else {
          emit(AuthUnauthenticated());
        }
      } catch (_) {
        emit(AuthUnauthenticated());
      }
    });
    on<AuthLogin>((ev, emit) async {
      emit(AuthLoading());
      try {
        final d = await _ds.login(ev.email, ev.password);
        final fresh = await _ds.refreshDriver(d.driverId).catchError((_) => d);
        emit(AuthAuthenticated(fresh));
      } catch (err) {
        emit(AuthError('$err'));
      }
    });
    on<AuthLogout>((_, emit) async {
      await _ds.logout();
      emit(AuthUnauthenticated());
    });
    on<AuthUpdateDriver>((ev, emit) => emit(AuthAuthenticated(ev.driver)));
    on<AuthRefresh>((_, emit) async {
      final auth = state;
      if (auth is! AuthAuthenticated) return;
      try {
        final fresh = await _ds.refreshDriver(auth.driver.driverId);
        emit(AuthAuthenticated(fresh));
      } catch (_) {}
    });
  }
}

// ══════════════════════════════════════════════════════════════
//  PROFILE BLOC
// ══════════════════════════════════════════════════════════════
abstract class ProfileEvent extends Equatable {
  const ProfileEvent();
  @override
  List<Object?> get props => [];
}

class ProfileSave extends ProfileEvent {
  final int driverId;
  final String? name, phone, licenseNo;
  const ProfileSave(this.driverId, {this.name, this.phone, this.licenseNo});
  @override
  List<Object?> get props => [driverId];
}

class ProfileUploadAvatar extends ProfileEvent {
  final int driverId;
  final File file;
  const ProfileUploadAvatar(this.driverId, this.file);
  @override
  List<Object?> get props => [driverId];
}

class ProfileReset extends ProfileEvent {
  const ProfileReset();
}

abstract class ProfileState extends Equatable {
  const ProfileState();
  @override
  List<Object?> get props => [];
}

class ProfileIdle extends ProfileState {}

class ProfileSaving extends ProfileState {}

class ProfileSaved extends ProfileState {}

class ProfileUploading extends ProfileState {}

class ProfileUploaded extends ProfileState {
  final String url;
  const ProfileUploaded(this.url);
  @override
  List<Object?> get props => [url];
}

class ProfileFailed extends ProfileState {
  final String msg;
  const ProfileFailed(this.msg);
  @override
  List<Object?> get props => [msg];
}

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final DS _ds;
  ProfileBloc(this._ds) : super(ProfileIdle()) {
    on<ProfileSave>((e, emit) async {
      emit(ProfileSaving());
      try {
        await _ds.updateProfile(e.driverId,
            name: e.name, phone: e.phone, licenseNo: e.licenseNo);
        emit(ProfileSaved());
      } catch (err) {
        emit(ProfileFailed('$err'));
      }
    });
    on<ProfileUploadAvatar>((e, emit) async {
      emit(ProfileUploading());
      try {
        final url = await _ds.uploadAvatar(e.driverId, e.file);
        emit(ProfileUploaded(url));
      } catch (err) {
        emit(ProfileFailed('$err'));
      }
    });
    on<ProfileReset>((_, emit) => emit(ProfileIdle()));
  }
}

// ══════════════════════════════════════════════════════════════
//  TRIP BLOC
// ══════════════════════════════════════════════════════════════
abstract class TripEvent extends Equatable {
  const TripEvent();
  @override
  List<Object?> get props => [];
}

class TripLoad extends TripEvent {
  final int busId;
  const TripLoad(this.busId);
  @override
  List<Object?> get props => [busId];
}

class TripStart extends TripEvent {
  final int busId, driverId;
  const TripStart(this.busId, this.driverId);
  @override
  List<Object?> get props => [busId];
}

class TripEnd extends TripEvent {
  final int tripId;
  const TripEnd(this.tripId);
  @override
  List<Object?> get props => [tripId];
}

class TripAddPassenger extends TripEvent {
  const TripAddPassenger();
}

class _Tick extends TripEvent {
  const _Tick();
}

abstract class TripState extends Equatable {
  const TripState();
  @override
  List<Object?> get props => [];
}

class TripInitial extends TripState {}

class TripLoading extends TripState {}

class TripInactive extends TripState {}

class TripActive extends TripState {
  final Trip trip;
  final Duration elapsed;
  final int pax;
  const TripActive(this.trip, this.elapsed, this.pax);
  @override
  List<Object?> get props => [trip.tripId, elapsed.inSeconds, pax];
}

class TripEnded extends TripState {
  final int pax;
  final double collected;
  const TripEnded(this.pax, this.collected);
  @override
  List<Object?> get props => [pax];
}

class TripError extends TripState {
  final String msg;
  const TripError(this.msg);
  @override
  List<Object?> get props => [msg];
}

class TripBloc extends Bloc<TripEvent, TripState> {
  final DS _ds;
  Timer? _t;
  Trip? _trip;
  int _pax = 0;
  bool _closed = false;

  TripBloc(this._ds) : super(TripInitial()) {
    on<TripLoad>((e, emit) async {
      emit(TripLoading());
      try {
        final t = await _ds.activeTrip(e.busId);
        if (t == null) {
          emit(TripInactive());
          return;
        }
        _trip = t;
        _pax = t.passengerCount;
        _startTick();
        emit(TripActive(t, t.elapsed, _pax));
      } catch (err) {
        emit(TripError('$err'));
      }
    });
    on<TripStart>((e, emit) async {
      emit(TripLoading());
      try {
        final t = await _ds.startTrip(busId: e.busId, driverId: e.driverId, position: await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.bestForNavigation)  );
        _trip = t;
        _pax = 0;
        _startTick();
        emit(TripActive(t, Duration.zero, 0));
      } catch (err) {
        emit(TripError('$err'));
      }
    });
    on<TripEnd>((e, emit) async {
      _t?.cancel();
      _t = null;
      try {
        await _ds.endTrip(e.tripId);
        final pax = _pax;
        _trip = null;
        _pax = 0;
        emit(TripEnded(pax, 0));
      } catch (err) {
        emit(TripError('$err'));
      }
    });
    on<TripAddPassenger>((_, emit) {
      if (_trip == null) return;
      _pax++;
      emit(TripActive(_trip!, _trip!.elapsed, _pax));
    });
    on<_Tick>((_, emit) {
      if (_trip != null) emit(TripActive(_trip!, _trip!.elapsed, _pax));
    });
  }

  void _startTick() {
    _t?.cancel();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_closed && !isClosed) add(const _Tick());
    });
  }

  @override
  Future<void> close() {
    _closed = true;
    _t?.cancel();
    return super.close();
  }
}

// ══════════════════════════════════════════════════════════════
//  GPS BLOC
// ══════════════════════════════════════════════════════════════
abstract class GpsEvent extends Equatable {
  const GpsEvent();
  @override
  List<Object?> get props => [];
}

class GpsStart extends GpsEvent {
  final int busId;
  const GpsStart(this.busId);
  @override
  List<Object?> get props => [busId];
}

class GpsStop extends GpsEvent {
  const GpsStop();
}

abstract class GpsState extends Equatable {
  const GpsState();
  @override
  List<Object?> get props => [];
}

class GpsOff extends GpsState {}

class GpsTracking extends GpsState {
  final GpsPoint? last;
  const GpsTracking({this.last});
  @override
  List<Object?> get props => [last?.lat, last?.lng];
}

class GpsBloc extends Bloc<GpsEvent, GpsState> {
  final DS _ds;
  Timer? _t;
  int? _bid;
  bool _closed = false;
  GpsBloc(this._ds) : super(GpsOff()) {
    on<GpsStart>((e, emit) async {
      _bid = e.busId;
      emit(const GpsTracking());
      _t?.cancel();
      _t = Timer.periodic(const Duration(seconds: 15), (_) {
        if (_closed) return;
        Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
        ).then((p) {
          if (!_closed && !isClosed && _bid != null) {
            _ds.pushGps(_bid!, p.latitude, p.longitude).ignore();
            if (!isClosed)
              emit(GpsTracking(
                  last: GpsPoint(
                      lat: p.latitude,
                      lng: p.longitude,
                      timestamp: DateTime.now())));
          }
        }).catchError((_) {});
      });
    });
    on<GpsStop>((_, emit) async {
      _t?.cancel();
      _t = null;
      _bid = null;
      emit(GpsOff());
    });
  }
  @override
  Future<void> close() {
    _closed = true;
    _t?.cancel();
    return super.close();
  }
}

// ══════════════════════════════════════════════════════════════
//  STATS BLOC
// ══════════════════════════════════════════════════════════════
abstract class StatsEvent extends Equatable {
  const StatsEvent();
  @override
  List<Object?> get props => [];
}

class StatsLoad extends StatsEvent {
  final int driverId;
  const StatsLoad(this.driverId);
  @override
  List<Object?> get props => [driverId];
}

class StatsLoadWeekly extends StatsEvent {
  final int driverId;
  const StatsLoadWeekly(this.driverId);
  @override
  List<Object?> get props => [driverId];
}

abstract class StatsState extends Equatable {
  const StatsState();
  @override
  List<Object?> get props => [];
}

class StatsInitial extends StatsState {}

class StatsLoading extends StatsState {}

class StatsLoaded extends StatsState {
  final DailyStats daily;
  final List<DayStats> weekly;
  const StatsLoaded(this.daily, this.weekly);
  @override
  List<Object?> get props => [daily.tripsToday, weekly.length];
}

class StatsError extends StatsState {
  final String msg;
  const StatsError(this.msg);
  @override
  List<Object?> get props => [msg];
}

class StatsBloc extends Bloc<StatsEvent, StatsState> {
  final DS _ds;
  StatsBloc(this._ds) : super(StatsInitial()) {
    on<StatsLoad>((e, emit) async {
      emit(StatsLoading());
      try {
        final daily = await _ds.dailyStats(e.driverId);
        final weekly = await _ds.weeklyStats(e.driverId, days: 7);
        emit(StatsLoaded(daily, weekly));
      } catch (err) {
        emit(StatsError('$err'));
      }
    });
  }
}

// ══════════════════════════════════════════════════════════════
//  HISTORY BLOC
// ══════════════════════════════════════════════════════════════
abstract class HistoryEvent extends Equatable {
  const HistoryEvent();
  @override
  List<Object?> get props => [];
}

class HistoryLoad extends HistoryEvent {
  final int driverId;
  const HistoryLoad(this.driverId);
  @override
  List<Object?> get props => [driverId];
}

abstract class HistoryState extends Equatable {
  const HistoryState();
  @override
  List<Object?> get props => [];
}

class HistoryInitial extends HistoryState {}

class HistoryLoading extends HistoryState {}

class HistoryLoaded extends HistoryState {
  final List<TripSummary> trips;
  const HistoryLoaded(this.trips);
  @override
  List<Object?> get props => [trips.length];
}

class HistoryError extends HistoryState {
  final String msg;
  const HistoryError(this.msg);
  @override
  List<Object?> get props => [msg];
}

class HistoryBloc extends Bloc<HistoryEvent, HistoryState> {
  final DS _ds;
  HistoryBloc(this._ds) : super(HistoryInitial()) {
    on<HistoryLoad>((e, emit) async {
      emit(HistoryLoading());
      try {
        emit(HistoryLoaded(await _ds.tripHistory(e.driverId)));
      } catch (err) {
        emit(HistoryError('$err'));
      }
    });
  }
}

// ══════════════════════════════════════════════════════════════
//  BUS BLOC
// ══════════════════════════════════════════════════════════════
abstract class BusEvent extends Equatable {
  const BusEvent();
  @override
  List<Object?> get props => [];
}

class BusLoad extends BusEvent {
  final int busId;
  const BusLoad(this.busId);
  @override
  List<Object?> get props => [busId];
}

class BusSetStatus extends BusEvent {
  final int busId;
  final String status;
  const BusSetStatus(this.busId, this.status);
  @override
  List<Object?> get props => [busId, status];
}

abstract class BusState extends Equatable {
  const BusState();
  @override
  List<Object?> get props => [];
}

class BusInitial extends BusState {}

class BusLoading extends BusState {}

class BusLoaded extends BusState {
  final BusInfo bus;
  const BusLoaded(this.bus);
  @override
  List<Object?> get props => [bus.busId, bus.status.label];
}

class BusError extends BusState {
  final String msg;
  const BusError(this.msg);
  @override
  List<Object?> get props => [msg];
}

class BusBloc extends Bloc<BusEvent, BusState> {
  final DS _ds;
  BusBloc(this._ds) : super(BusInitial()) {
    on<BusLoad>((e, emit) async {
      emit(BusLoading());
      try {
        final b = await _ds.busInfo(e.busId);
        emit(b != null ? BusLoaded(b) : const BusError('Bus not found'));
      } catch (err) {
        emit(BusError('$err'));
      }
    });
    on<BusSetStatus>((e, emit) async {
      try {
        await _ds.setBusStatus(e.busId, e.status);
        final b = await _ds.busInfo(e.busId);
        if (b != null) emit(BusLoaded(b));
      } catch (err) {
        emit(BusError('$err'));
      }
    });
  }
}

// ══════════════════════════════════════════════════════════════
//  WALLET BLOC
// ══════════════════════════════════════════════════════════════
abstract class WalletEvent extends Equatable {
  const WalletEvent();
  @override
  List<Object?> get props => [];
}

class WalletLoad extends WalletEvent {
  final int walletId;
  const WalletLoad(this.walletId);
  @override
  List<Object?> get props => [walletId];
}

abstract class WalletState extends Equatable {
  const WalletState();
  @override
  List<Object?> get props => [];
}

class WalletInitial extends WalletState {}

class WalletLoading extends WalletState {}

class WalletLoaded extends WalletState {
  final double bal;
  final List<WalletTx> txs;
  const WalletLoaded(this.bal, this.txs);
  @override
  List<Object?> get props => [bal, txs.length];
}

class WalletError extends WalletState {
  final String msg;
  const WalletError(this.msg);
  @override
  List<Object?> get props => [msg];
}

class WalletBloc extends Bloc<WalletEvent, WalletState> {
  final DS _ds;
  WalletBloc(this._ds) : super(WalletInitial()) {
    on<WalletLoad>((e, emit) async {
      emit(WalletLoading());
      try {
        final bal = await _ds.fetchBalance(e.walletId);
        final txs = await _ds.transactions(e.walletId);
        emit(WalletLoaded(bal, txs));
      } catch (err) {
        emit(WalletError('$err'));
      }
    });
  }
}

// ══════════════════════════════════════════════════════════════
//  INCIDENT BLOC
// ══════════════════════════════════════════════════════════════
abstract class IncidentEvent extends Equatable {
  const IncidentEvent();
  @override
  List<Object?> get props => [];
}

class IncidentLoad extends IncidentEvent {
  final int driverId, busId;
  const IncidentLoad(this.driverId, this.busId);
  @override
  List<Object?> get props => [busId];
}

class IncidentSubmit extends IncidentEvent {
  final int busId, driverId;
  final String severity, description;
  const IncidentSubmit(
      {required this.busId,
      required this.driverId,
      required this.severity,
      required this.description});
  @override
  List<Object?> get props => [busId];
}

class IncidentReset extends IncidentEvent {
  const IncidentReset();
}

abstract class IncidentState extends Equatable {
  const IncidentState();
  @override
  List<Object?> get props => [];
}

class IncidentInitial extends IncidentState {}

class IncidentLoading extends IncidentState {}

class IncidentListLoaded extends IncidentState {
  final List<Incident> items;
  const IncidentListLoaded(this.items);
  @override
  List<Object?> get props => [items.length];
}

class IncidentIdle extends IncidentState {
  final List<Incident> items;
  const IncidentIdle(this.items);
  @override
  List<Object?> get props => [items.length];
}

class IncidentSubmitting extends IncidentState {}

class IncidentDone extends IncidentState {
  final List<Incident> items;
  const IncidentDone(this.items);
  @override
  List<Object?> get props => [items.length];
}

class IncidentFailed extends IncidentState {
  final String msg;
  final List<Incident> items;
  const IncidentFailed(this.msg, this.items);
  @override
  List<Object?> get props => [msg];
}

class IncidentBloc extends Bloc<IncidentEvent, IncidentState> {
  final DS _ds;
  List<Incident> _items = [];

  IncidentBloc(this._ds) : super(IncidentInitial()) {
    on<IncidentLoad>((e, emit) async {
      emit(IncidentLoading());
      try {
        _items = await _ds.myIncidents(e.driverId, e.busId);
        emit(IncidentIdle(_items));
      } catch (err) {
        emit(IncidentIdle([]));
      }
    });
    on<IncidentSubmit>((e, emit) async {
      emit(IncidentSubmitting());
      try {
        await _ds.reportIncident(
          busId: e.busId,
          driverId: e.driverId,
          severity: e.severity,
          description: e.description,
        );
        _items = await _ds
            .myIncidents(e.driverId, e.busId)
            .catchError((_) => _items);
        emit(IncidentDone(_items));
      } catch (err) {
        emit(IncidentFailed('$err', _items));
      }
    });
    on<IncidentReset>((_, emit) => emit(IncidentIdle(_items)));
  }
}

// ══════════════════════════════════════════════════════════════
//  THEME BLOC
// ══════════════════════════════════════════════════════════════
class ThemeToggle extends Equatable {
  const ThemeToggle();
  @override
  List<Object?> get props => [];
}

class ThemeState extends Equatable {
  final bool isDark;
  const ThemeState(this.isDark);
  @override
  List<Object?> get props => [isDark];
}

class ThemeBloc extends Bloc<ThemeToggle, ThemeState> {
  ThemeBloc() : super(const ThemeState(true)) {
    on<ThemeToggle>((_, emit) => emit(ThemeState(!state.isDark)));
  }
}
