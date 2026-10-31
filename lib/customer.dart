import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' show MapController;
import 'package:latlong2/latlong.dart';

import 'common.dart';
import 'routing.dart';
import 'theme.dart';

class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key});

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  String? _rideId;
  late final Future<void> _restore = _restoreActiveRide();

  Future<void> _restoreActiveRide() async {
    final active = await rides
        .where('customerId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
        .where('status', whereIn: openStatuses)
        .limit(1)
        .get();
    if (active.docs.isNotEmpty) _rideId = active.docs.first.id;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _restore,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            appBar: transitBar('RIDER'),
            body: errorView(snap.error!),
          );
        }
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: loading);
        }
        return _rideId == null
            ? BookScreen(onBooked: (id) => setState(() => _rideId = id))
            : CustomerRideScreen(
                rideId: _rideId!,
                onDone: () => setState(() => _rideId = null),
              );
      },
    );
  }
}

class BookScreen extends StatefulWidget {
  const BookScreen({super.key, required this.onBooked});

  final ValueChanged<String> onBooked;

  @override
  State<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends State<BookScreen> {
  final _map = MapController();
  LatLng? _centre, _pickup, _drop;
  bool _pickupFromGps = false;
  bool _settingPickup = true;
  bool _locating = false;
  bool _booking = false;
  RideRoute? _route;
  String? _routeError;
  int _routeRequest = 0; // only the latest request's answer is used

  /// Routes between the pins whenever either one changes.
  Future<void> _findRoute() async {
    final request = ++_routeRequest;
    setState(() {
      _route = null;
      _routeError = null;
    });
    if (_pickup == null || _drop == null) return;
    try {
      // ponytail: the client routes and prices; the rules only bound the distance and check the
      // fare formula. A Cloud Function that calls Valhalla is the production step.
      final route = await routeBetween(_pickup!, _drop!);
      if (!mounted || request != _routeRequest) return;
      setState(() => _route = route);
      _map.fitCamera(fitTo(route.points));
    } on RouteException catch (e) {
      if (mounted && request == _routeRequest) setState(() => _routeError = e.message);
    }
  }

  @override
  void initState() {
    super.initState();
    _locate();
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  /// Sets the pickup to the device position: on open, and from the locate button.
  Future<void> _locate() async {
    setState(() => _locating = true);
    LatLng? here;
    try {
      here = await currentLocation();
    } catch (e) {
      if (mounted) showMessage(context, 'No location: ${errorText(e)}');
    }
    if (!mounted) return;
    final opening = _centre == null;
    if (here == null && !opening) {
      showMessage(context, 'Turn on location to use your position');
    }
    setState(() {
      _locating = false;
      _centre ??= here ?? defaultCentre;
      if (here != null) {
        _pickup = here;
        _pickupFromGps = true;
        _settingPickup = false;
      }
    });
    if (here != null && !opening) {
      _map.move(here, 16);
      _findRoute();
    }
  }

  void _onTap(LatLng point) {
    setState(() {
      if (_settingPickup) {
        _pickup = point;
        _pickupFromGps = false;
        _settingPickup = false;
      } else {
        _drop = point;
      }
    });
    _findRoute();
  }

  Future<void> _book(RideRoute route) async {
    final user = FirebaseAuth.instance.currentUser!;
    setState(() => _booking = true);
    try {
      // ponytail: fare is computed on the client and only loosely checked by the rules; move it to a Cloud Function when payments go online.
      final ride = await rides.add({
        'customerId': user.uid,
        'customerPhone': user.phoneNumber,
        'pickup': toGeoPoint(_pickup!),
        'drop': toGeoPoint(_drop!),
        'distanceKm': route.km,
        'fare': fareFor(route.km),
        'route': route.encoded,
        'status': requested,
        'driverId': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
      widget.onBooked(ride.id);
    } catch (e) {
      if (!mounted) return;
      showMessage(context, errorText(e));
      setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_centre == null) return const Scaffold(body: loading);
    final route = _route;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: mapShell(
        context,
        map: rideMap(
          controller: _map,
          center: _centre!,
          onTap: _onTap,
          // A fare comes only from a real route, so there is no straight-line fallback.
          lines: [if (route != null) rideLine(route.points, null)],
          markers: [
            if (_pickup != null) stationMarker(_pickup!, 'PICKUP'),
            if (_drop != null) stationMarker(_drop!, 'DROP'),
          ],
        ),
        actions: [
          MapButton(Icons.my_location, 'Use my location', _locating ? null : _locate),
        ],
        panel: [
          // Tap a station to choose which point the next map tap sets.
          StationLine(
            color: Swatch.scarlet,
            current: _settingPickup ? 0 : 1,
            stations: [
              Station(
                'PICKUP',
                subtitle: _pickup == null
                    ? 'Tap the map'
                    : _pickupFromGps
                        ? 'Your location'
                        : 'Pinned on map',
                selected: _settingPickup,
                onTap: () => setState(() => _settingPickup = true),
              ),
              Station(
                'DROP',
                subtitle: _drop == null ? 'Tap the map to set your drop-off' : 'Pinned on map',
                selected: !_settingPickup,
                onTap: () => setState(() => _settingPickup = false),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            spacing: 12,
            children: [
              Expanded(
                child: Text(
                  _pickup == null || _drop == null
                      ? 'Set both stops to see your fare'
                      : route != null
                          ? '${distanceText(route.km)} · ${route.minutes} min · cash'
                          : _routeError ?? 'Finding the road route…',
                  style: text.bodyMedium!
                      .copyWith(color: _routeError != null ? Swatch.scarletText : Swatch.mist),
                ),
              ),
              Text(
                route == null ? '—' : money(fareFor(route.km)),
                style: text.displayMedium!.copyWith(color: route == null ? Swatch.mist : null),
              ),
            ],
          ),
          const SizedBox(height: 16),
          primaryButton(
            _booking ? 'BOOKING…' : 'BOOK BIKE',
            route == null || _booking ? null : () => _book(route),
          ),
        ],
      ),
    );
  }
}

class CustomerRideScreen extends StatefulWidget {
  const CustomerRideScreen(
      {super.key, required this.rideId, required this.onDone});

  final String rideId;
  final VoidCallback onDone;

  @override
  State<CustomerRideScreen> createState() => _CustomerRideScreenState();
}

class _CustomerRideScreenState extends State<CustomerRideScreen> {
  late final _ref = rides.doc(widget.rideId);
  late final _ride = _ref.snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _ride,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(appBar: transitBar('RIDER'), body: errorView(snap.error!));
        }
        if (!snap.hasData) return const Scaffold(body: loading);
        final r = snap.data!.data();
        if (r == null) {
          return Scaffold(
            appBar: transitBar('RIDER'),
            body: rideNotFound(context, widget.onDone),
          );
        }
        final text = Theme.of(context).textTheme;
        final status = r['status'] as String;
        final driverAt = r['driverLocation'] as GeoPoint?;
        final fare = r['fare'] as num;
        final plate = r['driverPlate'] as String?;
        final driverPhone = r['driverPhone'] as String?;
        final color = lineFor(status);
        final step = rideStep(r);
        return Scaffold(
          body: mapShell(
            context,
            map: liveRideMap(r, driverAt == null ? null : toLatLng(driverAt)),
            panel: [
              Row(
                children: [
                  LineChip((statusLabel[status] ?? status).toUpperCase(), color,
                      cancelled: status == cancelled),
                  const Spacer(),
                  Text(money(fare), style: text.headlineSmall),
                ],
              ),
              const SizedBox(height: 8),
              StationLine(
                color: color,
                current: step,
                live: openStatuses.contains(status),
                cancelled: status == cancelled,
                // Passed stations read in the past tense.
                stations: [
                  Station('Finding a driver',
                      subtitle: step > 0 ? 'Driver found' : 'Waiting for a driver to accept'),
                  Station(
                    'Driver on the way',
                    subtitle: step > 1 ? 'Picked up' : r['driverName'] as String?,
                    trailing: plate == null ? null : LineChip(plate, Swatch.porcelain),
                  ),
                  Station('On the trip',
                      subtitle: step > 2
                          ? 'Dropped off'
                          : '${distanceText(r['distanceKm'])} to your drop-off'),
                  Station('Arrived', subtitle: 'Pay ${money(fare)} in cash'),
                ],
              ),
              if (driverPhone != null)
                callRow(context, '${r['driverName'] ?? 'your driver'}', driverPhone),
              const SizedBox(height: 16),
              if (status == requested || status == accepted)
                OutlinedButton(
                  onPressed: () => tryWrite(
                    context,
                    _ref.update({
                      'status': cancelled,
                      'cancelledAt': FieldValue.serverTimestamp(),
                    }),
                  ),
                  child: const Text('CANCEL RIDE'),
                ),
              if (status == completed || status == cancelled)
                primaryButton('DONE', widget.onDone),
            ],
          ),
        );
      },
    );
  }
}
