// Firestore rules check. Run from the project root:
// firebase emulators:exec --only firestore --project demo-bike-taxi "node --test rules-test/"
// (Never against a live demo emulator: every test clears the database.)
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import {
  GeoPoint, Timestamp, collection, count, doc, getAggregateFromServer, getCountFromServer, getDoc, getDocs,
  limit, orderBy, query, serverTimestamp, setDoc, sum, updateDoc, where,
} from 'firebase/firestore';

const phones = {
  cust: '+60111111111', drv: '+60122222222', drv2: '+60133333333', newbie: '+60144444444',
  admin: '+60155555555', stranger: '+60166666666', applicant: '+60177777777',
};

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-bike-taxi',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});
after(() => env.cleanup());
beforeEach(() => env.clearFirestore());

const db = (uid) => env.authenticatedContext(uid, { phone_number: phones[uid] }).firestore();

const ride = (extra = {}) => ({
  customerId: 'cust', customerPhone: phones.cust,
  pickup: new GeoPoint(3.139, 101.6869), drop: new GeoPoint(3.15, 101.7),
  // About 1.9 km apart in a straight line; 2.4 km by road at $2.50 + $1.50 a mile.
  distanceKm: 2.4, fare: 4.7, route: '_p~iF~ps|U_ulLnnqC_mqNvxq`@', status: 'requested', driverId: null,
  createdAt: serverTimestamp(), ...extra,
});
const takenBy = (uid, name, plate) => ({
  status: 'accepted', driverId: uid, driverName: name, driverPlate: plate, driverPhone: phones[uid],
});
const accept = (uid, name, plate) => ({ ...takenBy(uid, name, plate), acceptedAt: serverTimestamp() });

async function seed(rides = {}) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const d = ctx.firestore();
    const driver = (name, plate, phone, approved) => ({ name, plate, phone, approved, createdAt: Timestamp.now() });
    await setDoc(doc(d, 'admins/admin'), {});
    await setDoc(doc(d, 'drivers/drv'), driver('Dan', 'WXY 1234', phones.drv, true));
    await setDoc(doc(d, 'drivers/drv2'), driver('Dee', 'ABC 5678', phones.drv2, true));
    await setDoc(doc(d, 'drivers/newbie'), driver('Nina', 'NB 1', phones.newbie, false));
    for (const [id, data] of Object.entries(rides)) await setDoc(doc(d, 'rides', id), { ...ride(), ...data });
  });
}

test('1. customer creates a valid request, but not one for another user', async () => {
  await seed();
  const c = db('cust');
  await assertSucceeds(setDoc(doc(c, 'rides/r1'), ride()));
  await assertFails(setDoc(doc(c, 'rides/r2'), ride({ customerId: 'stranger' })));
});

test('2. only approved drivers see and take open requests, and only once', async () => {
  await seed({ r1: {} });
  const open = (d) => getDocs(query(collection(d, 'rides'), where('status', '==', 'requested')));
  const newbie = db('newbie');
  await assertFails(open(newbie));
  await assertFails(updateDoc(doc(newbie, 'rides/r1'), accept('newbie', 'Nina', 'NB 1')));

  const drv = db('drv');
  const snap = await assertSucceeds(open(drv));
  assert.equal(snap.size, 1);
  await assertSucceeds(updateDoc(doc(drv, 'rides/r1'), accept('drv', 'Dan', 'WXY 1234')));
  await assertFails(updateDoc(doc(db('drv2'), 'rides/r1'), accept('drv2', 'Dee', 'ABC 5678')));
});

test('3. only the assigned driver moves the ride along; strangers cannot read it', async () => {
  await seed({ r1: takenBy('drv', 'Dan', 'WXY 1234') });
  const ref = (uid) => doc(db(uid), 'rides/r1');
  await assertFails(updateDoc(ref('cust'), { status: 'completed', completedAt: serverTimestamp() }));
  await assertSucceeds(updateDoc(ref('drv'), { status: 'started', startedAt: serverTimestamp() }));
  await assertSucceeds(updateDoc(ref('drv'), { driverLocation: new GeoPoint(3.145, 101.69) }));
  await assertSucceeds(updateDoc(ref('drv'), { status: 'completed', completedAt: serverTimestamp() }));
  await assertFails(getDoc(ref('stranger')));
});

test('4. drivers cannot approve themselves; admins can', async () => {
  await seed();
  const me = doc(db('applicant'), 'drivers/applicant');
  const form = { name: 'Ali', plate: 'VBN 4321', phone: phones.applicant, createdAt: serverTimestamp() };
  await assertFails(setDoc(me, { ...form, approved: true }));
  await assertSucceeds(setDoc(me, { ...form, approved: false }));
  await assertFails(updateDoc(me, { approved: true }));
  await assertSucceeds(updateDoc(doc(db('admin'), 'drivers/applicant'), { approved: true }));
});

test('5. admins list rides by createdAt; customers cannot list them all', async () => {
  await seed({ r1: {}, r2: { customerId: 'stranger', customerPhone: phones.stranger } });
  const latest = (d) => getDocs(query(collection(d, 'rides'), orderBy('createdAt', 'desc'), limit(100)));
  const snap = await assertSucceeds(latest(db('admin')));
  assert.equal(snap.size, 2);
  await assertFails(latest(db('cust')));
});

test('6. every other query the apps run is allowed', async () => {
  await seed({
    r1: {},
    r2: { ...takenBy('drv', 'Dan', 'WXY 1234'), status: 'completed', completedAt: Timestamp.now() },
  });
  const rides = (uid) => collection(db(uid), 'rides');
  // Customer restores an active ride.
  await assertSucceeds(getDocs(query(rides('cust'),
    where('customerId', '==', 'cust'), where('status', 'in', ['requested', 'accepted', 'started']), limit(1))));
  // Driver restores an active ride, and loads earnings.
  await assertSucceeds(getDocs(query(rides('drv'),
    where('driverId', '==', 'drv'), where('status', 'in', ['accepted', 'started']), limit(1))));
  await assertSucceeds(getDocs(query(rides('drv'), where('driverId', '==', 'drv'), where('status', '==', 'completed'))));
  // Driver gate reads its own (possibly missing) doc; admin gate reads its own admin doc.
  await assertSucceeds(getDoc(doc(db('applicant'), 'drivers/applicant')));
  await assertSucceeds(getDoc(doc(db('admin'), 'admins/admin')));
  // Admin overview and drivers list.
  const today = await assertSucceeds(getAggregateFromServer(
    query(rides('admin'), where('completedAt', '>=', Timestamp.fromDate(new Date(new Date().setHours(0, 0, 0, 0))))),
    { n: count(), revenue: sum('fare') }));
  assert.deepEqual(today.data(), { n: 1, revenue: 4.7 });
  for (const [status, n] of [['requested', 1], ['accepted', 0], ['started', 0]]) {
    const open = await assertSucceeds(getCountFromServer(query(rides('admin'), where('status', '==', status))));
    assert.equal(open.data().count, n);
  }
  await assertSucceeds(getDocs(collection(db('admin'), 'drivers')));
  // Admin cancels an open ride.
  await assertSucceeds(updateDoc(doc(db('admin'), 'rides/r1'), { status: 'cancelled', cancelledAt: serverTimestamp() }));
});

test('7. a fare that does not match the distance is denied', async () => {
  await seed();
  await assertFails(setDoc(doc(db('cust'), 'rides/r1'), ride({ fare: 3.6 })));
});

test('8. a distance shorter than the straight line between the pins is denied', async () => {
  await seed();
  // 1 km (fare $3.40) for pins about 1.9 km apart.
  await assertFails(setDoc(doc(db('cust'), 'rides/r1'), ride({ distanceKm: 1, fare: 3.4 })));
});

test('9. a ride without a route is denied', async () => {
  await seed();
  const { route, ...noRoute } = ride();
  await assertFails(setDoc(doc(db('cust'), 'rides/r1'), noRoute));
});
