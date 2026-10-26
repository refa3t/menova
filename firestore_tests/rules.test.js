// Firestore security rules tests (run against the emulator).
// D-INFRA-01 = B: guests create their own order once; staff change status
// and payment under strict checks; nobody edits prices or menu data.
import { after, before, beforeEach, test } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { serverTimestamp, Timestamp } from 'firebase/firestore';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-menova',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});

after(() => env.cleanup());

const HASH = 'a'.repeat(64);

// TEMP fixture shaped like core Order.toJson() plus serverCreatedAt.
function newOrder(id, uid, overrides = {}) {
  return {
    id,
    requestId: id,
    payloadHash: HASH,
    customerUid: uid,
    customer: { name: 'TEMP', phone: '01012345678', fulfillment: 'pickup' },
    items: [{ lineId: 'l1' }],
    status: 'new',
    paymentStatus: 'unpaid',
    paymentMethod: 'cash',
    deliveryFee: 0,
    total: 11500,
    definitionVersions: { pizza: 1 },
    rulesVersion: 1,
    createdAt: '2026-01-01T00:00:00Z',
    notes: '',
    history: [],
    serverCreatedAt: serverTimestamp(),
    ...overrides,
  };
}

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc('products/p1').set({ name: 'p', basePrice: 100 });
    await db.doc('categoryContent/c1').set({ isVisible: true });
    await db.doc('ingredients/i1').set({ extraPrice: 10 });
    await db.doc('assets/a1').set({ secureUrl: 'x' });
    await db.doc('settings/store').set({
      location: { lat: 30.4468569, lng: 31.1910437 },
      delivery: { perKm: 600, minFee: 2500, maxDistanceMeters: 15000 },
    });
    await db.doc('orders/o1').set({
      ...newOrder('o1', 'guest1'),
      serverCreatedAt: Timestamp.now(),
    });
  });
});

const guest = (uid = 'guest1') => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();
const staff = (role, uid = 'staff1') =>
  env.authenticatedContext(uid, { role }).firestore();

function entry(field, value, extra = {}) {
  return { field, value, by: 'staff1', at: '2026-01-01T00:05:00Z', ...extra };
}

test('anyone can read the menu', async () => {
  for (const path of ['products/p1', 'categoryContent/c1', 'ingredients/i1', 'assets/a1']) {
    await assertSucceeds(anon().doc(path).get());
  }
});

test('nobody can write menu data or prices from a client', async () => {
  for (const db of [anon(), guest(), staff('reception')]) {
    await assertFails(db.doc('products/p1').update({ basePrice: 1 }));
    await assertFails(db.doc('ingredients/i1').set({ extraPrice: 0 }));
    await assertFails(db.doc('products/new').set({ name: 'x' }));
    await assertFails(db.doc('assets/a1').delete());
  }
});

test('a guest creates their own order in its initial state', async () => {
  await assertSucceeds(guest('g2').doc('orders/r2').set(newOrder('r2', 'g2')));
});

test('create is refused when anything is off', async () => {
  const g = guest('g2');
  await assertFails(anon().doc('orders/r2').set(newOrder('r2', 'g2')));
  await assertFails(g.doc('orders/r2').set(newOrder('r2', 'someoneElse')));
  await assertFails(g.doc('orders/r2').set(newOrder('other', 'g2')));
  await assertFails(g.doc('orders/r2').set(newOrder('r2', 'g2', { status: 'ready' })));
  await assertFails(g.doc('orders/r2').set(newOrder('r2', 'g2', { paymentStatus: 'paid' })));
  await assertFails(g.doc('orders/r2').set(newOrder('r2', 'g2', { total: -5 })));
  await assertFails(g.doc('orders/r2').set(newOrder('r2', 'g2', { items: [] })));
  await assertFails(g.doc('orders/r2').set(newOrder('r2', 'g2', { extra: 1 })));
  await assertFails(g.doc('orders/r2').set(newOrder('r2', 'g2', {
    customer: { name: 'TEMP', phone: '123', fulfillment: 'pickup' },
  })));
  await assertFails(g.doc('orders/r2').set(newOrder('r2', 'g2', {
    customer: { name: 'TEMP', phone: '01012345678', fulfillment: 'delivery' },
  })), 'delivery needs an address');
  await assertFails(g.doc('orders/r2').set(newOrder('r2', 'g2', {
    history: [entry('status', 'accepted')],
  })));
});

function delivery(distanceMeters, deliveryFee) {
  return {
    customer: {
      name: 'TEMP', phone: '01012345678', fulfillment: 'delivery',
      address: 'TEMP street 1', location: { lat: 30.46, lng: 31.18 },
      distanceMeters,
    },
    deliveryFee,
    total: 11500 + deliveryFee,
  };
}

test('delivery fee must follow the store rules', async () => {
  const g = guest('g3');
  await assertSucceeds(g.doc('orders/d1').set(newOrder('d1', 'g3', delivery(4300, 3000))));
  await assertSucceeds(g.doc('orders/d2').set(newOrder('d2', 'g3', delivery(1200, 2500))), 'minimum fee');
  await assertSucceeds(g.doc('orders/d3').set(newOrder('d3', 'g3', delivery(15000, 9000))), 'max is inclusive');
  await assertFails(g.doc('orders/d4').set(newOrder('d4', 'g3', delivery(4300, 2500))), 'underpaid fee');
  await assertFails(g.doc('orders/d5').set(newOrder('d5', 'g3', delivery(15001, 9600))), 'out of range');
  await assertFails(g.doc('orders/d6').set(newOrder('d6', 'g3', { deliveryFee: 500 })), 'pickup is free');
  const noLocation = delivery(4300, 3000);
  delete noLocation.customer.location;
  await assertFails(g.doc('orders/d7').set(newOrder('d7', 'g3', noLocation)), 'delivery needs a location');
});

test('settings are public read, never written by clients', async () => {
  await assertSucceeds(anon().doc('settings/store').get());
  await assertFails(guest('g1').doc('settings/store').set({ x: 1 }));
  await assertFails(staff('reception').doc('settings/store').update({ x: 1 }));
});

test('same requestId cannot be written twice (no duplicates, no edits)', async () => {
  const g = guest('guest1');
  await assertFails(g.doc('orders/o1').set(newOrder('o1', 'guest1')));
  await assertFails(g.doc('orders/o1').update({ total: 1 }));
  await assertFails(g.doc('orders/o1').delete());
});

test('guest reads only their own order; staff read all', async () => {
  await assertSucceeds(guest('guest1').doc('orders/o1').get());
  await assertFails(guest('guest2').doc('orders/o1').get());
  await assertFails(anon().doc('orders/o1').get());
  await assertSucceeds(staff('reception').doc('orders/o1').get());
  await assertSucceeds(staff('kitchen').collection('orders').get());
  await assertFails(staff('admin').collection('orders').get());
});

test('a guest can probe a missing order id but not list orders', async () => {
  await assertSucceeds(guest('g9').doc('orders/missing').get());
  await assertFails(anon().doc('orders/missing').get());
  await assertFails(guest('g9').collection('orders').get());
});

test('staff move status along allowed transitions with a history entry', async () => {
  const db = staff('reception');
  await assertSucceeds(db.doc('orders/o1').update({
    status: 'accepted',
    history: [entry('status', 'accepted')],
  }));
  await assertFails(db.doc('orders/o1').update({
    status: 'completed',
    history: [entry('status', 'accepted'), entry('status', 'completed')],
  }), 'accepted -> completed is not allowed');
});

test('status change without a history entry, or by someone else, is refused', async () => {
  const db = staff('reception');
  await assertFails(db.doc('orders/o1').update({ status: 'accepted' }));
  await assertFails(db.doc('orders/o1').update({
    status: 'accepted',
    history: [{ ...entry('status', 'accepted'), by: 'impostor' }],
  }));
  await assertFails(guest('guest1').doc('orders/o1').update({
    status: 'accepted',
    history: [entry('status', 'accepted')],
  }));
});

test('cancel needs a reason and only before preparing', async () => {
  const db = staff('reception');
  await assertFails(db.doc('orders/o1').update({
    status: 'cancelled',
    history: [entry('status', 'cancelled')],
  }));
  await assertSucceeds(db.doc('orders/o1').update({
    status: 'cancelled',
    history: [entry('status', 'cancelled', { reason: 'العميل ألغى' })],
  }));
});

test('payment status changes independently; prices stay locked', async () => {
  const db = staff('reception');
  await assertSucceeds(db.doc('orders/o1').update({
    paymentStatus: 'paid',
    history: [entry('paymentStatus', 'paid')],
  }));
  await assertFails(db.doc('orders/o1').update({
    total: 1,
    history: [entry('paymentStatus', 'paid'), entry('paymentStatus', 'paid')],
  }));
  await assertFails(db.doc('orders/o1').update({
    status: 'accepted',
    paymentStatus: 'refunded',
    history: [entry('paymentStatus', 'paid'), entry('status', 'accepted')],
  }), 'one change at a time');
});

test('unknown collections are closed', async () => {
  await assertFails(anon().doc('secrets/x').get());
  await assertFails(guest().doc('secrets/x').set({ a: 1 }));
});
