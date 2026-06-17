import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/constants.dart';
import '../../blocs/blocs.dart';
import '../../widgets/widgets.dart';
import '../../../domain/entities/entities.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _booted = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_booted) {
      _booted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final auth = context.read<AuthBloc>().state;
        if (auth is AuthAuthenticated) {
          context.read<HistoryBloc>().add(HistoryLoad(auth.driver.driverId));
          context.read<StatsBloc>().add(StatsLoad(auth.driver.driverId));
        }
      });
    }
  }

  @override void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      appBar: BAppBar(
        'History',
        canPop: false,
        bottom: _ThemedTabBar(controller: _tabs),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [_TripListTab(), _AnalyticsTab()],
      ),
    );
  }
}

// ── TRIP LIST TAB ────────────────────────────────────────────
class _TripListTab extends StatelessWidget {
  const _TripListTab();

  @override
  Widget build(BuildContext context) => BlocBuilder<HistoryBloc, HistoryState>(
    builder: (ctx, state) {
      if (state is HistoryLoading) return const BLoading();
      if (state is HistoryError)   return BEmpty(state.msg);
      if (state is HistoryLoaded) {
        if (state.trips.isEmpty) {
          return const BEmpty('No trips yet',
              subtitle: 'Start your first trip to see history here.',
              icon: Icons.route_outlined);
        }
        final grouped = <String, List<TripSummary>>{};
        for (final t in state.trips) {
          final key = DateFormat('EEEE, MMM d').format(t.startTime);
          grouped.putIfAbsent(key, () => []).add(t);
        }
        final keys = grouped.keys.toList();
        final totalTrips     = state.trips.length;
        final totalPax       = state.trips.fold(0, (s, t) => s + t.passengerCount);
        final totalCollected = state.trips.fold(0.0, (s, t) => s + t.totalCollected);

        return Column(children: [
          // Summary strip
          _SummaryStrip(
            totalTrips: totalTrips,
            totalPax: totalPax,
            totalCollected: totalCollected,
          ),
          Expanded(
            child: RefreshIndicator(
              color: Brand.sky,
              backgroundColor: C.of(context).surface,
              onRefresh: () async {
                final auth = ctx.read<AuthBloc>().state;
                if (auth is AuthAuthenticated) {
                  ctx.read<HistoryBloc>().add(HistoryLoad(auth.driver.driverId));
                }
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(Sp.md),
                itemCount: keys.length,
                itemBuilder: (_, i) => _DayGroup(
                    date: keys[i], trips: grouped[keys[i]]!),
              ),
            ),
          ),
        ]);
      }
      return const BEmpty('No data');
    },
  );
}

class _SummaryStrip extends StatelessWidget {
  final int    totalTrips, totalPax;
  final double totalCollected;
  const _SummaryStrip({required this.totalTrips,
    required this.totalPax, required this.totalCollected});

  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.sm),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        BMetric('$totalTrips', 'Trips', valueSize: 17),
        Container(width: 1, height: 28, color: c.border),
        BMetric('$totalPax', 'Passengers', valueSize: 17),
        Container(width: 1, height: 28, color: c.border),
        BMetric('${totalCollected.toStringAsFixed(0)} EGP', 'Collected',
            valueSize: 17, valueColor: Brand.green),
      ]),
    );
  }
}

// ── DAY GROUP ────────────────────────────────────────────────
class _DayGroup extends StatelessWidget {
  final String date;
  final List<TripSummary> trips;
  const _DayGroup({required this.date, required this.trips});

  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    final dayTotal = trips.fold(0.0, (s, t) => s + t.totalCollected);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: Sp.sm),
        child: Row(children: [
          Text(date, style: T.label(c: c.inkHint)),
          const Spacer(),
          Text('${dayTotal.toStringAsFixed(2)} EGP',
              style: T.labelMd(c: c.green)),
        ]),
      ),
      ...trips.map((t) => Padding(
        padding: const EdgeInsets.only(bottom: Sp.sm),
        child: _TripCard(trip: t),
      )),
      const SizedBox(height: Sp.xs),
    ]);
  }
}

// ── TRIP CARD ────────────────────────────────────────────────
class _TripCard extends StatelessWidget {
  final TripSummary trip;
  const _TripCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final c   = C.of(context);
    final dur = trip.duration;
    final hh  = dur.inHours.toString().padLeft(2, '0');
    final mm  = (dur.inMinutes % 60).toString().padLeft(2, '0');

    return BCard(
      onTap: () => _showDetail(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: Brand.sky.withOpacity(0.12),
              borderRadius: BorderRadius.circular(Rd.sm),
              border: Border.all(color: Brand.sky.withOpacity(0.25)),
            ),
            child: Text('Trip #${trip.tripId}',
                style: T.labelMd(c: Brand.navy)),
          ),
          const Spacer(),
          BChip.status(trip.active ? 'ACTIVE' : 'ENDED'),
        ]),
        const SizedBox(height: Sp.sm),
        Row(children: [
          _InfoPill(Icons.access_time_outlined,
              DateFormat('HH:mm').format(trip.startTime)),
          const SizedBox(width: Sp.sm),
          _InfoPill(Icons.timer_outlined, '$hh:$mm'),
          const SizedBox(width: Sp.sm),
          _InfoPill(Icons.people_outline, '${trip.passengerCount}'),
          const Spacer(),
          Text('${trip.totalCollected.toStringAsFixed(2)} EGP',
              style: T.labelMd(c: trip.totalCollected > 0
                  ? c.green : c.inkSoft)),
        ]),
      ]),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Rd.xxl)),
      ),
      builder: (_) => _TripDetail(trip: trip),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String   text;
  const _InfoPill(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 12, color: C.of(context).inkSoft),
    const SizedBox(width: 3),
    Text(text, style: T.caption(c: C.of(context).inkSoft)),
  ]);
}

// ── TRIP DETAIL SHEET ────────────────────────────────────────
class _TripDetail extends StatelessWidget {
  final TripSummary trip;
  const _TripDetail({required this.trip});

  @override
  Widget build(BuildContext context) {
    final c   = C.of(context);
    final dur = trip.duration;
    final hh  = dur.inHours.toString().padLeft(2,'0');
    final mm  = (dur.inMinutes % 60).toString().padLeft(2,'0');

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, ctrl) => SingleChildScrollView(
        controller: ctrl,
        padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.md, Sp.lg, Sp.xl),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const BSheetHandle(),
          const SizedBox(height: Sp.sm),
          Row(children: [
            Text('Trip #${trip.tripId}', style: T.h2()),
            const Spacer(),
            BChip.status(trip.active ? 'ACTIVE' : 'ENDED'),
          ]),
          const SizedBox(height: Sp.md),
          BCard(
            color: c.greenBg,
            borderColor: c.green.withOpacity(0.25),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              BMetric('${trip.totalCollected.toStringAsFixed(2)}', 'EGP Collected',
                  valueColor: Brand.green),
              Container(width: 1, height: 36, color: c.border),
              BMetric('${trip.passengerCount}', 'Passengers',
                  valueColor: Brand.green),
            ]),
          ),
          const SizedBox(height: Sp.md),
          BCard(child: Column(children: [
            BInfoRow('Start Time',
                DateFormat('EEE, MMM d · HH:mm').format(trip.startTime)),
            if (trip.endTime != null)
              BInfoRow('End Time',
                  DateFormat('EEE, MMM d · HH:mm').format(trip.endTime!)),
            BInfoRow('Duration', '$hh h $mm min'),
            if (trip.busNumber != null)
              BInfoRow('Bus', trip.busNumber!),
            if (trip.lineNumber != null)
              BInfoRow('Line', trip.lineNumber!, divider: false),
          ])),
        ]),
      ),
    );
  }
}

// ── ANALYTICS TAB ────────────────────────────────────────────
class _AnalyticsTab extends StatelessWidget {
  const _AnalyticsTab();

  @override
  Widget build(BuildContext context) => BlocBuilder<StatsBloc, StatsState>(
    builder: (ctx, state) {
      if (state is StatsLoading) return const BLoading();
      if (state is StatsLoaded)  return _AnalyticsView(stats: state);
      return const BEmpty('Loading analytics…');
    },
  );
}

class _AnalyticsView extends StatelessWidget {
  final StatsLoaded stats;
  const _AnalyticsView({required this.stats});

  @override
  Widget build(BuildContext context) {
    final c      = C.of(context);
    final weekly = stats.weekly;
    final maxTrips = weekly.fold(0, (m, d) => d.trips > m ? d.trips : m);
    final maxColl  = weekly.fold(0.0, (m, d) => d.collected > m ? d.collected : m);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Sp.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        BSectionHeader('Trips — Last 7 Days'),
        const SizedBox(height: Sp.sm),
        BCard(child: Column(children: [
          const SizedBox(height: Sp.xs),
          SizedBox(height: 140, child: _BarChart(
            data: weekly.map((d) => d.trips.toDouble()).toList(),
            labels: weekly.map((d) => DateFormat('E').format(d.date)).toList(),
            maxVal: maxTrips.toDouble(),
            color: Brand.navy,
          )),
        ])),
        const SizedBox(height: Sp.md),

        BSectionHeader('Earnings — Last 7 Days'),
        const SizedBox(height: Sp.sm),
        BCard(child: Column(children: [
          const SizedBox(height: Sp.xs),
          SizedBox(height: 140, child: _BarChart(
            data: weekly.map((d) => d.collected).toList(),
            labels: weekly.map((d) => DateFormat('E').format(d.date)).toList(),
            maxVal: maxColl,
            color: c.green,
            prefix: 'EGP',
          )),
        ])),
        const SizedBox(height: Sp.md),

        BSectionHeader('This Week'),
        const SizedBox(height: Sp.sm),
        Row(children: [
          Expanded(child: _WeeklyTile(
            value: '${weekly.fold(0, (s, d) => s + d.trips)}',
            label: 'Total Trips',
            icon: Icons.route_outlined,
            color: Brand.navy,
          )),
          const SizedBox(width: Sp.sm),
          Expanded(child: _WeeklyTile(
            value: '${weekly.fold(0.0, (s, d) => s + d.collected).toStringAsFixed(0)}',
            suffix: 'EGP',
            label: 'Total Earned',
            icon: Icons.payments_outlined,
            color: c.green,
          )),
        ]),
      ]),
    );
  }
}

class _BarChart extends StatelessWidget {
  final List<double> data;
  final List<String> labels;
  final double       maxVal;
  final Color        color;
  final String?      prefix;

  const _BarChart({required this.data, required this.labels,
    required this.maxVal, required this.color, this.prefix});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: List.generate(data.length, (i) {
      final ratio = maxVal > 0 ? data[i] / maxVal : 0.0;
      return Expanded(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          if (data[i] > 0)
            Text(
              prefix != null
                  ? '${data[i].toStringAsFixed(0)}'
                  : '${data[i].toInt()}',
              style: T.caption(c: color),
            ),
          const SizedBox(height: 3),
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            height: 88 * ratio.clamp(0.03, 1.0),
            decoration: BoxDecoration(
              color: color.withOpacity(0.8),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.25),
                  blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(labels[i],
              style: T.caption(c: C.of(context).inkHint)),
        ]),
      ));
    }),
  );
}

class _WeeklyTile extends StatelessWidget {
  final String   value;
  final String?  suffix;
  final String   label;
  final IconData icon;
  final Color    color;
  const _WeeklyTile({required this.value, required this.label,
    required this.icon, required this.color, this.suffix});

  @override
  Widget build(BuildContext context) => BCard(
    borderColor: color.withOpacity(0.2),
    padding: const EdgeInsets.all(Sp.md),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(Rd.md),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      const SizedBox(width: Sp.sm),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              suffix != null ? '$value $suffix' : value,
              style: T.num(c: color, size: 17),
            ),
          ),
          Text(label, style: T.caption(c: C.of(context).inkSoft),
              overflow: TextOverflow.ellipsis),
        ],
      )),
    ]),
  );
}

// ── THEMED TAB BAR ───────────────────────────────────────────
class _ThemedTabBar extends StatelessWidget implements PreferredSizeWidget {
  final TabController controller;
  const _ThemedTabBar({required this.controller});

  @override
  Size get preferredSize => const Size.fromHeight(44);

  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    return TabBar(
      controller:             controller,
      labelColor:             Brand.navy,
      unselectedLabelColor:   Brand.sky.withOpacity(0.5),
      indicatorColor:         Brand.sky,
      indicatorSize:          TabBarIndicatorSize.label,
      indicatorWeight:        2.5,
      labelStyle:             T.labelMd(),
      unselectedLabelStyle:   T.labelMd(),
      tabs: const [Tab(text: 'Trip Log'), Tab(text: 'Analytics')],
    );
  }
}
