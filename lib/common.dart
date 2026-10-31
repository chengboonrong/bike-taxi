import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'routing.dart' show decodePolyline;
import 'theme.dart';

const baseFare = 2.5;
const perMile = 1.5;
const milesPerKm = 0.621371;
const defaultCentre = LatLng(40.7549, -73.9840); // Midtown Manhattan

/// $2.50 + $1.50 a mile, rounded to 10 cents. Distances are stored in km.
double fareFor(double km) =>
    ((baseFare + perMile * km * milesPerKm) * 10).round() / 10;

String money(num v) => '\$${v.toStringAsFixed(2)}';

// ponytail: straight-line distance; use a routing API (OSRM/Google) when fares must follow roads.
double kmBetween(LatLng a, LatLng b) => const Distance()(a, b) / 1000;

String distanceText(num km) {
  final mi = km * milesPerKm;
  return mi < 0.05 ? '<0.1 mi' : '${mi.toStringAsFixed(1)} mi';
}

/// `+15550100002` as `(555) 010-0002`; any other number as given.
String usPhone(String? phone) {
  final m = RegExp(r'^\+1(\d{3})(\d{3})(\d{4})$').firstMatch(phone ?? '');
  return m == null ? phone ?? '' : '(${m[1]}) ${m[2]}-${m[3]}';
}

// Android emulator: 10.0.2.2, web: localhost; empty for a real project.
const emulatorHost = String.fromEnvironment('EMULATOR_HOST');

const requested = 'requested';
const accepted = 'accepted';
const started = 'started';
const completed = 'completed';
const cancelled = 'cancelled';
const openStatuses = [requested, accepted, started];
const statusLabel = {
  requested: 'Finding a driver',
  accepted: 'Driver on the way',
  started: 'On the trip',
  completed: 'Completed',
  cancelled: 'Cancelled',
};

final rides = FirebaseFirestore.instance.collection('rides');

/// The ride's station on the rider's line: 0 finding, 1 driver on the way,
/// 2 on the trip, 3 arrived. A cancelled ride stays where it stopped.
int rideStep(Map<String, dynamic> r) {
  final status = r['status'];
  if (status != cancelled) {
    return [requested, accepted, started, completed].indexOf(status);
  }
  return r['startedAt'] != null ? 2 : r['driverId'] != null ? 1 : 0;
}

LatLng toLatLng(GeoPoint g) => LatLng(g.latitude, g.longitude);

GeoPoint toGeoPoint(LatLng p) => GeoPoint(p.latitude, p.longitude);

/// The device position, or null when location is off, denied, or gets no fix in 15 s.
Future<LatLng?> currentLocation() async {
  if (!await Geolocator.isLocationServiceEnabled()) return null;
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    return null;
  }
  try {
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(timeLimit: Duration(seconds: 15)),
    );
    return LatLng(p.latitude, p.longitude);
  } on TimeoutException {
    return null;
  }
}

// Inverts OSM tiles into midnight: land #0E173B, buildings #1C254B, roads #060E31,
// label text #626C97 (a least-squares fit to those targets).
const _midnightTiles = ColorFilter.matrix(<double>[
  -0.0378, -0.2787, -0.1310, 0, 120.4,
  -0.0287, -0.2651, -0.1646, 0, 131.2,
  0.1013, -0.3965, -0.2042, 0, 176.6,
  0, 0, 0, 1, 0,
]);

// ponytail: public OSM tiles are for light use only; switch to a tile provider (MapTiler, Stadia…) before launch.
Widget rideMap({
  required List<Marker> markers,
  List<Polyline> lines = const [],
  LatLng center = defaultCentre,
  List<LatLng> fit = const [],
  MapController? controller,
  void Function(LatLng point)? onTap,
}) {
  return FlutterMap(
    mapController: controller,
    options: MapOptions(
      backgroundColor: Swatch.midnight,
      initialCenter: center,
      initialZoom: 15,
      initialCameraFit: fit.isEmpty ? null : fitTo(fit),
      onTap: onTap == null ? null : (_, point) => onTap(point),
    ),
    children: [
      TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.biketaxi.bike_taxi',
        tileBuilder: (context, tile, _) =>
            ColorFiltered(colorFilter: _midnightTiles, child: tile),
      ),
      PolylineLayer(polylines: lines),
      MarkerLayer(markers: markers),
      RichAttributionWidget(
        popupBackgroundColor: Swatch.panel,
        // The default open button is black, invisible on midnight.
        openButton: (context, open) => IconButton(
          onPressed: open,
          tooltip: 'Map attribution',
          icon: const Icon(Icons.info_outline, color: Swatch.mist),
        ),
        showFlutterMapAttribution: false,
        attributions: [
          const TextSourceAttribution('OpenStreetMap contributors'),
          TextSourceAttribution('Routing: Valhalla',
              onTap: () => launchUrl(Uri.parse('https://github.com/valhalla/valhalla'))),
        ],
      ),
    ],
  );
}

/// Fits the camera to [points], clear of the floating wordmark row and the station labels.
CameraFit fitTo(List<LatLng> points) => CameraFit.coordinates(
      coordinates: points,
      padding: const EdgeInsets.fromLTRB(56, 136, 96, 56),
      maxZoom: 17,
    );

/// The ride on the map: both stations, the line (its road route, or a straight
/// line for rides booked before routing) in the status ink, and the driver
/// (with a dashed approach to the pickup) while they ride.
Widget liveRideMap(Map<String, dynamic> r, LatLng? driverAt) {
  final status = r['status'] as String;
  final pickup = toLatLng(r['pickup']);
  final drop = toLatLng(r['drop']);
  final route = r['route'] is String ? decodePolyline(r['route']) : [pickup, drop];
  final riding = status == accepted || status == started;
  return rideMap(
    fit: route,
    lines: [
      rideLine(route, status),
      if (status == accepted && driverAt != null) approachLine(driverAt, pickup),
    ],
    markers: [
      stationMarker(pickup, 'PICKUP'),
      stationMarker(drop, 'DROP'),
      if (riding && driverAt != null) driverMarker(driverAt, lineFor(status)),
    ],
  );
}

Polyline rideLine(List<LatLng> points, String? status) => Polyline(
      points: points,
      strokeWidth: 6,
      color: lineFor(status),
      borderStrokeWidth: 3,
      borderColor: Swatch.midnight,
    );

Polyline approachLine(LatLng driver, LatLng pickup) => Polyline(
      points: [driver, pickup],
      strokeWidth: 4,
      color: Swatch.cobalt,
      pattern: StrokePattern.dashed(segments: const [10, 8]),
    );

/// An interchange circle on [p] with a caps label to its right, or to its left
/// in the right 30% of the map so the label stays on screen.
Marker stationMarker(LatLng p, String label) => Marker(
      point: p,
      // Symmetric, so the circle at the box's centre sits on the point either way.
      width: 296,
      height: 40,
      child: Builder(builder: (context) {
        final camera = MapCamera.of(context);
        final flip = camera.latLngToScreenOffset(p).dx > camera.size.width * 0.7;
        return Row(
          textDirection: flip ? TextDirection.rtl : TextDirection.ltr,
          spacing: 6,
          children: [
            const SizedBox(width: 130),
            Semantics(
              label: label,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Swatch.porcelain,
                  shape: BoxShape.circle,
                  border: Border.all(color: Swatch.midnight, width: 5),
                ),
              ),
            ),
            ExcludeSemantics(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Swatch.midnight.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(label,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall!
                          .copyWith(color: Swatch.porcelain)),
                ),
              ),
            ),
          ],
        );
      }),
    );

Marker driverMarker(LatLng p, Color color) => Marker(
      point: p,
      width: 36,
      height: 36,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Swatch.midnight, width: 3),
        ),
        child: Icon(Icons.two_wheeler,
            size: 20, color: onLine(color), semanticLabel: 'Driver'),
      ),
    );

/// `9:05 PM` today, `10/26 9:05 PM` before; a serverTimestamp reads null until the server confirms it.
String shortTime(Timestamp? t) {
  if (t == null) return 'just now';
  final d = t.toDate();
  final now = DateTime.now();
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final time = '$hour:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
  final today = d.year == now.year && d.month == now.month && d.day == now.day;
  return today ? time : '${d.month}/${d.day} $time';
}

String errorText(Object e) =>
    e is FirebaseException ? (e.message ?? e.code) : '$e';

void showMessage(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

/// A 48dp row under a station line that dials [phone]: "Call Marcus R.  (555) 010-0002".
Widget callRow(BuildContext context, String who, String phone) {
  final text = Theme.of(context).textTheme;
  return Padding(
    padding: const EdgeInsets.only(left: 40), // level with the station titles
    child: InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () async {
        final ok = await launchUrl(Uri(scheme: 'tel', path: phone)).catchError((_) => false);
        if (!ok && context.mounted) showMessage(context, "Couldn't open the phone app");
      },
      child: SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            spacing: 12,
            children: [
              const Icon(Icons.phone, color: Swatch.porcelain, size: 20),
              Expanded(
                child: Text('Call $who',
                    style: text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              Text(usPhone(phone),
                  style: text.bodyLarge!.copyWith(color: Swatch.mist, fontFeatures: tabular)),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Awaits a Firestore write; on failure shows the error in a SnackBar and returns false.
Future<bool> tryWrite(BuildContext context, Future<void> write) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await write;
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(errorText(e))));
    return false;
  }
}

Widget errorView(Object e) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            const Icon(Icons.error_outline, color: Swatch.scarletText),
            Text(errorText(e), textAlign: TextAlign.center),
          ],
        ),
      ),
    );

const loading = Center(child: CircularProgressIndicator());

Widget signOutButton() => IconButton(
      tooltip: 'Sign out',
      icon: const Icon(Icons.logout),
      onPressed: () => FirebaseAuth.instance.signOut(),
    );

/// The app bar for screens without a map.
AppBar transitBar(String role) => AppBar(
      title: Wordmark(role: role),
      actions: [signOutButton()],
      actionsPadding: const EdgeInsets.only(right: 8),
    );

/// Map screens: the map under a floating wordmark row (extra [actions], then
/// sign out), with the bottom panel below it.
Widget mapShell(
  BuildContext context, {
  required Widget map,
  required List<Widget> panel,
  List<Widget> actions = const [],
  String? role,
}) {
  final top = MediaQuery.paddingOf(context).top;
  return Column(
    children: [
      Expanded(
        child: Stack(
          children: [
            Positioned.fill(child: map),
            // Keeps the status bar off the street names; taps go through to the map.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: top + 56,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0, top / (top + 56), 1],
                      colors: [
                        Swatch.midnight,
                        Swatch.midnight.withValues(alpha: 0.75),
                        Swatch.midnight.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 8,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Swatch.midnight.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Wordmark(role: role),
                        ),
                      ),
                      const Spacer(),
                      ...actions,
                      MapButton(Icons.logout, 'Sign out',
                          () => FirebaseAuth.instance.signOut()),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      DecoratedBox(
        decoration: const BoxDecoration(
          color: Swatch.midnight,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          border: Border(top: BorderSide(color: Swatch.hairline)),
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            // Long panels scroll instead of pushing the map off a small or zoomed screen.
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.62),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: panel,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

Widget rideNotFound(BuildContext context, VoidCallback onDone) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            Text('Ride not found', style: Theme.of(context).textTheme.titleMedium),
            primaryButton('DONE', onDone),
          ],
        ),
      ),
    );

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.role});

  /// RIDER, DRIVER or ADMIN.
  final String role;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // The product explained as a line, in the app's own ink.
  static const _intro = {
    'RIDER': (Swatch.scarlet, ['Set your pickup', "Drop a pin where you're going", 'Ride, then pay cash']),
    'DRIVER': (Swatch.cobalt, ['Go online', 'Take the nearest pickup', 'Collect cash at drop-off']),
    'ADMIN': (Swatch.amber, ['Approve new drivers', "Watch today's rides", 'Clear stuck rides']),
  };

  final _phone = TextEditingController(text: '+1');
  final _code = TextEditingController();
  String? _verificationId; // Android
  ConfirmationResult? _confirmation; // web
  String? _error;
  bool _busy = false;

  bool get _codeSent => _verificationId != null || _confirmation != null;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  void _fail(Object e) {
    if (mounted) {
      setState(() {
        _error = errorText(e);
        _busy = false;
      });
    }
  }

  Future<void> _sendCode() async {
    final phone = _phone.text.replaceAll(RegExp(r'[\s-]'), '');
    if (!RegExp(r'^\+\d{8,15}$').hasMatch(phone)) {
      setState(() => _error = 'Enter the number with its country code, like +15550100000');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = FirebaseAuth.instance;
    try {
      if (kIsWeb) {
        final confirmation = await auth.signInWithPhoneNumber(phone);
        if (mounted) {
          setState(() {
            _confirmation = confirmation;
            _busy = false;
          });
        }
      } else {
        await auth.verifyPhoneNumber(
          phoneNumber: phone,
          // Android can verify the number by itself and hand over the credential.
          verificationCompleted: (credential) async {
            try {
              await auth.signInWithCredential(credential);
            } catch (e) {
              _fail(e);
            }
          },
          verificationFailed: _fail,
          codeSent: (verificationId, _) {
            if (mounted) {
              setState(() {
                _verificationId = verificationId;
                _busy = false;
              });
            }
          },
          // The code field stays open; nothing to do when auto-retrieval gives up.
          codeAutoRetrievalTimeout: (_) {},
        );
      }
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_confirmation != null) {
        await _confirmation!.confirm(code);
      } else {
        await FirebaseAuth.instance.signInWithCredential(
          PhoneAuthProvider.credential(
              verificationId: _verificationId!, smsCode: code),
        );
      }
    } catch (e) {
      _fail(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final mist = text.bodyMedium!.copyWith(color: Swatch.mist);
    final (color, steps) = _intro[widget.role]!;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                Wordmark(role: widget.role),
                const SizedBox(height: 32),
                StationLine(
                  color: color,
                  current: 0,
                  stations: [for (final s in steps) Station(s)],
                ),
                const SizedBox(height: 32),
                Text('Sign in with your phone', style: text.headlineSmall),
                const SizedBox(height: 4),
                Text("We'll text you a 6-digit code.", style: mist),
                const SizedBox(height: 24),
                if (!_codeSent)
                  TextField(
                    controller: _phone,
                    enabled: !_busy,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    decoration: const InputDecoration(
                        labelText: 'Phone number', hintText: '+1 555 010 0000'),
                    onSubmitted: (_) {
                      if (!_busy) _sendCode();
                    },
                  )
                else ...[
                  Text('Code sent to ${usPhone(_phone.text.replaceAll(RegExp(r'[\s-]'), ''))}',
                      style: mist),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _code,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    maxLength: 6,
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                        null,
                    style: text.bodyLarge!.copyWith(letterSpacing: 4, fontFeatures: tabular),
                    decoration: const InputDecoration(labelText: '6-digit code'),
                    onSubmitted: (_) {
                      if (!_busy) _verify();
                    },
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 8,
                      children: [
                        const Icon(Icons.error_outline, color: Swatch.scarletText, size: 20),
                        Expanded(
                          child: Text(_error!,
                              style: text.bodyMedium!.copyWith(color: Swatch.scarletText)),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                primaryButton(
                  _codeSent
                      ? (_busy ? 'VERIFYING…' : 'VERIFY')
                      : (_busy ? 'SENDING…' : 'SEND CODE'),
                  _busy ? null : (_codeSent ? _verify : _sendCode),
                ),
                if (_codeSent) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              _verificationId = null;
                              _confirmation = null;
                              _code.clear();
                            }),
                    child: const Text('Use another number'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
