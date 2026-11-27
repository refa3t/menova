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

test('the owner reads a period of orders by server time (P3-08)', async () => {
  const from = Timestamp.fromMillis(Date.now() - 7 * 864e5);
  const to = Timestamp.fromMillis(Date.now() + 864e5);
  const period = (db) =>
    db.collection('orders')
      .where('serverCreatedAt', '>=', from)
      .where('serverCreatedAt', '<', to)
      .get();
  const snap = await assertSucceeds(period(staff('owner')));
  assert.equal(snap.size, 1);
  await assertFails(period(staff('menu_manager', 'mgr1')));
  await assertFails(period(guest('guest1')));
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
  // Reusing an earlier audit entry (still stored) does not count.
  await assertFails(owner.doc('products/p9').update({ basePrice: 1500 }));
});

// Owner price caps, in piasters (also PriceCaps in the admin panel): each
// size 0 < base + delta <= 1000 EGP, size deltas >= 0, options 0..200 EGP.
test('product prices stay within the caps', async () => {
  const owner = staff('owner', 'own1');
  const ok = (o) => assertSucceeds(saveProduct(owner, 'own1', 'p9', product('p9', o)));
  const no = (o) => assertFails(saveProduct(owner, 'own1', 'p9', product('p9', o)));
  await ok({ basePrice: 100000 }); // exactly 1000 EGP
  await no({ basePrice: 100001 }); // 1000.01 EGP
  await no({ basePrice: 0 });
  await ok({ basePrice: 1 });
  await ok({ basePrice: 90000, sizeDeltas: { s: 0, m: 5000, l: 10000 } });
  await no({ basePrice: 90000, sizeDeltas: { s: 0, m: 5000, l: 10001 } });
  await no({ sizeDeltas: { s: -1 } });
  await no({ sizeDeltas: { s: 50.5 } }); // whole piasters only
  await ok({ optionDeltas: { a: 0, b: 20000 } }); // exactly 200 EGP
  await no({ optionDeltas: { b: 20001 } });
  await no({ optionDeltas: { b: -1 } });
  // Up to 6 sizes and 8 options, every one checked.
  const six = { a: 0, b: 0, c: 0, d: 0, e: 0, f: 0 };
  await ok({ sizeDeltas: six });
  await no({ sizeDeltas: { ...six, f: 87001 } }); // 13000 + 87001 > cap
  await no({ sizeDeltas: { ...six, g: 0 } });
  const eight = { ...six, g: 0, h: 0 };
  await ok({ optionDeltas: eight });
  await no({ optionDeltas: { ...eight, h: 20001 } });
  await no({ optionDeltas: { ...eight, i: 0 } });
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
  // Extra price cap: above zero and at most 200 EGP.
  await assertSucceeds(saveIngredient(manager, 'mgr1', 'i1', { ...ing, extraPrice: 20000 }));
  await assertSucceeds(saveIngredient(manager, 'mgr1', 'i1', { ...ing, extraPrice: 1 }));
  await assertFails(saveIngredient(manager, 'mgr1', 'i1', { ...ing, extraPrice: 20001 }));
  await assertFails(saveIngredient(manager, 'mgr1', 'i1', { ...ing, extraPrice: 0 }));
  await assertFails(saveIngredient(manager, 'mgr1', 'i9', { ...ing, id: 'i9' }));
  await assertFails(manager.doc('ingredients/i1').set({ ...ing, lastAuditId: 'nope' }));
  await assertFails(saveIngredient(staff('reception', 'rec1'), 'rec1', 'i1', ing));
  await assertFails(manager.doc('ingredients/i1').delete());
});

// Bulk availability from the admin lists: one batch, each record with its
// own audit entry (AuditedWriter.writeAll, maxChangesPerBatch = 10). The
// rules read each entry, and a batch may read at most 20 documents, so 20
// records pass and 21 do not.
async function bulkSave(db, uid, collection, action, records) {
  const batch = db.batch();
  for (const data of records) {
    const audit = db.collection('auditLog').doc();
    batch.set(audit, {
      action, target: `${collection}/${data.id}`, by: uid,
      at: serverTimestamp(), before: null, after: data,
    });
    batch.set(db.doc(`${collection}/${data.id}`), { ...data, lastAuditId: audit.id });
  }
  return batch.commit();
}

test('bulk availability: a batch of audited saves passes, one entry each', async () => {
  const manager = staff('menu_manager', 'mgr1');
  const products = (n, tag) =>
    Array.from({ length: n }, (_, i) => product(`${tag}${i}`, { isAvailable: false }));
  await assertSucceeds(bulkSave(manager, 'mgr1', 'products', 'saveProduct', products(10, 'a')));
  await assertSucceeds(bulkSave(manager, 'mgr1', 'products', 'saveProduct', products(20, 'b')));
  await assertFails(bulkSave(manager, 'mgr1', 'products', 'saveProduct', products(21, 'c')));
  // One record without its own entry fails the whole batch.
  const audit = manager.collection('auditLog').doc();
  const batch = manager.batch();
  batch.set(audit, {
    action: 'saveProduct', target: 'products/d0', by: 'mgr1',
    at: serverTimestamp(), before: null, after: product('d0'),
  });
  batch.set(manager.doc('products/d0'), { ...product('d0'), lastAuditId: audit.id });
  batch.set(manager.doc('products/d1'), { ...product('d1'), lastAuditId: audit.id });
  await assertFails(batch.commit());

  const ingredients = Array.from({ length: 10 }, (_, i) => ({
    id: `i${i}`, name: 'TEMP', names: { ar: 'TEMP' }, assetId: 'ing_i1',
    extraPrice: 1500, isAvailable: false, sizeMultipliers: {},
  }));
  await env.withSecurityRulesDisabled(async (ctx) => {
    for (const ing of ingredients) await ctx.firestore().doc(`ingredients/${ing.id}`).set(ing);
  });
  await assertSucceeds(bulkSave(manager, 'mgr1', 'ingredients', 'saveIngredient', ingredients));
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

// P3-05: categories (visibility/order) by admins, store settings by the owner.
async function auditedSet(db, uid, path, data) {
  const audit = db.collection('auditLog').doc();
  const batch = db.batch();
  batch.set(audit, {
    action: 'save', target: path, by: uid, at: serverTimestamp(),
    before: null, after: data,
  });
  batch.set(db.doc(path), { ...data, lastAuditId: audit.id });
  return batch.commit();
}

test('admins show, hide and order defined categories only', async () => {
  const m = staff('menu_manager', 'mgr1');
  await assertSucceeds(auditedSet(m, 'mgr1', 'categoryContent/c1',
    { isVisible: false, displayOrder: 2 }));
  await assertFails(auditedSet(m, 'mgr1', 'categoryContent/c1',
    { isVisible: true, displayOrder: 2, name: 'x' }));
  await assertFails(auditedSet(m, 'mgr1', 'categoryContent/new',
    { isVisible: true, displayOrder: 0 }));
  await assertFails(m.doc('categoryContent/c1').update({ isVisible: true }));
});

test('only the owner changes the store settings', async () => {
  const store = {
    location: { lat: 30.46, lng: 31.18 },
    delivery: { perKm: 700, minFee: 3000, maxDistanceMeters: 12000 },
  };
  await assertSucceeds(auditedSet(staff('owner', 'own1'), 'own1', 'settings/store', store));
  await assertFails(auditedSet(staff('menu_manager', 'mgr1'), 'mgr1', 'settings/store', store));
  await assertFails(auditedSet(staff('owner', 'own1'), 'own1', 'settings/store',
    { ...store, delivery: { ...store.delivery, perKm: -1 } }));
  await assertFails(auditedSet(staff('owner', 'own1'), 'own1', 'settings/store',
    { ...store, location: { lat: 120, lng: 31 } }));
});

// P3-09: offers and coupons (core Offer, every key written).
function offer(id, overrides = {}) {
  return {
    id, name: 'TEMP offer', names: {}, kind: 'percent', value: 10,
    categoryId: null, minSubtotal: 0, maxDiscount: null,
    startsAtMs: null, endsAtMs: null, isActive: true,
    code: null, maxUses: null, uses: 0,
    ...overrides,
  };
}

function coupon(code, overrides = {}) {
  return offer(code, { code, maxUses: 2, ...overrides });
}

// The frozen snapshot an order keeps (core OrderOffer).
function snapshot(o) {
  return {
    id: o.id, name: o.name, kind: o.kind, value: o.value,
    categoryId: o.categoryId, minSubtotal: o.minSubtotal,
    maxDiscount: o.maxDiscount, code: o.code,
  };
}

// 115 EGP of items with [o] taking [discount] off.
function withOffer(o, discount, overrides = {}) {
  return { offer: snapshot(o), discount, total: 11500 - discount, ...overrides };
}

async function seed(path, data) {
  await env.withSecurityRulesDisabled((ctx) => ctx.firestore().doc(path).set(data));
}

test('admins manage offers and coupons, audited (P3-09)', async () => {
  const m = staff('menu_manager', 'mgr1');
  await assertSucceeds(auditedSet(m, 'mgr1', 'offers/o9', offer('o9')));
  await assertSucceeds(auditedSet(m, 'mgr1', 'offers/o9',
    offer('o9', { kind: 'amount', value: 2000, categoryId: 'c1' })));
  await assertSucceeds(auditedSet(staff('owner', 'own1'), 'own1',
    'coupons/EID-26', coupon('EID-26')));
  await assertFails(auditedSet(staff('reception', 'rec1'), 'rec1',
    'offers/o8', offer('o8')));
  await assertFails(auditedSet(m, 'mgr1', 'offers/o8', offer('o8', { value: 150 })));
  await assertFails(auditedSet(m, 'mgr1', 'offers/o8',
    offer('o8', { kind: 'amount', value: 50 })), 'at least 1 EGP');
  await assertFails(auditedSet(m, 'mgr1', 'offers/o8',
    offer('o8', { categoryId: 'nope' })), 'a defined category');
  await assertFails(auditedSet(m, 'mgr1', 'offers/o8',
    offer('o8', { startsAtMs: 5, endsAtMs: 5 })), 'ends after it starts');
  await assertFails(auditedSet(m, 'mgr1', 'offers/o8',
    offer('o8', { code: 'ABC' })), 'a coupon is not an automatic offer');
  await assertFails(auditedSet(m, 'mgr1', 'coupons/eid', coupon('eid')),
    'codes are upper case');
  await assertFails(auditedSet(m, 'mgr1', 'coupons/ABC', coupon('ABD')),
    'the id is the code');
  await assertFails(auditedSet(m, 'mgr1', 'coupons/ABC',
    coupon('ABC', { uses: 3 })), 'a new coupon starts unused');
  await assertFails(m.doc('offers/o9').update({ value: 20 }), 'not audited');
  await assertFails(m.doc('offers/o9').delete());
});

test('offers are public; a coupon is read only by its exact code', async () => {
  await seed('offers/o1', offer('o1'));
  await seed('coupons/SAVE10', coupon('SAVE10'));
  await assertSucceeds(anon().collection('offers').where('isActive', '==', true).get());
  await assertSucceeds(anon().doc('coupons/SAVE10').get());
  await assertFails(anon().collection('coupons').get());
  await assertFails(guest('g1').collection('coupons').get());
  await assertSucceeds(staff('menu_manager', 'mgr1').collection('coupons').get());
});

test('an order gets a live offer, within its bounds', async () => {
  const g = guest('g5');
  await seed('offers/o1', offer('o1'));
  // 10% of 115 EGP is 11.5, rounded once to 12.
  await assertSucceeds(g.doc('orders/f1').set(newOrder('f1', 'g5', withOffer(offer('o1'), 1200))));
  await assertFails(g.doc('orders/f2').set(newOrder('f2', 'g5', withOffer(offer('o1'), 1300))),
    'more than the percent');
  await assertFails(g.doc('orders/f2').set(newOrder('f2', 'g5',
    withOffer(offer('o1', { value: 20 }), 2300))), 'the snapshot matches the live offer');
  await assertFails(g.doc('orders/f2').set(newOrder('f2', 'g5', { offer: snapshot(offer('o1')) })),
    'discount and offer go together');
  await assertFails(g.doc('orders/f2').set(newOrder('f2', 'g5', withOffer(offer('missing'), 1200))),
    'an offer that does not exist');

  await seed('offers/o2', offer('o2', { isActive: false }));
  await assertFails(g.doc('orders/f3').set(newOrder('f3', 'g5', withOffer(offer('o2'), 1200))),
    'stopped');
  await seed('offers/o3', offer('o3', { endsAtMs: Date.now() - 60000 }));
  await assertFails(g.doc('orders/f3').set(newOrder('f3', 'g5', withOffer(offer('o3'), 1200))),
    'ended');
  const minimum = offer('o4', { kind: 'amount', value: 2000, minSubtotal: 20000 });
  await seed('offers/o4', minimum);
  await assertFails(g.doc('orders/f3').set(newOrder('f3', 'g5', withOffer(minimum, 2000))),
    'below the minimum order');
  const amount = offer('o6', { kind: 'amount', value: 2000 });
  await seed('offers/o6', amount);
  await assertFails(g.doc('orders/f3').set(newOrder('f3', 'g5', withOffer(amount, 2500))),
    'more than the amount');

  // Free delivery takes exactly the fee: items stay at 115 EGP.
  const free = offer('o5', { kind: 'freeDelivery', value: 0 });
  await seed('offers/o5', free);
  await assertSucceeds(g.doc('orders/f5').set(newOrder('f5', 'g5',
    { ...delivery(4300, 3000), offer: snapshot(free), discount: 3000, total: 11500 })));
  await assertFails(g.doc('orders/f6').set(newOrder('f6', 'g5',
    { ...delivery(4300, 3000), offer: snapshot(free), discount: 2000, total: 12500 })));
});

test('a coupon counts each order once, up to its limit', async () => {
  const g = guest('g6');
  const c = coupon('SAVE10', { kind: 'amount', value: 1000, maxUses: 1 });
  await seed('coupons/SAVE10', c);
  const order = (id) => newOrder(id, 'g6', withOffer(c, 1000));
  await assertFails(g.doc('orders/c1').set(order('c1')), 'the use must be counted');
  await assertFails(g.doc('coupons/SAVE10').update({ uses: 1, lastOrderId: 'c9' }),
    'no use without its order');
  const first = g.batch();
  first.set(g.doc('orders/c1'), order('c1'));
  first.update(g.doc('coupons/SAVE10'), { uses: 1, lastOrderId: 'c1' });
  await assertSucceeds(first.commit());
  const second = g.batch();
  second.set(g.doc('orders/c2'), order('c2'));
  second.update(g.doc('coupons/SAVE10'), { uses: 2, lastOrderId: 'c2' });
  await assertFails(second.commit(), 'used up');

  // The admin edits the coupon but never its count.
  const m = staff('menu_manager', 'mgr1');
  await assertSucceeds(auditedSet(m, 'mgr1', 'coupons/SAVE10', { ...c, maxUses: 5, uses: 1 }));
  await assertFails(auditedSet(m, 'mgr1', 'coupons/SAVE10', { ...c, maxUses: 5, uses: 0 }));

  // With uses left, one order still counts only one use.
  const twice = g.batch();
  twice.set(g.doc('orders/c3'), order('c3'));
  twice.update(g.doc('coupons/SAVE10'), { uses: 3, lastOrderId: 'c3' });
  await assertFails(twice.commit(), 'one use per order');
});

// P3-09: drafts, saved and published by admins only.
function draft(target, uid, overrides = {}) {
  return {
    target, kind: target.startsWith('products/') ? 'product' : 'ingredient',
    isNew: false, changes: { basePrice: 14000 }, base: { basePrice: 13000 },
    by: uid, at: serverTimestamp(),
    ...overrides,
  };
}

test('admins keep drafts; customers and staff never see them (P3-09)', async () => {
  const m = staff('menu_manager', 'mgr1');
  await assertSucceeds(m.doc('drafts/products__p1').set(draft('products/p1', 'mgr1')));
  await assertSucceeds(staff('owner', 'own1').doc('drafts/products__p1')
    .set(draft('products/p1', 'own1', { changes: { basePrice: 15000 } })));
  await assertSucceeds(m.doc('drafts/ingredients__i1').set(draft('ingredients/i1', 'mgr1')));
  await assertSucceeds(m.collection('drafts').get());
  await assertFails(guest('g1').collection('drafts').get());
  await assertFails(staff('reception', 'rec1').doc('drafts/products__p1').get());
  await assertFails(staff('reception', 'rec1').doc('drafts/products__p2')
    .set(draft('products/p2', 'rec1')));
  await assertFails(m.doc('drafts/x').set(draft('products/p1', 'mgr1')), 'one draft per record');
  await assertFails(m.doc('drafts/offers__o1').set(draft('offers/o1', 'mgr1')),
    'products and ingredients only');
  await assertFails(m.doc('drafts/products__p3').set(draft('products/p3', 'mgr1',
    { kind: 'ingredient' })), 'the kind follows the target');
  await assertFails(m.doc('drafts/products__p3').set(draft('products/p3', 'own1')),
    'saved under its own name');
  await assertSucceeds(m.doc('drafts/products__p1').delete());
});

test('publishing a draft is an audited save that drops the draft', async () => {
  const m = staff('menu_manager', 'mgr1');
  await m.doc('drafts/products__p9').set(draft('products/p9', 'mgr1', { isNew: true }));
  const audit = m.collection('auditLog').doc();
  const batch = m.batch();
  batch.set(audit, {
    action: 'saveProduct', target: 'products/p9', by: 'mgr1',
    at: serverTimestamp(), before: null, after: product('p9'),
  });
  batch.set(m.doc('products/p9'), { ...product('p9'), lastAuditId: audit.id });
  batch.delete(m.doc('drafts/products__p9'));
  await assertSucceeds(batch.commit());
  const left = await m.collection('drafts').get();
  assert.equal(left.size, 0);
});

// P3-01: staff records. The owner grants reception, kitchen or menu_manager
// by email (staff/{lowercased email}), audited; a record counts only for a
// signed-in account whose email is verified, and never grants owner.
const person = (uid, email, verified = true) =>
  env.authenticatedContext(uid, { email, email_verified: verified }).firestore();

async function saveStaff(db, uid, email, role, overrides = {}) {
  const audit = db.collection('auditLog').doc();
  const batch = db.batch();
  batch.set(audit, {
    action: 'saveStaff', target: `staff/${email}`, by: uid,
    at: serverTimestamp(), before: null, after: { role },
  });
  batch.set(db.doc(`staff/${email}`), {
    role, addedBy: uid, addedAt: serverTimestamp(), lastAuditId: audit.id,
    ...overrides,
  });
  return batch.commit();
}

async function removeStaff(db, uid, email, auditId) {
  const batch = db.batch();
  batch.set(db.doc(`auditLog/${auditId}`), {
    action: 'removeStaff', target: `staff/${email}`, by: uid,
    at: serverTimestamp(), before: null, after: {},
  });
  batch.delete(db.doc(`staff/${email}`));
  return batch.commit();
}

const readOrder = (db) => db.doc('orders/o1').get();

test('a verified staff record grants its role; an unverified one does not', async () => {
  const owner = staff('owner', 'own1');
  await assertSucceeds(saveStaff(owner, 'own1', 'rec@x.com', 'reception'));
  await assertSucceeds(saveStaff(owner, 'own1', 'mgr@x.com', 'menu_manager'));
  // Reception: reads and updates orders.
  await assertSucceeds(readOrder(person('r1', 'rec@x.com')));
  await assertSucceeds(readOrder(person('r1', 'REC@x.com')), 'email case');
  await assertSucceeds(person('r1', 'rec@x.com').doc('orders/o1').update({
    status: 'accepted', history: [{ ...entry('status', 'accepted'), by: 'r1' }],
  }));
  await assertFails(readOrder(person('r2', 'rec@x.com', false)), 'unverified');
  await assertFails(readOrder(person('r3', 'other@x.com')), 'no record');
  await assertFails(readOrder(env.authenticatedContext('r4').firestore()), 'no email');
  // Menu manager: admin writes, but not the orders or owner areas.
  const mgr = person('m1', 'mgr@x.com');
  await assertSucceeds(saveProduct(mgr, 'm1', 'p9', product('p9')));
  await assertFails(saveProduct(person('m2', 'mgr@x.com', false), 'm2', 'p8', product('p8')));
  await assertFails(readOrder(mgr), 'menu manager is not reception');
  await assertFails(mgr.collection('auditLog').get(), 'owner only');
  // Each reads their own record (even unverified: the login screen asks
  // them to verify), nobody else's; only the owner lists them.
  await assertSucceeds(person('r2', 'rec@x.com', false).doc('staff/rec@x.com').get());
  await assertFails(person('r1', 'rec@x.com').doc('staff/mgr@x.com').get());
  await assertFails(person('r1', 'rec@x.com').collection('staff').get());
  await assertSucceeds(owner.collection('staff').get());
});

test('only the owner writes staff records, audited and in shape', async () => {
  const owner = staff('owner', 'own1');
  await assertSucceeds(saveStaff(owner, 'own1', 'mgr@x.com', 'menu_manager'));
  // Not the owner: a menu manager (record or claim), reception, a guest.
  await assertFails(saveStaff(person('m1', 'mgr@x.com'), 'm1', 'new@x.com', 'reception'));
  await assertFails(saveStaff(staff('menu_manager', 'mgr9'), 'mgr9', 'new@x.com', 'reception'));
  await assertFails(saveStaff(staff('reception', 'rec1'), 'rec1', 'new@x.com', 'kitchen'));
  await assertFails(saveStaff(guest(), 'guest1', 'new@x.com', 'kitchen'));
  // Nobody changes their own record.
  await assertFails(saveStaff(person('m1', 'mgr@x.com'), 'm1', 'mgr@x.com', 'reception'));
  // Bad shape: unknown role, no audit, someone else as adder, upper case id,
  // not an email, extra field.
  await assertFails(saveStaff(owner, 'own1', 'new@x.com', 'admin'));
  await assertFails(owner.doc('staff/new@x.com').set({
    role: 'kitchen', addedBy: 'own1', addedAt: serverTimestamp(), lastAuditId: 'nope',
  }));
  await assertFails(saveStaff(owner, 'own1', 'new@x.com', 'kitchen', { addedBy: 'mgr1' }));
  await assertFails(saveStaff(owner, 'own1', 'New@x.com', 'kitchen'));
  await assertFails(saveStaff(owner, 'own1', 'not-an-email', 'kitchen'));
  await assertFails(saveStaff(owner, 'own1', 'new@x.com', 'kitchen', { extra: 1 }));
  // Changing a role is the same audited write.
  await assertSucceeds(saveStaff(owner, 'own1', 'mgr@x.com', 'kitchen'));
});

test('the owner role can never come from a staff record', async () => {
  const owner = staff('owner', 'own1');
  await assertFails(saveStaff(owner, 'own1', 'boss@x.com', 'owner'));
  // Even one written past the rules (console) grants nothing.
  await env.withSecurityRulesDisabled((ctx) =>
    ctx.firestore().doc('staff/boss@x.com').set({ role: 'owner' }));
  const boss = person('b1', 'boss@x.com');
  await assertFails(readOrder(boss));
  await assertFails(boss.collection('auditLog').get());
  await assertFails(saveStaff(boss, 'b1', 'new@x.com', 'reception'));
  await assertFails(saveProduct(boss, 'b1', 'p9', product('p9')));
});

test('removing a staff record revokes access, audited', async () => {
  const owner = staff('owner', 'own1');
  await saveStaff(owner, 'own1', 'rec@x.com', 'reception');
  const rec = person('r1', 'rec@x.com');
  await assertSucceeds(readOrder(rec));
  const { lastAuditId } = (await owner.doc('staff/rec@x.com').get()).data();
  // Not the owner, no audit entry, or the wrong one.
  await assertFails(removeStaff(rec, 'r1', 'rec@x.com', `remove_${lastAuditId}`));
  await assertFails(owner.doc('staff/rec@x.com').delete());
  await assertFails(removeStaff(owner, 'own1', 'rec@x.com', 'remove_other'));
  await assertSucceeds(removeStaff(owner, 'own1', 'rec@x.com', `remove_${lastAuditId}`));
  await assertFails(readOrder(rec));
});
