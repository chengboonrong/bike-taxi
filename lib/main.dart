import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemChrome, appFlavor;

import 'admin.dart';
import 'common.dart';
import 'compute.dart' show initializeCompute;
import 'customer.dart';
import 'driver.dart';
import 'firebase_options.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(transitOverlay);
  await initializeCompute();
  await Firebase.initializeApp(options: firebaseOptions);
  if (emulatorHost.isNotEmpty) {
    await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);
    await FirebaseAuth.instance
        .setSettings(appVerificationDisabledForTesting: true);
  }
  runApp(const BikeTaxiApp());
}

class BikeTaxiApp extends StatelessWidget {
  const BikeTaxiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final (String title, String role, Widget home) = kIsWeb
        ? ('Bike Taxi Admin', 'ADMIN', const AdminGate())
        : appFlavor == 'driver'
            ? ('Bike Taxi Driver', 'DRIVER', const DriverGate())
            : ('Bike Taxi', 'RIDER', const CustomerHome());
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: title,
      theme: transitTheme,
      darkTheme: transitTheme,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: loading);
          }
          return snap.data == null ? LoginScreen(role: role) : home;
        },
      ),
    );
  }
}
