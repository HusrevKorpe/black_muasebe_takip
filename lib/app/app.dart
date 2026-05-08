import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/dashboard/presentation/boss_home_screen.dart';
import '../features/revenue/presentation/owner_home_screen.dart';
import '../features/splash/presentation/splash_screen.dart';

class MuasebeApp extends ConsumerWidget {
  const MuasebeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Black Muasebe',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],
      locale: const Locale('tr', 'TR'),
      home: const _RootRouter(),
    );
  }
}

class _RootRouter extends ConsumerWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      loading: () => const SplashScreen(),
      error: (e, _) => _ErrorScaffold(message: e.toString()),
      data: (firebaseUser) {
        if (firebaseUser == null) return const LoginScreen();
        final appUserAsync = ref.watch(currentAppUserProvider);
        return appUserAsync.when(
          loading: () => const SplashScreen(),
          error: (e, _) => _ErrorScaffold(message: e.toString()),
          data: (appUser) {
            if (appUser == null) {
              return const _ErrorScaffold(
                message:
                    'Profilinize erişilemiyor.\nLütfen yöneticinizle iletişime geçin.',
              );
            }
            if (appUser.isBoss) return const BossHomeScreen();
            return const OwnerHomeScreen();
          },
        );
      },
    );
  }
}

class _ErrorScaffold extends StatelessWidget {
  const _ErrorScaffold({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}
