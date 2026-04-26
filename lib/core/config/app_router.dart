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
import '../../features/profile/earnings_screen.dart';
import '../../features/ride/passenger_rating_screen.dart';
import '../../features/ride/ride_payment_screen.dart';
import '../../features/notifications/notifications_screen.dart';


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
      GoRoute(path: '/earnings',         builder: (context, __) => const EarningsScreen()),
      GoRoute(path: '/support', builder: (context, _) => const SupportScreen()),
      GoRoute(path: '/notifications', builder: (context, _) => const NotificationsScreen()),
      GoRoute(
        path: '/ride-detail/:id',
        builder: (_, state) => RideDetailScreen(
          rideId: state.pathParameters['id']!,
        ),
      ),
        GoRoute(
        path: '/ride-payment/:rideId',
        builder: (_, state) {
          final extras = state.extra as Map<String, dynamic>?;
          return RidePaymentScreen(
            rideId:        state.pathParameters['rideId']!,
            payMethod:     extras?['payMethod']?.toString() ?? 'cash',
            price: double.tryParse(
                extras?['price']?.toString() ?? '0') ?? 0.0,
            passengerName: extras?['passengerName']?.toString(),
          );
        },
      ),
 

          GoRoute(
        path: '/ride-rating/:rideId',
        builder: (_, state) {
          final extras = state.extra as Map<String, dynamic>?;
          return PassengerRatingScreen(
            rideId:        state.pathParameters['rideId']!,
            passengerName: extras?['passengerName']?.toString(),
            price: extras?['price'] != null
                ? double.tryParse(extras!['price'].toString())
                : null,
          );
        },
      ),

      
    ],
  );
}