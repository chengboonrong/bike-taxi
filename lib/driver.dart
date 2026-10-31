import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'common.dart';
import 'theme.dart';

class DriverGate extends StatefulWidget {
  const DriverGate({super.key});

  @override
  State<DriverGate> createState() => _DriverGateState();
}

class _DriverGateState extends State<DriverGate> {
  late final _driver = FirebaseFirestore.instance
      .collection('drivers')
      .doc(FirebaseAuth.instance.currentUser!.uid)
      .snapshots();

  Widget _page(Widget body) => Scaffold(appBar: transitBar('DRIVER'), body: body);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _driver,
      builder: (context, snap) {
        if (snap.hasError) return _page(errorView(snap.error!));
        if (!snap.hasData) return _page(loading);
        final driver = snap.data!.data();
        if (driver == null) return _page(const _RegisterForm());
        if (driver['approved'] != true) return _page(_waiting(context, driver));
        return DriverHome(driver: driver);
      },
    );
  }
}

Widget _waiting(BuildContext context, Map<String, dynamic> driver) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(24),
          children: [
            Text('Waiting for admin approval',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            StationLine(
              color: Swatch.amber,
              current: 1,
              live: true,
              stations: [
                Station('Registered', subtitle: '${driver['name']} · ${driver['plate']}'),
                const Station('Admin review',
                    subtitle: "This page updates by itself once you're approved."),
                const Station('Go online', subtitle: 'Take ride requests near you'),
              ],
            ),
          ],
        ),
      ),
    );

class _RegisterForm extends StatefulWidget {
  const _RegisterForm();

  @override
  State<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<_RegisterForm> {
  final _name = TextEditingController();
  final _plate = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _plate.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name = _name.text.trim();
    final plate = _plate.text.trim().toUpperCase();
    if (name.isEmpty || plate.isEmpty) {
      showMessage(context, 'Enter your name and bike plate');
      return;
    }
    final user = FirebaseAuth.instance.currentUser!;
    setState(() => _saving = true);
    final ok = await tryWrite(
      context,
      FirebaseFirestore.instance.collection('drivers').doc(user.uid).set({
        'name': name,
        'plate': plate,
        'phone': user.phoneNumber,
        'approved': false,
        'createdAt': FieldValue.serverTimestamp(),
      }),
    );
    if (!ok && mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(24),
          children: [
            Text('Join as a driver', style: text.headlineSmall),
            const SizedBox(height: 4),
            Text('An admin checks every new driver before they can take rides.',
                style: text.bodyMedium!.copyWith(color: Swatch.mist)),
            const SizedBox(height: 24),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              decoration: const InputDecoration(labelText: 'Your name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _plate,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Bike plate'),
            ),
            const SizedBox(height: 24),
            primaryButton('REGISTER', _saving ? null : _register),
          ],
        ),
      ),
    );
  }
}

class DriverHome extends StatefulWidget {
  const DriverHome({super.key, required this.driver});

  final Map<String, dynamic> driver;

  @override
  State<DriverHome> createState() => _DriverHomeState();
}

class _DriverHomeState extends State<DriverHome> {
  String? _activeRideId;
  int _tab = 0;
  late final Future<void> _restore = _restoreActiveRide();

  Future<void> _restoreActiveRide() async {
    final active = await rides
        .where('driverId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
        .where('status', whereIn: [accepted, started])
        .limit(1)
        .get();
    // setState: the app bar hides when the map screen comes back.
    if (active.docs.isNotEmpty && mounted) {
      setState(() => _activeRideId = active.docs.first.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    // The ride map brings its own floating wordmark row, like the rider's.
    final onMap = _activeRideId != null && _tab == 0;
    return Scaffold(
      appBar: onMap ? null : transitBar('DRIVER'),
      body: FutureBuilder(
        future: _restore,
        builder: (context, snap) {
          if (snap.hasError) return errorView(snap.error!);
          if (snap.connectionState != ConnectionState.done) return loading;
          // IndexedStack keeps the ride (and its location updates) alive on the Earnings tab.
          return IndexedStack(
            index: _tab,
            children: [
              _activeRideId == null
                  ? _OpenRides(
                      driver: widget.driver,
                      onAccepted: (id) => setState(() => _activeRideId = id),
                    )
                  : DriverRideScreen(
                      rideId: _activeRideId!,
                      onDone: () => setState(() => _activeRideId = null),
                    ),
              const _Earnings(),
            ],
          );
        },
      ),
      bottomNavigationBar: hairlineAbove(NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.two_wheeler), label: 'RIDES'),
          NavigationDestination(
              icon: Icon(Icons.payments_outlined),
              selectedIcon: Icon(Icons.payments),
              label: 'EARNINGS'),
        ],
      )),
    );
  }
}

class _OpenRides extends StatefulWidget {
  const _OpenRides({required this.driver, required this.onAccepted});

  final Map<String, dynamic> driver;
  final ValueChanged<String> onAccepted;

  @override
  State<_OpenRides> createState() => _OpenRidesState();
}

class _OpenRidesState extends State<_OpenRides> {
  bool _locating = false;
  LatLng? _here;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _requests;
  String? _accepting;

  Future<void> _setOnline(bool online) async {
    if (!online) {
      setState(() => _requests = null);
      return;
    }
    setState(() => _locating = true);
    LatLng? here;
    try {
      here = await currentLocation();
    } catch (e) {
      if (mounted) showMessage(context, 'No location: ${errorText(e)}');
    }
    if (!mounted) return;
    if (here == null) showMessage(context, 'Turn on location to go online');
    setState(() {
      _locating = false;
      _here = here;
      // ponytail: every online driver sees every open request; add geohash filtering when there are many drivers.
      _requests = here == null
          ? null
          : rides.where('status', isEqualTo: requested).snapshots();
    });
  }

  Future<void> _accept(String id) async {
    setState(() => _accepting = id);
    try {
      // The rules only allow this from `requested`, so a second driver is denied.
      await rides.doc(id).update({
        'status': accepted,
        'driverId': FirebaseAuth.instance.currentUser!.uid,
        'driverName': widget.driver['name'],
        'driverPlate': widget.driver['plate'],
        'driverPhone': FirebaseAuth.instance.currentUser!.phoneNumber,
        'acceptedAt': FieldValue.serverTimestamp(),
      });
      widget.onAccepted(id);
    } catch (e) {
      if (!mounted) return;
      showMessage(
          context,
          e is FirebaseException && e.code == 'permission-denied'
              ? 'Ride already taken'
              : errorText(e));
      setState(() => _accepting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final mist = text.bodyMedium!.copyWith(color: Swatch.mist);
    final online = _requests != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: MergeSemantics(
            child: Panel(
              padding: 0,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _locating ? null : () => _setOnline(!online),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                  child: Row(
                    spacing: 12,
                    children: [
                      online
                          ? const LineChip('ONLINE', Swatch.green)
                          : const LineChip('OFFLINE', Swatch.dim),
                      Expanded(
                        child: Text(
                            online ? 'Taking requests' : 'Go online to see ride requests',
                            style: text.bodyLarge),
                      ),
                      Switch(value: online, onChanged: _locating ? null : _setOnline),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_locating)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: LinearProgressIndicator(),
          ),
        Expanded(
          child: !online
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                      'Your location sorts the requests, nearest pickup first.',
                      style: mist),
                )
              : StreamBuilder(
                  stream: _requests,
                  builder: (context, snap) {
                    if (snap.hasError) return errorView(snap.error!);
                    if (!snap.hasData) return loading;
                    final open = [
                      for (final d in snap.data!.docs)
                        (
                          id: d.id,
                          ride: d.data(),
                          away: kmBetween(_here!, toLatLng(d.data()['pickup'])),
                        ),
                    ]..sort((a, b) => a.away.compareTo(b.away));
                    if (open.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            spacing: 4,
                            children: [
                              Text('No ride requests right now',
                                  style: text.titleMedium, textAlign: TextAlign.center),
                              Text('New requests appear here as riders book.',
                                  style: mist, textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                      );
                    }
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      children: [
                        Text('NEAREST PICKUP FIRST',
                            style: text.labelMedium!.copyWith(color: Swatch.mist)),
                        const SizedBox(height: 8),
                        for (final o in open)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Panel(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    spacing: 6,
                                    children: [
                                      Text(distanceText(o.away), style: text.headlineSmall),
                                      Expanded(child: Text('to pickup', style: mist)),
                                      Text(money(o.ride['fare']), style: text.displayMedium),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                      '${distanceText(o.ride['distanceKm'])} trip · requested ${shortTime(o.ride['createdAt'])}',
                                      style: mist),
                                  const SizedBox(height: 12),
                                  primaryButton(
                                    _accepting == o.id ? 'ACCEPTING…' : 'ACCEPT',
                                    _accepting == null ? () => _accept(o.id) : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class DriverRideScreen extends StatefulWidget {
  const DriverRideScreen(
      {super.key, required this.rideId, required this.onDone});

  final String rideId;
  final VoidCallback onDone;

  @override
  State<DriverRideScreen> createState() => _DriverRideScreenState();
}

class _DriverRideScreenState extends State<DriverRideScreen> {
  late final _ref = rides.doc(widget.rideId);
  late final StreamSubscription _rideSub;
  StreamSubscription<Position>? _gpsSub;
  DocumentSnapshot<Map<String, dynamic>>? _snap;
  Object? _error;
  LatLng? _me;

  bool get _live => [accepted, started].contains(_snap?.data()?['status']);

  @override
  void initState() {
    super.initState();
    _rideSub = _ref.snapshots().listen(
      (snap) {
        setState(() => _snap = snap);
        _syncGps();
      },
      onError: (Object e) => setState(() => _error = e),
    );
  }

  @override
  void dispose() {
    _rideSub.cancel();
    _gpsSub?.cancel();
    super.dispose();
  }

  // Shares the driver's position while the ride is accepted or started.
  void _syncGps() {
    if (_live && _gpsSub == null) {
      // ponytail: location is only sent while the app is in the foreground; add a foreground service for background tracking.
      _gpsSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(distanceFilter: 20),
      ).listen(
        (p) {
          if (!mounted) return;
          final here = LatLng(p.latitude, p.longitude);
          setState(() => _me = here);
          tryWrite(context, _ref.update({'driverLocation': toGeoPoint(here)}));
        },
        onError: (Object e) {
          if (mounted) showMessage(context, 'No location: ${errorText(e)}');
        },
      );
    } else if (!_live) {
      _gpsSub?.cancel();
      _gpsSub = null;
    }
  }

  Future<void> _move(String status, String stampField) async {
    if (status == completed || status == cancelled) {
      // Stop sharing first, so a late location write isn't denied on a finished ride.
      await _gpsSub?.cancel();
      _gpsSub = null;
    }
    if (!mounted) return;
    final ok = await tryWrite(context,
        _ref.update({'status': status, stampField: FieldValue.serverTimestamp()}));
    if (!ok && mounted) _syncGps();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return errorView(_error!);
    if (_snap == null) return loading;
    final r = _snap!.data();
    if (r == null) return rideNotFound(context, widget.onDone);
    final text = Theme.of(context).textTheme;
    final status = r['status'] as String;
    final fare = r['fare'] as num;
    final riderPhone = r['customerPhone'] as String?;
    final step = rideStep(r) - 1; // the driver's line starts at the pickup
    return mapShell(
      context,
      role: 'DRIVER',
      map: liveRideMap(r, _me),
      panel: [
        Row(
          children: [
            LineChip(status.toUpperCase(), lineFor(status), cancelled: status == cancelled),
            const Spacer(),
            Text(money(fare), style: text.headlineSmall),
          ],
        ),
        const SizedBox(height: 8),
        StationLine(
          color: lineFor(status),
          current: step,
          live: status == accepted || status == started,
          cancelled: status == cancelled,
          // Passed stations read in the past tense.
          stations: [
            Station('Go to pickup',
                subtitle: step > 0 ? 'Picked up' : 'Meet the rider at the pickup pin'),
            Station('On the trip',
                subtitle:
                    step > 1 ? 'Dropped off' : '${distanceText(r['distanceKm'])} to drop-off'),
            Station('Collect cash', subtitle: '${money(fare)} from the rider'),
          ],
        ),
        if (riderPhone != null) callRow(context, 'rider', riderPhone),
        const SizedBox(height: 16),
        if (status == accepted) ...[
          primaryButton('START TRIP', () => _move(started, 'startedAt')),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _move(cancelled, 'cancelledAt'),
            child: const Text('Cancel ride'),
          ),
        ],
        if (status == started) primaryButton('END TRIP', () => _move(completed, 'completedAt')),
        if (status == completed) ...[
          Text('Collect ${money(fare)} in cash', style: text.headlineSmall),
          const SizedBox(height: 12),
        ],
        if (status == completed || status == cancelled) primaryButton('DONE', widget.onDone),
      ],
    );
  }
}

class _Earnings extends StatefulWidget {
  const _Earnings();

  @override
  State<_Earnings> createState() => _EarningsState();
}

class _EarningsState extends State<_Earnings> {
  // ponytail: loads the driver's full history; switch to aggregate queries past a few thousand trips.
  late final _trips = rides
      .where('driverId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
      .where('status', isEqualTo: completed)
      .snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _trips,
      builder: (context, snap) {
        if (snap.hasError) return errorView(snap.error!);
        if (!snap.hasData) return loading;
        // completedAt is null until the server confirms a just-finished trip.
        DateTime doneAt(Map<String, dynamic> r) =>
            (r['completedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final trips = [for (final d in snap.data!.docs) d.data()]
          ..sort((a, b) => doneAt(b).compareTo(doneAt(a)));
        final now = DateTime.now();
        final startOfToday = DateTime(now.year, now.month, now.day);
        final today =
            trips.where((r) => !doneAt(r).isBefore(startOfToday)).toList();
        num sum(Iterable<Map<String, dynamic>> l) =>
            l.fold<num>(0, (acc, r) => acc + (r['fare'] as num));
        final text = Theme.of(context).textTheme;
        final mist = text.bodyMedium!.copyWith(color: Swatch.mist);
        final label = text.labelMedium!.copyWith(color: Swatch.mist);
        final figures = text.bodyLarge!.copyWith(fontFeatures: tabular);
        String count(int n) => '$n trip${n == 1 ? '' : 's'}';
        Widget total(String title, List<Map<String, dynamic>> l, TextStyle? figure) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: label),
                Text(money(sum(l)), style: figure),
                Text(count(l.length), style: mist),
              ],
            );
        // A departure board: time | distance | fare.
        Widget row(String time, String distance, String fare, TextStyle? style) => Row(
              children: [
                Expanded(child: Text(time, style: style)),
                Expanded(child: Text(distance, style: style)),
                Text(fare, style: style),
              ],
            );
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Panel(
              child: Wrap(
                spacing: 40,
                runSpacing: 16,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  total('TODAY', today, text.displayMedium),
                  total('ALL TIME', trips, text.headlineSmall),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (trips.isEmpty)
              Text('No trips yet. Finished trips show up here.', style: mist)
            else ...[
              row('TIME', 'DISTANCE', 'FARE', label),
              const SizedBox(height: 8),
              const Divider(),
              for (final r in trips) ...[
                SizedBox(
                  height: 48,
                  child: row(shortTime(r['completedAt']), distanceText(r['distanceKm']),
                      money(r['fare']), figures),
                ),
                const Divider(),
              ],
            ],
          ],
        );
      },
    );
  }
}
