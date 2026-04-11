import 'package:go_router/go_router.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/ride/ride_detail_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/wallet_screen.dart';
import '../../features/profile/ride_history_screen.dart';
import '../../features/profile/change_password_screen.dart';
import '../../features/profile/payment_methods_screen.dart';
import '../../features/profile/complete_profile_screen.dart';
import '../../features/profile/support_screen.dart';


class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash',           builder: (context, _) => const SplashScreen()),
      GoRoute(path: '/login',            builder: (context, _) => const LoginScreen()),
      GoRoute(path: '/register',         builder: (context, _) => const RegisterScreen()),
      GoRoute(path: '/home',             builder: (context, _) => const HomeScreen()),
      GoRoute(path: '/profile',          builder: (context, _) => const ProfileScreen()),
      GoRoute(path: '/wallet',           builder: (context, _) => const WalletScreen()),
      GoRoute(path: '/ride-history',     builder: (context, _) => const RideHistoryScreen()),
      GoRoute(path: '/change-password',  builder: (context, _) => const ChangePasswordScreen()),
      GoRoute(path: '/payment-methods',  builder: (context, _) => const PaymentMethodsScreen()),
      GoRoute(path: '/complete-profile', builder: (context, _) => const CompleteProfileScreen()),
      GoRoute(
        path: '/ride-detail/:id',
        builder: (_, state) => RideDetailScreen(
          rideId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(path: '/support', builder: (context, _) => const SupportScreen()),
      
    ],
  );
}