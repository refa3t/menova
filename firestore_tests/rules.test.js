// Firestore security rules tests (run against the emulator).
// D-INFRA-01 = B: guests create their own order once; staff change status
// and payment under strict checks; nobody edits prices or menu data.
import { after, before, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
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
    await db.doc('assets/ing_i1').set(asset('ing_i1', 'ingredient', 1));
    await db.doc('assets/base_x').set(asset('base_x', 'base', 1));
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
  await assertSucceeds(staff('owner').collection('orders').get());
  await assertFails(staff('menu_manager').collection('orders').get());
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

// P3-02 / P3-07: admins write products only with an audit entry in the
// same batch; the audit log is append-only and owner-readable.
function product(id, overrides = {}) {
  return {
    id, categoryId: 'cat', name: 'TEMP', names: { en: 'TEMP', ar: 'TEMP' },
    description: '', basePrice: 13000, imageAssetId: 'img', defaults: [],
    isAvailable: true, sizeDeltas: { s: 0 }, optionDeltas: {}, displayOrder: 0,
    ...overrides,
  };
}

async function saveProduct(db, uid, id, data, auditOverrides = {}) {
  const audit = db.collection('auditLog').doc();
  const batch = db.batch();
  batch.set(audit, {
    action: 'saveProduct', target: `products/${id}`, by: uid,
    at: serverTimestamp(), before: null, after: data, ...auditOverrides,
  });
  batch.set(db.doc(`products/${id}`), { ...data, lastAuditId: audit.id });
  return batch.commit();
}

test('admins save products only with an audit entry', async () => {
  const owner = staff('owner', 'own1');
  const manager = staff('menu_manager', 'mgr1');
  await assertSucceeds(saveProduct(owner, 'own1', 'p9', product('p9')));
  await assertSucceeds(saveProduct(manager, 'mgr1', 'p9', product('p9', { basePrice: 14000 })));
  // No audit entry.
  await assertFails(owner.doc('products/p9').set({ ...product('p9'), lastAuditId: 'nope' }));
  // Audit names someone else or another document.
  await assertFails(saveProduct(owner, 'own1', 'p9', product('p9'), { by: 'mgr1' }));
  await assertFails(saveProduct(owner, 'own1', 'p9', product('p9'), { target: 'products/p8' }));
  // Not an admin.
  await assertFails(saveProduct(staff('reception', 'rec1'), 'rec1', 'p9', product('p9')));
  // Bad data: no price, category change, unknown field.
  await assertFails(saveProduct(owner, 'own1', 'p9', product('p9', { basePrice: 0 })));
  await assertFails(saveProduct(owner, 'own1', 'p9', product('p9', { categoryId: 'other' })));
  await assertFails(saveProduct(owner, 'own1', 'p9', product('p9', { extra: 1 })));
  await assertFails(owner.doc('products/p9').delete());
});

test('the audit log is append-only and only the owner reads it', async () => {
  const owner = staff('owner', 'own1');
  await saveProduct(owner, 'own1', 'p9', product('p9'));
  const entries = await owner.collection('auditLog').get();
  assert.equal(entries.size, 1);
  const ref = entries.docs[0].ref;
  await assertFails(ref.update({ action: 'x' }));
  await assertFails(ref.delete());
  await assertFails(staff('menu_manager', 'mgr1').collection('auditLog').get());
  await assertFails(staff('reception', 'rec1').collection('auditLog').get());
});

// P3-03: admins edit existing ingredients only, audited.
async function saveIngredient(db, uid, id, data) {
  const audit = db.collection('auditLog').doc();
  const batch = db.batch();
  batch.set(audit, {
    action: 'saveIngredient', target: `ingredients/${id}`, by: uid,
    at: serverTimestamp(), before: null, after: data,
  });
  batch.set(db.doc(`ingredients/${id}`), { ...data, lastAuditId: audit.id });
  return batch.commit();
}

test('admins edit existing ingredients, audited; no create or delete', async () => {
  const ing = {
    id: 'i1', name: 'TEMP', names: { ar: 'TEMP' }, assetId: 'ing_i1',
    extraPrice: 1500, isAvailable: false, sizeMultipliers: {},
  };
  const manager = staff('menu_manager', 'mgr1');
  await assertSucceeds(saveIngredient(manager, 'mgr1', 'i1', ing));
  await assertFails(saveIngredient(manager, 'mgr1', 'i1', { ...ing, extraPrice: -5 }));
  await assertFails(saveIngredient(manager, 'mgr1', 'i9', { ...ing, id: 'i9' }));
  await assertFails(manager.doc('ingredients/i1').set({ ...ing, lastAuditId: 'nope' }));
  await assertFails(saveIngredient(staff('reception', 'rec1'), 'rec1', 'i1', ing));
  await assertFails(manager.doc('ingredients/i1').delete());
});

// P3-04: admins replace ingredient images and product photos, audited.
function asset(id, kind, version, overrides = {}) {
  return {
    id, kind, name: id, publicId: `menova/assets/${id}_${version}`,
    secureUrl: `https://res.cloudinary.com/etdgj6d8/image/upload/v1/${id}_${version}.webp`,
    version, variants: [], layerOrder: 20, allowedCategoryIds: ['cat'],
    adminReplaceable: false, ...overrides,
  };
}

async function saveAsset(db, uid, id, data) {
  const audit = db.collection('auditLog').doc();
  const batch = db.batch();
  batch.set(audit, {
    action: 'replaceAsset', target: `assets/${id}`, by: uid,
    at: serverTimestamp(), before: null, after: data,
  });
  batch.set(db.doc(`assets/${id}`), { ...data, lastAuditId: audit.id });
  return batch.commit();
}

test('admins replace ingredient images and add product photos', async () => {
  const m = staff('menu_manager', 'mgr1');
  await assertSucceeds(saveAsset(m, 'mgr1', 'ing_i1', asset('ing_i1', 'ingredient', 2)));
  // Version must go up by one; layer order and categories never change.
  await assertFails(saveAsset(m, 'mgr1', 'ing_i1', asset('ing_i1', 'ingredient', 2)));
  await assertFails(saveAsset(m, 'mgr1', 'ing_i1', asset('ing_i1', 'ingredient', 3, { layerOrder: 99 })));
  // Only our Cloudinary account.
  await assertFails(saveAsset(m, 'mgr1', 'ing_i1', asset('ing_i1', 'ingredient', 3, {
    secureUrl: 'https://evil.example/x.webp',
  })));
  // Bases are the developer's.
  await assertFails(saveAsset(m, 'mgr1', 'base_x', asset('base_x', 'base', 2)));
  // A product's first photo.
  await assertSucceeds(saveAsset(m, 'mgr1', 'final_p1', asset('final_p1', 'final', 1)));
  await assertFails(saveAsset(m, 'mgr1', 'new_ing', asset('new_ing', 'ingredient', 1)));
  await assertFails(saveAsset(staff('reception', 'rec1'), 'rec1', 'final_p2', asset('final_p2', 'final', 1)));
  await assertFails(m.doc('assets/ing_i1').delete());
});
