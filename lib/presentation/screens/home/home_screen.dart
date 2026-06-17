import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/constants.dart';
import '../../blocs/blocs.dart';
import '../../widgets/widgets.dart';
import '../shell/shell_screen.dart';
import '../../../domain/entities/entities.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _booted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_booted) {
      _booted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    }
  }

  void _refresh() {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    context.read<StatsBloc>().add(StatsLoad(auth.driver.driverId));
    if (auth.driver.walletId != null) {
      context.read<WalletBloc>().add(WalletLoad(auth.driver.walletId!));
    }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<AuthBloc, AuthState>(
    builder: (ctx, authState) {
      final driver = authState is AuthAuthenticated ? authState.driver : null;
      final c = C.of(context);
      return Scaffold(
        backgroundColor: c.bg,
        body: RefreshIndicator(
          color: Brand.sky,
          backgroundColor: c.surface,
          onRefresh: () async => _refresh(),
          child: CustomScrollView(slivers: [
            SliverToBoxAdapter(child: _HeroHeader(
              driver: driver, greeting: _greeting())),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, Sp.xl),
              sliver: SliverList(delegate: SliverChildListDelegate([

                // Active trip banner
                BlocBuilder<TripBloc, TripState>(
                  builder: (ctx, ts) {
                    if (ts is! TripActive) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: Sp.md),
                      child: _ActiveTripBanner(ts: ts),
                    );
                  },
                ),

                // Today stats
                BlocBuilder<StatsBloc, StatsState>(
                  builder: (ctx, ss) {
                    final s = ss is StatsLoaded ? ss.daily : null;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BSectionHeader('Today', trailing: Text(
                          DateFormat('EEE, MMM d').format(DateTime.now()),
                          style: T.caption(c: C.of(ctx).inkHint),
                        )),
                        const SizedBox(height: Sp.sm),
                        IntrinsicHeight(child: Row(children: [
                          Expanded(child: _StatTile(
                            value: '${s?.tripsToday ?? 0}',
                            label: 'Trips',
                            icon: Icons.route_outlined,
                            color: Brand.navy,
                          )),
                          const SizedBox(width: Sp.sm),
                          Expanded(child: _StatTile(
                            value: '${s?.passengersToday ?? 0}',
                            label: 'Passengers',
                            icon: Icons.people_outline,
                            color: Brand.sky,
                          )),
                          const SizedBox(width: Sp.sm),
                          Expanded(child: _StatTile(
                            value: '${(s?.collectedToday ?? 0).toStringAsFixed(0)}',
                            label: 'EGP',
                            icon: Icons.payments_outlined,
                            color: Brand.green,
                          )),
                        ])),
                      ],
                    );
                  },
                ),

                const SizedBox(height: Sp.lg),

                // Bus card
                if (driver?.busId != null) ...[
                  BSectionHeader('My Bus'),
                  const SizedBox(height: Sp.sm),
                  BlocBuilder<BusBloc, BusState>(
                    builder: (ctx, bs) {
                      if (bs is BusLoading) return const BLoading();
                      if (bs is BusLoaded)  return _BusCard(bus: bs.bus);
                      final num = driver!.busNumber ?? 'Bus ${driver.busId}';
                      return BCard(child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Brand.light.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(Rd.md),
                          ),
                          child: const Icon(Icons.directions_bus_rounded,
                              color: Brand.navy, size: 22),
                        ),
                        const SizedBox(width: Sp.md),
                        Expanded(child: Text(num, style: T.h4())),
                        BChip.status('IDLE'),
                      ]));
                    },
                  ),
                  const SizedBox(height: Sp.lg),
                ],

                // Quick actions
                BSectionHeader('Quick Actions'),
                const SizedBox(height: Sp.sm),
                _QuickActions(),
                const SizedBox(height: Sp.xl),
              ])),
            ),
          ]),
        ),
      );
    },
  );
}

// ── HERO HEADER — RideWave style ──────────────────────────────
class _HeroHeader extends StatelessWidget {
  final dynamic driver;
  final String  greeting;
  const _HeroHeader({this.driver, required this.greeting});

  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
          Sp.md, MediaQuery.of(context).padding.top + Sp.md, Sp.md, Sp.md),
      color: c.bg,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Top row: greeting + avatar
        Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting, style: T.caption(c: c.inkSoft)),
              const SizedBox(height: 2),
              Text(driver?.name ?? '…',
                  style: T.h2(c: c.ink),
                  overflow: TextOverflow.ellipsis),
            ],
          )),
          const SizedBox(width: Sp.md),
          BAvatar(url: driver?.avatarUrl, name: driver?.name, size: 40),
        ]),

        const SizedBox(height: Sp.md),

        // ── RideWave-style wallet gradient card ──────────────
        BlocBuilder<WalletBloc, WalletState>(
          builder: (_, ws) {
            final bal = ws is WalletLoaded
                ? ws.bal
                : (driver?.balance as double? ?? 0.0);
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Sp.md),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Brand.navy, Brand.sky],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(Rd.lg),
                boxShadow: [
                  BoxShadow(
                    color: Brand.navy.withOpacity(0.25),
                    blurRadius: 16, offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Wallet Balance',
                        style: T.caption(c: Colors.white.withOpacity(0.75))),
                    const SizedBox(height: 4),
                    Text('${bal.toStringAsFixed(2)} EGP',
                        style: T.num(c: Colors.white, size: 24)),
                    if (driver?.busId != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        driver?.busNumber != null
                            ? '🚌 Bus ${driver!.busNumber}'
                            : '🚌 Bus #${driver!.busId}',
                        style: T.caption(c: Colors.white.withOpacity(0.70))),
                    ],
                  ],
                )),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(Rd.md),
                  ),
                  child: const Icon(Icons.account_balance_wallet_outlined,
                      color: Colors.white, size: 22),
                ),
              ]),
            );
          },
        ),
        const SizedBox(height: Sp.sm),
      ]),
    );
  }
}

// ── STAT TILE ─────────────────────────────────────────────────
class _StatTile extends StatelessWidget {
  final String   value;
  final String   label;
  final IconData icon;
  final Color    color;
  const _StatTile({required this.value, required this.label,
    required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => BCard(
    borderColor: color.withOpacity(0.20),
    padding: const EdgeInsets.all(Sp.sm + 2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(Rd.sm),
          ),
          child: Icon(icon, color: color, size: 15),
        ),
        const SizedBox(height: Sp.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: T.num(c: color, size: 20)),
        ),
        Text(label, style: T.caption(c: C.of(context).inkSoft),
            overflow: TextOverflow.ellipsis),
      ],
    ),
  );
}

// ── ACTIVE TRIP BANNER ────────────────────────────────────────
class _ActiveTripBanner extends StatelessWidget {
  final TripActive ts;
  const _ActiveTripBanner({required this.ts});

  @override
  Widget build(BuildContext context) {
    final c  = C.of(context);
    final e  = ts.elapsed;
    final hh = e.inHours.toString().padLeft(2, '0');
    final mm = (e.inMinutes  % 60).toString().padLeft(2, '0');
    final ss = (e.inSeconds  % 60).toString().padLeft(2, '0');
    return GestureDetector(
      onTap: () => ShellNav.goTo(1),
      child: Container(
        padding: const EdgeInsets.all(Sp.md),
        decoration: BoxDecoration(
          color: c.greenBg,
          borderRadius: BorderRadius.circular(Rd.lg),
          border: Border.all(color: c.green.withOpacity(0.35)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: c.green.withOpacity(0.12),
              borderRadius: BorderRadius.circular(Rd.md),
            ),
            child: Icon(Icons.route_rounded, color: c.green, size: 20),
          ),
          const SizedBox(width: Sp.md),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TRIP IN PROGRESS', style: T.label(c: c.green)),
              Text('$hh:$mm:$ss', style: T.num(c: c.green, size: 18)),
            ],
          )),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${ts.pax}', style: T.num(c: c.green, size: 18)),
            Text('pax', style: T.caption(c: c.green.withOpacity(0.7))),
          ]),
          const SizedBox(width: Sp.xs),
          Icon(Icons.chevron_right_rounded, color: c.green.withOpacity(0.6), size: 18),
        ]),
      ),
    );
  }
}

// ── BUS CARD ──────────────────────────────────────────────────
class _BusCard extends StatelessWidget {
  final BusInfo bus;
  const _BusCard({required this.bus});

  @override
  Widget build(BuildContext context) => BCard(child: Row(children: [
    Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Brand.light.withOpacity(0.25),
        borderRadius: BorderRadius.circular(Rd.md),
      ),
      child: const Icon(Icons.directions_bus_rounded, color: Brand.navy, size: 22),
    ),
    const SizedBox(width: Sp.md),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Bus ${bus.busNumber}', style: T.h4()),
      if (bus.lineNumber != null)
        Text('Line ${bus.lineNumber}',
            style: T.bodySm(c: C.of(context).inkSoft)),
    ])),
    BChip.status(bus.status.label),

  ]));
}

// ── QUICK ACTIONS ─────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    final actions = [
      (Icons.route_outlined,         'New Trip',  Brand.navy,  () => ShellNav.goTo(1)),
      (Icons.history_outlined,       'History',   Brand.sky,   () => ShellNav.goTo(2)),
      (Icons.warning_amber_outlined, 'Incident',  Brand.red,   () => ShellNav.goTo(3)),
      (Icons.person_outline,         'Profile',   Brand.green, () => ShellNav.goTo(4)),
    ];
    return Row(
      children: actions.asMap().entries.map((e) {
        final i = e.key;
        final (icon, label, color, onTap) = e.value;
        return Expanded(child: Padding(
          padding: EdgeInsets.only(right: i < actions.length - 1 ? Sp.sm : 0),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: Sp.md, horizontal: Sp.xs),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(Rd.lg),
                border: Border.all(color: c.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8, offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(Rd.md),
                  ),
                  child: Icon(icon, color: color, size: 19),
                ),
                const SizedBox(height: 7),
                Text(label,
                    style: T.caption(c: c.inkSoft),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ]),
            ),
          ),
        ));
      }).toList(),
    );
  }
}
