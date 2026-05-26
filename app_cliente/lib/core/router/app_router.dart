import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/roles/cliente/presentation/screens/client_home_screen.dart';
import '../../features/roles/admin/presentation/screens/admin_home_screen.dart';
import '../../features/roles/tecnico/presentation/screens/tecnico_home_screen.dart';


final authNotifierProvider = Provider<AuthProvider>((ref) {
  return AuthProvider();
});

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    // RefreshListenable hace que GoRouter re-evalúe el redirect cada vez que authState hace notifyListeners()
    refreshListenable: authState,
    redirect: (BuildContext context, GoRouterState state) {
      final isLoggingIn = state.matchedLocation == '/login';
      final status = authState.authStatus;

      // Aún no sabemos el estado (checking)
      if (status == AuthStatus.checking) {
        return null; // Podríamos retornar a un splash screen aquí
      }

      // Si no está autenticado, forzar ir al login
      if (status == AuthStatus.unauthenticated) {
        return isLoggingIn ? null : '/login';
      }

      // Si está autenticado y está intentando ir al login o a la raíz, redirigir a su home
      if (status == AuthStatus.authenticated && (isLoggingIn || state.matchedLocation == '/')) {
        final role = authState.userRole;
        if (role == 'ADMIN_TALLER') {
          return '/admin-home';
        } else if (role == 'MECANICO' || role == 'TECNICO') {
          return '/tecnico-home';
        } else {
          // Por defecto a cliente
          return '/cliente-home';
        }
      }

      // Dejar que continúe normalmente
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/cliente-home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/admin-home',
        builder: (context, state) => const AdminHomeScreen(),
      ),
      GoRoute(
        path: '/tecnico-home',
        builder: (context, state) => const TecnicoHomeScreen(),
      ),
    ],
  );
});
