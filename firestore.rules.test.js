const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');

const PROJECT_ID = 'genz-dictionary-rules-test';

async function runTest(name, fn) {
  try {
    await fn();
    console.log(`PASS ${name}`);
  } catch (err) {
    console.error(`FAIL ${name}`);
    throw err;
  }
}

async function main() {
  const testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, 'firestore.rules'), 'utf8'),
    },
  });

  try {
    await runTest('owner can update own displayId fields', async () => {
      await testEnv.clearFirestore();
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection('users').doc('u1').set({
          displayId: 'old_name',
          displayIdLower: 'old_name',
        });
      });

      const u1db = testEnv.authenticatedContext('u1').firestore();
      await assertSucceeds(
        u1db.collection('users').doc('u1').update({
          displayId: 'RizzBoss',
          displayIdLower: 'rizzboss',
        }),
      );
    });

    await runTest(
      'non-participant cannot write battle history for others',
      async () => {
        await testEnv.clearFirestore();
        await testEnv.withSecurityRulesDisabled(async (ctx) => {
          const db = ctx.firestore();
          await db.collection('battle_lobbies').doc('ABC123').set({
            hostId: 'hostA',
            guestId: 'guestB',
            status: 'finished',
            scores: { hostA: 4, guestB: 2 },
            questions: ['q1', 'q2'],
          });
        });

        const intruderDb = testEnv.authenticatedContext('intruder').firestore();
        await assertFails(
          intruderDb
            .collection('users')
            .doc('hostA')
            .collection('battle_history')
            .doc('ABC123')
            .set({
              uid: 'hostA',
              hostId: 'hostA',
              guestId: 'guestB',
              lobbyCode: 'ABC123',
              myScore: 4,
              opponentScore: 2,
              outcome: 'win',
              recordedAt: new Date(),
            }),
        );
      },
    );

    await runTest(
      'non-participant cannot change lobby status to started',
      async () => {
        await testEnv.clearFirestore();
        await testEnv.withSecurityRulesDisabled(async (ctx) => {
          const db = ctx.firestore();
          await db.collection('battle_lobbies').doc('LOCK01').set({
            hostId: 'hostA',
            guestId: 'guestB',
            status: 'active',
            currentIndex: 0,
            questions: ['q1'],
            answers: {},
            locked: {},
            options: {},
          });
        });

        const intruderDb = testEnv.authenticatedContext('intruder').firestore();
        await assertFails(
          intruderDb.collection('battle_lobbies').doc('LOCK01').update({
            status: 'started',
          }),
        );
      },
    );

    await runTest('host can move active lobby to started', async () => {
      await testEnv.clearFirestore();
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await db.collection('battle_lobbies').doc('GOOD01').set({
          hostId: 'hostA',
          guestId: 'guestB',
          status: 'active',
          currentIndex: 0,
          questions: ['q1'],
          answers: {},
          locked: {},
          options: {},
        });
      });

      const hostDb = testEnv.authenticatedContext('hostA').firestore();
      await assertSucceeds(
        hostDb.collection('battle_lobbies').doc('GOOD01').update({
          status: 'started',
        }),
      );
    });

    await runTest(
      'battle stats write is denied when lobby linkage is invalid',
      async () => {
        await testEnv.clearFirestore();
        await testEnv.withSecurityRulesDisabled(async (ctx) => {
          const db = ctx.firestore();
          await db.collection('battle_lobbies').doc('REAL01').set({
            hostId: 'hostA',
            guestId: 'guestB',
            status: 'finished',
            currentIndex: 1,
            questions: ['q1', 'q2'],
            answers: {},
            locked: {},
            options: {},
          });
        });

        const hostDb = testEnv.authenticatedContext('hostA').firestore();
        await assertFails(
          hostDb
            .collection('users')
            .doc('hostA')
            .collection('battle_stats')
            .doc('main')
            .set({
              lastLobbyCode: 'FAKE01',
              participants: ['hostA', 'guestB'],
              gamesPlayed: 999,
            }),
        );
      },
    );

    await runTest('signed-in user can write _time_sync helper doc', async () => {
      await testEnv.clearFirestore();
      const u1db = testEnv.authenticatedContext('u1').firestore();
      await assertSucceeds(
        u1db.collection('battle_lobbies').doc('_time_sync').set({
          ts: new Date(),
        }),
      );
    });
  } finally {
    await testEnv.cleanup();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
