import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/constants/constants.dart';
import 'core/theme/theme.dart';
import 'data/datasources/datasource.dart';
import 'presentation/blocs/blocs.dart';
import 'presentation/screens/auth/splash_screen.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/shell/shell_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const BusCoDriverApp());
}

class BusCoDriverApp extends StatelessWidget {
  const BusCoDriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ds = DS();
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ThemeBloc()),
        BlocProvider(create: (_) => AuthBloc(ds)),
        BlocProvider(create: (_) => ProfileBloc(ds)),
        BlocProvider(create: (_) => TripBloc(ds)),
        BlocProvider(create: (_) => GpsBloc(ds)),
        BlocProvider(create: (_) => StatsBloc(ds)),
        BlocProvider(create: (_) => HistoryBloc(ds)),
        BlocProvider(create: (_) => BusBloc(ds)),
        BlocProvider(create: (_) => WalletBloc(ds)),
        BlocProvider(create: (_) => IncidentBloc(ds)),
      ],
      child: BlocBuilder<ThemeBloc, ThemeState>(
        builder: (_, themeState) => MaterialApp(
          title: 'BusCo Driver',
          debugShowCheckedModeBanner: false,
          theme:      AppTheme.light,
          darkTheme:  AppTheme.dark,
          themeMode:  themeState.isDark ? ThemeMode.dark : ThemeMode.light,
          home: const _AppRouter(),
        ),
      ),
    );
  }
}

class _AppRouter extends StatelessWidget {
  const _AppRouter();
  @override
  Widget build(BuildContext context) => BlocBuilder<AuthBloc, AuthState>(
    builder: (_, state) {
      if (state is AuthInitial || state is AuthLoading) return const SplashScreen();
      if (state is AuthAuthenticated) return ShellScreen();
      return const LoginScreen();
    },
  );
}
