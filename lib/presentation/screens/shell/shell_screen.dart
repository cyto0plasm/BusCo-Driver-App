import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/constants.dart';
import '../../blocs/blocs.dart';
import '../home/home_screen.dart';
import '../trip/trip_screen.dart';
import '../history/history_screen.dart';
import '../bus/bus_screen.dart';
import '../profile/profile_screen.dart';

class ShellNav {
  static final _key = GlobalKey<_ShellScreenState>();
  static GlobalKey<_ShellScreenState> get key => _key;
  static void goTo(int index) => _key.currentState?._goTo(index);
}

class ShellScreen extends StatefulWidget {
  ShellScreen({Key? key}) : super(key: ShellNav._key);
  @override State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int  _tab    = 0;
  bool _booted = false;

  void _goTo(int index) => setState(() => _tab = index);

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
    context.read<StatsBloc>().add(StatsLoad(d.driverId));
    if (d.walletId != null) context.read<WalletBloc>().add(WalletLoad(d.walletId!));
    final busId = d.busId;
    if (busId != null) {
      context.read<BusBloc>().add(BusLoad(busId));
      context.read<TripBloc>().add(TripLoad(busId));
      context.read<GpsBloc>().add(GpsStart(busId));
    }
  }

  static const _screens = [
    HomeScreen(), TripScreen(), HistoryScreen(), BusScreen(), ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarBrightness:     isDark ? Brightness.dark  : Brightness.light,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: IndexedStack(index: _tab, children: _screens),
        bottomNavigationBar: _BottomNav(
          selectedIndex: _tab,
          onSelected: (i) => setState(() => _tab = i),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int  selectedIndex;
  final void Function(int) onSelected;
  const _BottomNav({required this.selectedIndex, required this.onSelected});

  static const _items = [
    (Icons.home_outlined,           Icons.home_rounded,           'Home'),
    (Icons.route_outlined,          Icons.route_rounded,          'Trip'),
    (Icons.history_outlined,        Icons.history,                'History'),
    (Icons.directions_bus_outlined, Icons.directions_bus_rounded, 'Bus'),
    (Icons.person_outline,          Icons.person_rounded,         'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border, width: 1)),
        // Subtle shadow upward
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.xs, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (i) {
              final (icon, activeIcon, label) = _items[i];
              final selected = i == selectedIndex;
              return Expanded(
                child: _NavItem(
                  icon: icon,
                  activeIcon: activeIcon,
                  label: label,
                  selected: selected,
                  onTap: () => onSelected(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String   label;
  final bool     selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon, required this.activeIcon, required this.label,
    required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    // RideWave: selected = sky blue; nav bg uses cream-tinted highlight
    final selColor = Brand.sky;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? selColor.withOpacity(0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(Rd.md),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Icon(
              selected ? activeIcon : icon,
              key: ValueKey(selected),
              color: selected ? selColor : c.inkHint,
              size: 22,
            ),
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            style: TextStyle(
              fontFamily: 'Sora', fontSize: 10, fontWeight: FontWeight.w600,
              color: selected ? selColor : c.inkHint, letterSpacing: 0.3,
            ),
            child: Text(label),
          ),
        ]),
      ),
    );
  }
}
