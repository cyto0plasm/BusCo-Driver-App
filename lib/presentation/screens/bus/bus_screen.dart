import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/constants.dart';
import '../../blocs/blocs.dart';
import '../../widgets/widgets.dart';
import '../../../domain/entities/entities.dart';

class BusScreen extends StatefulWidget {
  const BusScreen({super.key});
  @override State<BusScreen> createState() => _BusScreenState();
}

class _BusScreenState extends State<BusScreen> {
  bool _booted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_booted) {
      _booted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final auth = context.read<AuthBloc>().state;
        if (auth is AuthAuthenticated && auth.driver.busId != null) {
          context.read<BusBloc>().add(BusLoad(auth.driver.busId!));
          context.read<IncidentBloc>().add(
            IncidentLoad(auth.driver.driverId, auth.driver.busId!));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => BlocListener<BusBloc, BusState>(
    listener: (ctx, state) {
      if (state is BusError) BSnack.err(ctx, state.msg);
    },
    child: Scaffold(
      backgroundColor: C.of(context).bg,
      appBar: BAppBar('My Bus', canPop: false,
        actions: [
          BIconBtn(Icons.refresh_outlined, onTap: () {
            final auth = context.read<AuthBloc>().state;
            if (auth is AuthAuthenticated && auth.driver.busId != null) {
              context.read<BusBloc>().add(BusLoad(auth.driver.busId!));
            }
          }),
        ],
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (ctx, authState) {
          if (authState is! AuthAuthenticated)
            return const BEmpty('Not logged in');
          final driver = authState.driver;
          if (driver.busId == null) {
            return const BEmpty('No bus assigned',
                subtitle: 'Ask your dispatcher to assign a bus to your account.',
                icon: Icons.directions_bus_outlined);
          }
          return BlocBuilder<BusBloc, BusState>(
            builder: (ctx, busState) {
              if (busState is BusLoading) return const BLoading();
              final bus = busState is BusLoaded ? busState.bus : null;
              return _BusContent(driver: driver, bus: bus);
            },
          );
        },
      ),
    ),
  );
}

class _BusContent extends StatelessWidget {
  final dynamic  driver;
  final BusInfo? bus;
  const _BusContent({required this.driver, this.bus});

  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    final status = bus?.status ?? BusStatusEnum.idle;
    final statusColor = switch (status) {
      BusStatusEnum.active => c.green,
      BusStatusEnum.broken => c.red,
      BusStatusEnum.idle   => c.orange,
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Sp.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Main bus card
        BCard(
          borderColor: statusColor.withOpacity(0.25),
          child: Column(children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(Rd.md),
                ),
                child: Icon(Icons.directions_bus_rounded,
                    color: statusColor, size: 30),
              ),
              const SizedBox(width: Sp.md),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bus ${bus?.busNumber ?? driver.busNumber ?? '–'}',
                      style: T.h3()),
                  if ((bus?.lineNumber ?? driver.lineNumber) != null)
                    Text('Line ${bus?.lineNumber ?? driver.lineNumber}',
                        style: T.bodySm(c: c.inkSoft)),
                  const SizedBox(height: 5),
                  BChip.status(status.label, dotSize: 6),
                ],
              )),
            ]),

            const SizedBox(height: Sp.md),
            Divider(color: c.border, height: 1),
            const SizedBox(height: Sp.sm),

            // GPS
            if (bus?.gpsLat != null && bus?.gpsLng != null) ...[
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: c.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(Rd.xs),
                  ),
                  child: Icon(Icons.gps_fixed, color: Brand.sky, size: 14),
                ),
                const SizedBox(width: 8),
                Text(
                  '${bus!.gpsLat!.toStringAsFixed(5)}, ${bus!.gpsLng!.toStringAsFixed(5)}',
                  style: T.mono(c: c.blue, size: 12),
                ),
                const Spacer(),
                if (bus?.gpsUpdatedAt != null)
                  Text(DateFormat('HH:mm').format(bus!.gpsUpdatedAt!),
                      style: T.caption(c: c.inkHint)),
              ]),
            ] else ...[
              Row(children: [
                Icon(Icons.gps_off, color: c.inkHint, size: 14),
                const SizedBox(width: 8),
                Text('GPS not available', style: T.caption(c: c.inkHint)),
              ]),
            ],
          ]),
        ),

        const SizedBox(height: Sp.lg),

        BSectionHeader('Bus Status'),
        const SizedBox(height: Sp.sm),
        _StatusControls(bus: bus, driver: driver),

        const SizedBox(height: Sp.lg),

        BSectionHeader('Incident Reports',
          trailing: TextButton.icon(
            onPressed: () => _showReportSheet(context, driver),
            icon: Icon(Icons.add_circle_outline, size: 15, color: Brand.sky),
            label: Text('Report', style: T.labelMd(c: Brand.sky)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
        const SizedBox(height: Sp.sm),
        BlocBuilder<IncidentBloc, IncidentState>(
          builder: (_, state) {
            final items = state is IncidentIdle   ? state.items
                : state is IncidentDone   ? state.items
                : state is IncidentFailed ? state.items : <Incident>[];
            if (items.isEmpty) {
              return const BEmpty('No incidents reported',
                  icon: Icons.check_circle_outline);
            }
            return Column(
              children: items.map((i) => Padding(
                padding: const EdgeInsets.only(bottom: Sp.sm),
                child: _IncidentTile(incident: i),
              )).toList(),
            );
          },
        ),
      ]),
    );
  }

  void _showReportSheet(BuildContext context, dynamic driver) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Rd.xxl)),
      ),
      builder: (_) => BlocProvider.value(
        value: context.read<IncidentBloc>(),
        child: _ReportIncidentSheet(
            driver: driver, busId: bus?.busId ?? driver.busId),
      ),
    );
  }
}

// ── STATUS CONTROLS ───────────────────────────────────────────
class _StatusControls extends StatelessWidget {
  final BusInfo? bus;
  final dynamic  driver;
  const _StatusControls({this.bus, required this.driver});

  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    final statuses = [
      ('ACTIVE', 'Active',  c.green,  Icons.check_circle_outline),
      ('IDLE',   'Idle',    c.orange, Icons.pause_circle_outline),
      ('BROKEN', 'Broken',  c.red,    Icons.error_outline),
    ];
    final current = bus?.status.label ?? 'IDLE';

    return Row(children: statuses.map((s) {
      final (key, label, color, icon) = s;
      final selected = current.toUpperCase() == key;
      return Expanded(child: Padding(
        padding: const EdgeInsets.only(right: Sp.xs),
        child: GestureDetector(
          onTap: selected ? null : () {
            if (bus == null) return;
            context.read<BusBloc>().add(BusSetStatus(bus!.busId, key));
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected ? color.withOpacity(0.12) : c.surface,
              border: Border.all(
                color: selected ? color.withOpacity(0.6) : c.border,
                width: selected ? 1.5 : 1,
              ),
              borderRadius: BorderRadius.circular(Rd.md),
            ),
            child: Column(children: [
              Icon(icon, color: selected ? color : c.inkHint, size: 20),
              const SizedBox(height: 5),
              Text(label, style: T.caption(c: selected ? color : c.inkSoft)),
            ]),
          ),
        ),
      ));
    }).toList());
  }
}

// ── INCIDENT TILE ─────────────────────────────────────────────
class _IncidentTile extends StatelessWidget {
  final Incident incident;
  const _IncidentTile({required this.incident});

  @override
  Widget build(BuildContext context) => BCard(child: Row(children: [
    BChip.status(incident.severity.label),
    const SizedBox(width: Sp.sm),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(incident.description,
          style: T.body(), maxLines: 2, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 2),
      Text(DateFormat('MMM d, HH:mm').format(incident.reportedAt),
          style: T.caption(c: C.of(context).inkHint)),
    ])),
    const SizedBox(width: Sp.sm),
    BChip.status(incident.status),
  ]));
}

// ── REPORT INCIDENT SHEET ─────────────────────────────────────
class _ReportIncidentSheet extends StatefulWidget {
  final dynamic driver;
  final int?    busId;
  const _ReportIncidentSheet({required this.driver, required this.busId});
  @override State<_ReportIncidentSheet> createState() => _ReportIncidentSheetState();
}

class _ReportIncidentSheetState extends State<_ReportIncidentSheet> {
  final _desc      = TextEditingController();
  String _severity = 'LOW';

  @override void dispose() { _desc.dispose(); super.dispose(); }

  void _submit() {
    if (_desc.text.trim().isEmpty) {
      BSnack.err(context, 'Please describe the incident');
      return;
    }
    if (widget.busId == null) {
      BSnack.err(context, 'No bus assigned');
      return;
    }
    context.read<IncidentBloc>().add(IncidentSubmit(
      busId:       widget.busId!,
      driverId:    widget.driver.driverId,
      severity:    _severity,
      description: _desc.text.trim(),
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Sp.lg, Sp.md, Sp.lg,
        MediaQuery.of(context).viewInsets.bottom + Sp.xl),
      child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        const BSheetHandle(),
        const SizedBox(height: Sp.sm),
        Text('Report Incident', style: T.h3()),
        Text('Bus ${widget.driver.busNumber ?? '–'}',
            style: T.bodySm(c: c.inkSoft)),
        const SizedBox(height: Sp.md),

        Text('SEVERITY', style: T.label(c: c.inkHint)),
        const SizedBox(height: Sp.xs),
        Row(children: ['LOW', 'MEDIUM', 'HIGH'].map((s) {
          final selected = _severity == s;
          final color = switch (s) {
            'HIGH'   => c.red,
            'MEDIUM' => c.orange,
            _        => c.blue,
          };
          return Expanded(child: Padding(
            padding: const EdgeInsets.only(right: Sp.xs),
            child: GestureDetector(
              onTap: () => setState(() => _severity = s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: selected ? color.withOpacity(0.12) : c.surfaceLt,
                  border: Border.all(
                    color: selected ? color.withOpacity(0.5) : c.border,
                    width: selected ? 1.5 : 1),
                  borderRadius: BorderRadius.circular(Rd.md),
                ),
                alignment: Alignment.center,
                child: Text(s, style: T.labelMd(c: selected ? color : c.inkSoft)),
              ),
            ),
          ));
        }).toList()),

        const SizedBox(height: Sp.md),
        BField(
          label: 'Description',
          controller: _desc,
          hint: 'Describe the issue…',
          maxLines: 4,
        ),
        const SizedBox(height: Sp.md),
        BlocBuilder<IncidentBloc, IncidentState>(
          builder: (ctx, state) => BBtn('Submit Report',
            loading: state is IncidentSubmitting,
            icon: Icon(Icons.send_rounded, color: Colors.white, size: 16),
            onTap: state is IncidentSubmitting ? null : _submit,
          ),
        ),
      ]),
    );
  }
}
