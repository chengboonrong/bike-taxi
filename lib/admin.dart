import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'common.dart';
import 'theme.dart';

class AdminGate extends StatefulWidget {
  const AdminGate({super.key});

  @override
  State<AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<AdminGate> {
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  late final _admin =
      FirebaseFirestore.instance.collection('admins').doc(_uid).snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _admin,
      builder: (context, snap) {
        if (snap.hasData && snap.data!.exists) return const AdminHome();
        final text = Theme.of(context).textTheme;
        return Scaffold(
          appBar: transitBar('ADMIN'),
          body: snap.hasError
              ? errorView(snap.error!)
              : !snap.hasData
                  ? loading
                  : Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.all(24),
                          children: [
                            Text("This number isn't an admin yet", style: text.headlineSmall),
                            const SizedBox(height: 16),
                            Panel(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                spacing: 4,
                                children: [
                                  Text('YOUR USER ID',
                                      style: text.labelMedium!.copyWith(color: Swatch.mist)),
                                  SelectableText(_uid,
                                      style: text.bodyLarge!.copyWith(fontFeatures: tabular)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Create the document admins/$_uid in Firestore '
                              '(Firebase console → Firestore Database). '
                              'This page opens the panel as soon as it exists.',
                              style: text.bodyMedium!.copyWith(color: Swatch.mist),
                            ),
                          ],
                        ),
                      ),
                    ),
        );
      },
    );
  }
}

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _tab = 0;

  void _select(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    final content = IndexedStack(index: _tab, children: const [_Rides(), _Drivers()]);
    if (MediaQuery.sizeOf(context).width >= 840) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _tab,
              onDestinationSelected: _select,
              leading: const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Wordmark(role: 'ADMIN'),
              ),
              trailing: Padding(padding: const EdgeInsets.only(bottom: 16), child: signOutButton()),
              trailingAtBottom: true,
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.two_wheeler), label: Text('RIDES')),
                NavigationRailDestination(
                    icon: Icon(Icons.badge_outlined),
                    selectedIcon: Icon(Icons.badge),
                    label: Text('DRIVERS')),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: content,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: transitBar('ADMIN'),
      body: content,
      bottomNavigationBar: hairlineAbove(NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.two_wheeler), label: 'RIDES'),
          NavigationDestination(
              icon: Icon(Icons.badge_outlined), selectedIcon: Icon(Icons.badge), label: 'DRIVERS'),
        ],
      )),
    );
  }
}

/// A caps section label in mist.
Widget _section(BuildContext context, String label) => Text(label,
    style: Theme.of(context).textTheme.labelMedium!.copyWith(color: Swatch.mist));

class _Rides extends StatefulWidget {
  const _Rides();

  @override
  State<_Rides> createState() => _RidesState();
}

typedef _Stats = ({int requested, int accepted, int started, int done, double revenue});

class _RidesState extends State<_Rides> {
  late Future<_Stats> _stats = _loadStats();
  final _latest =
      rides.orderBy('createdAt', descending: true).limit(100).snapshots();

  // Only completed rides have completedAt, so this needs no composite index.
  Future<_Stats> _loadStats() async {
    final now = DateTime.now();
    final startOfToday = Timestamp.fromDate(DateTime(now.year, now.month, now.day));
    Future<int> open(String status) async =>
        (await rides.where('status', isEqualTo: status).count().get()).count ?? 0;
    final (today, waiting, onTheWay, riding) = await (
      rides
          .where('completedAt', isGreaterThanOrEqualTo: startOfToday)
          .aggregate(count(), sum('fare'))
          .get(),
      open(requested),
      open(accepted),
      open(started),
    ).wait;
    return (
      requested: waiting,
      accepted: onTheWay,
      started: riding,
      done: today.count ?? 0,
      revenue: today.getSum('fare') ?? 0,
    );
  }

  Future<void> _refresh() {
    final stats = _loadStats();
    setState(() => _stats = stats);
    return stats;
  }

  // The network as one line: rides run REQUESTED → ACCEPTED → ON TRIP → COMPLETED, each
  // interchange in its state's ink, to a terminus labelled with today's revenue.
  Widget _networkLine(_Stats? s) {
    final text = Theme.of(context).textTheme;
    String n(int? v) => v == null ? '…' : '$v';
    final stops = [
      (Swatch.amber, 'REQUESTED', n(s?.requested)),
      (Swatch.cobalt, 'ACCEPTED', n(s?.accepted)),
      (Swatch.green, 'ON TRIP', n(s?.started)),
      (Swatch.porcelain, 'COMPLETED\nTODAY', n(s?.done)),
      (Swatch.porcelain, 'REVENUE\nTODAY', s == null ? '…' : money(s.revenue)),
    ];
    final last = stops.length - 1;
    return Stack(
      children: [
        // The line runs from the first interchange to the terminus, each stretch in the ink
        // of the stop it leaves.
        Positioned(
          top: 13,
          left: 0,
          right: 0,
          child: FractionallySizedBox(
            widthFactor: last / stops.length,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [for (final (ink, _, _) in stops.take(last)) ...[ink, ink]],
                  stops: [for (var i = 0; i < last; i++) ...[i / last, (i + 1) / last]],
                ),
              ),
              child: const SizedBox(height: 6),
            ),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, (ink, label, figure)) in stops.indexed)
              Expanded(
                child: MergeSemantics(
                  child: Column(
                    children: [
                      SizedBox(
                        height: 32,
                        child: Center(
                          child: i == last
                              ? const SizedBox(
                                  width: 6, height: 26, child: ColoredBox(color: Swatch.porcelain))
                              : Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: Swatch.porcelain,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: ink, width: 5),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Figures and labels shrink rather than wrap mid-word on a phone.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(figure, style: text.headlineSmall),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(label,
                            textAlign: TextAlign.center,
                            style: text.labelSmall!.copyWith(color: Swatch.mist)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _cancel(DocumentReference<Map<String, dynamic>> ride) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Swatch.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Swatch.hairline),
        ),
        title: const Text('Cancel this ride?'),
        content: const Text('It ends right away for the rider and the driver.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('KEEP RIDE'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Swatch.scarletText),
            child: const Text('CANCEL RIDE'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    await tryWrite(
      context,
      ride.update({'status': cancelled, 'cancelledAt': FieldValue.serverTimestamp()}),
    );
  }

  // The wide table's columns: status, fare, distance, rider, driver, time, action.
  Widget _wideRow(List<Widget> c) => Row(
        spacing: 12,
        children: [
          SizedBox(width: 120, child: Align(alignment: Alignment.centerLeft, child: c[0])),
          Expanded(child: c[1]),
          Expanded(child: c[2]),
          Expanded(flex: 2, child: c[3]),
          Expanded(flex: 2, child: c[4]),
          Expanded(child: c[5]),
          SizedBox(width: 96, child: c[6]),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: StreamBuilder(
        stream: _latest,
        builder: (context, snap) => LayoutBuilder(
          builder: (context, box) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(child: _section(context, 'NETWORK STATUS')),
                  // Pull-to-refresh needs touch; this covers the mouse.
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              FutureBuilder(
                future: _stats,
                builder: (context, stats) {
                  if (stats.hasError) {
                    return Text(errorText(stats.error!),
                        style: const TextStyle(color: Swatch.scarletText));
                  }
                  return Panel(child: _networkLine(stats.data));
                },
              ),
              const SizedBox(height: 32),
              _section(context, 'LATEST RIDES'),
              const SizedBox(height: 8),
              if (box.maxWidth >= 720 && (snap.data?.docs.isNotEmpty ?? false))
                SizedBox(
                  height: 32,
                  child: _wideRow([
                    for (final h in ['STATUS', 'FARE', 'DISTANCE', 'RIDER', 'DRIVER', 'BOOKED', ''])
                      Text(h,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall!
                              .copyWith(color: Swatch.mist)),
                  ]),
                ),
              const Divider(),
              if (snap.hasError)
                errorView(snap.error!)
              else if (!snap.hasData)
                const Padding(padding: EdgeInsets.all(24), child: loading)
              else if (snap.data!.docs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text('No rides yet.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium!
                          .copyWith(color: Swatch.mist)),
                )
              else
                for (final d in snap.data!.docs) ...[
                  _rideRow(d, wide: box.maxWidth >= 720),
                  const Divider(),
                ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _rideRow(QueryDocumentSnapshot<Map<String, dynamic>> d, {required bool wide}) {
    final r = d.data();
    final status = r['status'] as String;
    final text = Theme.of(context).textTheme;
    final figures = text.bodyLarge!.copyWith(fontFeatures: tabular);
    final chip = LineChip(status.toUpperCase(), lineFor(status), cancelled: status == cancelled);
    final driver = '${r['driverName'] ?? 'No driver'}';
    final cancel = openStatuses.contains(status)
        ? TextButton(onPressed: () => _cancel(d.reference), child: const Text('CANCEL'))
        : null;
    Widget cell(String s, {TextStyle? style}) =>
        Text(s, style: style ?? figures, maxLines: 1, overflow: TextOverflow.ellipsis);
    if (wide) {
      return SizedBox(
        height: 56,
        child: _wideRow([
          chip,
          cell(money(r['fare'])),
          cell(distanceText(r['distanceKm'])),
          cell(usPhone(r['customerPhone'])),
          cell(driver, style: text.bodyLarge),
          cell(shortTime(r['createdAt'])),
          cancel ?? const SizedBox.shrink(),
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Row(
                  spacing: 12,
                  children: [
                    chip,
                    Text(money(r['fare']),
                        style: text.titleMedium!.copyWith(fontFeatures: tabular)),
                  ],
                ),
                Text(
                  '${usPhone(r['customerPhone'])} · $driver · ${shortTime(r['createdAt'])}',
                  style: text.bodyMedium!.copyWith(color: Swatch.mist, fontFeatures: tabular),
                ),
              ],
            ),
          ),
          ?cancel,
        ],
      ),
    );
  }
}

class _Drivers extends StatefulWidget {
  const _Drivers();

  @override
  State<_Drivers> createState() => _DriversState();
}

class _DriversState extends State<_Drivers> {
  final _drivers = FirebaseFirestore.instance.collection('drivers').snapshots();

  // The whole row toggles approval.
  Widget _driverRow(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final x = d.data();
    final text = Theme.of(context).textTheme;
    final approved = x['approved'] == true;
    void set(bool v) => tryWrite(context, d.reference.update({'approved': v}));
    return MergeSemantics(
      child: Semantics(
        label: 'Approve ${x['name']}',
        child: InkWell(
          onTap: () => set(!approved),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              spacing: 12,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      Row(
                        spacing: 10,
                        children: [
                          Flexible(
                            child: Text('${x['name']}',
                                style: text.titleMedium, overflow: TextOverflow.ellipsis),
                          ),
                          LineChip('${x['plate']}', Swatch.porcelain),
                        ],
                      ),
                      Text(usPhone(x['phone']),
                          style: text.bodyMedium!
                              .copyWith(color: Swatch.mist, fontFeatures: tabular)),
                    ],
                  ),
                ),
                Switch(value: approved, onChanged: set),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _drivers,
      builder: (context, snap) {
        if (snap.hasError) return errorView(snap.error!);
        if (!snap.hasData) return loading;
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Text('No drivers have registered yet.',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Swatch.mist)),
          );
        }
        bool approved(QueryDocumentSnapshot<Map<String, dynamic>> d) =>
            d.data()['approved'] == true;
        final pending = docs.where((d) => !approved(d)).toList();
        final active = docs.where(approved).toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (pending.isNotEmpty) ...[
              Row(
                spacing: 8,
                children: [
                  _section(context, 'AWAITING APPROVAL'),
                  LineChip('${pending.length}', Swatch.amber),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(),
              for (final d in pending) ...[_driverRow(d), const Divider()],
              const SizedBox(height: 32),
            ],
            if (active.isNotEmpty) ...[
              _section(context, 'APPROVED'),
              const SizedBox(height: 8),
              const Divider(),
              for (final d in active) ...[_driverRow(d), const Divider()],
            ],
          ],
        );
      },
    );
  }
}
