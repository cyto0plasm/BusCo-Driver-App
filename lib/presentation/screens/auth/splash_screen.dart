import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/constants.dart';
import '../../blocs/blocs.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double>   _fade;
  late Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ac    = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fade  = CurvedAnimation(parent: _ac, curve: const Interval(0.0, 0.6, curve: Curves.easeOut));
    _scale = CurvedAnimation(parent: _ac, curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack));
    _ac.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthBloc>().add(const AuthCheck());
    });
  }

  @override void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    // Splash always uses navy background (brand identity)
    const navy  = Brand.navy;
    const cream  = Brand.cream;
    const sky    = Brand.sky;
    const light  = Brand.light;

    return Scaffold(
      backgroundColor: navy,
      body: Stack(children: [
        // Decorative blob top-right
        Positioned(
          top: -80, right: -80,
          child: Container(
            width: 280, height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: sky.withOpacity(0.18),
            ),
          ),
        ),
        // Decorative blob bottom-left
        Positioned(
          bottom: -60, left: -60,
          child: Container(
            width: 200, height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: light.withOpacity(0.12),
            ),
          ),
        ),
        Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Logo icon — light blue box
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: light,
                    borderRadius: BorderRadius.circular(Rd.xxl),
                    boxShadow: [
                      BoxShadow(
                        color: light.withOpacity(0.30),
                        blurRadius: 32, spreadRadius: 0,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.directions_bus_rounded,
                      color: navy, size: 42),
                ),
                const SizedBox(height: Sp.lg),
                Text('BusCo', style: T.h1(c: cream)),
                const SizedBox(height: 4),
                Text('DRIVER PORTAL', style: T.label(c: sky.withOpacity(0.7))),
                const SizedBox(height: Sp.xxl),
                SizedBox(
                  width: 24, height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: sky.withOpacity(0.5),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
