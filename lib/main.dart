import 'package:flutter/material.dart';
import 'package:vril/screens/vendor_users_screen.dart';
import 'screens/login_screen.dart';
import 'screens/customer_dashboard.dart';
import 'screens/vendor_dashboard.dart';
import 'screens/collector_dashboard.dart';

void main() {
  runApp(VrilApp());
}

class VrilApp extends StatelessWidget {
  const VrilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VRIL',
      theme: ThemeData(
        primaryColor: const Color(0xFF6644C0),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => LoginScreen(),
        '/customerDashboard': (context) => CustomerDashboard(),
        '/vendorDashboard': (context) => VendorDashboard(),
        '/collectorDashboard': (context) => CollectorDashboard(),
        '/vendorUsers': (context) => VendorUsersScreen(),

      },
    );
  }
}
