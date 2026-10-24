// P1-A04: Firestore security rules tests (run against the emulator).
import { after, before, beforeEach, test } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-menova',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});

after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc('products/p1').set({ name: 'p', basePrice: 100 });
    await db.doc('categoryContent/c1').set({ isVisible: true });
    await db.doc('ingredients/i1').set({ extraPrice: 10 });
    await db.doc('assets/a1').set({ secureUrl: 'x' });
    await db.doc('orders/o1').set({ customerUid: 'guest1', total: 100 });
  });
});

const guest = (uid = 'guest1') => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();
const staff = (role) =>
  env.authenticatedContext('staff1', { role }).firestore();

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

test('clients cannot create or edit orders (SEC-01)', async () => {
  for (const db of [anon(), guest(), staff('reception'), staff('kitchen')]) {
    await assertFails(db.doc('orders/o2').set({ total: 1 }));
    await assertFails(db.doc('orders/o1').update({ status: 'ready' }));
  }
});

test('guest reads only their own order', async () => {
  await assertSucceeds(guest('guest1').doc('orders/o1').get());
  await assertFails(guest('guest2').doc('orders/o1').get());
  await assertFails(anon().doc('orders/o1').get());
});

test('reception and kitchen staff read orders; other roles do not', async () => {
  await assertSucceeds(staff('reception').doc('orders/o1').get());
  await assertSucceeds(staff('kitchen').collection('orders').get());
  await assertFails(staff('admin').collection('orders').get());
  await assertFails(guest('guest1').collection('orders').get());
});

test('unknown collections are closed', async () => {
  await assertFails(anon().doc('secrets/x').get());
  await assertFails(guest().doc('secrets/x').set({ a: 1 }));
});
