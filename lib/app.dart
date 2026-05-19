import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/employees/employee_settings_screen.dart';
import 'features/entry/entry_screen.dart';
import 'features/report/report_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) {
          return const AuthGate(child: DashboardScreen());
        },
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/entry/:type',
        builder: (context, state) {
          return AuthGate(
            child: EntryScreen(
              entryType: state.pathParameters['type'] ?? 'ciro',
              initialMonthKey: state.uri.queryParameters['month'],
            ),
          );
        },
      ),
      GoRoute(
        path: '/report',
        builder: (context, state) {
          return AuthGate(
            child: ReportScreen(
              initialMonthKey: state.uri.queryParameters['month'],
            ),
          );
        },
      ),
      GoRoute(
        path: '/employees',
        builder: (context, state) {
          return const AuthGate(child: EmployeeSettingsScreen());
        },
      ),
    ],
    errorBuilder: (context, state) {
      return _MessageScaffold(
        icon: Icons.error_outline,
        title: 'Sayfa bulunamadı',
        message: 'Açmak istediğiniz ekran bulunamadı.',
        actionLabel: 'Ana ekrana dön',
        onAction: () => context.go('/'),
      );
    },
  );
});

class PalaogluKasaApp extends ConsumerWidget {
  const PalaogluKasaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Palaoğlu Kasa Takip',
      theme: AppTheme.darkTheme,
      routerConfig: ref.watch(appRouterProvider),
      builder: (context, child) {
        return ColoredBox(
          color: AppColors.background,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const _LoadingScaffold(message: 'Oturum kontrol ediliyor...'),
      error: (_, __) => const _MessageScaffold(
        icon: Icons.wifi_off_outlined,
        title: 'Bağlantı sorunu',
        message: 'Oturum bilgisi okunamadı. İnternet bağlantısını kontrol edin.',
      ),
      data: (firebaseUser) {
        if (firebaseUser == null) {
          return const LoginScreen();
        }

        final userState = ref.watch(currentAppUserProvider);
        return userState.when(
          loading: () => const _LoadingScaffold(message: 'Profil okunuyor...'),
          error: (_, __) => const _MessageScaffold(
            icon: Icons.wifi_off_outlined,
            title: 'Profil okunamadı',
            message: 'Kullanıcı profili alınamadı. İnternet bağlantısını kontrol edin.',
          ),
          data: (appUser) {
            if (appUser == null) {
              return _MessageScaffold(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Yetki tanımı yok',
                message: 'Bu kullanıcı için yetki tanımı bulunamadı',
                actionLabel: 'Çıkış Yap',
                onAction: () => ref.read(authControllerProvider.notifier).signOut(),
              );
            }

            if (!appUser.active) {
              return _MessageScaffold(
                icon: Icons.block_outlined,
                title: 'Kullanıcı pasif',
                message: 'Bu kullanıcı pasif',
                actionLabel: 'Çıkış Yap',
                onAction: () => ref.read(authControllerProvider.notifier).signOut(),
              );
            }

            return child;
          },
        );
      },
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(color: AppColors.mutedText)),
          ],
        ),
      ),
    );
  }
}

class _MessageScaffold extends StatelessWidget {
  const _MessageScaffold({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: AppColors.primary, size: 42),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.mutedText),
                      ),
                      if (actionLabel != null && onAction != null) ...[
                        const SizedBox(height: 22),
                        ElevatedButton(
                          onPressed: onAction,
                          child: Text(actionLabel!),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
