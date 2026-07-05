import 'package:go_router/go_router.dart';
import 'package:truck_account_book/data/database/app_database.dart';
import 'package:truck_account_book/features/customers/customer_detail_screen.dart';
import 'package:truck_account_book/features/customers/customer_list_screen.dart';
import 'package:truck_account_book/features/dashboard/dashboard_screen.dart';
import 'package:truck_account_book/features/expenses/add_expense_screen.dart';
import 'package:truck_account_book/features/payments/receive_payment_screen.dart';
import 'package:truck_account_book/features/reports/reports_screen.dart';
import 'package:truck_account_book/features/search/search_screen.dart';
import 'package:truck_account_book/features/settings/settings_screen.dart';
import 'package:truck_account_book/features/trips/create_trip_screen.dart';
import 'package:truck_account_book/features/trips/trip_detail_screen.dart';
import 'package:truck_account_book/features/trips/trip_list_screen.dart';
import 'package:truck_account_book/shell/app_shell.dart';

/// Central route table. Uses go_router's ShellRoute so the bottom
/// navigation bar persists across the four main tabs (Dashboard, Trips,
/// Customers, Settings) while modal-style screens (new trip, add expense,
/// receive payment, trip details) push on top full-screen.
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),
        GoRoute(path: '/trips', builder: (context, state) => const TripListScreen()),
        GoRoute(path: '/customers', builder: (context, state) => const CustomerListScreen()),
        GoRoute(path: '/reports', builder: (context, state) => const ReportsScreen()),
        GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      ],
    ),
    GoRoute(
      path: '/search',
      builder: (context, state) => const SearchScreen(),
    ),
    GoRoute(
      path: '/trips/new',
      builder: (context, state) => const CreateTripScreen(),
    ),
    GoRoute(
      path: '/trips/:id/edit',
      builder: (context, state) => CreateTripScreen(existing: state.extra as Trip?),
    ),
    GoRoute(
      path: '/trips/:id',
      builder: (context, state) => TripDetailScreen(
        tripId: int.parse(state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/customers/:id',
      builder: (context, state) => CustomerDetailScreen(
        customerId: int.parse(state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/expenses/new',
      builder: (context, state) => AddExpenseScreen(tripId: state.extra as int?),
    ),
    GoRoute(
      path: '/payments/new',
      builder: (context, state) {
        final extra = state.extra;
        int? tripId;
        int? customerId;
        if (extra is Map) {
          tripId = extra['tripId'] as int?;
          customerId = extra['customerId'] as int?;
        }
        return ReceivePaymentScreen(tripId: tripId, customerId: customerId);
      },
    ),
  ],
);
