import 'package:busco_driver/domain/entities/entities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/constants.dart';
import '../../blocs/blocs.dart';
import '../../widgets/widgets.dart';

class TripScreen extends StatefulWidget {
  const TripScreen({super.key});
  @override State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  bool _booted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_booted) {
      _booted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
    }
  }

  void _boot() {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    final d = auth.driver;
    if (d.busId != null) {
      context.read<TripBloc>().add(TripLoad(d.busId!));
      context.read<GpsBloc>().add(GpsStart(d.busId!));
    }
  }

  @override
  Widget build(BuildContext context) => BlocListener<TripBloc, TripState>(
    listener: (ctx, state) {
      if (state is TripEnded) {
        BSnack.ok(ctx, 'Trip ended — ${state.pax} passengers');
        ctx.read<StatsBloc>().add(StatsLoad(
          (ctx.read<AuthBloc>().state as AuthAuthenticated).driver.driverId,
        ));
      }
      if (state is TripError) BSnack.err(ctx, state.msg);
    },
    child: Scaffold(
      backgroundColor: C.of(context).bg,
      appBar: const BAppBar('Trip', canPop: false),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (ctx, authState) {
          if (authState is! AuthAuthenticated) return const BEmpty('Not logged in');
          final driver = authState.driver;
          if (driver.busId == null) {
            return const BEmpty('No bus assigned',
                subtitle: 'Contact your dispatcher to assign a bus.',
                icon: Icons.directions_bus_outlined);
          }
          return BlocBuilder<TripBloc, TripState>(
            builder: (ctx, tripState) {
              if (tripState is TripLoading) return const BLoading();
              if (tripState is TripActive)  return _ActiveTripView(driver: driver, ts: tripState);
              if (tripState is TripInactive || tripState is TripEnded || tripState is TripInitial)
                return _InactiveTripView(driver: driver);
              if (tripState is TripError) return _InactiveTripView(driver: driver);
              return const BLoading();
            },
          );
        },
      ),
    ),
  );
}

// ── INACTIVE VIEW ────────────────────────────────────────────
class _InactiveTripView extends StatelessWidget {
  final dynamic driver;
  const _InactiveTripView({required this.driver});

  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Sp.md),
      child: Column(children: [

        // Bus info card
        BCard(child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Brand.sky.withOpacity(0.12),
              borderRadius: BorderRadius.circular(Rd.md),
            ),
            child: Icon(Icons.directions_bus_rounded, color: Brand.navy, size: 26),
          ),
          const SizedBox(width: Sp.md),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bus ${driver.busNumber ?? '–'}', style: T.h4()),
              if (driver.lineNumber != null)
                Text('Line ${driver.lineNumber}',
                    style: T.bodySm(c: c.inkSoft)),
            ],
          )),
          BlocBuilder<BusBloc, BusState>(
            builder: (_, bs) => bs is BusLoaded
                ? BChip.status(bs.bus.status.label)
                : BChip.status('IDLE'),
          ),
        ])),

        const SizedBox(height: Sp.lg),

        // Ready state
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Sp.xl),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(Rd.xl),
            border: Border.all(color: c.border),
          ),
          child: Column(children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: Brand.sky.withOpacity(0.10),
                shape: BoxShape.circle,
                border: Border.all(color: Brand.sky.withOpacity(0.20), width: 2),
              ),
              child: Icon(Icons.directions_bus_rounded, color: Brand.navy, size: 36),
            ),
            const SizedBox(height: Sp.md),
            Text('Ready to Depart', style: T.h3()),
            const SizedBox(height: Sp.xs),
            Text('Start a new trip to begin tracking\npassengers and fares',
                style: T.bodySm(c: c.inkSoft), textAlign: TextAlign.center),
          ]),
        ),

        const SizedBox(height: Sp.lg),

        BBtn('Start Trip',
          icon: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
          onTap: () => context.read<TripBloc>().add(
            TripStart(driver.busId!, driver.driverId),
          ),
        ),

        const SizedBox(height: Sp.sm),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.gps_fixed, size: 12, color: c.inkHint),
          const SizedBox(width: 4),
          Text('GPS tracking will start automatically',
              style: T.caption(c: c.inkHint)),
        ]),
      ]),
    );
  }
}

// ── ACTIVE TRIP VIEW ─────────────────────────────────────────
class _ActiveTripView extends StatelessWidget {
  final dynamic    driver;
  final TripActive ts;
  const _ActiveTripView({required this.driver, required this.ts});

  @override
  Widget build(BuildContext context) {
    final c   = C.of(context);
    final e   = ts.elapsed;
    final hh  = e.inHours.toString().padLeft(2, '0');
    final mm  = (e.inMinutes  % 60).toString().padLeft(2, '0');
    final ss_ = (e.inSeconds  % 60).toString().padLeft(2, '0');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Sp.md),
      child: Column(children: [

        // Timer card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Sp.lg),
          decoration: BoxDecoration(
            color: c.greenBg,
            borderRadius: BorderRadius.circular(Rd.xl),
            border: Border.all(color: c.green.withOpacity(0.3)),
          ),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: c.green, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: c.green.withOpacity(0.5), blurRadius: 6)],
                ),
              ),
              const SizedBox(width: 7),
              Text('TRIP #${ts.trip.tripId} — IN PROGRESS',
                  style: T.label(c: c.green)),
            ]),
            const SizedBox(height: Sp.md),
            Text('$hh:$mm:$ss_',
                style: T.num(c: c.green, size: 52).copyWith(letterSpacing: 4)),
            const SizedBox(height: 4),
            Text('elapsed time', style: T.caption(c: c.green.withOpacity(0.6))),
          ]),
        ),

        const SizedBox(height: Sp.md),

        // Stats row
        Row(children: [
          Expanded(child: BCard(
            borderColor: Brand.sky.withOpacity(0.25),
            child: Column(children: [
              Icon(Icons.people_outline, color: Brand.navy, size: 20),
              const SizedBox(height: 6),
              Text('${ts.pax}', style: T.num(c: Brand.navy, size: 28)),
              Text('Passengers', style: T.caption(c: c.inkSoft)),
            ]),
          )),
          const SizedBox(width: Sp.sm),
          Expanded(child: BCard(
            child: Column(children: [
              Icon(Icons.gps_fixed, color: Brand.sky, size: 20),
              const SizedBox(height: 6),
              BlocBuilder<GpsBloc, GpsState>(
                builder: (_, gs) {
                  final tracking = gs is GpsTracking;
                  return Column(children: [
                    Text(tracking ? 'Active' : 'Off',
                        style: T.num(c: tracking ? c.blue : c.inkSoft, size: 20)),
                    Text('GPS', style: T.caption(c: c.inkSoft)),
                  ]);
                },
              ),
            ]),
          )),
        ]),

        const SizedBox(height: Sp.md),

        BBtn('Scan / Add Passenger',
          icon: Icon(Icons.person_add_outlined, color: Colors.white, size: 18),
          onTap: () => _showAddPassenger(context),
        ),

        const SizedBox(height: Sp.sm),

        BBtn('End Trip',
          bg: c.redBg,
          fg: c.red,
          icon: Icon(Icons.stop_circle_outlined, color: c.red, size: 18),
          onTap: () => _confirmEnd(context),
        ),

        const SizedBox(height: Sp.lg),
        Text('Bus ${driver.busNumber ?? '–'} · started ${_fmt(ts.trip.startTime)}',
            style: T.caption(c: c.inkHint)),
      ]),
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';

  void _showAddPassenger(BuildContext context) {
    final c = C.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Rd.xxl)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.md, Sp.lg, Sp.xl),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const BSheetHandle(),
          const SizedBox(height: Sp.sm),
          Text('Add Passenger', style: T.h3()),
          const SizedBox(height: 4),
          Text('Tap NFC card or add manually', style: T.bodySm(c: c.inkSoft)),
          const SizedBox(height: Sp.lg),
          BBtn('Add Manually', onTap: () {
            Navigator.pop(ctx);
            context.read<TripBloc>().add(const TripAddPassenger());
            BSnack.info(context, 'Passenger added');
          }),
          const SizedBox(height: Sp.sm),
          BGhostBtn('Cancel', onTap: () => Navigator.pop(ctx)),
        ]),
      ),
    );
  }

  void _confirmEnd(BuildContext context) {
    final c = C.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('End Trip?', style: T.h3()),
        content: Text(
          'This will end Trip #${ts.trip.tripId} with ${ts.pax} passengers.',
          style: T.body(c: c.inkSoft)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: T.btn(c: c.inkSoft)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<TripBloc>().add(TripEnd(ts.trip.tripId));
              context.read<GpsBloc>().add(const GpsStop());
            },
            child: Text('End Trip', style: T.btn(c: c.red)),
          ),
        ],
      ),
    );
  }
}
